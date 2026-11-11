# Weather FX

39 animated 2D weather, sky, water and ground effects for Godot 4.3+ (Forward+, Mobile, Compatibility). Each is
one shader drawn by one `WeatherFX` node: no textures, no particles.

**The full pack:** **[Weather FX](https://heyheythere.itch.io/weather-fx)** has all 39: lightning, storm clouds, a
tornado, a blizzard, hail, mist, the sun and moon, stars, meteors, an aurora, clouds, a rainbow, a lake
that reflects your scene with raindrop ripples, a waterfall, ash, embers, fireflies, pollen, a sandstorm,
wind, falling leaves, god rays, heat haze, frost and rain on the window, a day-night cycle, and wet
ground, puddles, snow cover, ice and fallen leaves building up on the ground, on top of these three,
and weather states for all of them. Same node, same code: install it over this one.

## Add one

```gdscript
var rain := WeatherFX.add(self, "rain")                   # covers the view, follows the camera
WeatherFX.add(self, "fog", {density = 0.8}).fade_in(3.0)
WeatherFX.add(self, "water", {position = Vector2(0, 500), size = Vector2(1280, 220)})
var storm := WeatherFX.add(self, "lightning", {frequency = 0.0})
storm.strike()                                            # a strike, now
rain.stop(2.0)                                            # fades out, then frees itself
```

Or add a WeatherFX node to a scene and pick `effect`. It previews in the editor, and its material
holds the uniforms.

## Effects

`WeatherFX.effects()` lists them all.

- Sky: stars, meteors, moon, sun, aurora, clouds, storm_clouds, rainbow, tornado
- Falling and blowing: rain, snow, blizzard, hail, leaves, ash, embers, fireflies, pollen, sandstorm,
  wind, bubbles
- Light and air: fog, mist, cloud_shadows, god_rays, heat_haze, lightning, caustics, day_night
- Water: ripples (rain rings on a surface; give it the water's rect), water and waterfall (rects,
  top-left corner at the node), ice (over the water's rect; `oval` for a pond in it)
- On the ground: wet_ground, puddles, snow_cover, fallen_leaves (rects over the ground; `amount`
  how far they have built up, `tilt` 1 for ground seen from above, lower from the side)
- On the screen: frost growing in from the edges in ferns of ice, rain_window (beads and runners on the glass)

Give any effect a `size` to draw it as a rect instead. Patterns are anchored to the world, so they
stay put when the camera moves.

## Options

Options go to `add()` or `set_option()`. A key that names a property of the node sets it, any other
key sets the shader uniform: see the material in the inspector for each effect's own (`density`,
`wind`, `color`, `fall_speed`, `time_of_day`...).

| option | | |
|---|---|---|
| `size` | node | rect in pixels; zero covers the view (water, waterfall, ice and the ground's have a default rect) |
| `pixel_size` | node | pixel-art mode: size of a pixel; -1 follows `WeatherFX.default_pixel_size` |
| `position`, `z_index`... | node | any Node2D property |
| `intensity` | shader | strength, 0..2; `fade_in()` and `stop()` drive it |
| `speed` | shader | animation speed |
| `seed` | shader | variation; `add()` picks a random one |
| `color_steps` | shader | posterize to N levels per channel |

## Layering

Draw order is node order, as listed in `WeatherFX.EFFECTS`: the sky first, water before rain,
day_night after the scene, rain_window last. Put your UI on a CanvasLayer
above the weather so day_night doesn't tint it.

Water, heat_haze and rain_window read the screen, and see what was drawn before them on a lower CanvasLayer
(or the same layer, before the first screen reader on it). Keep the level on layer 0 and put them on
a CanvasLayer at 1; heat_haze over water needs a layer of its own above the water, and rain_window
one above all the weather it should bend.

Rain splashes and hail bounces where they meet the `ground` uniform (0..1 down the view, 1 is off),
lightning strikes down to its own `ground` and a tornado touches down on it.

## Weather states

```gdscript
$Weather.change("storm", 6.0)                          # a WeatherSystem node, over 6 seconds
$Weather.forecast = {clear = 3, cloudy = 2, rain = 1}  # changes on its own every change_every seconds
```

A WeatherSystem adds a state's effects as its children and, on a change, fades out the ones the
next state doesn't have and fades in its new ones. `WeatherSystem.STATES` holds each state's effects
and options; `WeatherSystem.states()` lists the ones installed. `ground` sets where rain splashes and
lightning strikes, and `get_effect("lightning")` is its lightning, to `strike()`. Put it on a
CanvasLayer above the level, as the effects; heat_haze reads what is drawn before it there.

```gdscript
$Weather.ground_rect = Rect2(0, 470, 1280, 250)   # where the weather leaves its marks
$Weather.ground_tilt = 0.3                        # ground seen from the side
$Weather.settle()                                 # as far as the weather builds them, at once
```

Given a `ground_rect` (and a `water_rect` for ice), the weather builds its marks up there over a
minute or so (`WeatherSystem.MARKS`, `ground_rate` to hurry them) and wears them off once it has
gone: wet ground and puddles in rain, snow cover and ice in snow, fallen leaves in the wind.
`get_mark("puddles")` is how far one has built up; `mark_options` sets a mark's own
(`{ice = {oval = true}}`).

## Pixel art

```gdscript
WeatherFX.default_pixel_size = 4   # once, before adding effects
```

Effects then draw in 4x4 pixel blocks aligned to the world, with hard-edged alpha. Combine with
`color_steps` for a limited palette.
