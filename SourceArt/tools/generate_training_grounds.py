"""Generate the Training grounds sprite (ruined + normal states).

Authored per design/LordofHirelings_ArtStyleGuide.md and the art asset list:
  - the fifth building is an OPEN YARD, not a roofed mass (building table:
    "Fence + dummy posts, no roof mass"; accent = weathered wood)
  - contents per the asset list: fence, sparring dummies, archery butt,
    weapon rack, small shed
  - ruined state = broken fence and toppled dummy — plus the shared ruin
    language: dark, cold, cold() muted palette, weeds through the dirt
  - light from top-left, hue-shifted ramps, selective 1px outline in a
    deep warm brown (never pure black), lightened on the lit top side

Canvas is 160x96 with a bottom-center pivot (yard base at y=95) — wider
and lower than the 128x128 shops because it is a yard, not a facade.
Shares the cold() ruin muting and outline pass of the shop generators
(generate_weapon_shop.py etc.) so the five buildings read as one town.
Elements standing against the sky get the outline pass; elements inside
the yard sit on opaque dirt and carry hand-placed dark edges instead.

Output: lord-of-hirelings/sprites/town/training_grounds_normal.png (160x96)
        lord-of-hirelings/sprites/town/training_grounds_ruined.png (160x96)
        SourceArt/previews/training_grounds_normal_preview_4x.png
        SourceArt/previews/training_grounds_ruined_preview_4x.png
"""
import os
import random
from PIL import Image

W, H = 160, 96

# --- palette (3-step hue-shifted ramps; shadows cool, lights warm) ---------
WOOD_DK = (58, 46, 42, 255)     # weathered timber shadow (cool dark brown)
WOOD_MD = (108, 90, 70, 255)    # weathered timber mid
WOOD_LT = (156, 138, 104, 255)  # sun-bleached timber light (warm grey-gold)

DIRT_DK = (94, 72, 52, 255)     # trampled yard dirt
DIRT_MD = (126, 100, 70, 255)
DIRT_LT = (152, 126, 90, 255)

STRAW_DK = (146, 116, 52, 255)  # target butt / dummy stuffing
STRAW_MD = (196, 164, 82, 255)
STRAW_LT = (232, 206, 124, 255)

BURLAP_DK = (112, 90, 66, 255)  # dummy head + wrapped torso sacking
BURLAP_MD = (170, 142, 102, 255)
BURLAP_LT = (200, 174, 132, 255)

TARGET_CREAM = (226, 212, 178, 255)  # painted target rings
TARGET_RED = (176, 66, 50, 255)

STEEL_LT = (200, 208, 216, 255)      # single spear tip on the rack

WEED = (94, 122, 62, 255)       # ruined-state weeds through the dirt
WEED_DK = (66, 92, 48, 255)

DARK_IN = (30, 24, 28, 255)     # shed interior darkness

OUTLINE = (44, 32, 28, 255)     # deep warm-dark brown, never pure black
OUTLINE_LIT = (96, 68, 48, 255)

# --- layout (y down, base at y=95) ------------------------------------------
BASE = 95
YARD_TOP = 36                   # back edge of the trampled dirt
FENCE_BASE = 38                 # back fence posts stand on the yard's rim
DUMMY1_X, DUMMY1_GY = 92, 74    # standing sparring dummy
DUMMY2_X, DUMMY2_GY = 114, 58   # second dummy — toppled when ruined
TARGET_CX, TARGET_CY = 137, 60  # archery butt disc center
RACK_L, RACK_R = 52, 78         # weapon rack against the back fence
SHED_L, SHED_R = 10, 46         # small lean-to shed, back-left corner


def px(img, x, y, c):
    if 0 <= x < W and 0 <= y < H:
        img.putpixel((x, y), c)


