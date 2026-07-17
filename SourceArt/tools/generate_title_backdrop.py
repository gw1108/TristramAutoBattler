"""Generate the title screen background key art.

design/LordofHirelings_ArtAssetList.md line 114: "Behind New Game / Continue /
Manage Save. Key art: the ruined town at dusk with the dungeon looming, or the
lord overlooking the square. Can start as a plain panel." Of the two framings
offered this takes the first. The screen is a menu before it is a painting --
the title label, three buttons, and two centred panels all sit on top of it --
and a lord in the near foreground would put a lit, detailed, high-contrast
figure exactly where the button column lands. The ruined town at dusk puts its
subject matter at the edges and leaves the middle to sky, which is what the UI
needs, so it is the framing that survives having a menu dropped on it.

Composition (960x540, the style guide's locked native resolution, so the art is
1:1 at the 960x540 viewport and never fractionally scaled -- VISUAL_RULES.md):

  left third   the ruined town, backlit silhouettes along a low horizon
  middle       the empty square and the sky above it -- the menu's negative
               space; nothing here is brighter or busier than a dithered ramp
  right third  the dungeon outcrop looming over all of it, the darkest mass in
               the scene, with the mine portal a hole punched at its foot
  foreground   the road out of the square to that portal -- the trip every
               hireling the player ever hires is going to make

The sun has set in the WEST (frame left), which is what reconciles a dusk piece
with the guide's one global lighting rule (§4, light from the top biased left):
the ember is strongest at the left horizon and dies out to the right, so every
lit edge in the scene -- ruin rims, mountain facets -- still faces up and left,
and the dungeon gets the cold unlit side by geometry rather than by fiat.

Style guide (design/LordofHirelings_ArtStyleGuide.md) rules that shape this:
- §2 color script "Town — night": low-key deep blues/purples with warm gold
  window accents. Dusk is that palette caught on the way down, so the sky runs
  indigo at the top to ember at the horizon and the only gold in the frame is
  the inn's lit windows -- §4 calls warm gold on cool blue the money shot of the
  game, and one lit building in a dead town is the whole premise in one read.
- §2: dithering is banned on sprites but "allowed on large background gradients
  (sky) only" -- the sky is a 2D field ordered-dithered (Bayer 4x4) through a
  single 7-step ramp, so a 404px gradient resolves as texture, not bands.
- §3: "Backgrounds, backdrops, and tiles get NO outline" -- form and value only.
- §5: backdrops are compressed mid values at reduced saturation. Held harder
  here than in a dive row: nothing in this image is brighter than the inn's
  window core, because the brightest thing on this screen must be the gold of
  the title, which is UI and is not in this file.
- §7: no window-blind effect -- buildings, ruins, headstones and fence posts are
  all placed at hash-jittered spacing and varied size, never even stripes. And
  the ground stays quiet: the road is barely a value above the earth it cuts.

Output: lord-of-hirelings/sprites/ui/title_backdrop.png (960x540)
        SourceArt/previews/title_backdrop_preview.png (1:1 + a UI safe-area
        overlay, for judging the art against where the menu actually lands)
"""
import math
import os
from PIL import Image

W = 960
H = 540
HORIZON = 404          # the town's ground line

# Where the menu actually lands, measured off a capture of the running title
# screen rather than guessed from the .tscn: the "Lord of Hirelings" label at
# 32px is far wider than the 160px button column under it, and the ConfirmPanel
# is wider still. Art inside this box has to be quiet.
UI_BOX = (232, 150, 728, 396)

# Ordered dither matrix for the sky (§2 allows it on background gradients).
BAYER4 = (
    (0, 8, 2, 10),
    (12, 4, 14, 6),
    (3, 11, 1, 9),
    (15, 7, 13, 5),
)

# --- palette ----------------------------------------------------------------
# One 7-step sky ramp, hue-shifted along its length rather than darkened toward
# black (§2): the cool end goes violet, not gray, and saturation peaks in the
# middle of the ramp instead of at the ember end.
SKY = (
    (20, 19, 38, 255),      # 0 zenith -- deep indigo, where the stars are
    (34, 29, 52, 255),
    (52, 40, 66, 255),
    (76, 50, 72, 255),      # 3 the mauve the middle of the frame sits in
    (104, 60, 68, 255),
    (136, 78, 60, 255),
    (170, 106, 58, 255),    # 6 ember -- only reached at the west horizon
)

