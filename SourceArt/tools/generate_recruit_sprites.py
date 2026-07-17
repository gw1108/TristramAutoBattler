"""Generate the recruit adventurer sprite sheet (4 class-flavored variants).

Recruits at the inn are adventurers, so each variant follows its class row in
design/LordofHirelings_ArtStyleGuide.md §6 (silhouette is sacred):
- 48x48 canvas per figure, single static pose, bottom-center pivot
  (no walk cycles — locomotion is a code tween per the art asset list)
- Knight: square, oversized shield breaking the outline
- Berserker: wide-base triangle, huge bare arms, giant axe carried high
- Mage: tall narrow robe cone, featureless void hood, one thin staff vertical
- Rogue: small sharp triangles, crouched and low, cloak hem in points
- light from top-left, 3-step hue-shifted ramps, selective non-black outline

Sheet layout: 1 row x 4 cols (knight, berserker, mage, rogue) = 192x48.

Output: lord-of-hirelings/sprites/recruits/recruit_variants.png
        SourceArt/previews/recruit_variants_preview_8x.png (for review)
"""
import os
from PIL import Image

CELL = 48
GROUND = 45          # feet rest on this row; outline may dip one px below
CX = 23.5

# --- shared ramps (Apollo-adjacent; cool shadows, warm lights) ---------------
S_SH = (156, 107, 79, 255)      # skin shadow
S_MD = (201, 155, 118, 255)     # skin mid
S_LT = (232, 193, 154, 255)     # skin light

G_MD = (201, 161, 90, 255)      # UI gold ramp #c9a15a
G_LT = (240, 216, 144, 255)     # #f0d890


def shade3(nx, ny, sh, md, lt):
    """Pick a ramp step from a normalized offset; light from top-left."""
    v = nx * 0.8 + ny * 0.6
    if v < -0.3:
        return lt
    if v > 0.35:
        return sh
    return md


class Fig:
    """Pixel buffer for one 48x48 figure + its selective outline colors."""

    def __init__(self, out, out_lit):
        self.px = {}
        self.out = out
        self.out_lit = out_lit

    def put(self, x, y, c):
        if 0 <= x < CELL and 0 <= y < CELL:
            self.px[(int(x), int(y))] = c

    def ellipse(self, cx, cy, rx, ry, sh, md, lt):
        for y in range(int(cy - ry), int(cy + ry) + 1):
            for x in range(int(cx - rx), int(cx + rx) + 1):
                nx, ny = (x - cx) / rx, (y - cy) / ry
                if nx * nx + ny * ny <= 1.0:
                    self.put(x, y, shade3(nx, ny, sh, md, lt))

    def box(self, x0, x1, y0, y1, sh, md, lt):
        w = max(1.0, (x1 - x0) / 2.0)
        cx = (x0 + x1) / 2.0
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, shade3((x - cx) / w, 0.0, sh, md, lt))

    def render(self):
        """Selective 1px outline (selout lighter on lit top-left edges)."""
        outline = {}
        for (x, y) in list(self.px.keys()):
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if (nx, ny) not in self.px and 0 <= nx < CELL and 0 <= ny < CELL:
                    lit = (dy == -1 and ny <= 20) or (dx == -1 and nx <= 20)
                    if (nx, ny) not in outline or not lit:
                        outline[(nx, ny)] = self.out_lit if lit else self.out
        self.px.update(outline)
        img = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
        for (x, y), c in self.px.items():
            img.putpixel((x, y), c)
        return img


