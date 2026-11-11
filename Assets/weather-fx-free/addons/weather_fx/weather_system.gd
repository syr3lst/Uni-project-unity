@tool
class_name WeatherSystem
extends Node2D
## Weather as states: one call changes it, the effects that go fading out as the new ones fade in.
##
##     $Weather.change("storm", 6.0)                          # over 6 seconds
##     $Weather.weather = "snow"                              # over `fade`
##     $Weather.forecast = {clear = 3, cloudy = 2, rain = 1}  # changes on its own, by weight
##     $Weather.get_effect("lightning").strike()
##
## A state is WeatherFX effects with their options (STATES). An effect the next state has too, with
## the same options, stays as it is.
##
## Given a ground_rect (and a water_rect), the weather leaves its marks there over time: the ground
## wet and puddled in rain, snowed over, strewn with leaves in the wind, the water iced over; each
## wears off once its weather has gone.
##
##     $Weather.ground_rect = Rect2(0, 470, 1280, 250)
##     $Weather.settle()                                      # the marks of the weather now, at once

signal weather_changed(state: String)

## Each state's effects and their options. Its first is its lead: the state is offered (states())
## when that one is installed, and brings whichever of the others are.
const STATES := {
	"clear": {},
	"cloudy": {"clouds": {coverage = 0.55}, "cloud_shadows": {coverage = 0.35}},
	"drizzle": {"rain": {density = 0.3, drop_length = 14.0, fall_speed = 0.8, splashes = 0.4},
		"clouds": {coverage = 0.8, color = Color(0.85, 0.87, 0.9), shade = Color(0.56, 0.6, 0.68)},
		"mist": {density = 0.35}},
	"rain": {"rain": {density = 0.55}, "storm_clouds": {cover = 0.3, flashes = 0.0}},
	"storm": {"storm_clouds": {cover = 0.4, flashes = 0.5},
		"rain": {density = 0.8, wind = 0.45, drop_length = 34.0, fall_speed = 1.3},
		"lightning": {frequency = 0.3}},
	"hail": {"hail": {density = 0.5}, "storm_clouds": {cover = 0.35, flashes = 0.15}},
	"snow": {"snow": {density = 0.45},
		"clouds": {coverage = 0.75, color = Color(0.92, 0.93, 0.96), shade = Color(0.7, 0.74, 0.84)}},
	"blizzard": {"blizzard": {}, "fog": {density = 0.3}},
	"fog": {"fog": {density = 0.55}, "mist": {density = 0.5}},
	"windy": {"wind": {density = 0.5}, "leaves": {density = 0.25, wind = 0.9}, "clouds": {coverage = 0.35, wind = 1.2}},
	"sandstorm": {"sandstorm": {}, "wind": {density = 0.35, color = Color(1.0, 0.9, 0.7, 0.5)}},
	"heatwave": {"heat_haze": {}, "sun": {}},
	"ashfall": {"ash": {}, "embers": {density = 0.3}},
}
## The effects that take `ground`.
const GROUNDED := ["rain", "hail", "lightning", "tornado"]
## The marks on the ground (on water for ice): how far each state builds each up, 0..1. A state left
## out wears it off.
const MARKS := {
	"wet_ground": {"drizzle": 0.6, "rain": 1.0, "storm": 1.0, "hail": 0.8},
	"puddles": {"drizzle": 0.3, "rain": 0.8, "storm": 1.0, "hail": 0.5},
	"snow_cover": {"snow": 0.8, "blizzard": 1.0},
	"fallen_leaves": {"windy": 1.0},
	"ice": {"snow": 0.7, "blizzard": 1.0},
}
## Seconds each mark takes, at ground_rate 1, to build up from none to full and to wear off again.
const MARK_SECONDS := {
	"wet_ground": [20.0, 90.0], "puddles": [45.0, 120.0], "snow_cover": [60.0, 150.0],
	"fallen_leaves": [40.0, 300.0], "ice": [60.0, 120.0],
}

@export_enum("clear", "cloudy", "drizzle", "rain", "storm", "hail", "snow", "blizzard", "fog", "windy",
		"sandstorm", "heatwave", "ashfall")
var weather := "clear":
	set(v):
		if v not in STATES:
			push_error("WeatherSystem: no state %s, pick one of %s" % [v, states()])
			return
		weather = v
		_apply(fade if _seconds < 0.0 else _seconds)
		_seconds = -1.0
## Seconds a change takes when not given.
@export var fade := 4.0
## Where rain splashes, hail bounces, lightning strikes and a tornado touches down: 0..1 down the
## view, 1 its bottom.
@export_range(0.0, 1.0) var ground := 1.0:
	set(v):
		ground = v
		for e in _shown:
			if e in GROUNDED:
				_shown[e].set_param(&"ground", v)
## Random weather: each state's weight. Empty holds the weather.
@export var forecast := {}:
	set(v):
		forecast = v
		_next = randf_range(change_every.x, change_every.y)
## Where the marks of the weather build up, in the system's coordinates: wet ground, puddles, snow
## cover and fallen leaves. Empty for none.
@export var ground_rect := Rect2():
	set(v):
		ground_rect = v
		_place()
## The water that ices over in snow, in the system's coordinates. Empty for none.
@export var water_rect := Rect2():
	set(v):
		water_rect = v
		_place()