MOON_LT = (104, 102, 126, 255)   # hazy, deliberately dim: not the key light
MOON_MD = (74, 72, 96, 255)
STAR_LT = (118, 114, 144, 255)
STAR_DK = (74, 72, 96, 255)

# The far ridge, hazed back by atmospheric perspective (§7): cooler and lower
# contrast than the outcrop, and kept LOW -- a distant line behind the town, not
# a second mountain. It is a backlit silhouette against the ember, so it is not
# lighter than the near rock; distance flattens its internal contrast to two
# steps, and that is what sells the depth, not raising its value.
FAR_DK = (52, 40, 60, 255)
FAR_LT = (68, 50, 68, 255)

# The dungeon outcrop. The mine entrance generator's cold violet granite, pulled
# down into dusk -- same hue family as sprites/town/mine_entrance.png so the
# looming mountain and the prop the player walks into read as one rock.
ROCK_DEEP = (24, 22, 36, 255)    # the shadowed skirt
ROCK_DK = (38, 34, 54, 255)      # east-facing facets, turned away from the sun
ROCK_MD = (54, 48, 72, 255)      # west-facing facets, the quiet big mass
ROCK_RIM = (118, 72, 62, 255)    # sunset catching a crest lip
ROCK_RIM_W = (150, 92, 64, 255)  # ...hotter at the west end, dying out east

PITCH = (13, 13, 17, 255)        # the portal. The deepest value in the frame.
JAMB = (30, 28, 42, 255)         # last cold light on the hewn edge

WOOD_DK = (44, 34, 34, 255)      # weathered timber (the town generators' ramp,
WOOD_MD = (72, 56, 44, 255)      # muted for dusk)
WOOD_LT = (104, 82, 58, 255)

# Ruins. Cold and broken; the guide's ruined state is "dark, cold, broken
# silhouette", and at this distance that is all value.
RUIN_DK = (26, 24, 38, 255)
RUIN_MD = (40, 36, 52, 255)
RUIN_LT = (56, 50, 68, 255)
RUIN_RIM = (112, 68, 62, 255)    # the west ember catching a standing wall

# The inn: the one building still lit, and the only gold in the frame (§2 --
# gold is money, interactivity, and the player's attention, nothing else).
GLOW_DK = (150, 104, 50, 255)
GLOW_MD = (198, 148, 70, 255)
GLOW_LT = (240, 206, 128, 255)
SMOKE_A = (60, 52, 68, 255)
SMOKE_B = (48, 42, 58, 255)

# Ground. Darkens toward the viewer so the foreground is the floor of the
# scene's value range and the horizon stays the brightest thing in it.
EARTH = (
    (56, 44, 50, 255),
    (44, 35, 42, 255),
    (33, 27, 33, 255),
    (23, 19, 25, 255),
)
ROAD_LT = (70, 56, 56, 255)      # barely above the earth -- §7, quiet ground
ROAD_DK = (40, 32, 38, 255)
NEAR_BLACK = (16, 15, 21, 255)   # foreground framing: headstones, fence, tree
NEAR_LIT = (30, 27, 36, 255)


def rnd(seed, i):
    """Stable hash noise, so the scene regenerates identically."""
    v = ((i + 1) * 1103515245 + seed * 12345) & 0x7FFFFFFF
    v ^= v >> 13
    v = (v * 2654435761) & 0x7FFFFFFF
    return v / float(0x7FFFFFFF)


def spread(seed, i, count, x0, x1, jitter=0.85):
    """One x per element, stratified across [x0, x1): each element owns a slice
    and jitters inside it. Pure hash placement clumps and leaves bald patches;
    even spacing is the window-blind effect §7 bans. This is the middle."""
    f = (i + 0.5 + (rnd(seed, i) - 0.5) * jitter) / count
    return x0 + f * (x1 - x0)


def wave(x, k, phase):
    """Horizontal variation, 0..1."""
    return 0.5 + 0.5 * math.sin(2.0 * math.pi * k * x / W + phase)


def dither(x, y):
    return (BAYER4[y % 4][x % 4] + 0.5) / 16.0