def draw_knight():
    """Square silhouette; the oversized shield always breaks the outline."""
    A_SH = (58, 68, 90, 255)        # steel shadow (cool blue-gray)
    A_MD = (106, 118, 141, 255)
    A_LT = (160, 172, 190, 255)
    H_SH = (52, 70, 104, 255)       # shield-face heraldry blue
    H_MD = (74, 96, 132, 255)
    PLUME = (146, 66, 58, 255)      # desaturated costume red (never HP red)
    f = Fig((30, 34, 48, 255), (58, 68, 90, 255))

    f.box(18, 21, 38, GROUND, A_SH, A_SH, A_MD)         # legs
    f.box(26, 29, 38, GROUND, A_SH, A_SH, A_MD)
    f.box(16, 31, 22, 38, A_SH, A_MD, A_LT)             # blocky torso
    f.box(13, 34, 19, 22, A_SH, A_MD, A_LT)             # flat pauldrons
    f.box(18, 29, 9, 19, A_SH, A_MD, A_LT)              # closed helm
    for x in range(20, 28):                             # visor slit
        f.put(x, 14, (30, 34, 48, 255))
    f.box(22, 25, 5, 9, PLUME, PLUME, (176, 92, 76, 255))   # crest

    for y in range(20, 43):                             # oversized shield
        for x in range(4, 16):
            edge = x in (4, 15) or y in (20, 42)
            if y > 38 and x in (4, 15):                 # taper the point
                continue
            if y > 40 and (x < 6 or x > 13):
                continue
            f.put(x, y, A_MD if edge else (H_MD if x < 10 else H_SH))
    for x in range(6, 14):                              # gold chevron
        yy = 28 + abs(x - 9) // 2
        f.put(x, yy, G_MD)
        f.put(x, yy + 1, G_LT)

    f.box(31, 38, 23, 27, A_SH, A_MD, A_LT)             # sword arm from the
    f.box(36, 38, 26, 31, A_SH, A_MD, A_LT)             # pauldron + gauntlet
    for y in range(20, 33):                             # small sword (shield
        f.put(39, y, A_LT)                              # stays dominant)
        f.put(40, y, A_MD)
    f.box(37, 42, 33, 34, G_MD, G_MD, G_LT)             # crossguard
    return f


