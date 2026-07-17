"""Generate the Player Lord sprite sheet (idle + 4-direction walk).

Authored per design/LordofHirelings_ArtStyleGuide.md:
- 48x48 canvas, figure ~40px tall, bottom-center pivot
- circle shape language: round robe, bald head, white beard, gold book
- light from top-left, hue-shifted ramps, selective (non-black) outline
- rows: 0=down, 1=up, 2=side(right; left is flip_h) / cols: 4 walk frames
  (col 0 is the contact/stand pose, reused as the idle frame)

Output: lord-of-hirelings/sprites/lord/lord_sheet.png (192x144)
        SourceArt/previews/lord_sheet_preview_8x.png (for human/agent review)
"""
import os
from PIL import Image

CELL = 48
COLS, ROWS = 4, 3

# --- palette (Apollo-adjacent ramps, hue-shifted: cool shadows, warm lights) ---
OUT = (42, 26, 34, 255)        # outline: deep warm plum-brown, never pure black
OUT_LIT = (74, 47, 58, 255)    # selout on the lit (top-left) edge

R_SH = (77, 45, 60, 255)       # robe shadow (cool)
R_MD = (122, 72, 58, 255)      # robe mid (warm russet)
R_LT = (163, 109, 72, 255)     # robe light (warm)

S_SH = (156, 107, 79, 255)     # skin shadow
S_MD = (201, 155, 118, 255)    # skin mid
S_LT = (232, 193, 154, 255)    # skin light

B_SH = (141, 151, 171, 255)    # beard shadow (cool)
B_MD = (199, 204, 216, 255)    # beard mid
B_LT = (240, 242, 239, 255)    # beard light

G_SH = (154, 118, 64, 255)     # book gold shadow
G_MD = (201, 161, 90, 255)     # book gold mid  (#c9a15a from the UI gold ramp)
G_LT = (240, 216, 144, 255)    # book gold light (#f0d890)

SHOE = (58, 38, 40, 255)

DARKER = {R_LT: R_MD, R_MD: R_SH, R_SH: R_SH,
          S_LT: S_MD, S_MD: S_SH, S_SH: S_SH,
          B_LT: B_MD, B_MD: B_SH, B_SH: B_SH}

CX = 23.5  # figure center line


def robe_half_width(y):
    """Dome profile from shoulders (y=19) to hem (y=44)."""
    t = max(0.0, min(1.0, (y - 19) / 25.0))
    w = 7.0 + 6.0 * (t ** 0.7)
    if y >= 43:  # round the hem corners
        w -= (y - 42) * 0.8
    return w