class Canvas:
    """Flat RGBA pixel buffer. Unlike the biome backdrops this scene does not
    tile -- it is one framed composition -- so x clips instead of wrapping."""

    def __init__(self):
        self.px = [(0, 0, 0, 255)] * (W * H)

    def put(self, x, y, c):
        x, y = int(x), int(y)
        if 0 <= x < W and 0 <= y < H:
            self.px[y * W + x] = c

    def get(self, x, y):
        x, y = int(x), int(y)
        if 0 <= x < W and 0 <= y < H:
            return self.px[y * W + x]
        return (0, 0, 0, 255)

    def rect(self, x0, x1, y0, y1, c):
        for y in range(int(y0), int(y1) + 1):
            for x in range(int(x0), int(x1) + 1):
                self.put(x, y, c)

    def vramp(self, y0, y1, colors):
        """Vertical ordered-dithered ramp through `colors`."""
        span = max(1, y1 - y0)
        for y in range(y0, y1):
            f = (y - y0) / float(span) * (len(colors) - 1)
            i = min(int(f), len(colors) - 2)
            frac = f - i
            for x in range(W):
                self.put(x, y, colors[i + 1] if frac > dither(x, y) else colors[i])

    def blob(self, cx, cy, rx, ry, sh, md, lt):
        """Rounded mass shaded from the top-left. No outline -- §3."""
        for y in range(int(cy - ry), int(cy + ry) + 1):
            for x in range(int(cx - rx), int(cx + rx) + 1):
                nx, ny = (x - cx) / rx, (y - cy) / ry
                if nx * nx + ny * ny <= 1.0:
                    v = nx * 0.8 + ny * 0.6
                    self.put(x, y, lt if v < -0.35 else (sh if v > 0.3 else md))

    def image(self):
        img = Image.new("RGBA", (W, H))
        img.putdata(self.px)
        return img


# --- sky ---------------------------------------------------------------------
def draw_sky(c):
    """The sky is a scalar field t(x,y) in 0..1 pushed through the one SKY ramp
    and ordered-dithered between adjacent steps. A plain vertical ramp cannot
    say "the sun went down over there" -- and that is the whole lighting premise
    (§4 keeps the key top-left, which here means the west horizon burns and the
    east, where the dungeon is, does not).
    """
    # t = height above the horizon, biased warm toward the west.
    t = [0.0] * (W * HORIZON)
    for y in range(HORIZON):
        base = (y / float(HORIZON)) ** 1.5
        for x in range(W):
            west = (1.0 - x / float(W)) ** 1.2
            t[y * W + x] = base * (0.50 + 0.50 * west)

    # Dusk cloud banks, lit from underneath by the set sun: cool along a band's
    # top, warm along its belly. Density falls off from each spine and is
    # modulated by two waves, so the dither dissolves the edges into wisps
    # instead of reading as a checkerboard slab.
    for i in range(6):
        cy = 196 + rnd(11, i) * 186
        hh = 5.0 + rnd(12, i) * 12.0
        for y in range(int(cy - hh) - 2, int(cy + hh) + 3):
            if not (0 <= y < HORIZON):
                continue
            fade = 1.0 - abs(y - cy) / (hh + 1.5)
            if fade <= 0.0:
                continue
            # -1 along the top of the band, +1 along the belly.
            side = (y - cy) / (hh + 1.5)
            for x in range(W):
                # Two beating waves per band, at frequencies that share no
                # factor, so a band thins to nothing in places instead of
                # running wall to wall: six full-width stripes is a dusk sky
                # drawn as a venetian blind (§7).
                d = fade * (0.30 + 0.70 * (wave(x, 1.0 + i * 1.7, i * 1.9) * 0.6
                                           + wave(x, 3.0 + i * 2.3, i * 0.8) * 0.4))
                if d <= 0.30:
                    continue
                t[y * W + x] += d * (0.30 if side > 0 else -0.24)

    for y in range(HORIZON):
        for x in range(W):
            f = min(max(t[y * W + x], 0.0), 1.0) * (len(SKY) - 1)
            i = min(int(f), len(SKY) - 2)
            c.put(x, y, SKY[i + 1] if (f - i) > dither(x, y) else SKY[i])


def draw_stars(c):
    """Early dusk stars: only in the deep end of the sky, so they stay out of
    the ember and out of the mauve the menu column sits against."""
    for i in range(90):
        x = spread(21, i, 90, 0, W, jitter=1.8)
        y = rnd(22, i) ** 1.7 * 190
        if c.get(x, y) not in (SKY[0], SKY[1]):
            continue
        c.put(x, y, STAR_LT if rnd(23, i) > 0.78 else STAR_DK)


