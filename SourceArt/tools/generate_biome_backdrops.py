"""Generate the four dungeon level biome backdrops.

design/LordofHirelings_GameDesignDocument.md line 176 names the biomes and both
their uses: "level 1 gentle grassy forest, level 2 swampy forest, level 3
underground undead crypt, level 4 volcanic lava fields with rivers of fire.
Used in the dungeon dive rows and as the per-party headers in the expedition
summary." Each biome is therefore authored ONCE as a 320x128 scene and written
out as two crops of that same art:

- <biome>_header.png -- 320x64, the top half, for the expedition summary's
  party-column header (mockup .biome is a 64px-tall strip).
- <biome>_row.png -- the full 320x128, for the dungeon dive row backdrop.

The scene is composed so the split at y=64 works for both: HORIZON sits at
y=56, so the header crop carries sky/ceiling + the biome's midground + an 8px
lip of ground (a legible "which level was this" strip), while the full row adds
the 72px of floor a 48px combatant needs to stand on.

Everything wraps at x=W (Scene.put is modular), so both crops tile horizontally
with TextureRect STRETCH_TILE at any column or row width -- no fractional
scaling of pixel art (VISUAL_RULES.md).

Style guide (design/LordofHirelings_ArtStyleGuide.md) rules that shape this:
- §3: "Backgrounds, backdrops, and tiles get NO outline" -- form and value only.
- §5: backdrops sit in the middle 50% of the value range at reduced saturation;
  sprites own the extremes. Nothing here is brighter than the Rogue's dagger
  glint (206,216,230) or the Knight's steel light (160,172,190).
- §2 color script: 1 high-key analogous greens + warm sun; 2 mid-key
  desaturated gray-greens and murk browns; 3 low-key cold blue-greens, stone
  grays, sickly soul-green; 4 near-black basalt vs saturated orange-red lava.
  The arc drops in key each level until 4 breaks it with warm-on-dark.
- §2: dithering is banned on sprites but "allowed on large background gradients
  (sky) only" -- so every vertical ramp here is ordered-dithered (Bayer 4x4)
  rather than banded, and W is a multiple of 4 so the dither tiles too.
- §4: light from the top, biased left, everywhere. Flavor light (lava glow,
  soul-green torches) stays weaker than the global key on sprites.
- §7: no window-blind effect -- masonry courses, spikes and trees are all
  placed at varied, hash-driven spacing, never even stripes.

Output: lord-of-hirelings/sprites/dungeon/biome_{forest,swamp,crypt,volcanic}_{header,row}.png
        SourceArt/previews/biome_backdrops_preview_4x.png (for review)
"""
import math
import os
from PIL import Image

W = 320
H = 128
HORIZON = 56        # ground line; the header crop keeps 8px of it
HEADER_H = 64       # mock.css .biome height, and the header crop's height

# Ordered dither matrix for the background gradients (§2 allows it on skies).
BAYER4 = (
    (0, 8, 2, 10),
    (12, 4, 14, 6),
    (3, 11, 1, 9),
    (15, 7, 13, 5),
)


def rnd(seed, i):
    """Stable hash noise. Placement is by element index, never by world x, so
    every scene stays tileable and regenerates identically."""
    v = ((i + 1) * 1103515245 + seed * 12345) & 0x7FFFFFFF
    v ^= v >> 13
    v = (v * 2654435761) & 0x7FFFFFFF
    return v / float(0x7FFFFFFF)


def spread(seed, i, count, jitter=0.85):
    """One x per element, stratified: each element owns a slice of the width and
    jitters inside it. Pure hash placement clumps and leaves bald patches at
    these counts; even spacing would be the window-blind effect §7 bans. This is
    the middle -- full coverage, no rhythm."""
    return ((i + 0.5 + (rnd(seed, i) - 0.5) * jitter) / count) * W


def wave(x, k, phase):
    """Horizontal variation with an integer period, so it wraps at W and the
    backdrop still tiles. Returns 0..1."""
    return 0.5 + 0.5 * math.sin(2.0 * math.pi * k * x / W + phase)


