# Hoarder Trait — Fatten Treatment (Implementation Research)

Feasibility research for the Hoarder trait's "fattened" visual treatment (see the *Hoarder trait
treatment* row in `LordofHirelings_ArtAssetList.md`). **Verdict: fully feasible and cheap.** One
`canvas_item` shader plus one line of scale code, reused across every enemy sprite with no
per-enemy art.

Interactive demo with live comparisons: `mockups/hoarder-fatten-demo.html`
(published copy: https://claude.ai/code/artifact/6c064d58-0b28-4264-a317-09dea019d8a3)

## Decided treatment

Two layers, both driven by one `fatness` value. **Chosen default: `fatness = 0.83`** (picked
against the demo; reads clearly fat on every silhouette without outline mush).

1. **Belly bulge (UV shader).** A `canvas_item` shader magnifies an elliptical belly region
   outward via UV distortion. Silhouette-agnostic — same material for humanoids and quadrupeds.
2. **Squash (code, no shader).** `sprite.scale = Vector2(1 + 0.30 * fatness, 1 - 0.12 * fatness)`,
   anchored at the feet. Reads at battlefield distance where the bulge doesn't.

### Idle animation — "heavy bounce"

Hoarders don't sit on a static combined pose; they **passively bounce between bulge-only (B) and
squash+bulge (C)**: the belly bulge stays constant at full `fatness` while the squash component
oscillates `0 → full → 0`. Use `abs(sin(t))` timing (period ≈ 1.1 s) so the turnaround at zero
squash is sharp — it reads as a heavy body settling, not a smooth pulse. Squash is pure scale, so
the per-frame cost is nothing; the shader itself doesn't animate.

```gdscript
# per frame, hoarders only
var p := absf(sin(time * TAU / 1.1))
sprite.scale = Vector2(1.0 + 0.30 * fatness * p, 1.0 - 0.12 * fatness * p)
```

## The shader

`hoarder_fatten.gdshader` — works in normalized UV space, so the identical material applies to
any sprite resolution or body shape:

```glsl
shader_type canvas_item;

// Hoarder "fatten": belly-bulge UV distortion.
// Sprite frames need transparent padding (~15%) or the bulge clips at the texture edge.
uniform float fatness : hint_range(0.0, 1.0) = 0.83;
uniform vec2  belly_center = vec2(0.5, 0.58);  // tweak per body shape if needed
uniform float belly_radius = 0.46;
uniform float belly_width  = 1.3;   // ellipse: bulge reaches wider than tall

void fragment() {
    vec2 d = UV - belly_center;
    float r = length(vec2(d.x / belly_width, d.y)) / belly_radius;
    if (r < 1.0) {
        // f < 1 near the center: sample inward, so the texture magnifies outward
        float f = 1.0 - (0.55 * fatness) * pow(1.0 - r * r, 1.5);
        COLOR = texture(TEXTURE, belly_center + d * f);
    } else {
        COLOR = texture(TEXTURE, UV);
    }
}
```

Applying the trait when it rolls (5% of non-boss spawns):

```gdscript
sprite.material = hoarder_material.duplicate()  # per-instance copy; trivial at 5% spawn rate
sprite.material.set_shader_parameter("fatness", 0.83)
```

## Enemy data: per-enemy opt-out

Every enemy definition carries a fatten-eligibility flag, **default `true`** — all enemies can
gain the effect unless a designer turns it off for a specific enemy (e.g. if a future body shape
never reads well fattened):

```gdscript
# in the enemy resource/definition
@export var can_fatten: bool = true   # Hoarder fatten treatment allowed on this enemy
```

Trait roll logic: an enemy that rolls Hoarder but has `can_fatten = false` keeps the Hoarder
*stats* (×3 gold, +50% HP, −2 speed) and skips only the visual fatten (fall back to the coin-purse
overlay alone so it's still readable as a Hoarder). Bosses never roll traits, so no flag needed
there.

## Constraints & notes

- **Padding requirement (the only asset-side constraint).** The bulge pushes pixels outward, so
  each enemy sprite frame needs ~15% transparent margin around the body. Frames authored tight
  will clip the belly at the frame edge. Bake this into the sprite spec before enemy art starts.
- **Pixel-art fidelity.** The game renders at 960×540 native and integer-scales
  (`LordofHirelings_ArtStyleGuide.md`), so the shader resamples at art resolution and distortion
  stays on the pixel grid. Keep effective strength ≤ ~0.6 (the `0.55` factor caps this at
  `fatness = 1.0`) or curved outlines go lumpy.
- **Per-enemy tuning is optional.** Default `belly_center` works for humanoids; quadrupeds (Wolf,
  Giant Leech) may want it nudged — one exported vec2, not new art.
- **Material sharing.** Duplicate the material per hoarder instance (negligible at 5% spawns), or
  use `instance uniform` if the Godot version supports it in `canvas_item` shaders.
- **Stacking.** The coin-purse overlay from the asset list layers on top independently; the shader
  doesn't conflict with it, nor with the Gilded gold-sheen shader if traits ever stack.

## Sources

- [Squish Sprite shader (godotshaders.com)](https://godotshaders.com/shader/squish-sprite/) — same UV-displacement principle, with a bulge parameter
- [Godot canvas_item shader docs](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/canvas_item_shader.html)
- Unity-side equivalents for reference: [Alan Zucconi — sprite distortion](https://www.alanzucconi.com/2019/04/16/sprite-doodle-shader-effect/), [Shader Graph bulge tutorial](https://www.youtube.com/watch?v=3T8cKTQrMxk)
