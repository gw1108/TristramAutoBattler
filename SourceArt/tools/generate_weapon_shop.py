"""Generate the Weapon shop building sprite (ruined + normal states).

Authored per design/LordofHirelings_ArtStyleGuide.md:
  - smithy that reads as a forge at a glance (building table): open forge
    front, big chimney, hanging-blades sign, forge-orange glow accent
  - ruined state = broken silhouette, dark and cold: collapsed roof,
    cold forge, cracked chimney, fallen sign blade, rubble
  - light from top-left, hue-shifted ramps, selective 1px outline in a
    deep warm brown (never pure black), lightened on the lit top side
  - footprint inside the 112-160w x 96-128t building envelope

Canvas is 128x128 with a bottom-center pivot (building base at y=127).

Output: lord-of-hirelings/sprites/town/weapon_shop_normal.png (128x128)
        lord-of-hirelings/sprites/town/weapon_shop_ruined.png (128x128)
        SourceArt/previews/weapon_shop_normal_preview_4x.png
        SourceArt/previews/weapon_shop_ruined_preview_4x.png
"""
import os
import random
from PIL import Image

W, H = 128, 128

# --- palette (3-step hue-shifted ramps; shadows cool, lights warm) ---------
STONE_DK = (76, 74, 88, 255)    # wall stone shadow (cool slate)
STONE_MD = (122, 118, 122, 255) # wall stone mid
STONE_LT = (160, 152, 138, 255) # wall stone light (warm)

WOOD_DK = (58, 42, 38, 255)     # timber shadow (cool dark brown)
WOOD_MD = (96, 68, 48, 255)     # timber mid
WOOD_LT = (132, 100, 66, 255)   # timber light (warm)

ROOF_DK = (52, 46, 58, 255)     # dark shingle shadow (cool charcoal)
ROOF_MD = (84, 74, 78, 255)     # shingle mid
ROOF_LT = (120, 104, 92, 255)   # shingle light (warm)

FIRE_DK = (198, 84, 32, 255)    # forge glow ramp — the shop's accent
FIRE_MD = (244, 142, 52, 255)
FIRE_LT = (255, 210, 122, 255)

STEEL_DK = (108, 118, 134, 255) # blade metal
STEEL_MD = (156, 166, 182, 255)
STEEL_LT = (212, 220, 232, 255)

DARK_IN = (30, 24, 28, 255)     # interior darkness

OUTLINE = (44, 32, 28, 255)     # deep warm-dark brown, never pure black
OUTLINE_LIT = (96, 68, 48, 255)

SMOKE_A = (92, 88, 96, 150)     # forge smoke, sootier than the inn's
SMOKE_B = (128, 124, 130, 110)

# --- layout (y down, base at y=127) -----------------------------------------
WALL_L, WALL_R = 14, 113        # wall block: 100 wide
WALL_TOP = 64
BASE = 127
RIDGE_Y = 26
EAVE_Y = 64
EAVE_L, EAVE_R = 6, 121
RIDGE_L, RIDGE_R = 40, 87
FORGE_L, FORGE_R = 50, 85      # wide open forge front, arched
FORGE_TOP = 84
CHIM_L, CHIM_R = 24, 41        # big stone chimney, left side
CHIM_TOP = 6
RUIN_BREAK_X = 66              # roof east of here is collapsed when ruined
CHIM_RUIN_TOP = 34             # cracked chimney height when ruined


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
    rect(img, WALL_L, WALL_TOP, WALL_L + 26, WALL_TOP + 10, stone_lt)
    # eave shadow band under the roof overhang
    rect(img, WALL_L, WALL_TOP, WALL_R, WALL_TOP + 3, stone_dk)
    # right-side shade (light is top-left)
    rect(img, WALL_R - 6, WALL_TOP, WALL_R, BASE, stone_dk)
    # coursed stone joints
    for row, y in enumerate(range(WALL_TOP + 8, BASE - 4, 9)):
        for x in range(WALL_L + 1, WALL_R):
            if rng.random() < 0.85:
                px(img, x, y, stone_dk)
        off = 4 if row % 2 else 0
        for x in range(WALL_L + 3 + off, WALL_R - 1, 8):
            for yy in range(y - 8, y):
                px(img, x, yy, stone_dk)
    # foundation course
    rect(img, WALL_L, BASE - 5, WALL_R, BASE, stone_dk)
    rect(img, WALL_L, BASE, WALL_R, BASE, wood_dk)


def draw_roof(img, rng, ruined):
    roof_dk = cold(ROOF_DK) if ruined else ROOF_DK
    roof_md = cold(ROOF_MD) if ruined else ROOF_MD
    roof_lt = cold(ROOF_LT) if ruined else ROOF_LT
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
    # shingle rows: darker seam every 6px with staggered notches
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
        # dark broken shingles rimming the hole edge
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
        # ridge cap only survives on the west side
        rect(img, RIDGE_L, RIDGE_Y, RUIN_BREAK_X - 4, RIDGE_Y + 1, roof_lt)
        rect(img, RIDGE_L, RIDGE_Y + 2, RUIN_BREAK_X - 4, RIDGE_Y + 2, roof_dk)
    else:
        rect(img, RIDGE_L, RIDGE_Y, RIDGE_R, RIDGE_Y + 1, roof_lt)
        rect(img, RIDGE_L, RIDGE_Y + 2, RIDGE_R, RIDGE_Y + 2, roof_dk)
    # eave board (full width either way — the frame survives)
    left, right = roof_span(EAVE_Y)
    rect(img, left, EAVE_Y, right, EAVE_Y + 1, wood_md)
    rect(img, left, EAVE_Y + 1, right, EAVE_Y + 1, wood_dk)