class Scene:
    """Pixel buffer for one biome. x wraps at W so the backdrop tiles."""

    def __init__(self):
        self.px = {}

    def put(self, x, y, c):
        y = int(y)
        if 0 <= y < H:
            self.px[(int(x) % W, y)] = c

    def ramp(self, y0, y1, colors):
        """Vertical ramp through `colors`, ordered-dithered between steps so a
        56px sky resolves as texture instead of banding."""
        span = max(1, y1 - y0)
        for y in range(y0, y1):
            f = (y - y0) / float(span) * (len(colors) - 1)
            i = min(int(f), len(colors) - 2)
            frac = f - i
            for x in range(W):
                th = (BAYER4[y % 4][x % 4] + 0.5) / 16.0
                self.put(x, y, colors[i + 1] if frac > th else colors[i])

    def blob(self, cx, cy, rx, ry, sh, md, lt):
        """Rounded mass shaded from the top-left. No outline -- §3."""
        for y in range(int(cy - ry), int(cy + ry) + 1):
            for x in range(int(cx - rx), int(cx + rx) + 1):
                nx, ny = (x - cx) / rx, (y - cy) / ry
                if nx * nx + ny * ny <= 1.0:
                    v = nx * 0.8 + ny * 0.6
                    self.put(x, y, lt if v < -0.35 else (sh if v > 0.3 else md))

    def rect(self, x0, x1, y0, y1, c):
        for y in range(int(y0), int(y1) + 1):
            for x in range(int(x0), int(x1) + 1):
                self.put(x, y, c)

    def image(self):
        img = Image.new("RGBA", (W, H), (0, 0, 0, 255))
        for (x, y), c in self.px.items():
            img.putpixel((x, y), c)
        return img


# --- 1: Gentle Forest --------------------------------------------------------
# High-key analogous greens + warm sunlight. "Deceptively friendly": the only
# level whose backdrop is lighter than the sprites standing on it.
def draw_forest():
    s = Scene()
    # Sky darkens toward the top -- keeps the white LEVEL label legible in the
    # header's top-left corner, and warms to a sun-bleached haze at the horizon.
    s.ramp(0, HORIZON, [
        (104, 138, 170, 255), (134, 162, 182, 255),
        (158, 178, 178, 255), (178, 190, 168, 255),
    ])
    # Soft hills: atmospheric perspective -- lighter, cooler, low contrast (§7).
    for i in range(7):
        s.blob(spread(11, i, 7), HORIZON - 1, 44 + rnd(12, i) * 34,
               9 + rnd(13, i) * 6, (118, 142, 128, 255),
               (128, 152, 134, 255), (140, 162, 142, 255))
    # Forest edge sitting on the hills -- one value darker than the hills, still
    # hazed back so it never competes with the near trees.
    for i in range(30):
        r = 5 + rnd(22, i) * 5
        s.blob(spread(21, i, 30), HORIZON - 6 - rnd(23, i) * 4, r, r * 0.9,
               (86, 112, 92, 255), (98, 126, 100, 255), (112, 140, 110, 255))
    # Near trees: canopies break up into the sky, trunks run down to the grass,
    # so the 64px header crop reads as "forest" and not "a green stripe".
    for i in range(6):
        cx = spread(31, i, 6)
        top = 12 + rnd(32, i) * 10
        r = 11 + rnd(33, i) * 5
        cy = top + r
        s.rect(cx - 1, cx + 1, cy, HORIZON - 1, (72, 54, 40, 255))
        s.rect(cx - 1, cx - 1, cy, HORIZON - 1, (94, 72, 52, 255))
        for j in range(4):
            ox = (rnd(34, i * 4 + j) - 0.5) * r * 1.5
            oy = (rnd(35, i * 4 + j) - 0.5) * r * 0.9
            s.blob(cx + ox, cy + oy, r * 0.66, r * 0.58,
                   (56, 84, 50, 255), (78, 110, 62, 255), (102, 138, 76, 255))
    # Grass: lighter and cooler at the horizon, deeper and warmer underfoot, so
    # the foreground the party stands on is the darkest thing in the scene.
    s.ramp(HORIZON, H, [
        (108, 130, 82, 255), (94, 118, 70, 255),
        (78, 102, 58, 255), (66, 90, 50, 255),
    ])
    # Blades only -- §7 keeps the ground quiet, and the dithered ramp already
    # carries the depth. (Broad tonal swells were tried here and cut: any
    # y-phased wave beats into a diagonal lattice, the very window-blind tell
    # §7 bans, and hash-placed patches read as mold on a field this size.)
    for i in range(220):
        x = spread(41, i, 220, jitter=1.6)
        y = HORIZON + 2 + rnd(42, i) ** 1.6 * (H - HORIZON - 4)
        t = (y - HORIZON) / float(H - HORIZON)
        blade = (124, 148, 92, 255) if t < 0.45 else (96, 124, 64, 255)
        s.put(x, y, blade)
        if rnd(43, i) > 0.5:
            s.put(x, y - 1, blade)
        if rnd(44, i) > 0.82:                            # taller foreground tuft
            s.put(x + 1, y, blade)
            s.put(x, y - 2, blade)
    return s


