extends Node2D
## Turn effects on and off over a pixel-art landscape; they stack. Pick a weather state for a
## WeatherSystem to cross-fade to, its marks building up on the ground ten times as fast as in a
## game. Click to strike lightning.

const LANDSCAPE := preload("res://addons/weather_fx/demo/landscape.gd")
const ZOOM := 4
const GROUND := 0.66
const LAKE := 0.8
## Laid over the ground: below the ground line, or the whole meadow seen from above.
const ON_GROUND := ["wet_ground", "puddles", "snow_cover", "fallen_leaves"]
const SIDE_TILT := 0.3
const START := ["water", "fog", "god_rays", "snow"]   # the first three installed are on
const RESHAPE := ["waterfall", "sun", "moon"]          # the landscape changes under them
const INTRO := """[b]Weather FX[/b]

A pixel-art landscape in %d moods, and %d weather effects to lay over it, each one shader on one node. Pick the [b]mood[/b] at the top of the panel.

Turn effects on and off with the switches: they stack, drawn in the order a game would draw them. Or pick a [b]Weather[/b] state, and a WeatherSystem fades the old effects out as the new ones fade in%s.

[b]Pixel art[/b] draws every effect in blocks of 4 pixels, to match the art."""

var land: Node2D
var mood := "dusk"
var active := {}
var buttons := {}
var weather := CanvasLayer.new()
var states := CanvasLayer.new()
var system := WeatherSystem.new()
var haze := CanvasLayer.new()
var glass := CanvasLayer.new()
var intro: Control


func _ready() -> void:
	# Water, heat haze and rain_window read the screen as it was when the first of them drew on
	# their layer: the landscape goes below them, heat haze and rain_window on layers of their own,
	# to see the water and then all the weather.
	weather.layer = 1
	add_child(weather)
	states.layer = 2
	add_child(states)
	system.ground = GROUND
	system.ground_rate = 10.0
	states.add_child(system)
	system.weather_changed.connect(func(_s: String) -> void: _build_land())
	haze.layer = 3
	add_child(haze)
	glass.layer = 4
	add_child(glass)
	var ui := CanvasLayer.new()
	ui.layer = 10      # above the weather, so day_night doesn't tint it
	add_child(ui)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	ui.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	var moods := OptionButton.new()
	for m in LANDSCAPE.MOODS:
		moods.add_item(m)
	moods.select(LANDSCAPE.MOODS.keys().find(mood))
	moods.item_selected.connect(func(i: int) -> void:
		mood = moods.get_item_text(i)
		_build_land())
	box.add_child(moods)
	var row := HBoxContainer.new()
	box.add_child(row)
	var title := Label.new()
	title.text = "Weather"
	row.add_child(title)
	var picker := OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in WeatherSystem.states():
		picker.add_item(s)
	picker.item_selected.connect(func(i: int) -> void: system.change(picker.get_item_text(i), 2.0))
	row.add_child(picker)
	var grid := GridContainer.new()
	grid.columns = 3 if WeatherFX.effects().size() > 36 else (2 if WeatherFX.effects().size() > 10 else 1)
	grid.add_theme_constant_override("v_separation", 0)
	box.add_child(grid)
	for name in WeatherFX.effects():
		var b := CheckButton.new()
		b.text = name
		b.custom_minimum_size = Vector2(150 if grid.columns > 2 else 170, 0)
		b.toggled.connect(func(on: bool) -> void: _toggle(name, on))
		grid.add_child(b)
		buttons[name] = b
	var foot := HBoxContainer.new()
	box.add_child(foot)
	var pixel := CheckBox.new()
	pixel.text = "pixel art"
	pixel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pixel.toggled.connect(func(on: bool) -> void: WeatherFX.default_pixel_size = ZOOM if on else 0)
	foot.add_child(pixel)
	var again := Button.new()
	again.text = "About this demo"
	again.pressed.connect(func() -> void: intro.show())
	foot.add_child(again)
	if "lightning" in WeatherFX.effects():
		var hint := Label.new()
		hint.text = "Click to strike lightning."
		hint.position = Vector2(panel.get_combined_minimum_size().x + 40, 16)
		hint.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.12))
		hint.add_theme_constant_override("outline_size", 8)
		ui.add_child(hint)
	intro = _make_intro()
	ui.add_child(intro)
	intro.visible = Engine.get_write_movie_path() == ""  # the store's shot of the panel goes without it
	_build_land()
	for name in START.filter(func(e: String) -> bool: return e in buttons).slice(0, 3):
		buttons[name].button_pressed = true


