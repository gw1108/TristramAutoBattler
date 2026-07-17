"""Generate the Graveyard plot sprite and headstone-variant sheet.

Authored per design/LordofHirelings_ArtStyleGuide.md and the art asset list:
  - non-building interactable: "Small fenced plot with 12 grave positions.
    3-4 headstone variants (cross, slab, rounded stone) to mix; fresh-dirt
    mound state for a new grave. Name renders as text, not art."
  - the plot ships EMPTY (worn-earth patches mark the 12 positions);
    headstones/mounds are separate sheet cells composited at runtime as
    adventurers die, so there is no ruined/normal building state here
  - light from top-left, hue-shifted ramps, selective 1px outline in a
    deep warm brown (never pure black), lightened on the lit top side

Plot canvas is 144x96 with a bottom-center pivot (base at y=95) — an open
yard like the training grounds, not a roofed facade. Shares the weathered
wood ramps and outline pass of the town generators (generate_training_grounds.py
etc.) so the props read as one town. The gate gap faces the BACK (north)
because the plot sits on the south side of the west path arm.

Grave grid: 4 columns x 3 rows. Patch centers (plot pixel coords) are
columns x = 24, 56, 88, 120 and rows y = 52, 68, 84 — keep
scripts/town/graveyard.gd GRAVE_OFFSETS in sync with these.

Headstone sheet: 5 cells of 16x24, bottom-center pivot per cell:
  0 stone cross | 1 slab | 2 rounded stone | 3 cracked leaning slab
  4 fresh-dirt mound (new grave, no stone yet)

Output: lord-of-hirelings/sprites/town/graveyard_plot.png (144x96)
        lord-of-hirelings/sprites/town/graveyard_headstones.png (80x24)
        SourceArt/previews/graveyard_plot_preview_4x.png
        SourceArt/previews/graveyard_headstones_preview_4x.png
"""
import os
import random
from PIL import Image

W, H = 144, 96
BASE = 95

# --- palette (3-step hue-shifted ramps; shadows cool, lights warm) ---------
WOOD_DK = (58, 46, 42, 255)     # weathered fence timber (shared town ramp)
WOOD_MD = (108, 90, 70, 255)
WOOD_LT = (156, 138, 104, 255)

GRASS_DK = (58, 80, 48, 255)    # unmown graveyard turf, cooler than the lawn
GRASS_MD = (78, 102, 58, 255)
GRASS_LT = (102, 124, 70, 255)

EARTH_DK = (70, 54, 42, 255)    # old settled grave earth (worn patches)
EARTH_MD = (98, 76, 56, 255)
EARTH_LT = (124, 100, 72, 255)

MOUND_DK = (82, 60, 44, 255)    # fresh-turned mound dirt, richer and darker
MOUND_MD = (112, 84, 58, 255)
MOUND_LT = (142, 112, 78, 255)

STONE_DK = (72, 74, 88, 255)    # headstone granite: cool shadow, warm light
STONE_MD = (118, 120, 128, 255)
STONE_LT = (168, 164, 150, 255)

OUTLINE = (44, 32, 28, 255)     # deep warm-dark brown, never pure black
OUTLINE_LIT = (96, 68, 48, 255)

# --- layout (y down, base at y=95) ------------------------------------------
GROUND_TOP = 30                 # back edge of the plot turf
FENCE_BASE = 32                 # back fence posts stand on the plot's rim
GATE_L, GATE_R = 60, 84         # rail gap in the back fence (gate to the path)
GRAVE_XS = (24, 56, 88, 120)    # 4 columns x 3 rows = 12 grave positions
GRAVE_YS = (52, 68, 84)


def px(img, x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), c)