def draw_moon(c):
    """A hazy dusk moon east of the peak -- the clock on the scene, saying the
    night the town is about to spend is already coming. Dim on purpose: it is
    not the key light (§4) and it must not out-pop the inn's windows (§5)."""
    cx, cy, r = 842.0, 84.0, 8.5
    for y in range(int(cy - r - 5), int(cy + r + 6)):
        for x in range(int(cx - r - 5), int(cx + r + 6)):
            d = math.hypot(x - cx, y - cy)
            if d <= r:
                c.put(x, y, MOON_LT if d < r - 2.0 else MOON_MD)
            elif d <= r + 5.0:                       # dithered haze, no hard rim
                if (1.0 - (d - r) / 5.0) * 0.5 > dither(x, y):
                    c.put(x, y, MOON_MD)


# --- the dungeon outcrop -----------------------------------------------------
# "Looming" is the brief's word, so the mass is authored to break the top third
# of the frame and run off the east edge: no visible far side, no containing it.
def ridge_smooth(x):
    """The outcrop's underlying form, with no surface noise on it. This is what
    the facet shading reads its slope from, and it is a separate function for a
    reason: slope taken from the jittered crest is dominated by the jitter, and
    the face colour then flips on and off every few columns -- which renders as
    vertical stripes down the whole mass, i.e. the window-blind effect §7 bans
    and the noise field generate_mine_entrance.py's docstring already rejected
    for this same rock."""
    # One dominant summit with shoulders stepping DOWN to the east. The heights
    # of the eastern two are not free: the sunset ray off the main summit falls
    # at 0.30 per pixel (SUN_ELEV), so a shoulder authored near that line ends up
    # poking a couple of pixels into the light and renders as a bright 1px
    # scratch down the skyline. They are set well under it, which both settles
    # that and gives the crest the descending profile a single mass wants.
    peaks = ((742.0, 96.0, 210.0), (856.0, 154.0, 150.0), (648.0, 226.0, 120.0),
             (930.0, 172.0, 120.0), (792.0, 118.0, 90.0))
    y = float(HORIZON)
    for px, py, pw in peaks:
        d = abs(x - px) / pw
        if d < 1.0:
            y = min(y, py + (HORIZON - py) * (d ** 1.45))
    return y


def ridge(x):
    """The crest as drawn: the form plus hash-jittered faults, so the skyline is
    granite and not a pillow."""
    y = ridge_smooth(x)
    if y >= HORIZON:
        return y
    return y + (rnd(31, int(x / 7)) - 0.5) * 7.0


def far_ridge(x):
    """A low hazy line along the horizon behind the town -- one more depth plane
    for the near mass to be in front of. Deliberately kept under the outcrop's
    shoulder: a second big shape up in the frame competes with the one thing
    this piece needs to loom."""
    y = 366.0 - 15.0 * wave(x, 1.5, 2.1) - 8.0 * wave(x, 3.5, 0.4)
    return y + (rnd(41, int(x / 9)) - 0.5) * 4.0


def draw_far_ridge(c):
    for x in range(60, W):
        top = far_ridge(x)
        if top >= HORIZON:
            continue
        for y in range(int(top), HORIZON):
            # Two values only, and both close together: distance flattens
            # contrast (§7), and this plane has no business holding detail.
            c.put(x, y, FAR_LT if y - top < 2 else FAR_DK)


SUN_ELEV = 0.30        # rise over run of the sunset ray. The sun is ON the west
                       # horizon, so this is shallow, and that is the whole
                       # reason the mountain reads as one mass (see crest_lit).


def crest_lit(x):
    """Is this stretch of crest still in the sunset, or has the mountain put it
    in its own shadow? March west along the sun ray and see if anything pokes
    above it.

    Without this, every summit gets its own lit west flank and the outcrop reads
    as a row of organ pipes instead of one mountain -- shading each facet by its
    own normal is only half of lighting, and at a sun elevation this shallow the
    half that is missing is the half doing the work. The dominant summit throws
    the rest of the crest into shadow, which is both what actually happens at
    dusk and the composition this piece needs: ONE lit flank leading the eye up
    from the square, and one quiet dark body (§5's squint test, and the "big rock
    face stays a quiet flat mass" that generate_mine_entrance.py settled on for
    this same granite).
    """
    top = ridge_smooth(x)
    xx = x - 6
    while xx > x - 300:
        # The +4 is a margin, not a fudge: a crest that clears the ray by a pixel
        # or two is geometrically lit and artistically a scratch. Anything that
        # close to blocked resolves to shadow.
        if ridge_smooth(xx) < top - SUN_ELEV * (x - xx) + 4.0:
            return False
        xx -= 6
    return True


