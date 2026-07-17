"""Generate the Armor shop building sprite (ruined + normal states).

Authored per design/LordofHirelings_ArtStyleGuide.md:
  - armourer's workshop that reads as an armourer at a glance (building
    table): breastplate-and-shield sign, mannequin in plate outside,
    riveted door; steel blue-gray accent
  - deliberately NO chimney and NO forge mouth — the smithy next door owns
    those tells; this building's silhouette hooks are the mannequin and
    the hanging shield sign
  - ruined state = broken silhouette, dark and cold: collapsed roof,
    boarded door, toppled mannequin, fallen sign, rubble
  - light from top-left, hue-shifted ramps, selective 1px outline in a
    deep warm brown (never pure black), lightened on the lit top side
  - footprint inside the 112-160w x 96-128t building envelope

Canvas is 128x128 with a bottom-center pivot (building base at y=127).
Shares the layout/ruin approach of generate_weapon_shop.py (cold() muting,
ridge-sag collapse) so the two shops read as one town.

Output: lord-of-hirelings/sprites/town/armor_shop_normal.png (128x128)
        lord-of-hirelings/sprites/town/armor_shop_ruined.png (128x128)
        SourceArt/previews/armor_shop_normal_preview_4x.png
        SourceArt/previews/armor_shop_ruined_preview_4x.png
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

ROOF_DK = (46, 50, 64, 255)     # blue-slate shingle shadow — cooler than the
ROOF_MD = (76, 84, 100, 255)    # smithy's charcoal roof; part of the shop's
ROOF_LT = (116, 126, 142, 255)  # steel blue-gray identity

STEEL_DK = (96, 108, 128, 255)  # plate/rivet metal — the shop's accent
STEEL_MD = (150, 162, 180, 255)
STEEL_LT = (214, 224, 238, 255)

DARK_IN = (30, 24, 28, 255)     # interior darkness

OUTLINE = (44, 32, 28, 255)     # deep warm-dark brown, never pure black
OUTLINE_LIT = (96, 68, 48, 255)

# --- layout (y down, base at y=127) -----------------------------------------
WALL_L, WALL_R = 14, 113        # wall block: 100 wide
WALL_TOP = 64
BASE = 127
RIDGE_Y = 26
EAVE_Y = 64
EAVE_L, EAVE_R = 6, 121
RIDGE_L, RIDGE_R = 40, 87
DOOR_L, DOOR_R = 66, 88         # riveted door, right of center
DOOR_TOP = 90
RUIN_BREAK_X = 62               # roof east of here is collapsed when ruined
MANN_X = 50                     # plate mannequin stands here, between the
                                # display window and the door


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
    steel_md = cold(STEEL_MD) if ruined else STEEL_MD
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
        # steel ridge cap only survives on the west side
        rect(img, RIDGE_L, RIDGE_Y, RUIN_BREAK_X - 4, RIDGE_Y + 1, steel_md)
        rect(img, RIDGE_L, RIDGE_Y + 2, RUIN_BREAK_X - 4, RIDGE_Y + 2, roof_dk)
    else:
        # steel ridge cap — the armourer's metal roof trim
        rect(img, RIDGE_L, RIDGE_Y, RIDGE_R, RIDGE_Y + 1, steel_md)
        rect(img, RIDGE_L, RIDGE_Y, RIDGE_L + 14, RIDGE_Y, STEEL_LT)
        rect(img, RIDGE_L, RIDGE_Y + 2, RIDGE_R, RIDGE_Y + 2, roof_dk)
    # eave board (full width either way — the frame survives)
    left, right = roof_span(EAVE_Y)
    rect(img, left, EAVE_Y, right, EAVE_Y + 1, wood_md)
    rect(img, left, EAVE_Y + 1, right, EAVE_Y + 1, wood_dk)


def draw_door(img, ruined):
    """Riveted door: heavy planks crossed by two steel bands studded with
    rivets. Ruined: mouth gapes dark with planks nailed shut."""
    wood_dk = cold(WOOD_DK) if ruined else WOOD_DK
    wood_md = cold(WOOD_MD) if ruined else WOOD_MD
    wood_lt = cold(WOOD_LT) if ruined else WOOD_LT
    steel_dk = cold(STEEL_DK) if ruined else STEEL_DK
    steel_md = cold(STEEL_MD) if ruined else STEEL_MD
    rect(img, DOOR_L, DOOR_TOP, DOOR_R, BASE - 1, wood_dk)      # frame
    # arch the top corners
    for dx in (0, 1):
        for dy in range(1 - dx):
            px(img, DOOR_L + dx, DOOR_TOP + dy, (0, 0, 0, 0))
            px(img, DOOR_R - dx, DOOR_TOP + dy, (0, 0, 0, 0))
    if ruined:
        rect(img, DOOR_L + 1, DOOR_TOP + 1, DOOR_R - 1, BASE - 1, DARK_IN)
        # two planks nailed across the dark doorway
        for i in range(19):
            x = DOOR_L + 2 + i
            px(img, x, DOOR_TOP + 7 + i // 3, wood_md)
            px(img, x, DOOR_TOP + 8 + i // 3, wood_dk)
        for i in range(17):
            x = DOOR_L + 3 + i
            px(img, x, BASE - 12 - i // 4, wood_md)
    else:
        # door leaf: vertical planks, lit toward the left
        rect(img, DOOR_L + 1, DOOR_TOP + 1, DOOR_R - 1, BASE - 1, wood_md)
        rect(img, DOOR_L + 1, DOOR_TOP + 1, DOOR_L + 4, BASE - 1, wood_lt)
        for x in range(DOOR_L + 5, DOOR_R - 1, 5):
            for y in range(DOOR_TOP + 1, BASE - 1):
                px(img, x, y, wood_dk)
        # two steel bands with rivets — the "riveted door" tell
        for band_y in (DOOR_TOP + 6, BASE - 10):
            rect(img, DOOR_L + 1, band_y, DOOR_R - 1, band_y + 1, steel_md)
            rect(img, DOOR_L + 1, band_y + 1, DOOR_R - 1, band_y + 1, steel_dk)
            for x in range(DOOR_L + 3, DOOR_R - 1, 4):
                px(img, x, band_y, STEEL_LT)
        # ring handle
        px(img, DOOR_R - 5, DOOR_TOP + 16, steel_md)
        px(img, DOOR_R - 5, DOOR_TOP + 17, steel_dk)
    # threshold step
    rect(img, DOOR_L - 1, BASE - 1, DOOR_R + 1, BASE - 1,
         cold(STONE_DK) if ruined else STONE_DK)


def draw_window(img, ruined):
    """Display window left of the door: plate glinting behind the mullion,
    or shutters hanging broken."""
    wood_dk = cold(WOOD_DK) if ruined else WOOD_DK
    wood_md = cold(WOOD_MD) if ruined else WOOD_MD
    x0 = 24
    rect(img, x0, 90, x0 + 13, 106, wood_dk)
    if ruined:
        rect(img, x0 + 1, 91, x0 + 12, 105, DARK_IN)
        for i in range(12):                   # one shutter hangs broken
            px(img, x0 + 1 + i, 93 + i, wood_md)
    else:
        rect(img, x0 + 1, 91, x0 + 12, 105, DARK_IN)
        # displayed breastplate catching the light inside
        rect(img, x0 + 4, 95, x0 + 9, 101, STEEL_MD)
        rect(img, x0 + 4, 95, x0 + 6, 97, STEEL_LT)
        rect(img, x0 + 5, 102, x0 + 8, 102, STEEL_DK)
        rect(img, x0 + 6, 91, x0 + 7, 105, wood_dk)              # mullion
        rect(img, x0 + 1, 98, x0 + 12, 98, wood_dk)
    rect(img, x0 - 1, 106, x0 + 14, 107, wood_md)                # sill


def draw_mannequin(img, ruined):
    """Plate mannequin on a post outside, left of the door — the armourer's
    street tell. Ruined: post snapped, armor toppled in the dirt."""
    steel_dk = cold(STEEL_DK) if ruined else STEEL_DK
    steel_md = cold(STEEL_MD) if ruined else STEEL_MD
    steel_lt = cold(STEEL_LT) if ruined else STEEL_LT
    wood_dk = cold(WOOD_DK) if ruined else WOOD_DK
    wood_md = cold(WOOD_MD) if ruined else WOOD_MD
    x = MANN_X
    if ruined:
        # snapped post stub
        rect(img, x, BASE - 6, x + 1, BASE - 1, wood_dk)
        px(img, x, BASE - 7, wood_md)
        # breastplate lying on its side in the dirt beside it
        rect(img, x + 4, BASE - 4, x + 11, BASE - 2, steel_dk)
        rect(img, x + 5, BASE - 4, x + 8, BASE - 4, steel_md)
        # helm rolled away
        rect(img, x + 15, BASE - 3, x + 17, BASE - 2, steel_dk)
        px(img, x + 15, BASE - 3, steel_md)
        return
    # post and crossbar stand
    rect(img, x + 3, BASE - 20, x + 4, BASE - 1, wood_dk)
    rect(img, x, BASE - 1, x + 7, BASE - 1, wood_md)             # foot
    # breastplate: lit upper-left, gorget notch at the collar
    rect(img, x, BASE - 19, x + 7, BASE - 11, steel_md)
    rect(img, x, BASE - 19, x + 2, BASE - 16, steel_lt)
    rect(img, x + 6, BASE - 18, x + 7, BASE - 11, steel_dk)
    rect(img, x + 2, BASE - 11, x + 5, BASE - 10, steel_dk)      # faulds
    px(img, x + 3, BASE - 19, DARK_IN)                           # collar
    px(img, x + 4, BASE - 19, DARK_IN)
    # pauldron nubs breaking the shoulder line
    px(img, x - 1, BASE - 19, steel_md)
    px(img, x + 8, BASE - 19, steel_dk)
    # helm: rounded dome with a dark visor slit
    rect(img, x + 2, BASE - 25, x + 5, BASE - 21, steel_md)
    rect(img, x + 2, BASE - 25, x + 3, BASE - 24, steel_lt)
    rect(img, x + 2, BASE - 22, x + 5, BASE - 22, DARK_IN)       # visor
    px(img, x + 2, BASE - 26, steel_dk)                          # crest nub
    px(img, x + 3, BASE - 26, steel_md)


def draw_sign(img, ruined):
    """Breastplate-and-shield sign hanging from a bracket arm."""
    wood_dk = cold(WOOD_DK) if ruined else WOOD_DK
    wood_md = cold(WOOD_MD) if ruined else WOOD_MD
    steel_dk = cold(STEEL_DK) if ruined else STEEL_DK
    steel_md = cold(STEEL_MD) if ruined else STEEL_MD
    steel_lt = cold(STEEL_LT) if ruined else STEEL_LT
    bx = 92                                                      # bracket root
    rect(img, bx, 72, bx + 13, 72, wood_md)                      # bracket arm
    px(img, bx + 13, 73, wood_dk)
    px(img, bx, 73, wood_dk)
    if ruined:
        # bracket bare; the shield board fell and leans against the wall
        rect(img, bx + 2, 118, bx + 8, 124, steel_dk)
        rect(img, bx + 3, 119, bx + 5, 121, steel_md)
        px(img, bx + 2, 125, wood_dk)
        px(img, bx + 8, 125, wood_dk)
        return
    hx = bx + 6                                                  # hanging rings
    for dx in (-3, 3):
        px(img, hx + dx, 73, steel_dk)
        px(img, hx + dx, 74, steel_dk)
    # shield board: kite shape, steel face on a wood rim
    rect(img, hx - 5, 75, hx + 5, 84, wood_dk)
    rect(img, hx - 4, 76, hx + 4, 84, steel_md)
    rect(img, hx - 4, 76, hx - 2, 78, steel_lt)                  # lit corner
    rect(img, hx + 3, 77, hx + 4, 84, steel_dk)
    for dy, half in ((85, 3), (86, 2), (87, 1)):                 # tapered point
        rect(img, hx - half, dy, hx + half, dy, steel_md)
        px(img, hx + half, dy, steel_dk)
    px(img, hx, 88, steel_dk)
    # breastplate emblem on the shield face
    rect(img, hx - 2, 78, hx + 1, 81, steel_dk)
    px(img, hx - 2, 78, DARK_IN)
    px(img, hx + 1, 78, DARK_IN)
    px(img, hx - 1, 82, steel_dk)
    px(img, hx, 82, steel_dk)


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
    rng = random.Random(0xA4302)
    img = Image.new("RGBA", (W, H))
    draw_walls(img, rng, ruined)
    draw_roof(img, rng, ruined)
    draw_door(img, ruined)
    draw_window(img, ruined)
    draw_mannequin(img, ruined)
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
        out_path = os.path.join(sprite_dir, "armor_shop_%s.png" % state)
        img.save(out_path)
        big = img.resize((W * 4, H * 4), Image.NEAREST)
        bg = Image.new("RGBA", big.size, (92, 124, 60, 255))     # town grass
        bg.alpha_composite(big)
        bg.convert("RGB").save(os.path.join(
            preview_dir, "armor_shop_%s_preview_4x.png" % state))
        print("wrote", out_path)


if __name__ == "__main__":
    main()