# --- 2: Swamp ----------------------------------------------------------------
# Mid-key. §2's green rule: swamp green is gray and murky and must never be
# mistaken for the clean bright green of a heal.
def draw_swamp():
    s = Scene()
    s.ramp(0, HORIZON, [
        (66, 76, 72, 255), (86, 96, 88, 255),
        (108, 116, 102, 255), (128, 134, 116, 255),
    ])
    # Mist banked in layers. Density falls off from each band's spine and is
    # modulated by two wrapping waves, so the dither dissolves the edges into
    # wisps -- a flat dither threshold just reads as a checkerboard artifact.
    for i in range(5):
        cy = 24 + rnd(51, i) * 26
        hh = 2.0 + rnd(52, i) * 3.0
        for y in range(int(cy - hh) - 1, int(cy + hh) + 2):
            fade = 1.0 - abs(y - cy) / (hh + 0.75)
            if fade <= 0.0:
                continue
            for x in range(W):
                d = fade * (0.35 + 0.65 * (wave(x, 2 + i, i * 1.7) * 0.65
                                           + wave(x, 5 + i, i * 0.9) * 0.35))
                if d > (BAYER4[y % 4][x % 4] + 0.5) / 16.0:
                    s.put(x, y, (138, 144, 128, 255) if d > 0.75
                          else (120, 128, 114, 255))
    # Dead trees: bare, crooked, no canopy -- the silhouette that says "swamp"
    # rather than "forest" in the header crop. Wide jitter and a big height
    # spread on purpose: evenly spaced same-height trunks read as fence posts,
    # and a drowned wood is nothing if not disorderly.
    for i in range(9):
        cx = spread(61, i, 9, jitter=1.7)
        top = 4 + rnd(62, i) ** 1.7 * 30
        lean = (rnd(63, i) - 0.5) * 0.5
        for y in range(int(top), HORIZON):
            x = cx + lean * (y - top)
            s.put(x, y, (86, 78, 62, 255))
            s.put(x - 1, y, (104, 96, 76, 255))    # lit left edge (§4)
            s.put(x + 1, y, (66, 60, 48, 255))
        # Branches at varied heights, never a regular ladder (§7).
        for b in range(3):
            by = top + 3 + rnd(64, i * 3 + b) * 16
            bx = cx + lean * (by - top)
            dirn = 1 if rnd(65, i * 3 + b) > 0.5 else -1
            length = 4 + int(rnd(66, i * 3 + b) * 7)
            for k in range(length):
                s.put(bx + dirn * k, by - k * 0.6, (86, 78, 62, 255))
            # Moss hangs off the branch tip -- gray-green, never heal green.
            tipx = bx + dirn * (length - 1)
            for m in range(2 + int(rnd(67, i * 3 + b) * 7)):
                s.put(tipx, by - (length - 1) * 0.6 + m,
                      (94, 104, 76, 255) if m % 2 else (78, 88, 64, 255))
    # Mud, darkening toward the foreground.
    s.ramp(HORIZON, H, [
        (78, 70, 54, 255), (68, 60, 46, 255),
        (58, 51, 39, 255), (48, 42, 33, 255),
    ])
    # Standing water: flat pools, a touch cooler and lighter than the mud, with
    # a bright rim only on the lit (top) edge so they read as surface, not hole.
    for i in range(9):
        cx = spread(71, i, 9, jitter=1.4)
        cy = HORIZON + 4 + rnd(72, i) ** 1.5 * (H - HORIZON - 10)
        rx = 12 + rnd(73, i) * 22
        ry = 2.5 + rnd(74, i) * 3.5
        for y in range(int(cy - ry), int(cy + ry) + 1):
            for x in range(int(cx - rx), int(cx + rx) + 1):
                nx, ny = (x - cx) / rx, (y - cy) / ry
                if nx * nx + ny * ny <= 1.0:
                    s.put(x, y, (86, 102, 92, 255) if ny < -0.55
                          else (58, 74, 68, 255))
    # Reed clumps along the waterline: the swamp's only vertical detail below
    # the horizon, and what keeps the mud from reading as an empty brown slab.
    # Gray-green like the moss -- never the clean green of a heal (§2).
    for i in range(16):
        cx = spread(81, i, 16, jitter=1.7)
        cy = HORIZON + 2 + rnd(82, i) ** 1.7 * (H - HORIZON - 8)
        t = (cy - HORIZON) / float(H - HORIZON)
        blade = (96, 106, 78, 255) if t < 0.5 else (74, 84, 60, 255)
        for r in range(3 + int(rnd(83, i) * 4)):
            rx = cx + (rnd(84, i * 8 + r) - 0.5) * 7
            hgt = 3 + rnd(85, i * 8 + r) * 6
            lean = (rnd(86, i * 8 + r) - 0.5) * 0.7
            for k in range(int(hgt)):
                s.put(rx + lean * k, cy - k, blade)
    return s


