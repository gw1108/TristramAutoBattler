# Gilded Trait — Gold-Sheen Treatment

Implementation specification for the Gilded enemy trait. This is the visual counterpart to
`LordofHirelings_HoarderFattenTech.md`. It applies to every non-boss enemy that rolls Gilded and
has no dedicated sprite frames.

## Decided treatment

The base sprite keeps its alpha, silhouette, outline placement, and value structure. A `canvas_item`
shader remaps its luminance onto the existing gold accent ramp, then adds a restrained diagonal glint.
Rare coin sparkles are a separate tiny overlay/particle, not a shader output. The result must read as
valuable living treasure, not as a yellow enemy with a permanent bloom halo.

### Gold ramp and luminance remap

Map source luminance to the existing UI gold ramp while preserving the sprite's original light/dark
relationships:

| Source luminance band | Gilded output |
|---|---|
| Shadow | `#c9a15a` |
| Midtone | `#d4b000` |
| Light | `#f0d890` |
| Specular/highlight | `#ffe9b0` |

- Quantize softly between bands; do not flatten a sprite into solid yellow.
- Preserve `COLOR.a` exactly. Fully transparent texels must remain transparent.
- Keep the original 1px selective outline darker than the nearest gold band. It must still separate the
  enemy from its biome backdrop.
- The remap is luminance-driven and therefore applies to every approved-palette enemy without per-enemy
  art. The Golden Slime is the showcase case.

### Glint and sparkles

- A narrow diagonal specular sweep crosses the visible sprite from top-left to bottom-right every
  **2.5 seconds**, with a ±0.3-second per-instance phase offset. It lasts **0.22 seconds** and only
  lifts the current remapped band one step; it never makes a full-sprite white flash.
- Spawn at most **one** 2-frame coin sparkle around a Gilded enemy every **1.8-3.2 seconds**. The
  sparkle is 2-3 pixels, fades quickly, and is clipped to a small area around the sprite.
- Pause the glint and sparkles while the enemy is in its death/fade animation. No sparkle is required
  for the ordinary coin-drop effect.

## Shader outline

`gilded_gold.gdshader` receives only a per-instance phase offset. The 12% spawn rate is low enough to
duplicate a material per Gilded enemy, as with Hoarders. A shared material plus `instance uniform` is
also acceptable if the Godot renderer supports it.

```glsl
shader_type canvas_item;

uniform float phase_offset = 0.0;

vec3 gold_ramp(float luma) {
    if (luma < 0.25) return vec3(0.788, 0.631, 0.353); // #c9a15a
    if (luma < 0.50) return vec3(0.831, 0.690, 0.000); // #d4b000
    if (luma < 0.75) return vec3(0.941, 0.847, 0.565); // #f0d890
    return vec3(1.000, 0.914, 0.690);                  // #ffe9b0
}

void fragment() {
    vec4 source = texture(TEXTURE, UV);
    float luma = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
    vec3 color = gold_ramp(luma);

    float cycle = fract(TIME / 2.5 + phase_offset);
    float sweep = smoothstep(0.39, 0.50, cycle + UV.x * 0.16 - UV.y * 0.16)
        - smoothstep(0.50, 0.61, cycle + UV.x * 0.16 - UV.y * 0.16);
    color = mix(color, vec3(1.0), sweep * 0.35);
    COLOR = vec4(color, source.a);
}
```

The exact smoothstep geometry can be tuned in the shader, but the approved visual constraints above are
the source of truth: a thin diagonal sweep, no halo, no silhouette change, and no loss of alpha.

## Constraints

- Gilded is mutually exclusive with Hoarder under the current trait table; do not write the runtime
  assuming both materials must stack.
- Bosses and minions never receive this shader because they never roll gold traits.
- Count the glint against the style guide's glow budget. If a row already has strong caster or lava VFX,
  reduce glint intensity before reducing combat readability.
