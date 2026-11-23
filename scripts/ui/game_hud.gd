extends Control
class_name GymLifeHUD

const STAT_RING_SCRIPT := preload("res://scripts/ui/stat_ring.gd")

var _bars: Dictionary = {}
var _bar_tweens: Dictionary = {}
var _rings: Dictionary = {}
var _prompt_label: Label
var _clock_label: Label
var _drive_label: Label
var _crystal_label: Label
var _nitro_bar: ProgressBar
var _nitro_label: Label
var _victory_panel: PanelContainer
var _settings_panel: PanelContainer
var _settings_button: Button
var _settings_open: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_hud()


func _panel_style(background: Color, border: Color = Color(0.25, 0.33, 0.38, 1.0)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	return style


func _build_hud() -> void:
	var stats_panel := PanelContainer.new()
	stats_panel.position = Vector2(20, 18)
	stats_panel.custom_minimum_size = Vector2(310, 238)
	stats_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.055, 0.075, 0.88)))
	add_child(stats_panel)

	var stats_column := VBoxContainer.new()
	stats_column.add_theme_constant_override("separation", 10)
	stats_panel.add_child(stats_column)

	var title := Label.new()
	title.text = "GYM LIFE  /  ESTADO"
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(0.87, 0.95, 0.96))
	stats_column.add_child(title)

	_bars["happiness"] = _make_stat_row(stats_column, "Bienestar", Color(0.63, 0.72, 1.0))
	_bars["energy"] = _make_stat_row(stats_column, "Energía", Color(0.31, 0.85, 0.70))
	_bars["hunger"] = _make_stat_row(stats_column, "Hambre", Color(1.0, 0.70, 0.35))
	_bars["fitness"] = _make_stat_row(stats_column, "Forma física", Color(0.52, 0.72, 1.0))

	_crystal_label = Label.new()
	_crystal_label.text = "CRISTALES  0 / 5"
	_crystal_label.add_theme_font_size_override("font_size", 13)
	_crystal_label.add_theme_color_override("font_color", Color(0.82, 0.91, 0.93))
	stats_column.add_child(_crystal_label)

	var clock_panel := PanelContainer.new()
	clock_panel.anchor_left = 1.0
	clock_panel.anchor_right = 1.0
	clock_panel.offset_left = -172.0
	clock_panel.offset_right = -20.0
	clock_panel.offset_top = 18.0
	clock_panel.offset_bottom = 68.0
	clock_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.055, 0.075, 0.88)))
	add_child(clock_panel)
	_clock_label = Label.new()
	_clock_label.text = "08:00  /  DÍA"
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_clock_label.add_theme_font_size_override("font_size", 19)
	_clock_label.add_theme_color_override("font_color", Color(0.91, 0.96, 0.94))
	clock_panel.add_child(_clock_label)

	var ring_panel := PanelContainer.new()
	ring_panel.anchor_left = 1.0
	ring_panel.anchor_right = 1.0
	ring_panel.offset_left = -286.0
	ring_panel.offset_right = -20.0
	ring_panel.offset_top = 82.0
	ring_panel.offset_bottom = 186.0
	ring_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.055, 0.075, 0.82)))
	add_child(ring_panel)
	var ring_row := HBoxContainer.new()
	ring_row.alignment = BoxContainer.ALIGNMENT_CENTER
	ring_row.add_theme_constant_override("separation", 15)
	ring_panel.add_child(ring_row)
	_rings["energy"] = _make_ring(ring_row, "ENERGÍA", Color(0.31, 0.85, 0.70))
	_rings["hunger"] = _make_ring(ring_row, "HAMBRE", Color(1.0, 0.70, 0.35))
	_rings["fitness"] = _make_ring(ring_row, "FUERZA", Color(0.52, 0.72, 1.0))

	_drive_label = Label.new()
	_drive_label.anchor_left = 0.30
	_drive_label.anchor_right = 0.70
	_drive_label.anchor_top = 0.08
	_drive_label.anchor_bottom = 0.14
	_drive_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_drive_label.add_theme_font_size_override("font_size", 20)
	_drive_label.add_theme_color_override("font_color", Color(0.93, 0.97, 0.98))
	add_child(_drive_label)
	_drive_label.visible = false

	_nitro_label = Label.new()
	_nitro_label.text = "NITRO"
	_nitro_label.anchor_left = 0.42
	_nitro_label.anchor_right = 0.58
	_nitro_label.anchor_top = 0.15
	_nitro_label.anchor_bottom = 0.18
	_nitro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nitro_label.add_theme_font_size_override("font_size", 10)
	_nitro_label.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	add_child(_nitro_label)
	_nitro_label.visible = false

	_nitro_bar = ProgressBar.new()
	_nitro_bar.anchor_left = 0.40
	_nitro_bar.anchor_right = 0.60
	_nitro_bar.anchor_top = 0.18
	_nitro_bar.anchor_bottom = 0.205
	_nitro_bar.min_value = 0.0
	_nitro_bar.max_value = 100.0
	_nitro_bar.show_percentage = false
	var nitro_bg := StyleBoxFlat.new()
	nitro_bg.bg_color = Color(0.08, 0.12, 0.16, 0.9)
	nitro_bg.set_corner_radius_all(5)
	var nitro_fill := StyleBoxFlat.new()
	nitro_fill.bg_color = Color(0.30, 0.75, 1.0)
	nitro_fill.set_corner_radius_all(5)
	_nitro_bar.add_theme_stylebox_override("background", nitro_bg)
	_nitro_bar.add_theme_stylebox_override("fill", nitro_fill)
	add_child(_nitro_bar)
	_nitro_bar.visible = false

	_prompt_label = Label.new()
	_prompt_label.anchor_left = 0.20
	_prompt_label.anchor_right = 0.80
	_prompt_label.anchor_top = 0.82
	_prompt_label.anchor_bottom = 0.90
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 19)
	_prompt_label.add_theme_color_override("font_color", Color(0.96, 0.99, 0.98))
	add_child(_prompt_label)

	var controls := Label.new()
	controls.text = "RATÓN MIRAR  ·  TAB CURSOR  ·  WASD / FLECHAS MOVER  ·  SHIFT CORRER/NITRO  ·  C + W/S ESCALAR  ·  E INTERACTUAR  ·  G AUTO  ·  R CAMBIAR AUTO  ·  F ENTRAR/SALIR  ·  ESPACIO FRENAR"
	controls.anchor_left = 0.04
	controls.anchor_right = 0.88
	controls.anchor_top = 0.955
	controls.anchor_bottom = 0.99
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_theme_font_size_override("font_size", 9)
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls.add_theme_color_override("font_color", Color(0.82, 0.88, 0.91))
	add_child(controls)

	_settings_button = Button.new()
	_settings_button.text = "⚙"
	_settings_button.tooltip_text = "Configuración"
	_settings_button.custom_minimum_size = Vector2(48, 44)
	_settings_button.anchor_left = 1.0
	_settings_button.anchor_right = 1.0
	_settings_button.anchor_top = 1.0
	_settings_button.anchor_bottom = 1.0
	_settings_button.offset_left = -68.0
	_settings_button.offset_right = -20.0
	_settings_button.offset_top = -64.0
	_settings_button.offset_bottom = -18.0
	_settings_button.add_theme_font_size_override("font_size", 24)
	_settings_button.pressed.connect(_toggle_settings)
	add_child(_settings_button)
	_build_settings_panel()
	_build_victory_panel()


