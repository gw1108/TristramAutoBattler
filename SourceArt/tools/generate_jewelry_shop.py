"""Generate the Jewelry shop building sprite (ruined + normal states).

Authored per design/LordofHirelings_ArtStyleGuide.md:
  - goldsmith/jeweller that reads as a goldsmith at a glance (building
    table): hanging gold RING sign, ornate arched display window with
    glinting gems, finest masonry, warm lamp light by the door
  - accent identity is gem teal/purple glints against warm gold — no
    chimney, no forge, no steel; the silhouette hooks are the ring sign
    and the arched window
  - ruined state = broken silhouette, dark and cold: collapsed roof,
    boarded window, fallen ring half-buried in the dirt, dead lantern
  - light from top-left, hue-shifted ramps, selective 1px outline in a
    deep warm brown (never pure black), lightened on the lit top side
  - footprint inside the 112-160w x 96-128t building envelope

Canvas is 128x128 with a bottom-center pivot (building base at y=127).
Shares the layout/ruin approach of generate_weapon_shop.py and
generate_armor_shop.py (cold() muting, ridge-sag collapse) so the three
shops read as one town.

Output: lord-of-hirelings/sprites/town/jewelry_shop_normal.png (128x128)
        lord-of-hirelings/sprites/town/jewelry_shop_ruined.png (128x128)
        SourceArt/previews/jewelry_shop_normal_preview_4x.png
        SourceArt/previews/jewelry_shop_ruined_preview_4x.png
"""
import os
import random
from PIL import Image

W, H = 128, 128

# --- palette (3-step hue-shifted ramps; shadows cool, lights warm) ---------
STONE_DK = (96, 86, 92, 255)    # dressed sandstone shadow (cool mauve)
STONE_MD = (154, 140, 126, 255) # dressed sandstone mid — paler than the
STONE_LT = (198, 182, 152, 255) # armourer's rubble stone: "finest masonry"

WOOD_DK = (58, 42, 38, 255)     # timber shadow (cool dark brown)
WOOD_MD = (96, 68, 48, 255)     # timber mid
WOOD_LT = (132, 100, 66, 255)   # timber light (warm)

ROOF_DK = (50, 40, 62, 255)     # plum-slate shingle shadow — the purple half
ROOF_MD = (84, 66, 98, 255)     # of the shop's gem accent lives on the roof
ROOF_LT = (126, 102, 138, 255)

GOLD_DK = (138, 92, 36, 255)    # gilded trim — the goldsmith's metal
GOLD_MD = (202, 152, 56, 255)
GOLD_LT = (246, 216, 122, 255)

GEM_TEAL = (66, 194, 184, 255)  # display glints — teal
GEM_TEAL_LT = (172, 242, 232, 255)
GEM_PURP = (150, 88, 198, 255)  # display glints — purple
GEM_PURP_LT = (214, 168, 240, 255)

LAMP_CORE = (255, 234, 160, 255)  # lantern flame
LAMP_WARM = (232, 176, 88, 255)   # warm cast on the surrounding stone

DARK_IN = (30, 24, 28, 255)     # interior darkness

OUTLINE = (44, 32, 28, 255)     # deep warm-dark brown, never pure black
OUTLINE_LIT = (96, 68, 48, 255)

# --- layout (y down, base at y=127) -----------------------------------------
WALL_L, WALL_R = 18, 109        # wall block: 92 wide — trimmer than the smithy
WALL_TOP = 64
BASE = 127
RIDGE_Y = 26
EAVE_Y = 64
EAVE_L, EAVE_R = 10, 117
RIDGE_L, RIDGE_R = 44, 83
DOOR_L, DOOR_R = 70, 88         # fine panel door, right of center
DOOR_TOP = 92
RUIN_BREAK_X = 64               # roof east of here is collapsed when ruined
WIN_L, WIN_R = 26, 47           # ornate arched display window, left of door
WIN_TOP, WIN_BOT = 86, 108
LAMP_X = 61                     # wall lantern between window and door


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