def rect(img, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px(img, x, y, c)


def draw_turf(img, rng):
    """Unmown turf, slightly narrower at the back for depth."""
    for y in range(GROUND_TOP, BASE + 1):
        inset = max(0, (BASE - y) // 12)
        for x in range(3 + inset, W - 4 - inset + 1):
            # deterministic speckle so the ground is stable, not noisy
            h = (x * 7 + y * 13) % 31
            if h == 0:
                c = GRASS_DK
            elif h in (9, 21) and y < BASE - 2:
                c = GRASS_LT
            else:
                c = GRASS_MD
            px(img, x, y, c)
    # shaded back rim under the fence line
    for x in range(4, W - 4):
        px(img, x, GROUND_TOP, GRASS_DK)
        if (x * 5) % 3:
            px(img, x, GROUND_TOP + 1, GRASS_DK)
    # sparse weed tufts between the rows
    for _ in range(10):
        x = rng.randrange(10, W - 10)
        y = rng.randrange(GROUND_TOP + 6, BASE - 4)
        px(img, x, y, GRASS_DK)
        px(img, x, y - 1, GRASS_LT)


def draw_grave_patches(img):
    """Worn-earth ovals marking the 12 grave positions of the empty plot."""
    for gy in GRAVE_YS:
        for cx in GRAVE_XS:
            for y in range(gy - 2, gy + 3):
                for x in range(cx - 6, cx + 7):
                    dx, dy = x - cx, (y - gy) * 3
                    if dx * dx + dy * dy > 40:
                        continue
                    h = (x * 11 + y * 17) % 7
                    c = EARTH_DK if h == 0 else (EARTH_LT if h == 3 else EARTH_MD)
                    px(img, x, y, c)
            # turf creeping back over the old earth at the oval's rim
            px(img, cx - 6, gy, GRASS_MD)
            px(img, cx + 6, gy, GRASS_MD)
            px(img, cx - 4, gy + 2, GRASS_DK)
            px(img, cx + 3, gy - 2, GRASS_DK)


def draw_back_fence(img):
    """Split-rail fence across the back edge, rail gap for the gate onto the
    path. The two gate posts carry a small finial so the opening reads."""
    for x0 in (4, 22, 40, 58, 86, 104, 122, 137):
        top = FENCE_BASE - 14
        rect(img, x0, top, x0 + 2, FENCE_BASE, WOOD_MD)
        rect(img, x0 + 2, top, x0 + 2, FENCE_BASE, WOOD_DK)
        px(img, x0, top, WOOD_LT)
        if x0 in (58, 86):                        # gate posts: finial knob
            rect(img, x0, top - 2, x0 + 2, top - 2, WOOD_MD)
            px(img, x0, top - 2, WOOD_LT)
    for ry in (22, 27):                           # two rails, upper one lit
        for x in range(4, 140):
            if GATE_L <= x <= GATE_R:
                continue
            px(img, x, ry, WOOD_LT if ry == 22 else WOOD_MD)
            px(img, x, ry + 1, WOOD_MD)
            px(img, x, ry + 2, WOOD_DK)


def draw_side_fences(img):
    """Side runs seen almost edge-on: a thin vertical rail line per side with
    a few posts. Sits on opaque turf, so edges are hand-placed."""
    for xl, xd in ((4, 5), (137, 138)):
        for y in range(FENCE_BASE + 2, 86):
            px(img, xl, y, WOOD_MD)
            px(img, xd, y, WOOD_DK)
        for py in (46, 66):                       # posts along the run
            rect(img, xl - 1, py - 8, xd + 1, py, WOOD_MD)
            rect(img, xd + 1, py - 8, xd + 1, py, WOOD_DK)
            px(img, xl - 1, py - 8, WOOD_LT)


def draw_front_fence(img):
    """Front fence returns across the full width — no gate on this side; the
    plot opens onto the path behind it."""
    for ry in (86, 91):
        for x in range(4, 140):
            px(img, x, ry, WOOD_LT if ry == 86 else WOOD_MD)
            px(img, x, ry + 1, WOOD_MD)
            px(img, x, ry + 2, WOOD_DK)
    for x0 in (4, 30, 56, 82, 108, 137):
        rect(img, x0, 82, x0 + 2, 94, WOOD_MD)
        rect(img, x0, 82, x0, 94, WOOD_LT)
        rect(img, x0 + 2, 82, x0 + 2, 94, WOOD_DK)
        rect(img, x0, 94, x0 + 2, 94, OUTLINE)


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


def build_plot():
    rng = random.Random(0x67726176)               # 'grav'
    img = Image.new("RGBA", (W, H))
    draw_turf(img, rng)
    draw_grave_patches(img)
    draw_back_fence(img)
    draw_side_fences(img)
    draw_front_fence(img)
    outline(img)
    return img


# --- headstone sheet ---------------------------------------------------------
CELL_W, CELL_H = 16, 24


def draw_cross(img, cx):
    """Variant 0: stone cross, lit on the west face."""
    rect(img, cx - 1, 6, cx + 1, 22, STONE_MD)
    rect(img, cx - 1, 6, cx - 1, 22, STONE_LT)
    rect(img, cx + 1, 8, cx + 1, 22, STONE_DK)
    rect(img, cx - 4, 9, cx + 4, 11, STONE_MD)
    rect(img, cx - 4, 9, cx + 4, 9, STONE_LT)
    rect(img, cx - 4, 11, cx + 4, 11, STONE_DK)
    px(img, cx, 22, STONE_DK)


def draw_slab(img, cx):
    """Variant 1: rectangular slab, top corners chipped."""
    rect(img, cx - 4, 8, cx + 4, 22, STONE_MD)
    rect(img, cx - 4, 9, cx - 4, 22, STONE_LT)
    rect(img, cx + 4, 10, cx + 4, 22, STONE_DK)
    rect(img, cx - 3, 8, cx + 3, 8, STONE_LT)
    img.putpixel((cx - 4, 8), (0, 0, 0, 0))
    img.putpixel((cx + 4, 8), (0, 0, 0, 0))
    rect(img, cx - 2, 21, cx + 2, 22, STONE_DK)   # ground-line moss shadow


def draw_rounded(img, cx):
    """Variant 2: rounded-top stone."""
    rect(img, cx - 4, 11, cx + 4, 22, STONE_MD)
    rect(img, cx - 3, 9, cx + 3, 10, STONE_MD)
    rect(img, cx - 2, 8, cx + 2, 8, STONE_LT)
    rect(img, cx - 3, 9, cx - 3, 10, STONE_LT)
    rect(img, cx - 4, 11, cx - 4, 22, STONE_LT)
    rect(img, cx + 3, 10, cx + 3, 10, STONE_DK)
    rect(img, cx + 4, 12, cx + 4, 22, STONE_DK)
    rect(img, cx - 1, 21, cx + 2, 22, STONE_DK)


def draw_cracked(img, cx):
    """Variant 3: older slab leaning east, a diagonal crack across it."""
    for y in range(11, 23):
        lean = (22 - y) // 4                      # 1px east lean per 4 rows
        rect(img, cx - 3 + lean, y, cx + 4 + lean, y, STONE_MD)
        px(img, cx - 3 + lean, y, STONE_LT)
        px(img, cx + 4 + lean, y, STONE_DK)
    rect(img, cx, 11, cx + 6, 11, STONE_LT)       # top edge (leaned)
    for i, (dx, dy) in enumerate(((3, 13), (2, 14), (1, 15), (1, 16), (0, 17))):
        px(img, cx + dx, dy, STONE_DK)            # the crack
    px(img, cx + 2, 22, STONE_DK)


def draw_mound(img, cx):
    """Variant 4: fresh-dirt mound — a new grave with no stone yet."""
    for y in range(18, 23):
        dy = (y - 20) * 2
        for x in range(cx - 6, cx + 7):
            dx = x - cx
            if dx * dx + dy * dy > 40:
                continue
            h = (x * 11 + y * 17) % 6
            c = MOUND_DK if h == 0 else (MOUND_LT if h == 2 else MOUND_MD)
            px(img, x, y, c)
    for x in range(cx - 3, cx + 3):               # lit crest, upper-left
        px(img, x, 18, MOUND_LT)
    rect(img, cx - 4, 22, cx + 4, 22, MOUND_DK)


def build_headstones():
    img = Image.new("RGBA", (CELL_W * 5, CELL_H))
    for i, draw in enumerate((draw_cross, draw_slab, draw_rounded,
                              draw_cracked, draw_mound)):
        draw(img, i * CELL_W + 8)
    outline(img)
    return img


def main():
    root = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
    sprite_dir = os.path.join(root, "lord-of-hirelings", "sprites", "town")
    preview_dir = os.path.join(root, "SourceArt", "previews")
    os.makedirs(sprite_dir, exist_ok=True)
    os.makedirs(preview_dir, exist_ok=True)
    for name, img in (("graveyard_plot", build_plot()),
                      ("graveyard_headstones", build_headstones())):
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