func _build_settings_panel() -> void:
	_settings_panel = PanelContainer.new()
	_settings_panel.anchor_left = 0.34
	_settings_panel.anchor_right = 0.66
	_settings_panel.anchor_top = 0.27
	_settings_panel.anchor_bottom = 0.73
	_settings_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.055, 0.075, 0.98), Color(0.31, 0.85, 0.70)))
	_settings_panel.visible = false
	add_child(_settings_panel)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	_settings_panel.add_child(column)

	var title := Label.new()
	title.text = "⚙  CONFIGURACIÓN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.87, 0.95, 0.96))
	column.add_child(title)

	var volume_title := Label.new()
	volume_title.text = "VOLUMEN GENERAL"
	volume_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(volume_title)
	var volume_slider := HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.01
	volume_slider.value = 0.78
	volume_slider.custom_minimum_size = Vector2(250, 26)
	volume_slider.value_changed.connect(_on_volume_changed)
	column.add_child(volume_slider)
	_on_volume_changed(volume_slider.value)

	var resume := Button.new()
	resume.text = "VOLVER AL JUEGO"
	resume.custom_minimum_size = Vector2(210, 40)
	resume.pressed.connect(_close_settings)
	column.add_child(resume)
	var quit := Button.new()
	quit.text = "SALIR DEL JUEGO"
	quit.custom_minimum_size = Vector2(210, 40)
	quit.pressed.connect(func() -> void:
		get_tree().paused = false
		get_tree().quit()
	)
	column.add_child(quit)


