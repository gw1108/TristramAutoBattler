"""Generate the dungeon entrance (abandoned mine) and the call-to-arms bell.

Authored per design/LordofHirelings_ArtAssetList.md:
  - Dungeon entrance: "Timber-braced mine portal cut into a rocky outcrop,
    cart tracks running into pitch darkness, cold unlit interior. Weathered
    support beams; reads as long-abandoned, not industrious."
  - Call-to-arms bell: "Bronze bell on a wooden post or small arch, rope
    hanging. Rung state = tilted with motion arcs (tween)." The swing is a
    runtime tween, so the bell is its own sheet cell that the scene rotates
    around its hanging point — no baked rung frame.

Style: top-left light, hue-shifted 3-step ramps, selective 1px outline in a
deep warm brown (never pure black), lightened on lit top edges. Shares the
weathered-wood ramps of the other town generators so the props read as one
town.

The portal is the subject and the rock is its frame, so the value budget runs
that way (style guide §7, 60/30/10): the mouth owns the darkest value and the
timber owns the detail, the crest terraces support, and the big rock face stays
a quiet flat mass. The outcrop is massed into a few large facets rather than
textured per-pixel — the guide's squint test wants 2-3 clean value blocks, and
a noise field over the whole mass both fails that and out-shouts the mouth.

Mine canvas is 128x128 with a bottom-center pivot (base at y=127). The prop
stands at the EAST end of the path arm with its east flank running off the
map edge, so the rock mass peaks east and the dark portal mouth sits at the
bottom center, on the path band. Cart tracks run west out of the mouth along
the sprite's bottom rows and fade into the unlit interior.

Bell sheet: 2 cells of 32x48, bottom-center pivot per cell:
  0 wooden arch frame (posts + crossbar) | 1 the bronze bell + rope alone
Cell 1's hanging point is pixel (16, 10) — keep scripts/town/dungeon_bell.gd's
BellSprite position/offset in sync so the swing pivots there.

Output: lord-of-hirelings/sprites/town/mine_entrance.png (128x128)
        lord-of-hirelings/sprites/town/dungeon_bell.png (64x48)
        SourceArt/previews/mine_entrance_preview_4x.png
        SourceArt/previews/dungeon_bell_preview_4x.png
"""
import os
import random
from PIL import Image

W, H = 128, 128
BASE = 127

# --- palette (3-step hue-shifted ramps; shadows cool, lights warm) ---------
ROCK_DEEP = (34, 32, 48, 255)   # crevices and the outcrop's shadowed skirt
ROCK_DK = (52, 52, 76, 255)     # cold granite, shifted violet in shadow
ROCK_MD = (84, 88, 108, 255)    # the big quiet face; saturation peaks here
ROCK_LT = (146, 142, 126, 255)  # facets turned to the key light
ROCK_HI = (176, 168, 142, 255)  # the sun-struck crest lip

WOOD_DK = (58, 46, 42, 255)     # weathered support timber (shared town ramp)
WOOD_MD = (108, 90, 70, 255)
WOOD_LT = (156, 138, 104, 255)

DARK_RIM = (38, 36, 50, 255)    # the last cold light on the hewn jamb
DARK_MID = (24, 22, 32, 255)    # where the light gives up
DARK_IN = (16, 16, 20, 255)     # pitch — the style guide's deepest value

RAIL_MD = (96, 100, 112, 255)   # rusted-dull steel rails
RAIL_LT = (150, 152, 156, 255)
TIE_DK = (64, 52, 46, 255)      # half-buried sleepers, darker than the posts

BRONZE_DK = (110, 72, 32, 255)  # the bell: forge-warm bronze
BRONZE_MD = (168, 116, 48, 255)
BRONZE_LT = (222, 172, 90, 255)
BRONZE_HI = (246, 220, 150, 255)
ROPE = (172, 150, 110, 255)
ROPE_DK = (128, 108, 76, 255)

OUTLINE = (44, 32, 28, 255)     # deep warm-dark brown, never pure black
OUTLINE_LIT = (96, 68, 48, 255)

