"""Generate the two dungeon dive-row overlays: fog of war, and the stairs down.

design/LordofHirelings_ArtAssetList.md section 3, the last two dive-row entries,
both MVP:

- "Fog of war treatment | Hides the unexplored right side of each dungeon row. |
  Soft-edged darkness rolling back as the party advances. Can be a
  shader/gradient; optional pixel-noise edge texture to keep it in style. | MVP
  (gradient), Later (styled edge)"
- "Stairs down | Revealed when a level's boss dies (visual only -- never
  descended). | Stone stairway descending into darkness, fitted to each biome or
  one neutral version with biome tint. | MVP"

GDD line 33 is what both serve: "Each party moves left to right through its row,
exposing the fog of war as it advances", and "Defeating the boss exposes the
stairs down to the next dungeon level ... The stairs are a flavorful visual
depiction of the unlock only -- the party does not descend them."

Both sit on the 320x128 biome row backdrops from generate_biome_backdrops.py
(HORIZON at y=56, 72px of floor beneath it, horizontally tileable), so the
preview composites them over that real art rather than over a flat fill.

Style guide (design/LordofHirelings_ArtStyleGuide.md) rules that shape this:
- §5: "The fog of war ramps to #101014, matching UI shadow -- it reads as 'UI
  curtain,' not world." That is the whole brief for the fog: one color, one
  alpha ramp, no hue of its own. A fog that tinted toward its biome would read
  as weather the party is walking through; this has to read as the screen
  withholding information.
- §2: dithering is banned on sprites but "allowed on large background gradients
  (sky) only". The fog IS that gradient, so its alpha is quantized to 12 steps
  and ordered-dithered (Bayer 4x4) between them rather than left as a smooth
  256-level ramp. A smooth ramp is what the asset list literally asks for at MVP
  and it renders fine -- it just doesn't look drawn, and the one thing on screen
  that isn't pixel art is the thing you notice. This stays a gradient; the
  "styled pixel-noise edge" the asset list defers to Later is a different, more
  invasive thing (an irregular noise-shaped boundary), and is not attempted here.
- §3: "Backgrounds, backdrops, and tiles get NO outline" -- the stairs are
  scenery the party never touches, not an interactable prop, so they get form and
  value only. Their read against the biome is carried from both ends instead: the
  near-black stairwell separates them from the light biomes (forest grass), and
  the lit stone rim separates them from the dark ones (volcanic basalt). Either
  one alone would vanish on half the levels.
- §4: light from the top, biased left. The pit's LEFT inner wall faces right, into
  the light, so it is the lit one; the right inner wall is in shadow.
- §7: no window-blind effect -- the rim's masonry joints are hash-placed at varied
  spacing, and the treads compress as they recede instead of marching evenly.

Output: lord-of-hirelings/sprites/dungeon/fog_of_war_edge.png  (80x128)
        lord-of-hirelings/sprites/dungeon/stairs_down.png       (64x48)
        SourceArt/previews/dive_row_overlays_preview_3x.png     (for review)
"""
import os
from PIL import Image

# The biome row geometry these overlays sit on (generate_biome_backdrops.py).
ROW_W = 320
ROW_H = 128

# Ordered dither matrix, shared with the biome backdrops (§2 allows it here).
BAYER4 = (
    (0, 8, 2, 10),
    (12, 4, 14, 6),
    (3, 11, 1, 9),
    (15, 7, 13, 5),
)

# §5: the fog ramps to this exact value -- it is the UI shadow color, not a
# world color, which is what sells it as a curtain over the row.
DARK = (0x10, 0x10, 0x14, 255)

# --- Fog of war --------------------------------------------------------------
FOG_RAMP_W = 64     # the soft edge itself
FOG_TAIL_W = 16     # solid #101014; the consumer stretches/repeats this to the
                    # row's right edge, so the asset never has to know row width
FOG_W = FOG_RAMP_W + FOG_TAIL_W
FOG_H = ROW_H
FOG_STEPS = 12      # quantization levels the dither mixes between

# --- Stairs down -------------------------------------------------------------
ST_W = 64
ST_H = 48           # a hair shorter than a 48px combatant: a landmark, not a set
ST_Y_NEAR = 42      # near lip of the pit
ST_Y_FAR = 6        # far lip; everything between is the descent
ST_HW_NEAR = 24
ST_HW_FAR = 16      # converges as it recedes -- the only perspective cue
ST_FRAME = 4        # dressed-stone rim around the opening