# --- 3: Undead Crypt ---------------------------------------------------------
# Low-key: cold blue-greens and stone grays, with sickly soul-green the only
# saturated thing down here. Underground, so the sky is a vault instead.
def draw_crypt():
    s = Scene()
    s.ramp(0, HORIZON, [
        (30, 34, 42, 255), (44, 50, 58, 255),
        (62, 70, 76, 255), (74, 84, 90, 255),
    ])
    # Vaulted ceiling pressing down from the top of the crop.
    for i in range(6):
        cx = i * (W / 6.0) + rnd(81, i) * 8
        s.blob(cx, 0, 30 + rnd(82, i) * 10, 13 + rnd(83, i) * 5,
               (24, 27, 34, 255), (30, 34, 42, 255), (38, 43, 52, 255))
    # Back wall masonry: courses of varied block width, offset per row, so the
    # joints never line up into stripes (§7).
    for row in range(5):
        y0 = 20 + row * 8
        for y in range(y0, min(y0 + 7, HORIZON)):
            for x in range(W):
                s.put(x, y, (66, 74, 80, 255))
        x = int(rnd(91, row) * 24)
        while x < W + 30:
            bw = 14 + int(rnd(92, row * 20 + x) * 16)
            for y in range(y0, min(y0 + 7, HORIZON)):
                s.put(x, y, (46, 52, 58, 255))          # joint
                s.put(x + 1, y, (78, 88, 94, 255))      # lit left face (§4)
            for xx in range(x + 2, x + bw):
                s.put(xx, y0, (76, 86, 92, 255))        # lit top course line
                if y0 + 6 < HORIZON:
                    s.put(xx, y0 + 6, (48, 54, 60, 255))
            x += bw
    # Arched niches: black openings, each with one guttering soul-green flame.
    for i in range(4):
        cx = spread(101, i, 4, jitter=0.5)
        r = 7 + rnd(102, i) * 3
        cy = 34 + rnd(103, i) * 6
        s.blob(cx, cy, r, r * 1.5, (18, 22, 26, 255), (18, 22, 26, 255),
               (18, 22, 26, 255))
        s.rect(cx - r, cx + r, cy, HORIZON - 1, (18, 22, 26, 255))
        # Flavor light, deliberately weaker than the key on sprites (§4).
        s.blob(cx, cy + 2, 2.5, 3.5, (52, 92, 66, 255), (74, 122, 84, 255),
               (96, 148, 100, 255))
    # Pillars: the crypt's vertical rhythm, lit hard on the left. They run from
    # the vault to the floor -- a pillar with air above its capital reads as a
    # floating post, not as something holding the ceiling up.
    for i in range(4):
        cx = spread(111, i, 4)
        hw = 4 + rnd(112, i) * 3
        for y in range(0, HORIZON + 6):
            for x in range(int(cx - hw), int(cx + hw) + 1):
                nx = (x - cx) / hw
                s.put(x, y, (92, 102, 108, 255) if nx < -0.4
                      else ((70, 78, 86, 255) if nx < 0.45 else (50, 56, 64, 255)))
        for y in (5, 6, HORIZON + 3, HORIZON + 4):      # capital / base flare
            s.rect(cx - hw - 2, cx + hw + 2, y, y, (82, 92, 98, 255))
    # Sarcophagi and bone piles along the wall foot -- bone is the brightest
    # thing in the crypt, and still below the sprite ramps.
    for i in range(5):
        cx = spread(121, i, 5)
        if rnd(122, i) > 0.5:
            hw = 9 + rnd(123, i) * 6
            s.rect(cx - hw, cx + hw, HORIZON - 6, HORIZON + 1, (58, 64, 70, 255))
            s.rect(cx - hw, cx + hw, HORIZON - 6, HORIZON - 5, (84, 92, 98, 255))
        else:
            for b in range(9):
                bx = cx + (rnd(124, i * 9 + b) - 0.5) * 16
                by = HORIZON - 4 + rnd(125, i * 9 + b) * 5
                s.rect(bx, bx + 2 + rnd(126, i * 9 + b) * 2, by, by,
                       (140, 138, 118, 255))
    # Flagstone floor, pitched darker than the wall it meets. The wall and floor
    # are both gray stone, so value is the only thing that can separate them --
    # matched tones made the whole crop read as one flat wall. Dark underfoot
    # also gives the party the contrast §5 demands.
    s.ramp(HORIZON, H, [
        (54, 60, 68, 255), (46, 51, 59, 255),
        (38, 43, 50, 255), (31, 35, 42, 255),
    ])
    # Courses open up toward the viewer (step grows) -- the only perspective cue
    # down here; even spacing would be a window blind (§7). Three is enough: a
    # joint every few rows turns the floor back into masonry.
    # Joints are deliberately low-contrast against the local floor value. A dark
    # joint plus a lit lip per course banded the floor into more wall -- and §7
    # wants the ground quiet. The value ramp carries the depth; the joints only
    # need to hint that it is cut stone.
    courses = []
    y = HORIZON + 7.0
    step = 11.0
    while y < H:
        courses.append(int(y))
        y += step
        step *= 1.7
    for row, y in enumerate(courses):
        t = (y - HORIZON) / float(H - HORIZON)
        joint = (38 - int(12 * t), 43 - int(13 * t), 50 - int(14 * t), 255)
        for x in range(W):
            s.put(x, y, joint)
        bottom = courses[row + 1] if row + 1 < len(courses) else H
        x = int(rnd(131, row) * 50)
        while x < W:
            for yy in range(y + 1, min(bottom, H)):
                s.put(x, yy, joint)
            x += 34 + int(rnd(132, row * 40 + x) * 46)
    return s


