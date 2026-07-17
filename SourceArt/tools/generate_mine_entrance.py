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
ROCK_DK = (52, 52, 66, 255)     # cold granite outcrop, deeper than headstones
ROCK_MD = (92, 94, 106, 255)
ROCK_LT = (140, 138, 128, 255)
ROCK_DEEP = (38, 38, 50, 255)   # crevices and the outcrop's shadowed skirt

WOOD_DK = (58, 46, 42, 255)     # weathered support timber (shared town ramp)
WOOD_MD = (108, 90, 70, 255)
WOOD_LT = (156, 138, 104, 255)

DARK_IN = (14, 12, 18, 255)     # the unlit interior — pitch, faintly cold
DARK_RIM = (26, 24, 34, 255)    # where the last light dies at the mouth

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


def px(img, x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), c)


def rect(img, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px(img, x, y, c)


def _rock_top(x):
    """Silhouette of the outcrop: low on the west, peaking past the east edge
    where the map ends, with deterministic jaggedness."""
    if x < 12:
        return None                                  # grass west of the rocks
    t = (x - 12) / (W - 12)
    top = int(96 - 78 * (t ** 0.8))                  # 96 down to ~18
    top += ((x * 13) % 7) - 3                        # jagged crest
    return max(10, top)


def draw_rock(img):
    """The outcrop mass: cool granite facets, lit from the top-left."""
    for x in range(W):
        top = _rock_top(x)
        if top is None:
            continue
        for y in range(top, BASE + 1):
            h = (x * 7 + y * 13) % 29
            depth = y - top
            if depth <= 1 or (depth <= 3 and (x * 5 + y) % 4 == 0):
                c = ROCK_LT                          # lit crest facets
            elif h == 0:
                c = ROCK_DEEP
            elif h in (7, 19):
                c = ROCK_LT if (x + y) % 2 else ROCK_MD
            elif h in (3, 11, 23):
                c = ROCK_DK
            else:
                c = ROCK_MD
            px(img, x, y, c)
    # long diagonal cracks so the mass reads as split, weathered stone
    for sx, sy, n in ((30, 104, 14), (62, 60, 18), (94, 40, 22), (112, 26, 16)):
        x, y = sx, sy
        for i in range(n):
            px(img, x, y, ROCK_DEEP)
            px(img, x + 1, y, ROCK_DK)
            x += 1 if (i * 7 + sx) % 3 else 0
            y += 1
    # shadowed skirt where the rock meets the ground
    for x in range(12, W):
        top = _rock_top(x)
        if top is not None and top < BASE - 1:
            px(img, x, BASE, ROCK_DEEP)
            px(img, x, BASE - 1, ROCK_DK)
    # a few fallen boulders at the west toe of the slope
    for bx, by, r in ((16, 122, 3), (26, 124, 2), (8, 125, 2)):
        for y in range(by - r, by + r):
            for x in range(bx - r, bx + r + 1):
                if (x - bx) ** 2 + (y - by) ** 2 * 2 <= r * r + 2:
                    lit = (x - bx) < 0 and (y - by) < 0
                    px(img, x, y, ROCK_LT if lit else ROCK_MD)
        px(img, bx + r - 1, by, ROCK_DK)


def draw_mouth(img):
    """The portal opening: pitch dark, a cold rim where daylight gives up."""
    for y in range(MOUTH_TOP, BASE + 1):
        # the opening narrows slightly toward the top — a hewn arch, not a door
        inset = max(0, (MOUTH_TOP + 6 - y)) // 3
        for x in range(MOUTH_L + inset, MOUTH_R - inset + 1):
            edge = (y <= MOUTH_TOP + 2 or x <= MOUTH_L + inset + 1
                    or x >= MOUTH_R - inset - 1)
            px(img, x, y, DARK_RIM if edge else DARK_IN)


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
    # a cracked secondary brace leaning across the west post
    for i in range(14):
        x = MOUTH_L - POST_W - 4 + i
        y = BASE - 2 - i * 2
        rect(img, x, y, x + 1, y + 1, WOOD_MD)
        px(img, x, y, WOOD_LT)
    # rock overhanging the lintel ends so the frame reads as cut INTO stone
    rect(img, MOUTH_L - POST_W - 3, LINTEL_TOP - 2, MOUTH_L - POST_W - 1,
         LINTEL_TOP + 2, ROCK_MD)
    rect(img, MOUTH_R + POST_W + 1, LINTEL_TOP - 1, MOUTH_R + POST_W + 3,
         LINTEL_TOP + 3, ROCK_MD)


def draw_tracks(img):
    """Cart tracks running west along the path band and into the dark."""
    mouth_cx = (MOUTH_L + MOUTH_R) // 2
    for tx in range(2, mouth_cx, 8):                 # half-buried sleepers
        rect(img, tx, RAIL_YS[0] - 1, tx + 2, RAIL_YS[1] + 2, TIE_DK)
        px(img, tx, RAIL_YS[0] - 1, WOOD_MD)
    for ry in RAIL_YS:
        for x in range(0, mouth_cx + 10):
            into_dark = x > MOUTH_L + 2
            px(img, x, ry, DARK_RIM if into_dark else RAIL_LT)
            px(img, x, ry + 1, DARK_IN if into_dark else RAIL_MD)
    # an abandoned ore cart wheel leaning on the west post
    wx, wy = MOUTH_L - POST_W - 7, BASE - 5
    for a in range(-4, 5):
        for b in range(-4, 5):
            d = a * a + b * b
            if 8 <= d <= 17:
                px(img, wx + a, wy + b, RAIL_MD if a + b > 0 else RAIL_LT)
    px(img, wx, wy, RAIL_MD)


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
    img = Image.new("RGBA", (W, H))
    draw_rock(img)
    draw_mouth(img)
    draw_timber(img)
    draw_tracks(img)
    outline(img)
    return img


# --- bell sheet --------------------------------------------------------------
CELL_W, CELL_H = 32, 48
HANG_X, HANG_Y = 16, 10         # cell-local hanging point of the bell


def draw_bell_frame(img):
    """Cell 0: small wooden arch — two posts, a crossbar, angle braces."""
    for x0 in (5, 24):
        rect(img, x0, 12, x0 + 2, 46, WOOD_MD)
        rect(img, x0, 12, x0, 46, WOOD_LT)
        rect(img, x0 + 2, 14, x0 + 2, 46, WOOD_DK)
    rect(img, 2, 8, 29, 11, WOOD_MD)                 # crossbar
    rect(img, 2, 8, 29, 8, WOOD_LT)
    rect(img, 2, 11, 29, 11, WOOD_DK)
    px(img, 2, 12, WOOD_DK)                          # bar-end weathering
    px(img, 29, 12, WOOD_DK)
    for i in range(4):                               # angle braces
        px(img, 8 + i, 15 - i if 15 - i > 11 else 12, WOOD_DK)
        px(img, 23 - i, 15 - i if 15 - i > 11 else 12, WOOD_DK)
    rect(img, 4, 46, 8, 46, WOOD_DK)                 # feet in the dirt
    rect(img, 23, 46, 27, 46, WOOD_DK)


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
    for i, y in enumerate(range(HANG_Y + 14, HANG_Y + 26)):  # the pull rope
        x = cx + (1 if i in (4, 5, 9) else 0)        # slack, not plumb
        px(img, x, y, ROPE if i % 3 else ROPE_DK)
    rect(img, cx - 1, HANG_Y + 26, cx + 1, HANG_Y + 28, ROPE_DK)  # frayed knot
    px(img, cx, HANG_Y + 26, ROPE)


def build_bell_sheet():
    img = Image.new("RGBA", (CELL_W * 2, CELL_H))
    draw_bell_frame(img)
    draw_bell(img)
    outline(img)
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
