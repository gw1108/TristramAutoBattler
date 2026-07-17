"""Generate the Inn (level 1) building sprite for the town scene.

Authored per design/LordofHirelings_ArtStyleGuide.md:
  - cozy timber-framed tavern, wide + welcoming silhouette (building table)
  - hanging tankard sign, warm gold light accent (UI gold ramp)
  - chimney with smoke, light from top-left, hue-shifted ramps
  - selective 1px outline in a deep warm brown (never pure black),
    lightened on the lit top side; smoke stays soft (no outline)
  - footprint inside the 112-160w x 96-128t building envelope

Canvas is 128x128 with a bottom-center pivot (building base at y=127).

Output: lord-of-hirelings/sprites/town/inn_lv1.png (128x128)
        SourceArt/previews/inn_lv1_preview_4x.png
"""
import os
import random
from PIL import Image

W, H = 128, 128

# --- palette (3-step hue-shifted ramps; shadows cool, lights warm) ---------
WOOD_DK = (58, 42, 38, 255)     # timber shadow (cool dark brown)
WOOD_MD = (96, 68, 48, 255)     # timber mid
WOOD_LT = (132, 100, 66, 255)   # timber light (warm)

PLAS_DK = (166, 148, 130, 255)  # plaster shadow (cool)
PLAS_MD = (206, 188, 158, 255)  # plaster mid
PLAS_LT = (230, 216, 186, 255)  # plaster light (warm cream)

ROOF_DK = (98, 54, 48, 255)     # shingle shadow (cool red-brown)
ROOF_MD = (142, 80, 56, 255)    # shingle mid
ROOF_LT = (184, 118, 72, 255)   # shingle light (warm)

GOLD_DK = (201, 161, 90, 255)   # UI gold ramp #c9a15a
GOLD_MD = (240, 216, 144, 255)  # #f0d890
GOLD_LT = (255, 233, 176, 255)  # #ffe9b0

OUTLINE = (44, 32, 28, 255)     # deep warm-dark brown, never pure black
OUTLINE_LIT = (96, 68, 48, 255) # broken/lit outline on the top side

SMOKE_A = (206, 206, 212, 150)
SMOKE_B = (228, 228, 234, 110)

# --- layout (y down, base at y=127) -----------------------------------------
WALL_L, WALL_R = 10, 117        # wall block: 108 wide
WALL_TOP = 66
BASE = 127
RIDGE_Y = 24
EAVE_Y = 66
EAVE_L, EAVE_R = 2, 125
RIDGE_L, RIDGE_R = 36, 91
DOOR_L, DOOR_R = 56, 71         # 16 wide, arched
DOOR_TOP = 86
CHIM_L, CHIM_R = 90, 101
CHIM_TOP = 10


def px(img, x, y, c):
    if 0 <= x < W and 0 <= y < H:
        img.putpixel((x, y), c)