## The opening card: what the demo shows and how to use it, until it's closed.
func _make_intro() -> Control:
	var veil := ColorRect.new()
	veil.color = Color(0.03, 0.02, 0.06, 0.6)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.add_child(center)
	var card := PanelContainer.new()
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color(0.08, 0.07, 0.13, 0.96)
	style_box.set_corner_radius_all(10)
	style_box.set_content_margin_all(24)
	card.add_theme_stylebox_override(&"panel", style_box)
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 16)
	card.add_child(col)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.custom_minimum_size.x = 540
	var marks := ", its marks building up on the ground ten times as fast as in a game" if "puddles" in WeatherFX.effects() else ""
	text.text = INTRO % [LANDSCAPE.MOODS.size(), WeatherFX.effects().size(), marks]
	if "lightning" in WeatherFX.effects():
		text.text += " [b]Click[/b] anywhere to strike lightning."
	col.add_child(text)
	var go := Button.new()
	go.text = "Into the weather"
	go.custom_minimum_size = Vector2(220, 40)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.pressed.connect(veil.hide)
	col.add_child(go)
	veil.visibility_changed.connect(func() -> void:
		if veil.visible:
			go.grab_focus.call_deferred())
	go.grab_focus.call_deferred()
	return veil


func _unhandled_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and "lightning" in buttons:
		if system.get_effect("lightning"):
			system.get_effect("lightning").strike()
			return
		buttons["lightning"].button_pressed = true
		active["lightning"].strike()


func _build_land() -> void:
	if land:
		land.queue_free()
	land = LANDSCAPE.new()
	land.mood = mood
	land.art_size = Vector2i(get_viewport_rect().size) / ZOOM
	land.zoom = ZOOM
	land.ground = GROUND
	land.lake = LAKE if "water" in buttons or "ripples" in buttons else 0.0   # no bare lake without water
	land.cliff = 0.2 if "waterfall" in active else 0.0
	land.body = not ("sun" in active or "moon" in active or system.get_effect("sun"))   # one sun or moon in the sky
	land.sprites = [["bush", 0.36], ["mushroom", 0.5], ["slime", 0.66], ["chest", 0.88]]
	add_child(land)
	move_child(land, 0)
	var top_down := mood == "meadow"
	system.ground_tilt = 1.0 if top_down else SIDE_TILT
	system.ground_rect = _ground_rect()
	system.water_rect = _water_rect()
	system.mark_options = {ice = {oval = top_down}, snow_cover = {bank = 0.0 if top_down else 12.0}}
	for name in active:
		if name in ON_GROUND or name == "ice":
			for key in _placed(name):
				active[name].set_option(key, _placed(name)[key])


## The ground in view: below the ground line to the lake, or all of it seen from above.
func _ground_rect() -> Rect2:
	var size := get_viewport_rect().size
	if mood == "meadow":
		return Rect2(Vector2.ZERO, size)
	var bottom: float = land.lake_y() if land.lake > 0.0 else size.y
	return Rect2(0, land.ground_y(), size.x, bottom - land.ground_y())


## The water in view: the lake, or the meadow's pond.
func _water_rect() -> Rect2:
	var size := get_viewport_rect().size
	if mood == "meadow":
		return land.pond_rect()
	return Rect2(0, land.lake_y(), size.x, size.y - land.lake_y()) if land.lake > 0.0 else Rect2()


## A ground effect's or ice's place, as options.
func _placed(name: String) -> Dictionary:
	var rect := _water_rect() if name == "ice" else _ground_rect()
	var options := {position = rect.position, size = rect.size, tilt = 1.0 if mood == "meadow" else SIDE_TILT}
	if name == "ice":
		options.oval = mood == "meadow"
	if name == "snow_cover":
		options.bank = 0.0 if mood == "meadow" else 12.0
	return options


func _toggle(name: String, on: bool) -> void:
	if not on:
		if name in active:
			active[name].stop(0.4)
			active.erase(name)
		if name in RESHAPE:
			_build_land()
		return
	var size := get_viewport_rect().size
	var options := {}
	match name:
		"water", "ripples":
			options = {position = Vector2(0, land.lake_y()), size = Vector2(size.x, size.y - land.lake_y())}
		"waterfall":
			var top := int(land.art_size.y * 0.2) * ZOOM - 4.0
			options = {position = Vector2(size.x * 0.5 - 48, top), size = Vector2(96, land.lake_y() - top + 24)}
		"lightning", "tornado":
			options = {ground = GROUND}
		"wet_ground", "puddles", "snow_cover", "fallen_leaves", "ice":
			options = _placed(name)
		"rain", "hail":
			options = {ground = 1.0 if land.lake > 0.0 else GROUND + 0.01}
	var layer := {heat_haze = haze, rain_window = glass}.get(name, weather) as CanvasLayer
	active[name] = WeatherFX.add(layer, name, options).fade_in(0.4)
	if name in RESHAPE:
		_build_land()
	# Keep the drawing order of WeatherFX.EFFECTS: water under the rain, day_night over all.
	var i := 0
	for e in WeatherFX.EFFECTS:
		if e in active and active[e].get_parent() == weather:
			weather.move_child(active[e], i)
			i += 1