def draw_outcrop(c):
    for x in range(470, W):
        top = ridge(x)
        if top >= HORIZON - 1:
            continue
        sunlit = crest_lit(x)
        # Which way this stretch of crest faces. Descending to the east = turned
        # away from the sun = shadow; rising to the east = a west face = lit.
        # Read off the SMOOTH form, never the jittered crest -- see ridge_smooth.
        slope = ridge_smooth(x + 4) - ridge_smooth(x - 4)
        depth = HORIZON - top
        # The lit facet is a BAND hugging the crest, not a full-height column.
        # Colouring the whole column by its facet turns a five-summit crest into
        # five alternating vertical bars -- it reads as organ pipes, and it is
        # the window-blind effect (§7) arriving by a side door. Only the upper
        # faces catch the last of the west light anyway; below them the mass is
        # one quiet body, which is the 2-3 clean value blocks the squint test
        # (§5) wants and what generate_mine_entrance.py does with the same rock.
        band = 34.0 + 62.0 * min(1.0, abs(slope) * 0.6)
        for y in range(int(top), HORIZON):
            f = (y - top) / float(depth)
            lit = (sunlit and slope < 0.0
                   and (y - top) < band * (0.7 + 0.6 * dither(x, y)))
            col = ROCK_MD if lit else ROCK_DK
            # The skirt sinks into shadow, so the mass sits on the ground plane
            # instead of floating as one flat silhouette. Dithered so a 300px
            # fall-off does not band.
            c.put(x, y, ROCK_DEEP if f > 0.55 + 0.35 * dither(x, y) else col)
        # Ember rim on the west-facing crest only, hottest at the frame's west
        # end and gone by the east -- the sun is down there, not up here.
        if sunlit and slope < 0.0:
            heat = max(0.0, 1.0 - (x - 470) / 380.0)
            rim = ROCK_RIM_W if heat > 0.55 else ROCK_RIM
            if heat > 0.06:
                c.put(x, top, rim)
                if heat > 0.5:
                    c.put(x, top + 1, ROCK_RIM)


def draw_portal(c):
    """The mine portal at the outcrop's foot: timber-braced, cart tracks running
    out, pitch inside. Sized against the ruins across the square so the hole
    reads as human-scale and the rock above it reads as enormous -- that ratio
    is the only thing making the mountain "loom" rather than just "be there"."""
    x0, x1 = 748, 800
    top = 356
    # Mouth: a squared portal with an arched crown, hewn out of the rock.
    for y in range(top, HORIZON):
        for x in range(x0, x1 + 1):
            nx = (x - (x0 + x1) / 2.0) / ((x1 - x0) / 2.0)
            crown = top + 12.0 * (nx * nx)
            if y >= crown:
                c.put(x, y, PITCH)
    # Hewn jamb: the last cold light dying on the cut edge (§4 -- the left jamb
    # gets it, the right does not).
    for y in range(top + 12, HORIZON):
        c.put(x0 - 1, y, JAMB)
        c.put(x0, y, JAMB)
    # Timber bracing. Weathered, and leaning: the asset list's mine reads as
    # long-abandoned, not industrious, and true-square posts read as maintained.
    for i, (px, lean) in enumerate(((x0 - 3, -0.035), (x1 + 3, 0.03))):
        for y in range(top + 6, HORIZON):
            x = px + lean * (y - top)
            c.put(x, y, WOOD_MD)
            c.put(x - 1, y, WOOD_LT)          # lit left edge (§4)
            c.put(x + 1, y, WOOD_DK)
    for x in range(x0 - 7, x1 + 8):           # lintel
        c.put(x, top + 4, WOOD_LT)
        for y in range(top + 5, top + 8):
            c.put(x, y, WOOD_MD)
        c.put(x, top + 8, WOOD_DK)