def roof_span(y):
    """Left/right x extent of the roof face at row y (linear slope)."""
    t = (y - RIDGE_Y) / (EAVE_Y - RIDGE_Y)
    left = round(RIDGE_L + (EAVE_L - RIDGE_L) * t)
    right = round(RIDGE_R + (EAVE_R - RIDGE_R) * t)
    return left, right


def draw_walls(img, rng, ruined):
    stone_dk = cold(STONE_DK) if ruined else STONE_DK
    stone_md = cold(STONE_MD) if ruined else STONE_MD
    stone_lt = cold(STONE_LT) if ruined else STONE_LT
    wood_dk = cold(WOOD_DK) if ruined else WOOD_DK
    rect(img, WALL_L, WALL_TOP, WALL_R, BASE, stone_md)
    # top-left light: warm sheen on the upper-left stone
    rect(img, WALL_L, WALL_TOP, WALL_L + 24, WALL_TOP + 10, stone_lt)
    # eave shadow band under the roof overhang
    rect(img, WALL_L, WALL_TOP, WALL_R, WALL_TOP + 3, stone_dk)
    # right-side shade (light is top-left)
    rect(img, WALL_R - 5, WALL_TOP, WALL_R, BASE, stone_dk)
    # finest masonry: tight, perfectly regular ashlar courses — every joint
    # laid, none skipped, unlike the armourer's rougher random coursing
    for row, y in enumerate(range(WALL_TOP + 7, BASE - 4, 7)):
        for x in range(WALL_L + 1, WALL_R):
            px(img, x, y, stone_dk)
        off = 3 if row % 2 else 0
        for x in range(WALL_L + 3 + off, WALL_R - 1, 6):
            for yy in range(y - 6, y):
                px(img, x, yy, stone_dk)
    # dressed quoin stones up both corners — the mason showed off here
    for i, y in enumerate(range(WALL_TOP + 4, BASE - 6, 10)):
        wq = 4 if i % 2 else 6
        rect(img, WALL_L, y, WALL_L + wq, y + 3, stone_lt)
        rect(img, WALL_L, y + 3, WALL_L + wq, y + 3, stone_dk)
        rect(img, WALL_R - wq, y, WALL_R, y + 3,
             stone_md if ruined else stone_lt)
        rect(img, WALL_R - wq, y + 3, WALL_R, y + 3, stone_dk)
    # foundation course
    rect(img, WALL_L, BASE - 5, WALL_R, BASE, stone_dk)
    rect(img, WALL_L, BASE, WALL_R, BASE, wood_dk)