# --- 4: Volcanic Hellscape ---------------------------------------------------
# Low-key, and the one level that breaks the arc: near-black basalt against
# complementary orange-red lava. §5 still binds -- this lava is duller than the
# Flamecaller's flame VFX will be.
def draw_volcanic():
    s = Scene()
    # Cavern air, lit from below by the lava rather than from the sky.
    s.ramp(0, HORIZON, [
        (38, 24, 30, 255), (58, 32, 34, 255),
        (86, 42, 34, 255), (118, 56, 36, 255),
    ])
    # Ember rain drifting in the dark half.
    for i in range(70):
        x = rnd(141, i) * W
        y = rnd(142, i) * (HORIZON - 4)
        s.put(x, y, (196, 116, 48, 255) if rnd(143, i) > 0.45
              else (150, 74, 36, 255))
    # Basalt spikes: near-black silhouettes at varied heights and widths.
    for i in range(16):
        cx = spread(151, i, 16)
        h = 10 + rnd(152, i) * 26
        hw = 3 + rnd(153, i) * 6
        for y in range(int(HORIZON - h), HORIZON):
            t = (y - (HORIZON - h)) / float(h)
            w = hw * t
            for x in range(int(cx - w), int(cx + w) + 1):
                nx = (x - cx) / max(w, 0.5)
                s.put(x, y, (48, 40, 48, 255) if nx < -0.3
                      else ((32, 27, 33, 255) if nx < 0.5 else (22, 19, 24, 255)))
    # The river of fire at the horizon -- the line the whole biome reads by, and
    # the only saturated band in the crop.
    for y in range(HORIZON - 6, HORIZON + 2):
        t = (y - (HORIZON - 6)) / 8.0
        for x in range(W):
            th = (BAYER4[y % 4][x % 4] + 0.5) / 16.0
            hot = (206, 122, 48, 255) if t > th else (178, 84, 36, 255)
            s.put(x, y, hot)
    for i in range(40):                                  # brighter churn
        x = spread(161, i, 40, jitter=1.5)
        y = HORIZON - 5 + rnd(162, i) * 6
        for k in range(1 + int(rnd(163, i) * 5)):
            s.put(x + k, y, (222, 152, 62, 255))
    # Basalt field, cooling to near-black underfoot.
    s.ramp(HORIZON + 2, H, [
        (72, 56, 56, 255), (58, 46, 48, 255),
        (46, 37, 40, 255), (36, 29, 33, 255),
    ])
    # The crust nearest the river is lit by it -- flavor light, dithered out
    # over 16px, and still weaker than the key on sprites (§4). This is what
    # seats the river on the ground plane instead of leaving it a floating band.
    for y in range(HORIZON + 2, HORIZON + 18):
        d = 1.0 - (y - (HORIZON + 2)) / 16.0
        for x in range(W):
            if d * 0.8 > (BAYER4[y % 4][x % 4] + 0.5) / 16.0:
                s.put(x, y, (104, 62, 52, 255) if d > 0.55 else (86, 54, 50, 255))
    # Cracks glowing through the crust: separate fissures running roughly with
    # the ground plane, dulling toward the viewer so the party never stands in a
    # bright patch (§5). Deliberately NOT hung off the river -- cracks that all
    # descend from one line read as drips. Kept few and dim: at higher counts
    # they stop reading as fissures in stone and start reading as loose twigs.
    for i in range(7):
        x = spread(171, i, 7, jitter=1.9)
        y = HORIZON + 6 + rnd(172, i) ** 1.3 * (H - HORIZON - 12)
        t = (y - HORIZON) / float(H - HORIZON)
        slope = (rnd(173, i) - 0.5) * 0.9
        glow = (168 - int(44 * t), 78 - int(26 * t), 36 - int(10 * t), 255)
        for k in range(5 + int(rnd(174, i) * 20)):
            s.put(x, y, glow)
            x += 1.0
            y += slope + (rnd(175, i * 40 + k) - 0.5) * 0.9
    return s