# --- mine layout (y down, base at y=127) ------------------------------------
MOUTH_L, MOUTH_R = 48, 80       # portal opening span
MOUTH_TOP = 90                  # opening rises from the base to here
POST_W = 4                      # timber posts flanking the mouth
LINTEL_TOP = 82                 # main beam over the opening
RAIL_YS = (116, 122)            # cart rails along the bottom rows (path band)

# Crest control points: a low west toe rising over alternating steep and
# shallow facets to the east map edge. Authored rather than hashed — a
# per-pixel hash gives a periodic comb, which is the "even stripes" tell the
# style guide bans and which the 1px outline then eats into brown teeth.
CREST = ((10, 123), (20, 104), (31, 98), (44, 74), (57, 67), (73, 45),
         (91, 37), (108, 23), (127, 11))

STRATA = (19, 41, 63)           # depth below the crest of each bedding ledge


def px(img, x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), c)


def rect(img, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px(img, x, y, c)


def _crest_jitter(rng):
    """Low-frequency crest wobble: plateaus 4-8px wide, so the skyline breaks
    into facets a 1px outline can trace instead of a per-pixel comb."""
    j = []
    while len(j) < W:
        j.extend([rng.choice((-2, -1, -1, 0, 0, 1, 2))] * rng.randint(4, 8))
    return j[:W]


def _crest_span(x):
    for a, b in zip(CREST, CREST[1:]):
        if a[0] <= x <= b[0]:
            return a, b
    return CREST[-2], CREST[-1]


def _rock_top(x, jitter):
    """Silhouette of the outcrop; None where the grass shows west of it."""
    if x < CREST[0][0]:
        return None
    (x0, y0), (x1, y1) = _crest_span(x)
    t = (x - x0) / float(x1 - x0)
    return max(8, int(round(y0 + (y1 - y0) * t)) + jitter[x])


def _lit_depth(x):
    """How far the key light runs below the crest. Near-flat facets face the
    sky and take it; steep ones catch only a lip. This is what breaks the slope
    into terraces instead of one pillow-shaded ridge."""
    (x0, y0), (x1, y1) = _crest_span(x)
    slope = abs((y1 - y0) / float(x1 - x0))
    if slope < 0.8:
        return 6
    if slope < 1.3:
        return 3
    return 1


def draw_rock(img, rng):
    """The outcrop: cool granite massed into flat facets, lit from the
    top-left. Value does the work and the face stays quiet, so the portal —
    not the stone — is what the eye lands on."""
    jitter = _crest_jitter(rng)
    for x in range(W):
        top = _rock_top(x, jitter)
        if top is None:
            continue
        lit = _lit_depth(x)
        for y in range(top, BASE + 1):
            depth = y - top
            if depth <= 1:
                c = ROCK_HI                      # sun-struck lip
            elif depth <= lit:
                c = ROCK_LT                      # the facet's lit terrace
            elif y >= BASE - 1:
                c = ROCK_DEEP                    # skirt, where it meets dirt
            elif y >= BASE - 4:
                c = ROCK_DK
            else:
                c = ROCK_MD                      # the big quiet face
            px(img, x, y, c)
    draw_strata(img, jitter)
    draw_clefts(img, jitter)
    draw_boulders(img)


def draw_strata(img, jitter):
    """Bedding ledges running parallel to the crest: a lit lip with its own
    shadow thrown under it. The face is bedded, not fluted — ledges echo the
    crest terraces and break the mass horizontally. A cleft per facet break
    corrugates it instead (style guide: never even stripes), and texturing it
    is the noise the squint test exists to catch."""
    for k, depth in enumerate(STRATA):
        for x in range(CREST[0][0], W):
            # the ledge steps in chunky runs so it is a bed, not a ruler line
            y = _rock_top(x, jitter) + depth + ((x // (7 + k * 3)) % 2)
            if y >= BASE - 5:
                continue
            px(img, x, y, ROCK_LT)
            for s in range(1, 3 + (k % 2)):
                px(img, x, y + s, ROCK_DK)


def draw_clefts(img, jitter):
    """A few cracks splitting the mass — enough to read as weathered stone,
    few enough to leave the face quiet under the portal."""
    for x0, length, lean in ((36, 22, 3), (84, 40, 3), (110, 44, 4)):
        x, y = x0, _rock_top(x0, jitter) + 3
        for i in range(length):
            if y >= BASE - 5 or x >= W:
                break
            px(img, x - 1, y, ROCK_LT)           # lit lip above the cleft
            px(img, x, y, ROCK_DEEP)
            px(img, x + 1, y, ROCK_DK)           # its own shadow, thrown right
            y += 1
            if i % lean == 0:
                x += 1                           # leans away from the light


def draw_boulders(img):
    """Fallen rubble at the west toe — the outcrop shedding itself."""
    for bx, by, r in ((16, 122, 3), (26, 125, 2), (7, 125, 2)):
        for y in range(by - r, by + r + 1):
            for x in range(bx - r, bx + r + 1):
                if (x - bx) ** 2 + (y - by) ** 2 * 2 <= r * r + 2:
                    lit = (x - bx) + (y - by) * 2 < -1
                    px(img, x, y, ROCK_LT if lit else ROCK_MD)
        px(img, bx + r - 1, by + 1, ROCK_DK)


def draw_mouth(img):
    """The portal opening: a cold rim where daylight gives up, deepening to
    pitch. Graded so it reads as a shaft going somewhere, not a flat panel."""
    for y in range(MOUTH_TOP, BASE + 1):
        # the opening narrows slightly toward the top — a hewn arch, not a door
        inset = max(0, (MOUTH_TOP + 6 - y)) // 3
        left, right = MOUTH_L + inset, MOUTH_R - inset
        for x in range(left, right + 1):
            edge = min(x - left, right - x, y - MOUTH_TOP)
            if edge <= 0:
                c = DARK_RIM
            elif edge <= 2:
                c = DARK_MID
            else:
                c = DARK_IN
            px(img, x, y, c)
        # the top-left key reaches a sliver of the near jamb and stops
        if y < MOUTH_TOP + 22:
            px(img, left, y, ROCK_DK)


def draw_timber(img):
    """Weathered support frame: two posts, a lintel, and a sagging brace —
    long-abandoned, so nothing sits square."""
    for x0 in (MOUTH_L - POST_W, MOUTH_R + 1):
        rect(img, x0, LINTEL_TOP + 4, x0 + POST_W - 1, BASE - 1, WOOD_MD)
        rect(img, x0, LINTEL_TOP + 4, x0, BASE - 1, WOOD_LT)
        rect(img, x0 + POST_W - 1, LINTEL_TOP + 6, x0 + POST_W - 1, BASE - 1, WOOD_DK)
        for y in range(LINTEL_TOP + 8, BASE - 2, 9):     # split-grain checks
            px(img, x0 + 1, y, WOOD_DK)
            px(img, x0 + 2, y + 4, WOOD_DK)
    # lintel beam, sagging one pixel toward the east (abandoned, not built)
    for x in range(MOUTH_L - POST_W - 3, MOUTH_R + POST_W + 4):
        sag = 1 if x > (MOUTH_L + MOUTH_R) // 2 else 0
        y0 = LINTEL_TOP + sag
        rect(img, x, y0, x, y0 + 5, WOOD_MD)
        px(img, x, y0, WOOD_LT)
        px(img, x, y0 + 5, WOOD_DK)
    # a cracked secondary brace leaning on the west post — stopped short of the
    # opening, or it reads as a stick floating in the dark
    for i in range(8):
        x = MOUTH_L - POST_W - 4 + i
        y = BASE - 2 - i * 2
        rect(img, x, y, x + 1, y + 1, WOOD_MD)
        px(img, x, y, WOOD_LT)
    # rock overhanging the lintel ends so the frame reads as cut INTO stone
    rect(img, MOUTH_L - POST_W - 3, LINTEL_TOP - 2, MOUTH_L - POST_W - 1,
         LINTEL_TOP + 2, ROCK_MD)
    rect(img, MOUTH_R + POST_W + 1, LINTEL_TOP - 1, MOUTH_R + POST_W + 3,
         LINTEL_TOP + 3, ROCK_MD)


def draw_tracks(img, rng):
    """Cart tracks running west along the path band and into the dark. Drawn
    AFTER the outline pass: rails are 1px and west of the rock they are their
    own island, so outlining would swallow them into a dark ladder. They lie on
    the ground in front of the outcrop, and ground takes no outline anyway."""
    mouth_cx = (MOUTH_L + MOUTH_R) // 2
    tx = 2                                       # half-buried sleepers
    while tx < mouth_cx:
        # they die at the threshold with the rails: a lit sleeper standing in
        # the pitch reads as a post in the doorway, not as track
        if tx > MOUTH_L - 2:
            tie, lip = DARK_MID, DARK_RIM
        else:
            tie, lip = TIE_DK, WOOD_MD
        rect(img, tx, RAIL_YS[0] - 1, tx + 2, RAIL_YS[1] + 2, tie)
        px(img, tx, RAIL_YS[0] - 1, lip)
        tx += rng.randint(6, 11)                 # never an even stripe rhythm
    for ry in RAIL_YS:
        for x in range(0, mouth_cx + 8):
            if x < MOUTH_L - 8:
                top_c, bot_c = RAIL_LT, RAIL_MD
            elif x < MOUTH_L + 2:
                top_c, bot_c = RAIL_MD, TIE_DK   # dulled at the threshold
            elif x < MOUTH_L + 10:
                top_c, bot_c = DARK_RIM, DARK_MID  # the last glint, dying
            else:
                continue                         # swallowed whole
            px(img, x, ry, top_c)
            px(img, x, ry + 1, bot_c)
    # an abandoned ore cart wheel, leaned on the rock west of the portal and
    # clear of the rails — nothing here has rolled in a long time. Steel on
    # granite is nearly the same value, so it carries its own dark ring or it
    # vanishes into the face.
    wx, wy = 26, 110
    for a in range(-5, 6):
        for b in range(-5, 6):
            d = a * a + b * b
            if 8 <= d <= 17:
                px(img, wx + a, wy + b, RAIL_MD if a + b > 0 else RAIL_LT)
            elif 17 < d <= 26 or 4 <= d < 8:
                px(img, wx + a, wy + b, ROCK_DEEP)     # separation ring
    px(img, wx, wy, RAIL_MD)                     # hub
    rect(img, wx - 3, wy + 6, wx + 3, wy + 6, ROCK_DEEP)   # contact shadow


def outline(img):
    """Selective 1px outline on the silhouette; lit (lighter) on top edges."""
    src = img.copy()
    w, h = img.width, img.height
    for y in range(h):
        for x in range(w):
            if src.getpixel((x, y))[3] == 0:
                continue
            edge_top = y == 0 or src.getpixel((x, y - 1))[3] == 0
            edge_other = (x == 0 or src.getpixel((x - 1, y))[3] == 0
                          or x == w - 1 or src.getpixel((x + 1, y))[3] == 0
                          or y == h - 1 or src.getpixel((x, y + 1))[3] == 0)
            if edge_top and not edge_other:
                px(img, x, y, OUTLINE_LIT)
            elif edge_other or edge_top:
                px(img, x, y, OUTLINE)


def build_mine():
    rng = random.Random(0x6D696E65)              # 'mine'
    img = Image.new("RGBA", (W, H))
    draw_rock(img, rng)
    draw_mouth(img)
    draw_timber(img)
    outline(img)
    draw_tracks(img, rng)
    return img


# --- bell sheet --------------------------------------------------------------
CELL_W, CELL_H = 32, 48
HANG_X, HANG_Y = 16, 10         # cell-local hanging point of the bell


def draw_bell_frame(img):
    """Cell 0: small wooden arch — two posts, a crossbar, angle braces. Posts
    are 4px so the outline pass leaves a 2px wood core; at 3px the ramp is
    eaten entirely and the arch reads as two dark sticks."""
    for x0 in (4, 24):
        rect(img, x0, 12, x0 + 3, 47, WOOD_MD)
        rect(img, x0, 12, x0, 47, WOOD_LT)           # lit west face
        rect(img, x0 + 3, 14, x0 + 3, 47, WOOD_DK)   # shaded east face
        for y in range(20, 44, 9):                   # split-grain checks
            px(img, x0 + 1, y, WOOD_DK)
            px(img, x0 + 2, y + 4, WOOD_DK)
    rect(img, 2, 8, 29, 11, WOOD_MD)                 # crossbar
    rect(img, 2, 8, 29, 8, WOOD_LT)
    rect(img, 2, 11, 29, 11, WOOD_DK)
    for i in range(4):                               # solid angle gussets
        rect(img, 8, 12 + i, 11 - i, 12 + i, WOOD_DK)
        rect(img, 20 + i, 12 + i, 23, 12 + i, WOOD_DK)
    rect(img, 2, 46, 7, 47, WOOD_DK)                 # feet spread in the dirt
    rect(img, 24, 46, 29, 47, WOOD_DK)


def draw_bell(img, ox=CELL_W):
    """Cell 1: the bronze bell alone, hung at (HANG_X, HANG_Y) — the scene
    rotates this cell around that point when the bell rings."""
    cx = ox + HANG_X
    rect(img, cx - 1, HANG_Y - 2, cx, HANG_Y, BRONZE_DK)     # mount loop
    # the bell: crown to flared lip, lit on the upper-left of the dome
    rows = ((2, HANG_Y + 1), (3, HANG_Y + 2), (4, HANG_Y + 3), (4, HANG_Y + 4),
            (5, HANG_Y + 5), (5, HANG_Y + 6), (5, HANG_Y + 7), (6, HANG_Y + 8),
            (7, HANG_Y + 9), (8, HANG_Y + 10))
    for half_w, y in rows:
        for x in range(cx - half_w, cx + half_w + 1):
            dx = x - cx
            if dx < -half_w // 2 and y < HANG_Y + 8:
                c = BRONZE_LT
            elif dx > half_w - 2 or y >= HANG_Y + 9:
                c = BRONZE_DK
            else:
                c = BRONZE_MD
            px(img, x, y, c)
    px(img, cx - 2, HANG_Y + 3, BRONZE_HI)           # the forge glint
    px(img, cx - 3, HANG_Y + 4, BRONZE_HI)
    rect(img, cx - 8, HANG_Y + 10, cx + 8, HANG_Y + 10, BRONZE_DK)  # lip band
    px(img, cx - 8, HANG_Y + 10, BRONZE_MD)
    px(img, cx, HANG_Y + 12, BRONZE_DK)              # clapper below the lip
    px(img, cx, HANG_Y + 13, BRONZE_MD)


def draw_rope(img, ox=CELL_W):
    """The pull rope, drawn AFTER the outline pass — at 1-2px every column
    borders transparency, so outlining swallows the whole rope and leaves a
    dark dashed line that reads as chain. Unoutlined it stays rope."""
    cx = ox + HANG_X
    for i, y in enumerate(range(HANG_Y + 14, HANG_Y + 26)):
        x = cx + (1 if i in (4, 5, 9) else 0)        # slack, not plumb
        px(img, x, y, ROPE)
        px(img, x + 1, y, ROPE_DK)                   # the twist's shaded side
    rect(img, cx - 1, HANG_Y + 26, cx + 1, HANG_Y + 28, ROPE_DK)  # frayed knot
    rect(img, cx - 1, HANG_Y + 26, cx, HANG_Y + 26, ROPE)


def build_bell_sheet():
    img = Image.new("RGBA", (CELL_W * 2, CELL_H))
    draw_bell_frame(img)
    draw_bell(img)
    outline(img)
    draw_rope(img)
    return img


def main():
    root = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
    sprite_dir = os.path.join(root, "lord-of-hirelings", "sprites", "town")
    preview_dir = os.path.join(root, "SourceArt", "previews")
    os.makedirs(sprite_dir, exist_ok=True)
    os.makedirs(preview_dir, exist_ok=True)
    for name, img in (("mine_entrance", build_mine()),
                      ("dungeon_bell", build_bell_sheet())):
        out_path = os.path.join(sprite_dir, "%s.png" % name)
        img.save(out_path)
        big = img.resize((img.width * 4, img.height * 4), Image.NEAREST)
        bg = Image.new("RGBA", big.size, (92, 124, 60, 255))     # town grass
        bg.alpha_composite(big)
        bg.convert("RGB").save(os.path.join(
            preview_dir, "%s_preview_4x.png" % name))
        print("wrote", out_path)


if __name__ == "__main__":
    main()