def draw_chimney(img, rng, ruined):
    """Big stone chimney — the smithy's silhouette tell."""
    stone_dk = cold(STONE_DK) if ruined else STONE_DK
    stone_md = cold(STONE_MD) if ruined else STONE_MD
    stone_lt = cold(STONE_LT) if ruined else STONE_LT
    top = CHIM_RUIN_TOP if ruined else CHIM_TOP
    rect(img, CHIM_L, top, CHIM_R, EAVE_Y, stone_dk)
    rect(img, CHIM_L, top, CHIM_L + 3, EAVE_Y, stone_md)   # lit left face
    for y in range(top + 3, EAVE_Y, 5):
        for x in range(CHIM_L + 1, CHIM_R, 6):
            px(img, x, y, cold(WOOD_DK) if ruined else WOOD_DK)
    if ruined:
        # cracked, jagged broken top
        for x in range(CHIM_L, CHIM_R + 1):
            for dy in range(rng.randrange(0, 4)):
                px(img, x, top + dy, (0, 0, 0, 0))
        for i in range(6):                    # crack running down the face
            px(img, CHIM_L + 7 + (i % 2), top + 6 + i * 3, DARK_IN)
    else:
        # cap, lit on top
        rect(img, CHIM_L - 1, top, CHIM_R + 1, top + 2, stone_md)
        rect(img, CHIM_L - 1, top, CHIM_R + 1, top, stone_lt)
        rect(img, CHIM_L - 1, top + 2, CHIM_R + 1, top + 2, stone_dk)
        # ember light inside the flue mouth
        rect(img, CHIM_L + 5, top + 3, CHIM_R - 5, top + 3, FIRE_DK)