def rect(img, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px(img, x, y, c)


def roof_span(y):
    """Left/right x extent of the roof face at row y (linear slope)."""
    t = (y - RIDGE_Y) / (EAVE_Y - RIDGE_Y)
    left = round(RIDGE_L + (EAVE_L - RIDGE_L) * t)
    right = round(RIDGE_R + (EAVE_R - RIDGE_R) * t)
    return left, right


def draw_walls(img, rng):
    rect(img, WALL_L, WALL_TOP, WALL_R, BASE, PLAS_MD)
    # top-left light: a warm sheen on the upper-left plaster
    rect(img, WALL_L, WALL_TOP, WALL_L + 30, WALL_TOP + 12, PLAS_LT)
    # eave shadow band under the roof overhang
    rect(img, WALL_L, WALL_TOP, WALL_R, WALL_TOP + 3, PLAS_DK)
    # right-side shade (light is top-left)
    rect(img, WALL_R - 6, WALL_TOP, WALL_R, BASE, PLAS_DK)
    # sparse plaster texture
    for _ in range(70):
        x = rng.randrange(WALL_L + 1, WALL_R)
        y = rng.randrange(WALL_TOP + 4, BASE - 8)
        px(img, x, y, PLAS_DK if rng.random() < 0.6 else PLAS_LT)
    # stone foundation course
    rect(img, WALL_L, BASE - 6, WALL_R, BASE, PLAS_DK)
    for x in range(WALL_L, WALL_R + 1, 7):
        px(img, x + 3, BASE - 5, WOOD_DK)
        px(img, x, BASE - 2, WOOD_DK)
    rect(img, WALL_L, BASE, WALL_R, BASE, WOOD_DK)


def draw_timbers(img):
    # vertical posts
    for x0 in (WALL_L, 46, 81, WALL_R - 2):
        rect(img, x0, WALL_TOP, x0 + 2, BASE - 7, WOOD_MD)
        rect(img, x0, WALL_TOP, x0, BASE - 7, WOOD_LT)   # lit left edge
        rect(img, x0 + 2, WALL_TOP, x0 + 2, BASE - 7, WOOD_DK)
    # horizontal rails: top plate and mid rail
    for y0 in (WALL_TOP + 2, 92):
        rect(img, WALL_L, y0, WALL_R, y0 + 2, WOOD_MD)
        rect(img, WALL_L, y0, WALL_R, y0, WOOD_LT)
        rect(img, WALL_L, y0 + 2, WALL_R, y0 + 2, WOOD_DK)
    # diagonal braces in the two outer upper panels
    for x0, flip in ((16, False), (108, True)):
        for i in range(18):
            x = x0 + (i if not flip else -i)
            y = WALL_TOP + 6 + i
            px(img, x, y, WOOD_MD)
            px(img, x + 1, y, WOOD_MD)
            px(img, x, y - 1, WOOD_LT)


def draw_roof(img, rng):
    for y in range(RIDGE_Y, EAVE_Y + 1):
        left, right = roof_span(y)
        for x in range(left, right + 1):
            # light from top-left: left third light, right quarter shadow
            t = (x - left) / max(1, right - left)
            ty = (y - RIDGE_Y) / (EAVE_Y - RIDGE_Y)
            if t < 0.30 and ty < 0.6:
                c = ROOF_LT
            elif t > 0.72 or ty > 0.85:
                c = ROOF_DK
            else:
                c = ROOF_MD
            px(img, x, y, c)
    # shingle rows: darker seam every 6px with staggered notches
    for i, y in enumerate(range(RIDGE_Y + 5, EAVE_Y, 6)):
        left, right = roof_span(y)
        for x in range(left + 1, right):
            px(img, x, y, ROOF_DK)
        off = 3 if i % 2 else 0
        for x in range(left + 2 + off, right - 1, 7):
            px(img, x, y - 1, ROOF_DK)
            px(img, x + 1, y - 2, ROOF_LT if x < (left + right) // 2 else ROOF_MD)
    # ridge cap
    rect(img, RIDGE_L, RIDGE_Y, RIDGE_R, RIDGE_Y + 1, ROOF_LT)
    rect(img, RIDGE_L, RIDGE_Y + 2, RIDGE_R, RIDGE_Y + 2, ROOF_DK)
    # eave board
    left, right = roof_span(EAVE_Y)
    rect(img, left, EAVE_Y, right, EAVE_Y + 1, WOOD_MD)
    rect(img, left, EAVE_Y + 1, right, EAVE_Y + 1, WOOD_DK)


def draw_chimney(img):
    left, _ = roof_span(CHIM_TOP + 18)
    rect(img, CHIM_L, CHIM_TOP, CHIM_R, CHIM_TOP + 22, PLAS_DK)
    # stone texture + lit left face
    rect(img, CHIM_L, CHIM_TOP, CHIM_L + 2, CHIM_TOP + 22, PLAS_MD)
    for y in range(CHIM_TOP + 3, CHIM_TOP + 22, 4):
        for x in range(CHIM_L + 1, CHIM_R, 5):
            px(img, x, y, WOOD_DK)
    # cap
    rect(img, CHIM_L - 1, CHIM_TOP, CHIM_R + 1, CHIM_TOP + 2, PLAS_MD)
    rect(img, CHIM_L - 1, CHIM_TOP, CHIM_R + 1, CHIM_TOP, PLAS_LT)
    rect(img, CHIM_L - 1, CHIM_TOP + 2, CHIM_R + 1, CHIM_TOP + 2, WOOD_DK)


def draw_smoke(img, rng):
    """Soft puffs drifting up-right from the chimney mouth. Drawn after the
    outline pass so smoke edges stay soft (no outline)."""
    cx = (CHIM_L + CHIM_R) // 2
    for i, (dx, dy, r) in enumerate(((0, -4, 2), (3, -8, 2), (7, -11, 3))):
        c = SMOKE_A if i < 2 else SMOKE_B
        for yy in range(-r, r + 1):
            for xx in range(-r, r + 1):
                if xx * xx + yy * yy <= r * r + rng.choice((-1, 0, 1)):
                    px(img, cx + dx + xx, CHIM_TOP + dy + yy, c)


def draw_windows(img):
    """Warm gold lit windows — the Inn's accent color."""
    # two ground-floor windows flanking the door
    for x0 in (20, 96):
        rect(img, x0, 98, x0 + 13, 113, WOOD_DK)                 # frame
        rect(img, x0 + 1, 99, x0 + 12, 112, GOLD_MD)             # glow
        rect(img, x0 + 1, 99, x0 + 12, 101, GOLD_LT)             # top light
        rect(img, x0 + 1, 110, x0 + 12, 112, GOLD_DK)
        rect(img, x0 + 6, 99, x0 + 7, 112, WOOD_DK)              # mullions
        rect(img, x0 + 1, 105, x0 + 12, 105, WOOD_DK)
        rect(img, x0 - 1, 113, x0 + 14, 114, WOOD_MD)            # sill
        px(img, x0 - 1, 114, WOOD_DK)
        px(img, x0 + 14, 114, WOOD_DK)
    # two small upper windows under the eaves
    for x0 in (26, 92):
        rect(img, x0, 74, x0 + 7, 83, WOOD_DK)
        rect(img, x0 + 1, 75, x0 + 6, 82, GOLD_MD)
        rect(img, x0 + 1, 75, x0 + 6, 76, GOLD_LT)
        rect(img, x0 + 3, 75, x0 + 4, 82, WOOD_DK)


def draw_door(img):
    # arched doorway: dark opening, plank door, gold lantern glow above
    rect(img, DOOR_L, DOOR_TOP, DOOR_R, BASE - 1, WOOD_DK)       # frame
    rect(img, DOOR_L + 1, DOOR_TOP + 1, DOOR_R - 1, BASE - 1, WOOD_MD)
    # arch the top corners
    for dx in (0, 1):
        px(img, DOOR_L + dx, DOOR_TOP + (1 - dx), WOOD_DK)
        px(img, DOOR_R - dx, DOOR_TOP + (1 - dx), WOOD_DK)
        px(img, DOOR_L + dx, DOOR_TOP, (0, 0, 0, 0))
        px(img, DOOR_R - dx, DOOR_TOP, (0, 0, 0, 0))
    # planks
    for x in range(DOOR_L + 4, DOOR_R - 1, 4):
        rect(img, x, DOOR_TOP + 2, x, BASE - 1, WOOD_DK)
    rect(img, DOOR_L + 1, DOOR_TOP + 1, DOOR_R - 1, DOOR_TOP + 1, WOOD_LT)
    # iron band + handle
    rect(img, DOOR_L + 1, DOOR_TOP + 14, DOOR_R - 1, DOOR_TOP + 14, WOOD_DK)
    rect(img, DOOR_R - 4, DOOR_TOP + 18, DOOR_R - 3, DOOR_TOP + 19, GOLD_DK)
    # step
    rect(img, DOOR_L - 1, BASE - 2, DOOR_R + 1, BASE - 1, PLAS_DK)
    # small gold lantern above the door
    px(img, (DOOR_L + DOOR_R) // 2, DOOR_TOP - 4, GOLD_LT)
    rect(img, (DOOR_L + DOOR_R) // 2 - 1, DOOR_TOP - 3, (DOOR_L + DOOR_R) // 2 + 1,
         DOOR_TOP - 2, GOLD_MD)


def draw_sign(img):
    """Hanging tankard sign on a bracket, right of the door."""
    bx = 78                                                      # bracket root
    rect(img, bx, 74, bx + 11, 74, WOOD_MD)                      # bracket arm
    px(img, bx + 11, 75, WOOD_DK)
    for dy in (1, 2):                                            # chains
        px(img, bx + 4, 74 + dy, GOLD_DK)
        px(img, bx + 9, 74 + dy, GOLD_DK)
    # sign board
    rect(img, bx + 2, 77, bx + 11, 88, WOOD_MD)
    rect(img, bx + 2, 77, bx + 11, 77, WOOD_LT)
    rect(img, bx + 2, 88, bx + 11, 88, WOOD_DK)
    rect(img, bx + 2, 77, bx + 2, 88, WOOD_LT)
    rect(img, bx + 11, 77, bx + 11, 88, WOOD_DK)
    # tankard: gold body, handle, foam
    rect(img, bx + 5, 81, bx + 8, 86, GOLD_DK)
    rect(img, bx + 5, 81, bx + 6, 86, GOLD_MD)
    px(img, bx + 9, 82, GOLD_DK)                                 # handle
    px(img, bx + 10, 83, GOLD_DK)
    px(img, bx + 9, 84, GOLD_DK)
    rect(img, bx + 5, 80, bx + 8, 80, GOLD_LT)                   # foam


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


def main():
    root = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
    rng = random.Random(0x1AA1)
    img = Image.new("RGBA", (W, H))

    draw_walls(img, rng)
    draw_timbers(img)
    draw_roof(img, rng)
    draw_chimney(img)
    draw_windows(img)
    draw_door(img)
    draw_sign(img)
    outline(img)
    draw_smoke(img, rng)      # after outline: smoke edges stay soft

    out_path = os.path.join(root, "lord-of-hirelings", "sprites", "town",
                            "inn_lv1.png")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    img.save(out_path)

    preview_dir = os.path.join(root, "SourceArt", "previews")
    os.makedirs(preview_dir, exist_ok=True)
    big = img.resize((W * 4, H * 4), Image.NEAREST)
    bg = Image.new("RGBA", big.size, (92, 124, 60, 255))         # town grass
    bg.alpha_composite(big)
    bg.convert("RGB").save(os.path.join(preview_dir, "inn_lv1_preview_4x.png"))
    print("wrote", out_path)


if __name__ == "__main__":
    main()
