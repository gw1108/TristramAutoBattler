"""Generate the 16x16 town ground tileset (grass / dirt-path variants).

Authored per design/LordofHirelings_ArtStyleGuide.md town-day mood:
high-key, warm grass greens and timber/dirt browns, with a rare gold
wildflower accent. The ground is background — noise stays low-contrast so
character sprites keep the detail hierarchy.

Sheet layout (one row, 8 tiles of 16x16 -> 128x16):
  col 0-3  grass: plain, specks, tufts, tufts+specks
  col 4-6  packed-dirt path: plain, pebbles, cracks
  col 7    grass with tiny gold wildflowers (rare scatter tile)

Every tile is self-contained (no cross-edge structures) so any variant
tiles seamlessly against any other of its family.

Output: lord-of-hirelings/sprites/town/town_ground_tiles.png (128x16)
        SourceArt/previews/town_ground_tiles_preview_8x.png
        SourceArt/previews/town_ground_tiled_sample_4x.png (seam check)
"""
import os
import random
from PIL import Image

CELL = 16
TILES = 8

# --- palette (town-day: warm greens, timber browns; low internal contrast) ---
G_BASE = (92, 124, 60, 255)    # grass mid (warm green)
G_DK = (76, 104, 50, 255)      # grass shadow speck
G_LT = (118, 150, 74, 255)     # grass blade light
G_LT2 = (140, 170, 88, 255)    # blade tip catch-light

D_BASE = (142, 107, 68, 255)   # packed dirt mid (timber brown)
D_DK = (116, 86, 54, 255)      # dirt shadow speck / crack
D_LT = (166, 131, 86, 255)     # dirt light speck
P_LT = (186, 156, 108, 255)    # pebble light
P_DK = (100, 74, 47, 255)      # pebble under-shadow

F_GOLD = (240, 216, 144, 255)  # wildflower petal (#f0d890 UI gold ramp)
F_CORE = (201, 161, 90, 255)   # wildflower core  (#c9a15a)


def base_fill(img, color, dark, rng, density):
    """Flat fill with sparse darker dither so the ground never reads flat."""
    for y in range(CELL):
        for x in range(CELL):
            img.putpixel((x, y), dark if rng.random() < density else color)


def scatter(img, rng, count, color, avoid_edge=1):
    for _ in range(count):
        x = rng.randrange(avoid_edge, CELL - avoid_edge)
        y = rng.randrange(avoid_edge, CELL - avoid_edge)
        img.putpixel((x, y), color)


def grass_tufts(img, rng, count):
    """Little 2-tall grass blades, light with a bright tip."""
    for _ in range(count):
        x = rng.randrange(1, CELL - 1)
        y = rng.randrange(2, CELL - 1)
        img.putpixel((x, y), G_LT)
        img.putpixel((x, y - 1), G_LT2 if rng.random() < 0.5 else G_LT)


def pebbles(img, rng, count):
    """2px stones: light top, shadow below (top-left light)."""
    for _ in range(count):
        x = rng.randrange(1, CELL - 2)
        y = rng.randrange(1, CELL - 2)
        img.putpixel((x, y), P_LT)
        img.putpixel((x + 1, y), D_LT)
        img.putpixel((x, y + 1), P_DK)


def cracks(img, rng, count):
    """Short horizontal-ish dry cracks in the packed dirt."""
    for _ in range(count):
        x = rng.randrange(1, CELL - 4)
        y = rng.randrange(1, CELL - 1)
        for i in range(rng.randrange(2, 4)):
            img.putpixel((min(x + i, CELL - 1), y), D_DK)
            if rng.random() < 0.3 and y + 1 < CELL:
                y += 1


def flowers(img, rng, count):
    """Tiny gold wildflowers: plus-shaped petals around a darker core."""
    for _ in range(count):
        x = rng.randrange(2, CELL - 2)
        y = rng.randrange(2, CELL - 2)
        img.putpixel((x, y), F_CORE)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            img.putpixel((x + dx, y + dy), F_GOLD)


def make_tile(index):
    rng = random.Random(0x70A0 + index * 977)
    img = Image.new("RGBA", (CELL, CELL))
    if index <= 3 or index == 7:                     # grass family
        base_fill(img, G_BASE, G_DK, rng, 0.10)
        if index in (1, 3):
            scatter(img, rng, 7, G_DK)
        if index in (2, 3):
            grass_tufts(img, rng, 4)
        if index == 7:
            grass_tufts(img, rng, 2)
            flowers(img, rng, 2)
    else:                                            # packed-dirt path family
        base_fill(img, D_BASE, D_DK, rng, 0.08)
        scatter(img, rng, 5, D_LT)
        if index == 5:
            pebbles(img, rng, 3)
        if index == 6:
            cracks(img, rng, 3)
    return img


def main():
    root = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
    sheet = Image.new("RGBA", (TILES * CELL, CELL))
    tiles = [make_tile(i) for i in range(TILES)]
    for i, tile in enumerate(tiles):
        sheet.paste(tile, (i * CELL, 0))

    out_path = os.path.join(root, "lord-of-hirelings", "sprites", "town",
                            "town_ground_tiles.png")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    sheet.save(out_path)

    preview_dir = os.path.join(root, "SourceArt", "previews")
    os.makedirs(preview_dir, exist_ok=True)
    big = sheet.resize((sheet.width * 8, sheet.height * 8), Image.NEAREST)
    big.convert("RGB").save(
        os.path.join(preview_dir, "town_ground_tiles_preview_8x.png"))

    # seam-check sample: 8x8 field of grass with a 3-wide path cross
    rng = random.Random(7)
    sample = Image.new("RGBA", (8 * CELL, 8 * CELL))
    for ty in range(8):
        for tx in range(8):
            on_path = tx in (3, 4, 5) or ty in (3, 4, 5)
            if on_path:
                idx = 4 + rng.randrange(3)
            else:
                r = rng.random()
                idx = 0 if r < 0.5 else (7 if r > 0.96 else 1 + rng.randrange(3))
            sample.paste(tiles[idx], (tx * CELL, ty * CELL))
    sample = sample.resize((sample.width * 4, sample.height * 4), Image.NEAREST)
    sample.convert("RGB").save(
        os.path.join(preview_dir, "town_ground_tiled_sample_4x.png"))
    print("wrote", out_path)


if __name__ == "__main__":
    main()