def rect(img, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px(img, x, y, c)


def cold(c):
    """Mute a palette color for the ruined state: desaturate, darken, cool."""
    r, g, b, a = c
    grey = int(0.299 * r + 0.587 * g + 0.114 * b)
    mix = lambda v: int((v * 0.55 + grey * 0.45) * 0.80)
    return (mix(r), mix(g), min(255, mix(b) + 10), a)


def pick(c, ruined):
    return cold(c) if ruined else c


def draw_yard(img, rng, ruined):
    """Trampled dirt yard, slightly narrower at the back for depth."""
    dirt_dk = pick(DIRT_DK, ruined)
    dirt_md = pick(DIRT_MD, ruined)
    dirt_lt = pick(DIRT_LT, ruined)
    for y in range(YARD_TOP, BASE + 1):
        inset = max(0, (BASE - y) // 10)          # 5px narrower at the back
        for x in range(3 + inset, W - 4 - inset + 1):
            # deterministic speckle so the ground is stable, not noisy
            h = (x * 7 + y * 13) % 29
            if h == 0:
                c = dirt_dk
            elif h in (9, 19) and y < BASE - 2:
                c = dirt_lt
            else:
                c = dirt_md
            px(img, x, y, c)
    # worn sparring circles: pale scuffed rings under each dummy
    for cx, gy in ((DUMMY1_X, DUMMY1_GY), (DUMMY2_X, DUMMY2_GY)):
        for y in range(gy - 4, gy + 5):
            for x in range(cx - 11, cx + 12):
                dx, dy = x - cx, (y - gy) * 2
                if 64 <= dx * dx + dy * dy <= 121 and (x + y) % 2 == 0:
                    px(img, x, y, dirt_lt)
    # shaded back rim under the fence line
    for x in range(4, W - 4):
        px(img, x, YARD_TOP, dirt_dk)
        if (x * 5) % 3:
            px(img, x, YARD_TOP + 1, dirt_dk)
    if ruined:
        # weeds reclaiming the untrampled dirt
        for _ in range(16):
            x = rng.randrange(8, W - 8)
            y = rng.randrange(YARD_TOP + 4, BASE - 2)
            px(img, x, y, WEED_DK)
            px(img, x, y - 1, WEED)
            if rng.random() < 0.5:
                px(img, x + 1, y, WEED)


def draw_back_fence(img, ruined):
    """Split-rail fence across the yard's back edge. Ruined: a gap where the
    rails are down, one post leaning, one snapped."""
    wood_dk = pick(WOOD_DK, ruined)
    wood_md = pick(WOOD_MD, ruined)
    wood_lt = pick(WOOD_LT, ruined)
    gap_l, gap_r = 66, 114                        # ruined rail gap
    for x0 in (8, 26, 44, 62, 80, 98, 116, 134, 151):
        top = FENCE_BASE - 16
        if ruined and x0 == 98:                   # snapped post stub
            top = FENCE_BASE - 6
        if ruined and x0 == 80:                   # leaning post
            for i in range(14):
                px(img, x0 + 3 + i // 2, FENCE_BASE - i, wood_md)
                px(img, x0 + 4 + i // 2, FENCE_BASE - i, wood_dk)
            continue
        rect(img, x0, top, x0 + 2, FENCE_BASE, wood_md)
        rect(img, x0 + 2, top, x0 + 2, FENCE_BASE, wood_dk)
    for ry, c in ((26, wood_lt), (32, wood_md)):  # two rails, upper one lit
        for x in range(8, 154):
            if ruined and gap_l <= x <= gap_r:
                continue
            px(img, x, ry, wood_lt if ry == 26 else c)
            px(img, x, ry + 1, c if ry == 26 else wood_md)
            px(img, x, ry + 2, wood_dk)
    if ruined:
        # a fallen rail lying across the dirt below the gap
        for i in range(30):
            x = 70 + i
            px(img, x, 44 + i // 8, cold(WOOD_MD))
            px(img, x, 45 + i // 8, cold(WOOD_DK))


def draw_shed(img, ruined):
    """Small lean-to gear shed in the back-left corner — the yard's only
    roofed thing, kept low so the grounds read roofless overall."""
    wood_dk = pick(WOOD_DK, ruined)
    wood_md = pick(WOOD_MD, ruined)
    wood_lt = pick(WOOD_LT, ruined)

    def roof_top(x):
        return 12 + (x - (SHED_L - 2)) * 8 // (SHED_R + 4 - SHED_L)

    # plank wall — each column rises to meet the sloping roof's underside
    for x in range(SHED_L, SHED_R + 1):
        if x <= SHED_L + 1:
            c = wood_lt                                    # lit west edge
        elif (x - SHED_L) % 5 == 4:
            c = wood_dk                                    # plank seam
        else:
            c = wood_md
        rect(img, x, roof_top(x) + 4, x, 46, c)
    rect(img, SHED_L, 45, SHED_R, 46, wood_dk)            # base shadow
    # dark door opening on the right face
    rect(img, SHED_R - 10, 30, SHED_R - 2, 45, DARK_IN)
    rect(img, SHED_R - 11, 29, SHED_R - 1, 29, wood_dk)   # lintel
    # lean-to roof sloping down to the east, overhanging 2px each side
    for x in range(SHED_L - 2, SHED_R + 3):
        ytop = roof_top(x)
        hole = ruined and 22 <= x <= 32
        for dy in range(4):
            c = wood_lt if dy == 0 else (wood_dk if dy == 3 else wood_md)
            if hole and dy < 3:
                c = DARK_IN                                # roof torn open
            px(img, x, ytop + dy, c)
    if ruined:
        # missing wall planks show darkness
        rect(img, SHED_L + 9, 24, SHED_L + 10, 40, DARK_IN)
        rect(img, SHED_L + 19, 21, SHED_L + 19, 34, DARK_IN)


def draw_rack(img, ruined):
    """Weapon rack against the back fence: practice staves leaning on a top
    rail. Ruined: rack bare, one upright snapped."""
    wood_dk = pick(WOOD_DK, ruined)
    wood_md = pick(WOOD_MD, ruined)
    wood_lt = pick(WOOD_LT, ruined)
    right_top = 34 if ruined else 24              # snapped east upright
    rect(img, RACK_L, 24, RACK_L + 2, 42, wood_md)
    rect(img, RACK_L + 2, 24, RACK_L + 2, 42, wood_dk)
    rect(img, RACK_R - 2, right_top, RACK_R, 42, wood_md)
    rect(img, RACK_R, right_top, RACK_R, 42, wood_dk)
    if ruined:
        # top rail fallen, propped on the snapped stub
        for i in range(24):
            px(img, RACK_L + 1 + i, 26 + i // 3, cold(WOOD_MD))
            px(img, RACK_L + 1 + i, 27 + i // 3, cold(WOOD_DK))
        return
    rect(img, RACK_L, 24, RACK_R, 24, wood_lt)    # top rail, sun-bleached
    rect(img, RACK_L, 25, RACK_R, 26, wood_md)
    rect(img, RACK_L, 26, RACK_R, 26, wood_dk)
    # three practice staves leaning ground-to-rail (lean 4px left over 15 rows)
    for i, foot in enumerate((60, 66, 72)):
        for step in range(16):
            x = foot - step * 4 // 15
            px(img, x, 41 - step, wood_lt if i == 1 else wood_md)
            px(img, x + 1, 41 - step, wood_dk)
    # the spear: taller lean past the rail, steel tip glint added post-outline
    for step in range(19):
        px(img, 77 - step * 4 // 18, 41 - step, wood_md)


def draw_dummy(img, x, gy, ruined, toppled):
    """Sparring dummy: post, crossbar arms, wrapped burlap torso, sack head.
    Sits on opaque dirt, so edges are hand-placed (no outline pass here)."""
    wood_dk = pick(WOOD_DK, ruined)
    wood_md = pick(WOOD_MD, ruined)
    wood_lt = pick(WOOD_LT, ruined)
    bur_dk = pick(BURLAP_DK, ruined)
    bur_md = pick(BURLAP_MD, ruined)
    bur_lt = pick(BURLAP_LT, ruined)
    straw = pick(STRAW_MD, ruined)
    # ground shadow
    rect(img, x - 5, gy + 1, x + 5, gy + 1, pick(DIRT_DK, ruined))
    if toppled:
        # post lying flat, arms jutting up, head rolled loose
        rect(img, x - 13, gy - 3, x + 6, gy - 1, wood_md)
        rect(img, x - 13, gy - 1, x + 6, gy - 1, wood_dk)
        rect(img, x - 13, gy - 3, x + 6, gy - 3, wood_lt)
        for i in range(7):                        # crossbar sticking skyward
            px(img, x - 4 + i // 3, gy - 4 - i, wood_md)
            px(img, x - 3 + i // 3, gy - 4 - i, wood_dk)
        rect(img, x + 9, gy - 4, x + 13, gy - 1, bur_md)   # loose head
        rect(img, x + 9, gy - 1, x + 13, gy - 1, bur_dk)
        px(img, x + 10, gy - 4, bur_lt)
        for dx in (-8, -2, 5, 8):                 # spilled straw
            px(img, x + dx, gy, straw)
        return
    # post
    rect(img, x - 1, gy - 20, x + 1, gy, wood_md)
    rect(img, x - 1, gy - 20, x - 1, gy, wood_lt)
    rect(img, x + 1, gy - 20, x + 1, gy, wood_dk)
    # crossbar arms
    rect(img, x - 7, gy - 15, x + 7, gy - 13, wood_md)
    rect(img, x - 7, gy - 15, x + 7, gy - 15, wood_lt)
    rect(img, x - 7, gy - 13, x + 7, gy - 13, wood_dk)
    # wrapped burlap torso with stitch marks
    rect(img, x - 3, gy - 12, x + 3, gy - 4, bur_md)
    rect(img, x - 3, gy - 12, x - 3, gy - 4, bur_lt)
    rect(img, x + 3, gy - 12, x + 3, gy - 4, bur_dk)
    rect(img, x - 3, gy - 4, x + 3, gy - 4, bur_dk)
    for dy in (10, 7):                            # rope wraps
        rect(img, x - 3, gy - dy, x + 3, gy - dy, bur_dk)
    # sack head, lit upper-left, straw at the neck
    rect(img, x - 2, gy - 26, x + 2, gy - 21, bur_md)
    rect(img, x - 2, gy - 26, x - 1, gy - 25, bur_lt)
    rect(img, x + 2, gy - 23, x + 2, gy - 21, bur_dk)
    rect(img, x - 2, gy - 21, x + 2, gy - 21, bur_dk)
    px(img, x - 3, gy - 20, straw)
    px(img, x + 2, gy - 20, straw)
    if ruined:                                    # battered even when upright
        px(img, x, gy - 24, bur_dk)
        px(img, x - 5, gy - 14, wood_dk)          # chipped arm


def draw_target(img, ruined):
    """Archery butt: straw disc with painted rings on an A-frame. Ruined:
    fallen flat in the dirt, straw torn out, a broken arrow beside it."""
    cx, cy = TARGET_CX, TARGET_CY
    straw_dk = pick(STRAW_DK, ruined)
    straw_md = pick(STRAW_MD, ruined)
    straw_lt = pick(STRAW_LT, ruined)
    wood_dk = pick(WOOD_DK, ruined)
    wood_md = pick(WOOD_MD, ruined)
    if ruined:
        gy = 72
        # the disc lies face-up: squashed ellipse of cold straw + faded rings
        for y in range(gy - 4, gy + 5):
            for x in range(cx - 10, cx + 11):
                dx, dy = x - cx, (y - gy) * 2
                d2 = dx * dx + dy * dy
                if d2 <= 100:
                    c = straw_md if d2 > 36 else cold(TARGET_CREAM)
                    if d2 <= 8:
                        c = cold(TARGET_RED)
                    px(img, x, y, c)
        rect(img, cx - 10, gy + 5, cx + 10, gy + 5, pick(DIRT_DK, True))
        for dx, dy in ((-13, 2), (12, -1), (-6, 6)):     # torn straw
            px(img, cx + dx, gy + dy, straw_dk)
        for i in range(6):                        # broken arrow shaft
            px(img, cx - 16 + i, gy - 6, wood_md)
        px(img, cx - 17, gy - 6, cold(STEEL_LT))
        return
    gy = 74
    # A-frame legs
    for i in range(10):
        px(img, cx - 5 + i // 2, gy - i, wood_md)
        px(img, cx + 5 - i // 2, gy - i, wood_dk)
    rect(img, cx - 6, gy + 1, cx + 6, gy + 1, DIRT_DK)   # ground shadow
    # straw disc, lit upper-left
    for y in range(cy - 10, cy + 11):
        for x in range(cx - 10, cx + 11):
            dx, dy = x - cx, y - cy
            d2 = dx * dx + dy * dy
            if d2 > 100:
                continue
            if d2 > 72:
                c = straw_lt if (dx < 0 and dy < 0) else \
                    (straw_dk if (dx > 2 and dy > 2) else straw_md)
            elif d2 > 42:
                c = TARGET_CREAM
            elif d2 > 16:
                c = TARGET_RED
            elif d2 > 3:
                c = TARGET_CREAM
            else:
                c = TARGET_RED
            px(img, x, y, c)
    # edge definition so the disc pops off the dirt
    for y in range(cy - 10, cy + 11):
        for x in range(cx - 10, cx + 11):
            dx, dy = x - cx, y - cy
            if 90 < dx * dx + dy * dy <= 100 and (dx > 4 or dy > 4):
                px(img, x, y, straw_dk)
    # two arrows in the target: shaft + pale fletching
    for ax, ay, ddx in ((cx - 3, cy - 2, -1), (cx + 2, cy + 3, 1)):
        for i in range(4):
            px(img, ax + i * ddx, ay - i, WOOD_DK)
        px(img, ax + 4 * ddx, ay - 4, TARGET_CREAM)
        px(img, ax + 5 * ddx, ay - 4, TARGET_CREAM)


def draw_front_fence(img, ruined):
    """Front fence returns with a wide gate opening onto the path. Sits on
    opaque dirt, so shading is hand-placed. Ruined: the left run is down."""
    wood_dk = pick(WOOD_DK, ruined)
    wood_md = pick(WOOD_MD, ruined)
    wood_lt = pick(WOOD_LT, ruined)
    for seg_l, seg_r, posts in ((8, 56, (8, 30, 53)), (118, 152, (118, 135, 150))):
        broken = ruined and seg_l == 8
        for ry in (84, 89):
            for x in range(seg_l, seg_r + 1):
                if broken and 20 <= x <= 42:
                    continue
                px(img, x, ry, wood_lt if ry == 84 else wood_md)
                px(img, x, ry + 1, wood_md)
                px(img, x, ry + 2, wood_dk)
        for x0 in posts:
            if broken and x0 == 30:               # snapped front post
                rect(img, x0, 89, x0 + 2, 94, wood_md)
                rect(img, x0 + 2, 89, x0 + 2, 94, wood_dk)
                continue
            rect(img, x0, 80, x0 + 2, 94, wood_md)
            rect(img, x0, 80, x0, 94, wood_lt)
            rect(img, x0 + 2, 80, x0 + 2, 94, wood_dk)
            px(img, x0, 80, wood_lt)
            rect(img, x0, 94, x0 + 2, 94, OUTLINE)
        if broken:
            for i in range(20):                   # downed rails in the dirt
                px(img, 22 + i, 87 + i // 7, cold(WOOD_MD))
                px(img, 22 + i, 88 + i // 7, cold(WOOD_DK))


def outline(img):
    """Selective 1px outline on the silhouette; lit (lighter) on top edges."""
    src = img.copy()
    for y in range(H):
        for x in range(W):
            if src.getpixel((x, y))[3] == 0:
                continue
            edge_top = y == 0 or src.getpixel((x, y - 1))[3] == 0
            edge_other = (x == 0 or src.getpixel((x - 1, y))[3] == 0
                          or x == W - 1 or src.getpixel((x + 1, y))[3] == 0
                          or y == H - 1 or src.getpixel((x, y + 1))[3] == 0)
            if edge_top and not edge_other:
                px(img, x, y, OUTLINE_LIT)
            elif edge_other or edge_top:
                px(img, x, y, OUTLINE)


def build(ruined):
    rng = random.Random(0x7261)
    img = Image.new("RGBA", (W, H))
    draw_yard(img, rng, ruined)
    draw_back_fence(img, ruined)
    draw_shed(img, ruined)
    draw_rack(img, ruined)
    draw_dummy(img, DUMMY1_X, DUMMY1_GY, ruined, False)
    draw_dummy(img, DUMMY2_X, DUMMY2_GY, ruined, ruined)  # toppled when ruined
    draw_target(img, ruined)
    draw_front_fence(img, ruined)
    outline(img)
    if not ruined:
        # steel spear tip glint, re-placed after the outline pass
        px(img, 73, 22, STEEL_LT)
        px(img, 73, 21, STEEL_LT)
    return img


def main():
    root = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
    sprite_dir = os.path.join(root, "lord-of-hirelings", "sprites", "town")
    preview_dir = os.path.join(root, "SourceArt", "previews")
    os.makedirs(sprite_dir, exist_ok=True)
    os.makedirs(preview_dir, exist_ok=True)
    for state, ruined in (("normal", False), ("ruined", True)):
        img = build(ruined)
        out_path = os.path.join(sprite_dir, "training_grounds_%s.png" % state)
        img.save(out_path)
        big = img.resize((W * 4, H * 4), Image.NEAREST)
        bg = Image.new("RGBA", big.size, (92, 124, 60, 255))     # town grass
        bg.alpha_composite(big)
        bg.convert("RGB").save(os.path.join(
            preview_dir, "training_grounds_%s_preview_4x.png" % state))
        print("wrote", out_path)


if __name__ == "__main__":
    main()