def draw_tracks(c):
    """Cart tracks out of the portal into the square. They and the road are the
    same gesture from opposite ends -- the tracks say things came out of that
    hole, the road says people still walk toward it."""
    for i in range(2):
        x = 762.0 + i * 22.0
        y = float(HORIZON)
        while y < 452 and x > 0:
            c.put(x, y, ROAD_DK)
            c.put(x + 1, y, ROAD_DK)
            x -= 1.05 + i * 0.12
            y += 0.62
    for i in range(26):                        # sleepers, unevenly spaced (§7)
        t = (i + rnd(51, i) * 0.7) / 26.0
        y = HORIZON + t * 46.0
        x = 762.0 - (y - HORIZON) * 1.7
        c.put(x, y, ROAD_DK)
        for k in range(1, 4 + int(rnd(52, i) * 22)):
            c.put(x + k, y, ROAD_DK)


# --- the ruined town ---------------------------------------------------------
def draw_building(c, cx, hw, height, ruined, lit_windows, seed):
    """One building, back-lit. Everything below the horizon is silhouette and
    value: at this distance a ruin is a broken outline plus the absence of
    light, and that is exactly what the guide's ruined state is (mass and light
    change, identity does not)."""
    top = int(HORIZON - height)
    x0, x1 = int(cx - hw), int(cx + hw)
    body_top = top + int(height * 0.42)        # where the roof stops and wall starts

    # Roof. Intact = a clean gable; ruined = the same gable with the east half
    # fallen in, because a collapse the player can read has to be a bite out of
    # a shape they already know.
    for x in range(x0, x1 + 1):
        nx = abs(x - cx) / float(hw)
        r_top = top + (body_top - top) * nx
        if ruined:
            # Jagged break, hash-driven so no two ruins share a profile.
            if x > cx - hw * 0.25:
                bite = 0.35 + 0.5 * rnd(seed, int(x / 5))
                r_top = max(r_top, body_top - height * 0.10 * bite
                            + rnd(seed + 1, int(x / 3)) * 5.0)
        for y in range(int(r_top), body_top + 1):
            c.put(x, y, RUIN_MD if x < cx else RUIN_DK)
        if not ruined:
            c.put(x, int(r_top), RUIN_LT if x < cx else RUIN_MD)

    # Wall.
    for y in range(body_top, HORIZON):
        for x in range(x0, x1 + 1):
            nx = (x - cx) / float(hw)
            c.put(x, y, RUIN_MD if nx < -0.2 else RUIN_DK)
    if ruined:
        # Collapsed east wall: the wall falls away and leaves rubble, so the
        # silhouette breaks at the ground too and not only at the roof.
        for x in range(int(cx + hw * 0.35), x1 + 1):
            gap = max(0.0, (x - (cx + hw * 0.35)) / max(1.0, hw * 0.65))
            wall_top = body_top + height * 0.55 * (gap ** 0.7) * rnd(seed + 2, x)
            for y in range(body_top, int(min(wall_top, HORIZON))):
                c.put(x, y, c.get(x, top - 4) if y < HORIZON else RUIN_DK)
        for i in range(14):                    # rubble at the foot
            rx = cx + hw * (0.2 + rnd(seed + 3, i) * 0.9)
            ry = HORIZON - 1 - rnd(seed + 4, i) * 5
            c.rect(rx, rx + 1 + rnd(seed + 5, i) * 3, ry, HORIZON - 1, RUIN_DK)

    # West edge rim: the last of the set sun catching the standing wall (§4).
    for y in range(body_top, HORIZON):
        c.put(x0, y, RUIN_RIM)
    c.put(x0, body_top, RUIN_RIM)

    # Chimney. Cracked and leaning on the ruins, upright and smoking on the inn.
    ch_x = cx - hw * 0.55
    ch_h = height * (0.22 if ruined else 0.34)
    lean = 0.16 if ruined else 0.0
    for k in range(int(ch_h)):
        y = top - k + int(height * 0.10)
        x = ch_x + lean * k
        c.rect(x - 3, x + 3, y, y, RUIN_MD)
        c.put(x - 3, y, RUIN_LT)

    # Windows. Dark sockets in a ruin -- and the ONLY gold in the frame in the
    # inn, warm against the cool dusk (§4's money shot, §2's gold channel).
    rows = 2 if height > 74 else 1
    for r in range(rows):
        wy = body_top + 10 + r * int(height * 0.26)
        if wy > HORIZON - 12:
            continue
        for i in range(3):
            wx = spread(seed + 6 + r, i, 3, x0 + 5, x1 - 5, jitter=0.5)
            if ruined and rnd(seed + 7, r * 3 + i) > 0.75:
                continue                       # a hole where a window was
            c.rect(wx, wx + 3, wy, wy + 4, PITCH)
            if not lit_windows:
                continue
            c.rect(wx, wx + 3, wy, wy + 4, GLOW_MD)
            c.rect(wx + 1, wx + 2, wy + 1, wy + 3, GLOW_LT)
            # Spill onto the wall around the frame -- dithered so the glow has
            # no hard edge. The guide's glow budget lists lit windows at night
            # as one of the few things allowed to emit; it does not license a
            # bloom, so this stays a two-pixel halo.
            for yy in range(int(wy) - 3, int(wy) + 8):
                for xx in range(int(wx) - 3, int(wx) + 7):
                    if c.get(xx, yy) in (GLOW_MD, GLOW_LT, PITCH):
                        continue
                    d = 1.0 - math.hypot((xx - wx - 1.5) / 4.0,
                                         (yy - wy - 2.0) / 4.5)
                    if d > 0 and d * 0.8 > dither(xx, yy):
                        c.put(xx, yy, GLOW_DK if d > 0.5 else RUIN_RIM)


