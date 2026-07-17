"""Generate the recruit adventurer sprite sheet (all 6 class variants).

Recruits at the inn are adventurers, so each variant follows its class row in
design/LordofHirelings_ArtStyleGuide.md §6 (silhouette is sacred):
- 48x48 canvas per figure, single static pose, bottom-center pivot
  (no walk cycles — locomotion is a code tween per the art asset list)
- Knight: square, oversized shield breaking the outline
- Berserker: wide-base triangle, huge bare arms, giant axe carried high
- Mage: tall narrow robe cone, featureless void hood, one thin staff vertical
- Rogue: small sharp triangles, crouched and low, cloak hem in points
- Captain: square + upward line, tallest polearm, horn breaking the hip line
- Cleric: circle, round hood and soft robe curves, raised open book
- light from top-left, 3-step hue-shifted ramps, selective non-black outline

Sheet layout: 1 row x 6 cols (knight, berserker, mage, rogue, captain,
cleric) = 288x48 — new classes append so existing frame indices stay stable.

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
    """Small sharp triangles: crouched, compact, the lowest outline here.

    Palette deliberately avoids the grass-green band of town_ground_tiles.png
    ((92,124,60)/(76,104,50)): slate-gray cloak with a clearly lighter lit
    side, warm russet leather jerkin, bright dagger glint — so the figure
    passes the squint test on grass instead of reading as a bush.
    """
    L_SH = (96, 62, 38, 255)        # warm russet leather
    L_MD = (142, 96, 54, 255)
    L_LT = (192, 146, 92, 255)
    C_SH = (54, 58, 66, 255)        # cloak (cool slate gray, no green)
    C_MD = (88, 94, 102, 255)
    C_LT = (134, 140, 148, 255)
    A_LT = (206, 216, 230, 255)     # dagger steel, glinting
    A_MD = (140, 152, 172, 255)
    f = Fig((32, 34, 40, 255), (60, 64, 72, 255))

    f.box(17, 20, 38, GROUND, L_SH, L_SH, L_MD)         # bent legs / boots
    f.box(26, 29, 38, GROUND, L_SH, L_SH, L_MD)
    for y in range(20, 39):                             # crouched cloaked mass
        t = (y - 20) / 18.0
        hw = 5.0 + 4.5 * t
        for x in range(48):
            nx = (x - CX) / hw
            if abs(nx) <= 1.0:
                f.put(x, y, shade3(nx, 0.0, C_SH, C_MD, C_LT))
    for tip_x, tip_y in ((15, 43), (21, 41), (28, 43), (32, 40)):
        for y in range(38, tip_y + 1):                  # hem breaks into
            hw = (tip_y - y) // 2 + 1                   # sharp points
            for x in range(tip_x - hw, tip_x + hw + 1):
                f.put(x, y, C_SH if x > tip_x else C_MD)
    f.box(19, 28, 25, 32, L_SH, L_MD, L_LT)             # leather jerkin
    for x in range(20, 28):                             # pale strap catches
        f.put(x, 27 - (x - 20) // 3, L_LT)              # light across the chest

    f.ellipse(CX, 17.0, 5.2, 4.6, C_SH, C_MD, C_LT)     # hood, pulled up
    for x in range(21, 27):                             # shadowed human face
        for y in range(16, 20):
            f.put(x, y, S_SH if y > 17 and 22 <= x <= 25 else C_SH)
    f.put(22, 17, (32, 34, 40, 255))                    # eyes catch the dark
    f.put(25, 17, (32, 34, 40, 255))

    f.box(29, 31, 27, 29, S_SH, S_MD, S_MD)             # hand + dagger
    for i in range(6):                                  # notching the outline
        f.put(32 + i, 26 - i, A_LT)
        f.put(32 + i, 27 - i, A_MD)
    return f


def draw_captain():
    """Square + one upward line; the polearm is the tallest silhouette."""
    A_SH = (58, 68, 90, 255)        # steel (shared with the Knight)
    A_MD = (106, 118, 141, 255)
    A_LT = (160, 172, 190, 255)
    T_SH = (52, 70, 104, 255)       # officer tabard blue (heraldry ramp)
    T_MD = (74, 96, 132, 255)
    T_LT = (104, 130, 164, 255)
    W_SH = (64, 44, 32, 255)        # polearm haft / signal horn wood
    W_MD = (97, 69, 45, 255)
    W_LT = (134, 101, 64, 255)
    f = Fig((30, 34, 48, 255), (58, 68, 90, 255))

    f.box(17, 20, 37, GROUND, A_SH, A_SH, A_MD)         # lighter frame than
    f.box(25, 28, 37, GROUND, A_SH, A_SH, A_MD)         # the Knight's stance
    f.box(16, 29, 22, 37, T_SH, T_MD, T_LT)             # square tabard torso
    for y in range(24, 37):                             # gold officer stripe
        f.put(22, y, G_MD)
        f.put(23, y, G_LT)
    f.box(14, 31, 20, 23, A_SH, A_MD, A_LT)             # slim pauldrons

    f.ellipse(22.5, 14.0, 4.0, 4.4, S_SH, S_MD, S_LT)   # open face (no visor)
    f.put(21, 14, (30, 34, 48, 255))                    # eyes
    f.put(25, 14, (30, 34, 48, 255))
    f.box(17, 28, 8, 10, A_SH, A_MD, A_LT)              # kettle-helm brim
    f.box(19, 26, 5, 8, A_SH, A_MD, A_LT)               # helm crown

    for y in range(1, GROUND):                          # polearm: one tall
        f.put(37, y, W_MD if y % 3 else W_SH)           # vertical, tip above
        f.put(38, y, W_SH)                              # every other head
    for y in range(1, 8):                               # leaf spearhead
        span = 2 - abs(y - 4) // 2
        for x in range(36 - span, 38 + span + 1):
            f.put(x, y, A_LT if x < 37 else A_MD)
    f.box(37, 40, 8, 9, G_MD, G_MD, G_LT)               # gold socket collar
    f.box(29, 35, 24, 27, A_SH, A_MD, A_LT)             # arm out to the haft
    f.box(35, 39, 26, 30, A_SH, A_MD, A_LT)             # gauntlet grips it

    f.ellipse(12.0, 35.0, 4.0, 2.6, W_SH, W_MD, W_LT)   # signal horn breaks
    f.put(8, 34, G_MD)                                  # the hip line; gold
    f.put(8, 35, G_LT)                                  # mouthpiece band
    for i in range(4):                                  # baldric strap up to
        f.put(14 + i, 32 - i, W_MD)                     # the torso
    return f


def draw_cleric():
    """Circle everywhere: round hood, soft robe curves, raised open book."""
    R_SH = (118, 102, 86, 255)      # undyed cream wool robe
    R_MD = (170, 152, 120, 255)
    R_LT = (214, 198, 160, 255)
    P_SH = (176, 162, 134, 255)     # parchment pages
    P_LT = (234, 224, 196, 255)
    f = Fig((72, 60, 48, 255), (118, 102, 86, 255))

    f.ellipse(CX, 36.0, 9.5, 8.5, R_SH, R_MD, R_LT)     # soft bell of robe,
    f.ellipse(CX, 26.0, 7.0, 7.0, R_SH, R_MD, R_LT)     # no straight hemline
    for x in range(15, 33):                             # knotted rope belt
        if (x, 31) in f.px:
            f.put(x, 31, G_MD if x % 3 else G_LT)

    f.ellipse(CX, 14.0, 5.6, 5.4, R_SH, R_MD, R_LT)     # round hood
    f.ellipse(CX, 15.0, 3.2, 3.4, S_SH, S_MD, S_LT)     # open friendly face
    f.put(22, 15, (72, 60, 48, 255))                    # eyes
    f.put(25, 15, (72, 60, 48, 255))

    f.ellipse(30.0, 20.0, 2.6, 4.6, R_SH, R_MD, R_LT)   # sleeve raised toward
    f.box(31, 33, 14, 16, S_SH, S_MD, S_LT)             # the book, hand under
    for y in range(9, 14):                              # open book held high,
        for x in range(29, 39):                         # breaking the outline
            if x in (33, 34):
                f.put(x, y + 1, R_SH)                   # spine valley dips
            else:
                f.put(x, y, P_LT if x < 33 else P_SH)
    for x in (29, 38):                                  # gilt page edges
        f.put(x, 9, G_LT)
        f.put(x, 13, G_MD)
    return f


def main():
    root = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
    figs = [draw_knight(), draw_berserker(), draw_mage(), draw_rogue(),
            draw_captain(), draw_cleric()]
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