def draw_berserker():
    """Wide-base triangle; huge bare arms and a giant axe carried high."""
    F_SH = (64, 44, 32, 255)        # fur/hide shadow
    F_MD = (97, 69, 45, 255)
    F_LT = (134, 101, 64, 255)
    HAIR = (96, 42, 34, 255)
    HAIR_LT = (128, 62, 44, 255)
    A_SH = (58, 68, 90, 255)        # axe steel
    A_MD = (106, 118, 141, 255)
    A_LT = (160, 172, 190, 255)
    f = Fig((46, 30, 26, 255), (78, 50, 40, 255))

    f.box(14, 19, 36, GROUND, F_SH, F_MD, F_LT)         # wide-set fur boots
    f.box(28, 33, 36, GROUND, F_SH, F_MD, F_LT)
    for y in range(20, 37):                             # torso: narrow waist
        t = (y - 20) / 16.0                             # up to huge shoulders
        hw = 11.0 - 5.0 * t
        for x in range(48):
            nx = (x - CX) / hw
            if abs(nx) <= 1.0:
                f.put(x, y, shade3(nx, 0.0, S_SH, S_MD, S_LT))
    for i in range(14):                                 # fur strap across chest
        x, y = 15 + i, 22 + i // 2
        f.put(x, y, F_MD)
        f.put(x, y + 1, F_SH)
    f.box(16, 31, 33, 38, F_SH, F_MD, F_LT)             # hide waist wrap

    f.ellipse(11.5, 24.0, 3.2, 5.5, S_SH, S_MD, S_LT)   # left arm hangs low
    f.ellipse(35.0, 20.0, 3.2, 5.0, S_SH, S_MD, S_LT)   # right arm raised

    f.ellipse(CX, 12.0, 4.6, 4.8, S_SH, S_MD, S_LT)     # head
    for sx, top in ((17, 6), (20, 3), (24, 2), (28, 4), (31, 7)):
        for y in range(top, 10):                        # wild hair spikes
            f.put(sx, y, HAIR if y > top + 1 else HAIR_LT)
            f.put(sx + 1, y, HAIR)
    f.put(21, 12, (46, 30, 26, 255))                    # eyes
    f.put(26, 12, (46, 30, 26, 255))

    for i in range(12):                                 # haft, carried high
        f.put(36 + i // 3, 26 - i * 2, F_MD)
        f.put(37 + i // 3, 26 - i * 2, F_SH)
        f.put(36 + i // 3, 25 - i * 2, F_MD)
    for y in range(3, 13):                              # giant axe head
        span = 5 - abs(y - 8)
        for x in range(38 - span, 45):
            f.put(x, y, A_LT if x < 40 - span + 2 else (A_MD if x < 43 else A_SH))
    return f


def draw_mage():
    """Tall narrow robe cone; the featureless void hood is the focal point."""
    R_SH = (52, 40, 78, 255)        # robe shadow (cool violet)
    R_MD = (84, 66, 116, 255)
    R_LT = (122, 100, 152, 255)
    VOID = (13, 13, 18, 255)        # featureless black face opening
    W_SH = (64, 44, 32, 255)        # staff wood
    W_MD = (97, 69, 45, 255)
    f = Fig((34, 26, 52, 255), (60, 46, 88, 255))

    for y in range(3, GROUND):                          # one unbroken cone,
        t = (y - 3) / float(GROUND - 3)                 # hood tip to hem
        hw = 0.6 + 8.4 * (t ** 1.15)
        for x in range(48):
            nx = (x - 22.5) / hw
            if abs(nx) <= 1.0:
                f.put(x, y, shade3(nx, 0.0, R_SH, R_MD, R_LT))
    f.ellipse(22.5, 13.0, 3.4, 3.6, VOID, VOID, VOID)   # void hood opening
    for x in range(15, 31):                             # gold hem trim
        if (x, 43) in f.px:
            f.put(x, 43, G_MD)

    for y in range(7, GROUND):                          # staff: one thin
        f.put(34, y, W_MD if y % 3 else W_SH)           # vertical
    f.box(33, 35, 4, 6, W_SH, W_MD, W_MD)               # plain finial knob
    f.put(34, 5, G_LT)
    f.box(28, 33, 27, 29, R_SH, R_MD, R_LT)             # sleeve reaching out
    f.box(32, 34, 27, 29, S_SH, S_MD, S_LT)             # hand on the staff
    return f


def draw_rogue():
    """Small sharp triangles: crouched, compact, the lowest outline here."""
    L_SH = (52, 44, 34, 255)        # leathers
    L_MD = (84, 70, 50, 255)
    L_LT = (115, 98, 68, 255)
    C_SH = (38, 52, 40, 255)        # cloak (desaturated green)
    C_MD = (58, 78, 56, 255)
    C_LT = (82, 104, 70, 255)
    A_LT = (160, 172, 190, 255)     # dagger steel
    A_MD = (106, 118, 141, 255)
    f = Fig((28, 36, 30, 255), (48, 62, 48, 255))

    f.box(17, 20, 40, GROUND, L_SH, L_SH, L_MD)         # bent legs / boots
    f.box(26, 29, 40, GROUND, L_SH, L_SH, L_MD)
    for y in range(24, 41):                             # crouched cloaked mass
        t = (y - 24) / 16.0
        hw = 5.0 + 4.5 * t
        for x in range(48):
            nx = (x - CX) / hw
            if abs(nx) <= 1.0:
                f.put(x, y, shade3(nx, 0.0, C_SH, C_MD, C_LT))
    for tip_x, tip_y in ((15, 44), (21, 42), (28, 44), (32, 41)):
        for y in range(40, tip_y + 1):                  # hem breaks into
            hw = (tip_y - y) // 2 + 1                   # sharp points
            for x in range(tip_x - hw, tip_x + hw + 1):
                f.put(x, y, C_SH if x > tip_x else C_MD)
    f.box(19, 28, 28, 34, L_SH, L_MD, L_LT)             # leather jerkin

    f.ellipse(CX, 21.0, 5.2, 4.6, C_SH, C_MD, C_LT)     # hood, pulled up
    for x in range(21, 27):                             # shadowed human face
        for y in range(20, 24):
            f.put(x, y, S_SH if y > 21 and 22 <= x <= 25 else L_SH)
    f.put(22, 21, (28, 36, 30, 255))                    # eyes catch the dark
    f.put(25, 21, (28, 36, 30, 255))

    f.box(29, 31, 30, 32, S_SH, S_MD, S_MD)             # hand + dagger
    for i in range(5):                                  # notching the outline
        f.put(32 + i, 29 - i, A_LT)
        f.put(32 + i, 30 - i, A_MD)
    return f


def main():
    root = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
    figs = [draw_knight(), draw_berserker(), draw_mage(), draw_rogue()]
    sheet = Image.new("RGBA", (len(figs) * CELL, CELL), (0, 0, 0, 0))
    for col, fig in enumerate(figs):
        sheet.paste(fig.render(), (col * CELL, 0))

    out_path = os.path.join(root, "lord-of-hirelings", "sprites", "recruits",
                            "recruit_variants.png")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    sheet.save(out_path)

    preview_dir = os.path.join(root, "SourceArt", "previews")
    os.makedirs(preview_dir, exist_ok=True)
    big = sheet.resize((sheet.width * 8, sheet.height * 8), Image.NEAREST)
    bg = Image.new("RGBA", big.size, (23, 23, 28, 255))
    bg.alpha_composite(big)
    bg.convert("RGB").save(
        os.path.join(preview_dir, "recruit_variants_preview_8x.png"))
    print("wrote", out_path)


if __name__ == "__main__":
    main()