def draw_smoke(c, cx, top):
    """Chimney smoke off the inn -- the guide's Inn silhouette feature, and the
    only moving-looking thing in a dead town. Cool and thin: it is dusk smoke
    against a violet sky, not a forge plume."""
    x, y = float(cx), float(top)
    for k in range(74):
        drift = math.sin(k * 0.16) * 3.4 + k * 0.16
        for j in range(1 + int(rnd(61, k) * 3)):
            # Fans out as it climbs. A column that stays one width all the way up
            # is a chimney with an antenna on it, not smoke.
            px = x + drift + (rnd(62, k * 4 + j) - 0.5) * (3 + k * 0.34)
            py = y - k * 1.5 - rnd(63, k * 4 + j) * 2
            if (1.0 - k / 74.0) * 0.85 > dither(int(px), int(py)):
                c.put(px, py, SMOKE_A if rnd(64, k * 4 + j) > 0.45 else SMOKE_B)


def draw_town(c):
    """Seven buildings between the frame's west edge and the square. One of them
    -- the inn -- still stands and is still lit; the rest are the ruined state
    the campaign actually starts in. That ratio is the pitch: a dead town, one
    light on in it, and a hole in a mountain across the square.
    """
    inn = 2
    for i in range(7):
        cx = spread(71, i, 7, 10, 372, jitter=0.9)
        hw = 22 + rnd(72, i) * 16
        height = 58 + rnd(73, i) * 44
        if i == inn:
            cx, hw, height = 150.0, 40.0, 96.0   # nearest, widest, tallest: the
            # guide's Inn is "wide + welcoming", and the one intact silhouette
            # should be the one the eye lands on first.
        draw_building(c, cx, hw, height, i != inn, i == inn, 81 + i * 11)
        if i == inn:
            draw_smoke(c, cx - hw * 0.55, HORIZON - height - int(height * 0.24))

    # One last ruin marooned at the outcrop's foot, across the square: it sets
    # the mountain's scale and says the town used to reach that far.
    draw_building(c, 596.0, 20.0, 46.0, True, False, 167)


def draw_graveyard(c):
    """Headstones in the near foreground, lower west. The graveyard is a real
    town building (sprites/town/graveyard_*.png) and every hireling who dies in
    that hole ends up here, so it belongs in the key art -- as near-black
    silhouette, at the frame's edge, saying it without asking for a look."""
    for i in range(9):
        x = spread(91, i, 9, 18, 178, jitter=1.5)
        y = 452 + rnd(92, i) ** 1.4 * 66
        hgt = 12 + rnd(93, i) * 13
        hw = 3 + rnd(94, i) * 3
        lean = (rnd(95, i) - 0.5) * 0.28       # settled and crooked, not planted
        for k in range(int(hgt)):
            yy = y - k
            xx = x + lean * k
            cap = hw if k < hgt - 3 else hw * (1.0 - (k - (hgt - 3)) / 3.5)
            for dx in range(int(-cap), int(cap) + 1):
                c.put(xx + dx, yy, NEAR_LIT if dx < -cap * 0.4 else NEAR_BLACK)