def draw_frame(direction, col):
    px = {}

    def put(x, y, c):
        if 0 <= x < CELL and 0 <= y < CELL:
            px[(x, y)] = c

    is_walk_lift = col in (1, 3)
    bob = 1 if is_walk_lift else 0

    # --- robe (drawn first; head/book layer on top) ---
    for y in range(19, 45):
        w = robe_half_width(y)
        yy = y - bob
        for x in range(48):
            nx = (x - CX) / w
            if abs(nx) > 1.0:
                continue
            # hem sway on stride frames
            sway = 0
            if y >= 41 and is_walk_lift:
                sway = -1 if col == 1 else 1
            if nx < -0.25:
                c = R_LT
            elif nx > 0.4:
                c = R_SH
            else:
                c = R_MD
            if y >= 41:
                c = DARKER[c]
            put(x + sway, yy, c)

    # --- feet: shoes peeking under the hem (anchored to the ground) ---
    if direction in ("down", "up"):
        lft, rgt = (20, 21), (26, 27)
        if col == 0 or col == 2:
            for x in lft + rgt:
                put(x, 45, SHOE)
        elif col == 1:  # left foot striding
            for x in lft:
                put(x, 45, SHOE)
                put(x, 46, SHOE)
            put(rgt[0], 45, SHOE)
        else:           # right foot striding
            for x in rgt:
                put(x, 45, SHOE)
                put(x, 46, SHOE)
            put(lft[1], 45, SHOE)
    else:  # side view: feet along the walk axis
        if col == 0 or col == 2:
            for x in range(21, 26):
                put(x, 45, SHOE)
        elif col == 1:  # stride: front + back foot
            for x in range(26, 29):
                put(x, 45, SHOE)
            for x in range(18, 21):
                put(x, 45, SHOE)
        else:           # passing stride mirrored
            for x in range(25, 28):
                put(x, 46, SHOE)
            for x in range(19, 22):
                put(x, 45, SHOE)

    # --- head ---
    hcx = 25.0 if direction == "side" else CX
    hcy = 12.5 - bob
    r = 6.8 if direction == "side" else 7.2
    for y in range(3, 22):
        for x in range(12, 36):
            dx, dy = x - hcx, y - hcy
            if dx * dx + dy * dy > r * r:
                continue
            shade = dx * 0.7 + dy
            if shade < -3:
                c = S_LT
            elif shade > 3.5:
                c = S_SH
            else:
                c = S_MD
            put(x, y, c)

    if direction == "side":
        # nose bump
        put(int(hcx + r), int(hcy + 1), S_MD)
        put(int(hcx + r), int(hcy + 2), S_MD)

    # --- beard / face / hair fringe per direction ---
    if direction == "down":
        # beard: rounded mass hugging the chin, tapering onto the chest
        for y in range(17, 25):
            for x in range(16, 32):
                dx, dy = (x - CX) / 5.4, (y - 19.5) / 4.6
                if dx * dx + dy * dy <= 1.0 and y >= 17:
                    if x < 21 and y < 21:
                        c = B_LT
                    elif x > 26 or y > 22:
                        c = B_SH
                    else:
                        c = B_MD
                    put(x, y - bob, c)
        # eyes + white brows (cheeks stay skin between eyes and beard)
        for ex in (21, 26):
            put(ex, 13 - bob, OUT)
            put(ex, 12 - bob, B_MD)
    elif direction == "up":
        # balding ring seen from behind
        for y in range(13, 19):
            for x in range(16, 32):
                dx, dy = x - hcx, y - hcy
                if dx * dx + dy * dy <= r * r and y >= 14:
                    if dx * dx + dy * dy >= (r - 2.5) * (r - 2.5) or y >= 17:
                        put(x, y, B_MD if x < 24 else B_SH)
    else:  # side
        for y in range(16, 23):
            for x in range(20, 34):
                dx, dy = (x - 27.5) / 4.6, (y - 18.5) / 3.9
                if dx * dx + dy * dy <= 1.0 and x >= 23:
                    c = B_LT if y < 18 and x < 29 else (B_SH if x > 30 or y > 20 else B_MD)
                    put(x, y - bob, c)
        put(28, 12 - bob, OUT)          # eye
        put(28, 11 - bob, B_MD)         # brow

    # --- the gold book + hands (front-facing directions only) ---
    if direction == "down":
        for y in range(26, 32):
            for x in range(18, 30):
                c = G_MD
                if y == 26:
                    c = G_LT
                elif y == 31:
                    c = G_SH
                elif x in (23, 24):
                    c = G_SH  # spine
                put(x, y - bob, c)
        for hx in (16, 17, 30, 31):     # hands gripping the sides
            put(hx, 28 - bob, S_MD)
            put(hx, 29 - bob, S_SH if hx > 24 else S_MD)
    elif direction == "side":
        for y in range(27, 32):
            for x in range(30, 37):
                c = G_MD
                if y == 27:
                    c = G_LT
                elif x >= 35:
                    c = B_LT  # page edge
                elif y == 31:
                    c = G_SH
                put(x, y - bob, c)
        for h in ((29, 29), (29, 30), (30, 29)):
            put(h[0], h[1] - bob, S_MD)

    # --- selective outline pass (1px, selout lighter on lit top-left edges) ---
    outline = {}
    for (x, y) in list(px.keys()):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if (nx, ny) not in px and 0 <= nx < CELL and 0 <= ny < CELL:
                lit = (dy == -1 and nx <= 24) or (dx == -1 and ny <= 20)
                if (nx, ny) not in outline or not lit:
                    outline[(nx, ny)] = OUT_LIT if lit else OUT
    px.update(outline)

    img = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    for (x, y), c in px.items():
        img.putpixel((x, y), c)
    return img


def main():
    root = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
    sheet = Image.new("RGBA", (COLS * CELL, ROWS * CELL), (0, 0, 0, 0))
    for row, direction in enumerate(("down", "up", "side")):
        for col in range(COLS):
            sheet.paste(draw_frame(direction, col), (col * CELL, row * CELL))

    out_path = os.path.join(root, "lord-of-hirelings", "sprites", "lord", "lord_sheet.png")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    sheet.save(out_path)

    preview_dir = os.path.join(root, "SourceArt", "previews")
    os.makedirs(preview_dir, exist_ok=True)
    big = sheet.resize((sheet.width * 8, sheet.height * 8), Image.NEAREST)
    bg = Image.new("RGBA", big.size, (23, 23, 28, 255))
    bg.alpha_composite(big)
    bg.convert("RGB").save(os.path.join(preview_dir, "lord_sheet_preview_8x.png"))
    print("wrote", out_path)


if __name__ == "__main__":
    main()