BIOMES = (
    ("forest", draw_forest),
    ("swamp", draw_swamp),
    ("crypt", draw_crypt),
    ("volcanic", draw_volcanic),
)


def main():
    root = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
    out_dir = os.path.join(root, "lord-of-hirelings", "sprites", "dungeon")
    os.makedirs(out_dir, exist_ok=True)

    images = []
    for name, draw in BIOMES:
        row = draw().image()
        images.append((name, row))
        row.save(os.path.join(out_dir, "biome_%s_row.png" % name))
        row.crop((0, 0, W, HEADER_H)).save(
            os.path.join(out_dir, "biome_%s_header.png" % name))
        print("wrote", os.path.join(out_dir, "biome_%s_{row,header}.png" % name))

    # Review sheet: every biome at 4x with the header/row split marked, so the
    # crop can be judged without opening the game.
    preview_dir = os.path.join(root, "SourceArt", "previews")
    os.makedirs(preview_dir, exist_ok=True)
    gap = 8
    sheet = Image.new("RGB", (W * 4, (H * 4 + gap) * len(images) - gap),
                      (23, 23, 28))
    for i, (_, row) in enumerate(images):
        big = row.convert("RGB").resize((W * 4, H * 4), Image.NEAREST)
        sheet.paste(big, (0, i * (H * 4 + gap)))
        for x in range(0, W * 4, 8):                     # header crop line
            for k in range(2):
                sheet.putpixel((x + k, i * (H * 4 + gap) + HEADER_H * 4),
                               (255, 0, 200))
    sheet.save(os.path.join(preview_dir, "biome_backdrops_preview_4x.png"))
    print("wrote", os.path.join(preview_dir, "biome_backdrops_preview_4x.png"))


if __name__ == "__main__":
    main()