# A broken fence was authored along the road's west shoulder here and cut: at
# the size a fence post is in this frame it rendered as scattered dirt specks
# rather than a line, and it put them squarely under the button column. The road
# is already the lead-in it was meant to reinforce, and §7's detail budget wants
# the ground quiet, so the fix was to delete it rather than to shout it louder.


# --- ground ------------------------------------------------------------------
def draw_ground(c):
    c.vramp(HORIZON, H, list(EARTH))
    # A dead scatter of tufts and stones. Sparse and low contrast -- §7 wants the
    # ground quiet, and the dithered ramp is already carrying the depth.
    for i in range(150):
        x = spread(111, i, 150, 0, W, jitter=1.7)
        y = HORIZON + 4 + rnd(112, i) ** 1.5 * (H - HORIZON - 8)
        t = (y - HORIZON) / float(H - HORIZON)
        c.put(x, y, ROAD_DK if t < 0.5 else NEAR_LIT)
        if rnd(113, i) > 0.7:
            c.put(x + 1, y, ROAD_DK if t < 0.5 else NEAR_LIT)


def draw_road(c):
    """The road out of the square to the portal, widening toward the viewer. It
    enters bottom-centre and leaves at the mine, which puts the one line in the
    scene that the eye follows underneath the menu and pointing at the dungeon.
    Kept within a value or two of the earth: this is a lead-in, not a subject."""
    for y in range(HORIZON, H):
        t = (y - HORIZON) / float(H - HORIZON)
        cx = 762.0 - (t ** 0.85) * 300.0
        hw = 5.0 + (t ** 1.25) * 86.0
        for x in range(int(cx - hw), int(cx + hw) + 1):
            nx = abs(x - cx) / hw
            # Dithered shoulders: a hard-edged road on a dark plain reads as a
            # ribbon laid on top of it rather than as a track worn into it.
            if (1.0 - nx) * 1.5 < dither(x, y):
                continue
            lit = ROAD_LT if nx < 0.55 else ROAD_DK
            c.put(x, y, lit if t < 0.62 else ROAD_DK)
    # Ruts: two, converging with the road, dropped before the foreground so they
    # do not run under the buttons as a pair of stripes.
    for i in range(2):
        for y in range(HORIZON + 6, H - 40):
            t = (y - HORIZON) / float(H - HORIZON)
            cx = 762.0 - (t ** 0.85) * 300.0
            hw = 5.0 + (t ** 1.25) * 86.0
            x = cx + (i * 2 - 1) * hw * 0.42
            if 0.5 > dither(int(x), y):
                c.put(x, y, ROAD_DK)


def main():
    root = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
    out_dir = os.path.join(root, "lord-of-hirelings", "sprites", "ui")
    os.makedirs(out_dir, exist_ok=True)

    c = Canvas()
    # Back to front. Everything is opaque, so paint order IS depth order.
    draw_sky(c)
    draw_stars(c)
    draw_moon(c)
    draw_far_ridge(c)
    draw_outcrop(c)
    draw_ground(c)
    draw_road(c)
    draw_tracks(c)
    draw_portal(c)
    draw_town(c)
    draw_graveyard(c)

    img = c.image()
    out = os.path.join(out_dir, "title_backdrop.png")
    img.save(out)
    print("wrote", out)

    # Review sheet: 1:1 (it is authored at native resolution, so 1:1 is exactly
    # what ships) with the menu's safe area boxed in magenta. The art has to be
    # judged against where the buttons and panels actually land, not in the
    # abstract -- that box is the whole reason this framing was chosen.
    preview_dir = os.path.join(root, "SourceArt", "previews")
    os.makedirs(preview_dir, exist_ok=True)
    sheet = img.convert("RGB")
    x0, y0, x1, y1 = UI_BOX
    for x in range(x0, x1, 8):
        for k in range(4):
            sheet.putpixel((min(x + k, W - 1), y0), (255, 0, 200))
            sheet.putpixel((min(x + k, W - 1), y1), (255, 0, 200))
    for y in range(y0, y1, 8):
        for k in range(4):
            sheet.putpixel((x0, min(y + k, H - 1)), (255, 0, 200))
            sheet.putpixel((x1, min(y + k, H - 1)), (255, 0, 200))
    preview = os.path.join(preview_dir, "title_backdrop_preview.png")
    sheet.save(preview)
    print("wrote", preview)


if __name__ == "__main__":
    main()