## 1 for ground seen from above, lower for ground seen from the side: the marks' tilt.
@export_range(0.1, 1.0) var ground_tilt := 1.0:
	set(v):
		ground_tilt = v
		for e in _marks:
			_marks[e].set_param(&"tilt", v)
## Options for a mark's WeatherFX, by mark: {ice = {oval = true}} for a pond seen from above.
@export var mark_options := {}:
	set(v):
		mark_options = v
		for e in _marks:
			for key in mark_options.get(e, {}):
				_marks[e].set_option(key, mark_options[e][key])
## How fast the marks build up and wear off: 1 takes a minute or so, more for a time-lapse.
@export_range(0.0, 100.0) var ground_rate := 1.0
## Seconds between the forecast's changes, at random from x to y.
@export var change_every := Vector2(60, 180):
	set(v):
		change_every = v
		_next = randf_range(v.x, v.y)

var _shown := {}    # effect: its WeatherFX
var _marks := {}    # mark: its WeatherFX, while it shows
var _amounts := {}  # mark: how far it has built up, 0..1
var _options := {}  # effect: the options it was added with
var _seconds := -1.0
var _next := randf_range(60, 180)


## The states whose lead effect is installed, and clear.
static func states() -> PackedStringArray:
	var have := WeatherFX.effects()
	return PackedStringArray(STATES.keys().filter(func(s: String) -> bool:
		return STATES[s].is_empty() or STATES[s].keys()[0] in have))


## Changes the weather over `seconds` (-1: `fade`).
func change(state: String, seconds := -1.0) -> void:
	_seconds = seconds
	weather = state


## The state's WeatherFX for `effect`, or a mark's while it shows, or null.
func get_effect(effect: String) -> WeatherFX:
	return _shown.get(effect, _marks.get(effect))


## How far a mark has built up, 0..1.
func get_mark(mark: String) -> float:
	return _amounts.get(mark, 0.0)


## Every mark as far as the weather builds it, at once: for a game loaded or a scene started mid-storm.
func settle() -> void:
	for e in MARKS:
		_set_mark(e, MARKS[e].get(weather, 0.0))


func _ready() -> void:
	_apply(0.0)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	for e in MARKS:
		var target: float = MARKS[e].get(weather, 0.0)
		var now: float = _amounts.get(e, 0.0)
		if now != target:
			var step: float = delta * ground_rate / MARK_SECONDS[e][0 if target > now else 1]
			_set_mark(e, move_toward(now, target, step))
	if forecast.is_empty():
		return
	_next -= delta
	if _next > 0.0:
		return
	_next = randf_range(change_every.x, change_every.y)
	var offered := states()
	var total := 0.0
	for s in forecast:
		total += forecast[s] if s in offered else 0.0
	var pick := randf() * total
	for s in forecast:
		if s in offered:
			pick -= forecast[s]
			if pick < 0.0:
				if s != weather:
					change(s)
				return


## A mark at `amount`, its WeatherFX added or freed as it comes and goes.
func _set_mark(mark: String, amount: float) -> void:
	_amounts[mark] = amount
	var rect := water_rect if mark == "ice" else ground_rect
	if amount <= 0.0 or not rect.has_area() or mark not in WeatherFX.effects():
		if mark in _marks:
			_marks[mark].queue_free()
			_marks.erase(mark)
		return
	if mark not in _marks:
		var options: Dictionary = {position = rect.position, size = rect.size, tilt = ground_tilt}
		options.merge(mark_options.get(mark, {}), true)
		_marks[mark] = WeatherFX.add(self, mark, options)
		_order()
	_marks[mark].set_param(&"amount", amount)
	if mark == "puddles":
		_marks[mark].set_param(&"rain", 0.6 if weather in ["rain", "storm"] else (0.25 if weather == "drizzle" else 0.0))


## The marks showing moved to their rects.
func _place() -> void:
	for e in _amounts.keys():
		_set_mark(e, _amounts[e])
	for e in _marks:
		var rect := water_rect if e == "ice" else ground_rect
		_marks[e].position = rect.position
		_marks[e].size = rect.size


func _apply(seconds: float) -> void:
	if not is_inside_tree():
		return
	if Engine.is_editor_hint():
		seconds = 0.0
	var want: Dictionary = STATES[weather]
	for e in _shown.keys():
		if e not in want or want[e] != _options[e]:
			_shown[e].stop(seconds)
			_shown.erase(e)
			_options.erase(e)
	var have := WeatherFX.effects()
	for e in want:
		if e in _shown or e not in have:
			continue
		var options: Dictionary = want[e].duplicate()
		if e in GROUNDED:
			options.ground = ground
		_shown[e] = WeatherFX.add(self, e, options).fade_in(seconds)
		_options[e] = want[e]
	_order()
	weather_changed.emit(weather)


## WeatherFX.EFFECTS' drawing order, the ones fading out and the marks among them.
func _order() -> void:
	var order := WeatherFX.EFFECTS.keys()
	var fx := get_children().filter(func(n: Node) -> bool: return n is WeatherFX)
	fx.sort_custom(func(a: WeatherFX, b: WeatherFX) -> bool: return order.find(a.effect) < order.find(b.effect))
	for i in fx.size():
		move_child(fx[i], i)