def draw_roof(img, rng, ruined):
    roof_dk = cold(ROOF_DK) if ruined else ROOF_DK
    roof_md = cold(ROOF_MD) if ruined else ROOF_MD
    roof_lt = cold(ROOF_LT) if ruined else ROOF_LT
    gold_md = cold(GOLD_MD) if ruined else GOLD_MD
    wood_md = cold(WOOD_MD) if ruined else WOOD_MD
    wood_dk = cold(WOOD_DK) if ruined else WOOD_DK
    def break_x(y):
        """Jagged east edge of the surviving roof when ruined."""
        return RUIN_BREAK_X + (y - RIDGE_Y) // 3 + ((y * 7) % 3 - 1)

    for y in range(RIDGE_Y, EAVE_Y + 1):
        left, right = roof_span(y)
        for x in range(left, right + 1):
            if ruined and x > break_x(y):
                # collapsed east half: silhouette bitten down from the ridge,
                # dark cavity below the bite
                sag = min(13, (x - RUIN_BREAK_X) // 2 + ((x * 13) % 3))
                if y < RIDGE_Y + sag:
                    continue
                px(img, x, y, DARK_IN)
                continue
            t = (x - left) / max(1, right - left)
            ty = (y - RIDGE_Y) / (EAVE_Y - RIDGE_Y)
            if t < 0.30 and ty < 0.6:
                c = roof_lt
            elif t > 0.72 or ty > 0.85:
                c = roof_dk
            else:
                c = roof_md
            px(img, x, y, c)
    # slate rows: darker seam every 6px with staggered notches
    for i, y in enumerate(range(RIDGE_Y + 5, EAVE_Y, 6)):
        left, right = roof_span(y)
        stop = min(right, break_x(y)) if ruined else right
        for x in range(left + 1, stop):
            px(img, x, y, roof_dk)
        off = 3 if i % 2 else 0
        for x in range(left + 2 + off, stop - 1, 7):
            px(img, x, y - 1, roof_dk)
            px(img, x + 1, y - 2, roof_lt if x < (left + right) // 2 else roof_md)
    if ruined:
        # dark broken slates rimming the hole edge
        for y in range(RIDGE_Y + 1, EAVE_Y):
            bx = break_x(y)
            px(img, bx, y, roof_dk)
            px(img, bx - 1, y, roof_dk if (y * 5) % 4 == 0 else roof_md)
        # sagging broken rafters crossing the cavity
        for i in range(26):
            x = RUIN_BREAK_X + 2 + i
            px(img, x, RIDGE_Y + 10 + i // 2, wood_md)
            px(img, x, RIDGE_Y + 11 + i // 2, wood_dk)
        for i in range(16):
            x = RUIN_BREAK_X + 14 + i
            px(img, x, RIDGE_Y + 28 - i // 2, wood_md)
        # gilt ridge cap only survives on the west side, its shine gone
        rect(img, RIDGE_L, RIDGE_Y, RUIN_BREAK_X - 4, RIDGE_Y + 1, gold_md)
        rect(img, RIDGE_L, RIDGE_Y + 2, RUIN_BREAK_X - 4, RIDGE_Y + 2, roof_dk)
    else:
        # gilded ridge cap — the goldsmith's rooftop boast
        rect(img, RIDGE_L, RIDGE_Y, RIDGE_R, RIDGE_Y + 1, gold_md)
        rect(img, RIDGE_L, RIDGE_Y, RIDGE_L + 14, RIDGE_Y, GOLD_LT)
        rect(img, RIDGE_L, RIDGE_Y + 2, RIDGE_R, RIDGE_Y + 2, roof_dk)
        # small gilt finial at the west ridge end
        px(img, RIDGE_L, RIDGE_Y - 1, GOLD_MD)
        px(img, RIDGE_L, RIDGE_Y - 2, GOLD_LT)
    # eave board (full width either way — the frame survives)
    left, right = roof_span(EAVE_Y)
    rect(img, left, EAVE_Y, right, EAVE_Y + 1, wood_md)
    rect(img, left, EAVE_Y + 1, right, EAVE_Y + 1, wood_dk)


def draw_door(img, ruined):
    """Fine panel door with a gilt handle — a merchant's door, no rivets.
    Ruined: mouth gapes dark with planks nailed shut."""
    wood_dk = cold(WOOD_DK) if ruined else WOOD_DK
    wood_md = cold(WOOD_MD) if ruined else WOOD_MD
    wood_lt = cold(WOOD_LT) if ruined else WOOD_LT
    stone_lt = cold(STONE_LT) if ruined else STONE_LT
    rect(img, DOOR_L, DOOR_TOP, DOOR_R, BASE - 1, wood_dk)      # frame
    # arch the top corners
    for dx in (0, 1):
        for dy in range(1 - dx):
            px(img, DOOR_L + dx, DOOR_TOP + dy, (0, 0, 0, 0))
            px(img, DOOR_R - dx, DOOR_TOP + dy, (0, 0, 0, 0))
    # carved stone lintel over the door
    rect(img, DOOR_L - 1, DOOR_TOP - 3, DOOR_R + 1, DOOR_TOP - 1, stone_lt)
    rect(img, DOOR_L - 1, DOOR_TOP - 1, DOOR_R + 1, DOOR_TOP - 1,
         cold(STONE_DK) if ruined else STONE_DK)
    if ruined:
        rect(img, DOOR_L + 1, DOOR_TOP + 1, DOOR_R - 1, BASE - 1, DARK_IN)
        # two planks nailed across the dark doorway
        for i in range(15):
            x = DOOR_L + 2 + i
            px(img, x, DOOR_TOP + 6 + i // 3, wood_md)
            px(img, x, DOOR_TOP + 7 + i // 3, wood_dk)
        for i in range(13):
            x = DOOR_L + 3 + i
            px(img, x, BASE - 11 - i // 4, wood_md)
    else:
        # door leaf: two carpentered panels, lit toward the left
        rect(img, DOOR_L + 1, DOOR_TOP + 1, DOOR_R - 1, BASE - 1, wood_md)
        rect(img, DOOR_L + 1, DOOR_TOP + 1, DOOR_L + 3, BASE - 1, wood_lt)
        for py0, py1 in ((DOOR_TOP + 4, DOOR_TOP + 14), (DOOR_TOP + 18, BASE - 4)):
            rect(img, DOOR_L + 4, py0, DOOR_R - 4, py0, wood_dk)
            rect(img, DOOR_L + 4, py1, DOOR_R - 4, py1, wood_dk)
            rect(img, DOOR_L + 4, py0, DOOR_L + 4, py1, wood_dk)
            rect(img, DOOR_R - 4, py0, DOOR_R - 4, py1, wood_dk)
        # gilt ring handle
        px(img, DOOR_R - 5, DOOR_TOP + 16, GOLD_MD)
        px(img, DOOR_R - 5, DOOR_TOP + 17, GOLD_DK)
    # threshold step
    rect(img, DOOR_L - 1, BASE - 1, DOOR_R + 1, BASE - 1,
         cold(STONE_DK) if ruined else STONE_DK)


def draw_window(img, ruined):
    """Ornate arched display window left of the door: gems glinting teal and
    purple on a velvet-dark shelf behind gilt mullions. The jeweller's street
    tell. Ruined: arch survives, boarded over, everything dark."""
    wood_dk = cold(WOOD_DK) if ruined else WOOD_DK
    wood_md = cold(WOOD_MD) if ruined else WOOD_MD
    stone_lt = cold(STONE_LT) if ruined else STONE_LT
    stone_dk = cold(STONE_DK) if ruined else STONE_DK
    # dressed stone surround with an arched head
    rect(img, WIN_L - 2, WIN_TOP - 2, WIN_R + 2, WIN_BOT + 1, stone_lt)
    rect(img, WIN_R + 1, WIN_TOP - 2, WIN_R + 2, WIN_BOT + 1, stone_dk)
    for dx in (0, 1):                          # round the surround's corners
        for dy in range(2 - dx):
            px(img, WIN_L - 2 + dx, WIN_TOP - 2 + dy, (0, 0, 0, 0))
            px(img, WIN_R + 2 - dx, WIN_TOP - 2 + dy, (0, 0, 0, 0))
    # window opening: arched top, dark interior
    rect(img, WIN_L, WIN_TOP, WIN_R, WIN_BOT, DARK_IN)
    for dx in (0, 1):
        for dy in range(2 - dx):
            px(img, WIN_L + dx, WIN_TOP + dy, stone_lt)
            px(img, WIN_R - dx, WIN_TOP + dy,
               stone_dk if not ruined else stone_lt)
    if ruined:
        # two boards nailed across the smashed display
        for i in range(20):
            x = WIN_L + 1 + i
            px(img, x, WIN_TOP + 4 + i // 3, wood_md)
            px(img, x, WIN_TOP + 5 + i // 3, wood_dk)
        for i in range(18):
            x = WIN_L + 2 + i
            px(img, x, WIN_BOT - 5 - i // 4, wood_md)
    else:
        # velvet-dark display shelf catching warm lamplight
        rect(img, WIN_L + 2, WIN_BOT - 7, WIN_R - 2, WIN_BOT - 1,
             (52, 34, 46, 255))
        rect(img, WIN_L + 2, WIN_BOT - 7, WIN_R - 2, WIN_BOT - 7,
             (84, 56, 66, 255))
        # the goods: gem glints, teal and purple, each a 2px spark + star tip
        for gx, base_c, lit_c in ((WIN_L + 5, GEM_TEAL, GEM_TEAL_LT),
                                  (WIN_L + 11, GEM_PURP, GEM_PURP_LT),
                                  (WIN_L + 17, GEM_TEAL, GEM_TEAL_LT)):
            px(img, gx, WIN_BOT - 4, base_c)
            px(img, gx + 1, WIN_BOT - 4, base_c)
            px(img, gx, WIN_BOT - 5, lit_c)
            px(img, gx, WIN_BOT - 6, lit_c)   # star tip
        # a gold chain laid between the gems
        for i, gx in enumerate(range(WIN_L + 7, WIN_L + 11)):
            px(img, gx, WIN_BOT - 3, GOLD_MD if i % 2 else GOLD_DK)
        px(img, WIN_L + 14, WIN_BOT - 3, GOLD_LT)
        px(img, WIN_L + 15, WIN_BOT - 3, GOLD_MD)
        # gilt mullions: one vertical, one transom above the shelf
        rect(img, (WIN_L + WIN_R) // 2, WIN_TOP + 1, (WIN_L + WIN_R) // 2,
             WIN_BOT - 8, GOLD_DK)
        px(img, (WIN_L + WIN_R) // 2, WIN_TOP + 2, GOLD_MD)
        rect(img, WIN_L + 1, WIN_BOT - 8, WIN_R - 1, WIN_BOT - 8, GOLD_DK)
        px(img, WIN_L + 2, WIN_BOT - 8, GOLD_MD)
    # projecting stone sill
    rect(img, WIN_L - 3, WIN_BOT + 2, WIN_R + 3, WIN_BOT + 3, stone_lt)
    rect(img, WIN_L - 3, WIN_BOT + 3, WIN_R + 3, WIN_BOT + 3, stone_dk)


def draw_lamp(img, ruined):
    """Wall lantern between window and door — the warm lamp light that says
    someone minds the shop. Ruined: bracket bare, lantern dark and crooked."""
    wood_dk = cold(WOOD_DK) if ruined else WOOD_DK
    gold_dk = cold(GOLD_DK) if ruined else GOLD_DK
    gold_md = cold(GOLD_MD) if ruined else GOLD_MD
    x = LAMP_X
    top = 84
    rect(img, x, top, x, top + 2, wood_dk)          # bracket stub off the wall
    if ruined:
        # dark lantern hanging askew, glass gone
        px(img, x - 1, top + 3, gold_dk)
        rect(img, x - 2, top + 4, x, top + 7, DARK_IN)
        px(img, x - 2, top + 4, gold_dk)
        px(img, x - 1, top + 8, gold_dk)
        return
    # lantern body: gilt cage around a warm flame
    px(img, x, top + 3, gold_dk)                    # hanger link
    rect(img, x - 1, top + 4, x + 1, top + 8, gold_dk)
    rect(img, x, top + 5, x, top + 7, LAMP_CORE)    # flame core
    px(img, x - 1, top + 4, gold_md)                # lit cage corner
    px(img, x, top + 9, gold_md)                    # base drip
    # warm cast dithered onto the stone around the lantern
    for dx, dy in ((-2, 5), (2, 4), (-2, 8), (2, 7), (-1, 10), (1, 10),
                   (-3, 6), (3, 6), (0, 11)):
        px(img, x + dx, top + dy, LAMP_WARM)


def draw_sign(img, ruined):
    """The ring sign: a great gold ring hanging bare from the bracket arm —
    no board, the ring IS the sign. Ruined: bracket empty, the ring fallen
    and half-buried in the dirt below."""
    wood_dk = cold(WOOD_DK) if ruined else WOOD_DK
    wood_md = cold(WOOD_MD) if ruined else WOOD_MD
    gold_dk = cold(GOLD_DK) if ruined else GOLD_DK
    gold_md = cold(GOLD_MD) if ruined else GOLD_MD
    bx = 94                                                      # bracket root
    rect(img, bx, 72, bx + 13, 72, wood_md)                      # bracket arm
    px(img, bx + 13, 73, wood_dk)
    px(img, bx, 73, wood_dk)
    hx = bx + 7                                                  # hang point
    if ruined:
        # the fallen ring, on edge and half-sunk in the ground
        for dx in (-3, -2, 2, 3):
            px(img, hx + dx, BASE - 3, gold_dk)
        for dx in (-1, 0, 1):
            px(img, hx + dx, BASE - 4, gold_md)
            px(img, hx + dx, BASE - 2, gold_dk)
        return
    px(img, hx, 73, gold_dk)                                     # hanger links
    px(img, hx, 74, gold_dk)
    # the ring: a 9px open torus, lit upper-left, shaded lower-right
    ring = [(-1, 0), (0, 0), (1, 0),                             # top rim
            (-2, 1), (2, 1), (-3, 2), (3, 2), (-3, 3), (3, 3),
            (-3, 4), (3, 4), (-2, 5), (2, 5),
            (-1, 6), (0, 6), (1, 6)]                             # bottom rim
    for dx, dy in ring:
        y = 75 + dy
        lit = dx <= 0 and dy <= 2
        dark = dx >= 1 and dy >= 4
        c = GOLD_LT if lit else (gold_dk if dark else gold_md)
        px(img, hx + dx, y, c)
    # the set stone: a teal gem seated at the ring's crown
    px(img, hx, 75, GEM_TEAL)
    px(img, hx, 74, GEM_TEAL_LT)


def draw_rubble(img, rng, ruined):
    if not ruined:
        return
    stone_md = cold(STONE_MD)
    stone_dk = cold(STONE_DK)
    for _ in range(26):                       # tumbled stone along the front
        x = rng.randrange(WALL_L - 4, WALL_R + 5)
        y = BASE - rng.randrange(0, 3)
        px(img, x, y, stone_md if rng.random() < 0.5 else stone_dk)
        if rng.random() < 0.4:
            px(img, x + 1, y, stone_dk)
    for _ in range(8):                        # slate shards below the collapse
        x = rng.randrange(RUIN_BREAK_X, WALL_R)
        y = BASE - rng.randrange(1, 4)
        px(img, x, y, cold(ROOF_MD))


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
    rng = random.Random(0x0E3E1)
    img = Image.new("RGBA", (W, H))
    draw_walls(img, rng, ruined)
    draw_roof(img, rng, ruined)
    draw_door(img, ruined)
    draw_window(img, ruined)
    draw_lamp(img, ruined)
    draw_sign(img, ruined)
    draw_rubble(img, rng, ruined)
    outline(img)
    return img


def main():
    root = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
    sprite_dir = os.path.join(root, "lord-of-hirelings", "sprites", "town")
    preview_dir = os.path.join(root, "SourceArt", "previews")
    os.makedirs(sprite_dir, exist_ok=True)
    os.makedirs(preview_dir, exist_ok=True)
    for state, ruined in (("normal", False), ("ruined", True)):
        img = build(ruined)
        out_path = os.path.join(sprite_dir, "jewelry_shop_%s.png" % state)
        img.save(out_path)
        big = img.resize((W * 4, H * 4), Image.NEAREST)
        bg = Image.new("RGBA", big.size, (92, 124, 60, 255))     # town grass
        bg.alpha_composite(big)
        bg.convert("RGB").save(os.path.join(
            preview_dir, "jewelry_shop_%s_preview_4x.png" % state))
        print("wrote", out_path)


if __name__ == "__main__":
    main()