# Only four steps, and they are chunky. A first pass ran eight with the value
# falling on a curve, and it read as a bathtub: the curve had spent its whole
# range by step three, so the back five were one indistinguishable smudge and
# the 1px risers inside them never separated. Steps are legible from flat treads
# with hard risers between them, not from a smooth ramp -- so the treads are an
# explicit 4-value ramp, each flat, and everything past the last one is simply
# void. Heights compress as they recede (§7: never an even march).
ST_STEP_HEIGHTS = (9, 7, 6, 5)
ST_TREADS = (
    (172, 176, 186, 255),
    (130, 134, 144, 255),
    (92, 96, 106, 255),
    (58, 61, 70, 255),
)

# Neutral stone ramp for the rim. Authored deliberately BRIGHT for a backdrop
# element: every real use multiplies a biome tint through it (modulate), and
# multiply only ever darkens, so the neutral base has to sit above the §5
# backdrop band for the tinted result to land inside it. The untinted PNG is
# never what ships on screen.
ST_LIT = (168, 172, 182, 255)
ST_MID = (130, 134, 144, 255)
ST_SHA = (92, 96, 106, 255)
ST_DEEP = (54, 57, 66, 255)

# Per-biome modulate values for the one neutral stairway, matched to §2's color
# script (1 high-key green, 2 murk gray-green, 3 cold blue-green, 4 warm basalt).
# The dive scene does not exist yet; when it does and it wires the modulate, these
# belong in data/balance.csv as tunables. They live here for now because nothing
# reads them yet, and this is the file that proves them against the real biomes.
BIOME_TINTS = (
    ("forest", (216, 220, 200)),
    ("swamp", (176, 184, 156)),
    ("crypt", (152, 170, 180)),
    ("volcanic", (180, 130, 106)),
)


def rnd(seed, i):
    """Stable hash noise -- same generator as the biome backdrops, so joints
    regenerate identically on every run."""
    v = ((i + 1) * 1103515245 + seed * 12345) & 0x7FFFFFFF
    v ^= v >> 13
    v = (v * 2654435761) & 0x7FFFFFFF
    return v / float(0x7FFFFFFF)


def lerp(a, b, t):
    """Blend two RGBA colors. t=0 -> a, t=1 -> b. Alpha rides along."""
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(4))