func _build_victory_panel() -> void:
	_victory_panel = PanelContainer.new()
	_victory_panel.anchor_left = 0.25
	_victory_panel.anchor_right = 0.75
	_victory_panel.anchor_top = 0.30
	_victory_panel.anchor_bottom = 0.70
	_victory_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.95, 0.97, 0.94, 0.97), Color(0.28, 0.83, 0.70)))
	_victory_panel.visible = false
	add_child(_victory_panel)
	var victory_column := VBoxContainer.new()
	victory_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_victory_panel.add_child(victory_column)
	var victory_title := Label.new()
	victory_title.text = "¡DÍA COMPLETADO!"
	victory_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	victory_title.add_theme_font_size_override("font_size", 32)
	victory_title.add_theme_color_override("font_color", Color(0.08, 0.30, 0.25))
	victory_column.add_child(victory_title)
	var victory_text := Label.new()
	victory_text.text = "Reuniste todos los cristales de bienestar.\n¡Buen trabajo!"
	victory_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	victory_text.add_theme_color_override("font_color", Color(0.13, 0.20, 0.22))
	victory_column.add_child(victory_text)
	var restart := Button.new()
	restart.text = "JUGAR DE NUEVO"
	restart.pressed.connect(func() -> void:
		get_tree().paused = false
		get_tree().reload_current_scene()
	)
	victory_column.add_child(restart)


func _toggle_settings() -> void:
	if _settings_open:
		_close_settings()
	else:
		_settings_open = true
		_settings_panel.visible = true
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _close_settings() -> void:
	_settings_open = false
	_settings_panel.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_volume_changed(value: float) -> void:
	get_tree().call_group("audio_manager", "set_master_volume", value)


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		if _settings_open:
			_close_settings()
		else:
			_toggle_settings()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("toggle_cursor") and not _settings_open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return



func _make_stat_row(parent: Node, label_text: String, fill_color: Color) -> ProgressBar:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(100, 18)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.79, 0.86, 0.89))
	row.add_child(label)
	var bar := ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(150, 15)
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.show_percentage = false
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.13, 0.18, 0.21)
	background.set_corner_radius_all(7)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(7)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
	return bar


func _make_ring(parent: Node, label_text: String, tint: Color) -> GymLifeStatRing:
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 0)
	parent.add_child(column)
	var ring := STAT_RING_SCRIPT.new() as GymLifeStatRing
	ring.ring_color = tint
	column.add_child(ring)
	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color(0.79, 0.86, 0.89))
	column.add_child(label)
	return ring


func update_stats(hunger: float, energy: float, happiness: float, fitness: float) -> void:
	_animate_bar("hunger", hunger)
	_animate_bar("energy", energy)
	_animate_bar("happiness", happiness)
	_animate_bar("fitness", fitness)
	if _rings.has("energy"):
		(_rings["energy"] as GymLifeStatRing).set_progress(energy)
		(_rings["hunger"] as GymLifeStatRing).set_progress(hunger)
		(_rings["fitness"] as GymLifeStatRing).set_progress(fitness)


func _animate_bar(key: String, target: float) -> void:
	if not _bars.has(key):
		return
	if _bar_tweens.has(key):
		var previous: Tween = _bar_tweens[key]
		if previous != null and previous.is_running():
			previous.kill()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_bars[key], "value", clampf(target, 0.0, 100.0), 0.24)
	_bar_tweens[key] = tween


func set_prompt(message: String) -> void:
	if is_instance_valid(_prompt_label):
		_prompt_label.text = message


func set_clock(_hours: float, clock_text: String) -> void:
	if not is_instance_valid(_clock_label):
		return
	var hour: int = int(clock_text.substr(0, 2))
	var phase: String = "DÍA" if hour >= 7 and hour < 19 else "NOCHE"
	_clock_label.text = "%s  /  %s" % [clock_text, phase]


func set_crystals(total: int, maximum: int) -> void:
	if is_instance_valid(_crystal_label):
		_crystal_label.text = "CRISTALES  %d / %d" % [total, maximum]
	if total >= maximum and maximum > 0:
		_victory_panel.visible = true


func set_driving(active: bool) -> void:
	_drive_label.visible = active
	_nitro_label.visible = active
	_nitro_bar.visible = active
	if active:
		_drive_label.text = "CONDUCIENDO  ·  0 km/h"
	else:
		_drive_label.text = ""
		_nitro_bar.value = 0.0


func set_drive_speed(speed_kmh: float, maximum_kmh: float = 0.0, speed_class: String = "", nitro_percent: float = 0.0) -> void:
	if not _drive_label.visible:
		return
	if maximum_kmh > 0.0:
		_drive_label.text = "CONDUCIENDO  ·  %.0f / %.0f km/h  ·  %s" % [speed_kmh, maximum_kmh, speed_class]
	else:
		_drive_label.text = "CONDUCIENDO  ·  %.0f km/h" % speed_kmh
	if is_instance_valid(_nitro_bar):
		_nitro_bar.value = clampf(nitro_percent, 0.0, 100.0)