def draw_forge_front(img, rng, ruined):
    """Wide arched forge opening: glowing hearth + anvil, or cold and dark."""
    wood_dk = cold(WOOD_DK) if ruined else WOOD_DK
    wood_md = cold(WOOD_MD) if ruined else WOOD_MD
    rect(img, FORGE_L, FORGE_TOP, FORGE_R, BASE - 1, wood_dk)    # frame
    rect(img, FORGE_L + 1, FORGE_TOP + 1, FORGE_R - 1, BASE - 1, DARK_IN)
    # arch the top corners
    for dx in (0, 1, 2):
        arch = (2 - dx) if dx < 2 else 0
        px(img, FORGE_L + dx, FORGE_TOP + arch, wood_dk)
        px(img, FORGE_R - dx, FORGE_TOP + arch, wood_dk)
        for dy in range(arch):
            px(img, FORGE_L + dx, FORGE_TOP + dy, (0, 0, 0, 0))
            px(img, FORGE_R - dx, FORGE_TOP + dy, (0, 0, 0, 0))
    cx = (FORGE_L + FORGE_R) // 2
    if not ruined:
        # hearth glow: brightest low-center, falling off outward
        for y in range(FORGE_TOP + 2, BASE - 1):
            for x in range(FORGE_L + 2, FORGE_R - 1):
                d = abs(x - cx) + abs(y - (BASE - 6)) * 2
                if d <= 10:
                    px(img, x, y, FIRE_LT)
                elif d <= 18:
                    px(img, x, y, FIRE_MD)
                elif d <= 26:
                    px(img, x, y, FIRE_DK)
        # glow licking the frame edge
        rect(img, FORGE_L + 1, BASE - 2, FORGE_R - 1, BASE - 1, FIRE_DK)
    # anvil silhouette in front of the hearth (stays through ruin — cold iron)
    av = DARK_IN if not ruined else (52, 50, 58, 255)
    rect(img, cx - 7, BASE - 12, cx + 6, BASE - 9, av)           # body
    rect(img, cx + 6, BASE - 12, cx + 9, BASE - 11, av)          # horn
    rect(img, cx - 4, BASE - 9, cx + 3, BASE - 5, av)            # waist
    rect(img, cx - 6, BASE - 5, cx + 5, BASE - 2, av)            # foot
    if not ruined:
        rect(img, cx - 7, BASE - 12, cx + 6, BASE - 12, FIRE_DK)  # glow rim
    else:
        # boarded-up corner: two planks nailed across the cold mouth
        for i in range(30):
            x = FORGE_L + 3 + i
            px(img, x, FORGE_TOP + 6 + i // 3, wood_md)
            px(img, x, FORGE_TOP + 7 + i // 3, wood_dk)
        for i in range(26):
            x = FORGE_L + 6 + i
            px(img, x, BASE - 22 - i // 4, wood_md)
    # threshold step
    rect(img, FORGE_L - 1, BASE - 1, FORGE_R + 1, BASE - 1,
         cold(STONE_DK) if ruined else STONE_DK)


def draw_window(img, ruined):
    """Small shuttered window, right of the forge mouth."""
    wood_dk = cold(WOOD_DK) if ruined else WOOD_DK
    wood_md = cold(WOOD_MD) if ruined else WOOD_MD
    x0 = 96
    rect(img, x0, 92, x0 + 9, 104, wood_dk)
    if ruined:
        rect(img, x0 + 1, 93, x0 + 8, 103, DARK_IN)
        for i in range(9):                    # one shutter hangs broken
            px(img, x0 + 1 + i, 95 + i, wood_md)
    else:
        rect(img, x0 + 1, 93, x0 + 8, 103, FIRE_DK)              # dim forge light
        rect(img, x0 + 2, 96, x0 + 7, 100, FIRE_MD)
        rect(img, x0 + 4, 93, x0 + 5, 103, wood_dk)              # mullion
    rect(img, x0 - 1, 104, x0 + 10, 105, wood_md)                # sill


def draw_sign(img, ruined):
    """Hanging-blades sign: two swords dangling from a bracket arm."""
    wood_dk = cold(WOOD_DK) if ruined else WOOD_DK
    wood_md = cold(WOOD_MD) if ruined else WOOD_MD
    steel_dk = cold(STEEL_DK) if ruined else STEEL_DK
    steel_md = cold(STEEL_MD) if ruined else STEEL_MD
    steel_lt = cold(STEEL_LT) if ruined else STEEL_LT
    bx = 88                                                      # bracket root
    rect(img, bx, 72, bx + 13, 72, wood_md)                      # bracket arm
    px(img, bx + 13, 73, wood_dk)
    px(img, bx, 73, wood_dk)
    if ruined:
        # bracket bare but one blade fallen, leaning against the wall below
        for i in range(10):
            px(img, bx + 3 + i // 3, 116 + i, steel_dk)
        rect(img, bx + 6, 124, bx + 7, 126, wood_dk)             # grip in dirt
        return
    for hx in (bx + 3, bx + 10):                                 # hanging rings
        px(img, hx, 73, steel_dk)
        px(img, hx, 74, steel_dk)
    for i, hx in enumerate((bx + 3, bx + 10)):                   # two blades
        rect(img, hx - 1, 75, hx + 1, 76, wood_dk)               # crossguard
        rect(img, hx, 77, hx, 88 - i * 2, steel_md)              # blade
        px(img, hx - 1 if i == 0 else hx + 1, 78, steel_lt)      # edge glint
        px(img, hx, 89 - i * 2, steel_lt)                        # tip
        px(img, hx, 74, wood_md)                                 # grip


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
    for _ in range(8):                        # roof shards below the collapse
        x = rng.randrange(RUIN_BREAK_X, WALL_R)
        y = BASE - rng.randrange(1, 4)
        px(img, x, y, cold(ROOF_MD))


def draw_smoke(img, rng):
    """Sooty forge smoke, up-right from the chimney. Drawn after the outline
    pass so smoke edges stay soft (no outline)."""
    cx = (CHIM_L + CHIM_R) // 2
    for i, (dx, dy, r) in enumerate(((0, -4, 2), (4, -8, 3), (8, -12, 3))):
        c = SMOKE_A if i < 2 else SMOKE_B
        for yy in range(-r, r + 1):
            for xx in range(-r, r + 1):
                if xx * xx + yy * yy <= r * r + rng.choice((-1, 0, 1)):
                    px(img, cx + dx + xx, CHIM_TOP + dy + yy, c)


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
    rng = random.Random(0x5A17)
    img = Image.new("RGBA", (W, H))
    draw_walls(img, rng, ruined)
    draw_roof(img, rng, ruined)
    draw_chimney(img, rng, ruined)
    draw_forge_front(img, rng, ruined)
    draw_window(img, ruined)
    draw_sign(img, ruined)
    draw_rubble(img, rng, ruined)
    outline(img)
    if not ruined:
        draw_smoke(img, rng)      # after outline: smoke edges stay soft
    return img


def main():
    root = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
    sprite_dir = os.path.join(root, "lord-of-hirelings", "sprites", "town")
    preview_dir = os.path.join(root, "SourceArt", "previews")
    os.makedirs(sprite_dir, exist_ok=True)
    os.makedirs(preview_dir, exist_ok=True)
    for state, ruined in (("normal", False), ("ruined", True)):
        img = build(ruined)
        out_path = os.path.join(sprite_dir, "weapon_shop_%s.png" % state)
        img.save(out_path)
        big = img.resize((W * 4, H * 4), Image.NEAREST)
        bg = Image.new("RGBA", big.size, (92, 124, 60, 255))     # town grass
        bg.alpha_composite(big)
        bg.convert("RGB").save(os.path.join(
            preview_dir, "weapon_shop_%s_preview_4x.png" % state))
        print("wrote", out_path)


if __name__ == "__main__":
    main()