class Sprite:
    """Pixel buffer that does NOT wrap -- unlike the biome Scene, these are
    finite sprites with transparent surrounds, not tiling scenes."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = {}

    def put(self, x, y, c):
        x, y = int(x), int(y)
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[(x, y)] = c

    def hline(self, x0, x1, y, c):
        for x in range(int(x0), int(x1) + 1):
            self.put(x, y, c)

    def image(self):
        img = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        for (x, y), c in self.px.items():
            img.putpixel((x, y), c)
        return img


def draw_fog():
    """A vertical curtain whose alpha ramps 0 -> 255 left to right, in #101014.

    Every column is uniform in y on purpose. It costs nothing at MVP (the brief
    is a plain gradient) and it buys the consumer a lot: the dive splits the
    screen into up to 3 equal rows, so row height is a runtime number, and a
    y-uniform texture tiles or stretches vertically to any of them with no
    distortion. The Bayer dither still gives the ramp per-row texture -- each
    column samples 4 thresholds down the matrix -- and 128 is a multiple of 4, so
    the dither tiles vertically too.
    """
    img = Image.new("RGBA", (FOG_W, FOG_H), (DARK[0], DARK[1], DARK[2], 0))
    for x in range(FOG_W):
        if x >= FOG_RAMP_W:
            lo = hi = FOG_STEPS - 1                  # solid tail
            frac = 0.0
        else:
            t = x / float(FOG_RAMP_W - 1)
            t = t * t * (3.0 - 2.0 * t)              # smoothstep: the leading
            # edge feathers out to nothing instead of arriving as a visible line,
            # which is what "rolling back" needs to look like in motion.
            f = t * (FOG_STEPS - 1)
            lo = min(int(f), FOG_STEPS - 2)
            hi = lo + 1
            frac = f - lo
        for y in range(FOG_H):
            th = (BAYER4[y % 4][x % 4] + 0.5) / 16.0
            lvl = hi if frac > th else lo
            a = int(round(255.0 * lvl / (FOG_STEPS - 1)))
            img.putpixel((x, y), (DARK[0], DARK[1], DARK[2], a))
    return img


def hw_at(y):
    """Half-width of the pit OPENING at row y -- the hole cut in the floor.

    Smooth, not stepped. The steps inside are seen through this one hole and
    span wall to wall, so they take their width from it; giving each step its own
    width would notch the silhouette into something no stairwell does.
    """
    t = (ST_Y_NEAR - y) / float(ST_Y_NEAR - ST_Y_FAR)
    t = max(0.0, min(1.0, t))
    return ST_HW_NEAR + (ST_HW_FAR - ST_HW_NEAR) * t


def shade(c, f):
    return (int(c[0] * f), int(c[1] * f), int(c[2] * f), 255)


def draw_stairs():
    """A stone opening in the floor with a flight of steps swallowed by darkness.

    Drawn as a hole receding UP-screen into black rather than as a fully
    projected staircase. A descending flight seen from a camera above and in
    front is close to degenerate -- the depth gain pushes each step up the screen
    while the descent pushes it back down, and the two nearly cancel -- so the
    only honest read at this size is the conventional one: a near lip, four
    treads, and blackness taking the rest. The darkness is doing the work, which
    is also why it is #101014: the same value the fog ramps to.
    """
    s = Sprite(ST_W, ST_H)
    cx = ST_W / 2.0

    # Floor the whole opening in darkness first, so any seam the steps leave
    # reads as more depth rather than as a hole punched in the sprite. Whatever
    # the steps do not cover stays void -- that is the "into darkness".
    for y in range(ST_Y_FAR, ST_Y_NEAR + 1):
        hw = hw_at(y)
        s.hline(cx - hw, cx + hw, y, DARK)

    # Treads, near to far. Each is flat; the separation between them is what
    # reads as steps.
    y_bot = ST_Y_NEAR
    for k, h in enumerate(ST_STEP_HEIGHTS):
        y_top = y_bot - h + 1
        tread = ST_TREADS[k]
        left = shade(tread, 0.78)    # the pit's left wall faces right, into the
        right = shade(tread, 0.48)   # key light (§4); the right wall is shadowed
        for y in range(y_top, y_bot + 1):
            hw = hw_at(y)
            s.hline(cx - hw, cx + hw, y, tread)
            for j in range(2):
                s.put(cx - hw + j, y, left)
                s.put(cx + hw - j, y, right)
        # The drop to the next step down: a hard 2px face at the tread's far
        # edge. This line is the entire difference between "steps" and "a ramp".
        riser = shade(tread, 0.42)
        for y in (y_top, y_top + 1):
            hw = hw_at(y)
            s.hline(cx - hw, cx + hw, y, riser)
        y_bot -= h

    # Dressed-stone rim: cheeks down both sides, closing across the far lip. The
    # far lip is what stops the opening from reading as a cut-off sprite edge; it
    # is kept to 3px so the darkness still dominates the shape.
    for y in range(ST_Y_FAR - 3, ST_Y_NEAR + ST_FRAME + 2):
        hw = hw_at(max(min(y, ST_Y_NEAR), ST_Y_FAR))
        for k in range(1, ST_FRAME + 1):
            s.put(cx - hw - k, y, ST_LIT if k > 1 else ST_MID)
            s.put(cx + hw + k, y, ST_MID if k > 1 else ST_SHA)
    hw = hw_at(ST_Y_FAR)
    for y in range(ST_Y_FAR - 3, ST_Y_FAR):
        s.hline(cx - hw - ST_FRAME, cx + hw + ST_FRAME, y,
                ST_MID if y == ST_Y_FAR - 3 else ST_SHA)

    # Near lip: the cut edge of the floor the party stands on, and the brightest
    # thing here -- it is flat ground taking the full key light, where everything
    # past it is inside the pit.
    hw = hw_at(ST_Y_NEAR)
    for y in range(ST_Y_NEAR + 1, ST_Y_NEAR + ST_FRAME + 2):
        d = y - ST_Y_NEAR
        c = ST_LIT if d == 1 else (ST_MID if d < 4 else ST_SHA)
        s.hline(cx - hw - ST_FRAME, cx + hw + ST_FRAME, y, c)

    # Masonry joints, hash-placed at varied spacing (§7). Low contrast on
    # purpose: they only need to say "cut stone", and a rim that reads as loud
    # brickwork would pop out of the backdrop §5 wants receding.
    joint = lerp(ST_SHA, ST_DEEP, 0.5)
    x = int(rnd(211, 0) * 10)
    while x < ST_W:
        for y in range(ST_Y_NEAR + 1, ST_Y_NEAR + ST_FRAME + 2):
            if (x, y) in s.px:
                s.put(x, y, joint)
        x += 9 + int(rnd(212, x) * 11)
    for i in range(6):
        y = ST_Y_FAR + int(rnd(213, i) * (ST_Y_NEAR - ST_Y_FAR))
        hw = hw_at(y)
        for k in range(1, ST_FRAME + 1):
            s.put(cx - hw - k, y, joint)
            s.put(cx + hw + k, y, joint)
    return s.image()


def tinted(img, tint):
    """What Godot's modulate does: multiply the texture by the biome tint."""
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            px[x, y] = (r * tint[0] // 255, g * tint[1] // 255,
                        b * tint[2] // 255, a)
    return out


# --- Preview -----------------------------------------------------------------
SCALE = 3
STRIP_W = 480           # 1.5 biome tiles: proves the row still tiles under both
STAIRS_X = 296
STAIRS_BASE_Y = 122     # the near lip sits well down the floor (HORIZON is 56)
FOG_X = 372


def biome_strip(row, tint, stairs, fog):
    """One review band: the real biome row, tiled, with the tinted stairs on the
    floor and the fog curtain closing off the right."""
    strip = Image.new("RGBA", (STRIP_W, ROW_H), (0, 0, 0, 255))
    for x0 in range(0, STRIP_W, ROW_W):
        strip.paste(row, (x0, 0))
    strip.alpha_composite(tinted(stairs, tint), (STAIRS_X, STAIRS_BASE_Y - ST_H))
    strip.alpha_composite(fog, (FOG_X, 0))
    # The solid tail the consumer repeats out to the row's right edge.
    strip.paste(Image.new("RGBA", (STRIP_W - FOG_X - FOG_W, ROW_H), DARK),
                (FOG_X + FOG_W, 0))
    return strip


def assets_strip(stairs, fog):
    """Top band: both assets raw. The stairs sit untinted on panel fill so the
    neutral stone can be judged, and the fog runs over a checker so its alpha
    ramp is actually visible -- on any dark ground it just looks like nothing."""
    band = Image.new("RGBA", (STRIP_W, ROW_H), (0x26, 0x26, 0x2E, 255))
    band.alpha_composite(stairs, (24, STAIRS_BASE_Y - ST_H))
    for y in range(ROW_H):
        for x in range(200, 316):
            band.putpixel((x, y), (196, 196, 204, 255)
                          if ((x // 8) + (y // 8)) % 2 == 0
                          else (108, 108, 116, 255))
    band.alpha_composite(fog, (208, 0))
    band.paste(Image.new("RGBA", (28, ROW_H), DARK), (288, 0))
    return band


def main():
    root = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
    out_dir = os.path.join(root, "lord-of-hirelings", "sprites", "dungeon")
    os.makedirs(out_dir, exist_ok=True)

    fog = draw_fog()
    stairs = draw_stairs()
    fog.save(os.path.join(out_dir, "fog_of_war_edge.png"))
    stairs.save(os.path.join(out_dir, "stairs_down.png"))
    print("wrote", os.path.join(out_dir, "fog_of_war_edge.png"))
    print("wrote", os.path.join(out_dir, "stairs_down.png"))

    bands = [assets_strip(stairs, fog)]
    for name, tint in BIOME_TINTS:
        row = Image.open(os.path.join(out_dir, "biome_%s_row.png" % name))
        bands.append(biome_strip(row.convert("RGBA"), tint, stairs, fog))

    gap = 8
    bh = ROW_H * SCALE
    sheet = Image.new("RGB", (STRIP_W * SCALE, (bh + gap) * len(bands) - gap),
                      (23, 23, 28))
    for i, band in enumerate(bands):
        sheet.paste(band.convert("RGB").resize((STRIP_W * SCALE, bh),
                                               Image.NEAREST), (0, i * (bh + gap)))
    preview_dir = os.path.join(root, "SourceArt", "previews")
    os.makedirs(preview_dir, exist_ok=True)
    path = os.path.join(preview_dir, "dive_row_overlays_preview_3x.png")
    sheet.save(path)
    print("wrote", path)


if __name__ == "__main__":
    main()
