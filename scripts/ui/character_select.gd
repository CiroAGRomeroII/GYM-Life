extends Control
class_name GymLifeCharacterSelect

signal character_confirmed(character_id: String)

const CHARACTER_DATA := {
    "male": {
        "name": "ALEX RIVERA",
        "age": "24 AÑOS",
        "description": "Explorador urbano, constante y competitivo. Busca equilibrio entre entrenamiento y vida social.",
        "strength": 68.0,
        "stamina": 74.0,
        "discipline": 61.0,
        "palette": [Color("#2D6A8A"), Color("#57A5B8"), Color("#D6E4E8"), Color("#E7A85B"), Color("#18242C")]
    },
    "female": {
        "name": "SOFÍA TORRES",
        "age": "23 AÑOS",
        "description": "Activa, creativa y sociable. Disfruta descubrir la ciudad y superar nuevos objetivos físicos.",
        "strength": 61.0,
        "stamina": 86.0,
        "discipline": 79.0,
        "palette": [Color("#B76E79"), Color("#E9A3A8"), Color("#F1D8C8"), Color("#6F8F7A"), Color("#252B32")]
    }
}
const MODEL_PATHS := {
    "male": "res://assets/characters/male/Superhero_Male_FullBody.gltf",
    "female": "res://assets/characters/female/Superhero_Female_FullBody.gltf"
}

var _character_ids: Array[String] = ["male", "female"]
var _selected_index: int = 1
var _name_label: Label
var _age_label: Label
var _description_label: Label
var _strength_bar: ProgressBar
var _stamina_bar: ProgressBar
var _discipline_bar: ProgressBar
var _palette_row: HBoxContainer
var _selected_label: Label
var _previous_button: Button
var _next_button: Button
var _preview_worlds: Array[Node3D] = []


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _build_interface()
    _select_index(_selected_index)


func _build_interface() -> void:
    var backdrop := ColorRect.new()
    backdrop.color = Color(0.015, 0.025, 0.038, 1.0)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(backdrop)

    var glow := ColorRect.new()
    glow.color = Color(0.08, 0.16, 0.20, 0.24)
    glow.anchor_left = 0.0
    glow.anchor_right = 1.0
    glow.anchor_top = 0.72
    glow.anchor_bottom = 1.0
    add_child(glow)

    var window := PanelContainer.new()
    window.anchor_left = 0.045
    window.anchor_right = 0.955
    window.anchor_top = 0.055
    window.anchor_bottom = 0.945
    window.add_theme_stylebox_override("panel", _window_style())
    add_child(window)

    var outer := VBoxContainer.new()
    outer.add_theme_constant_override("separation", 0)
    window.add_child(outer)

    var title_bar := PanelContainer.new()
    title_bar.custom_minimum_size.y = 42.0
    title_bar.add_theme_stylebox_override("panel", _titlebar_style())
    outer.add_child(title_bar)

    var title_row := HBoxContainer.new()
    title_row.alignment = BoxContainer.ALIGNMENT_CENTER
    title_bar.add_child(title_row)

    var app_mark := Label.new()
    app_mark.text = "◆"
    app_mark.add_theme_color_override("font_color", Color("#2B8E87"))
    app_mark.add_theme_font_size_override("font_size", 17)
    title_row.add_child(app_mark)

    var app_title := Label.new()
    app_title.text = "  GYM LIFE  /  CHARACTER TERMINAL"
    app_title.add_theme_font_size_override("font_size", 13)
    app_title.add_theme_color_override("font_color", Color("#17252A"))
    title_row.add_child(app_title)

    var title_spacer := Control.new()
    title_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title_row.add_child(title_spacer)

    for dot_color in [Color("#D96B65"), Color("#D7B35B"), Color("#6DAB88")]:
        var dot := ColorRect.new()
        dot.color = dot_color
        dot.custom_minimum_size = Vector2(11, 11)
        title_row.add_child(dot)

    var content := VBoxContainer.new()
    content.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 10)
    content.add_theme_constant_override("margin_left", 16)
    content.add_theme_constant_override("margin_right", 16)
    content.add_theme_constant_override("margin_top", 13)
    content.add_theme_constant_override("margin_bottom", 13)
    outer.add_child(content)

    var heading := HBoxContainer.new()
    heading.alignment = BoxContainer.ALIGNMENT_CENTER
    content.add_child(heading)
    var heading_column := VBoxContainer.new()
    heading_column.alignment = BoxContainer.ALIGNMENT_CENTER
    heading.add_child(heading_column)

    var headline := Label.new()
    headline.text = "ELIGE QUIÉN VAS A SER"
    headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    headline.add_theme_font_size_override("font_size", 25)
    headline.add_theme_color_override("font_color", Color("#E9F1EF"))
    heading_column.add_child(headline)

    var subtitle := Label.new()
    subtitle.text = "Personaliza tu inicio y construye tu rutina en la ciudad."
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 13)
    subtitle.add_theme_color_override("font_color", Color("#93A8A9"))
    heading_column.add_child(subtitle)

    var body := HBoxContainer.new()
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body.add_theme_constant_override("separation", 14)
    content.add_child(body)

    var left_panel := PanelContainer.new()
    left_panel.custom_minimum_size.x = 360.0
    left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    left_panel.add_theme_stylebox_override("panel", _card_style(Color("#151F27"), Color("#53616A")))
    body.add_child(left_panel)

    var info := VBoxContainer.new()
    info.add_theme_constant_override("separation", 9)
    left_panel.add_child(info)

    var identity_header := Label.new()
    identity_header.text = "PERFIL DEL PERSONAJE"
    identity_header.add_theme_font_size_override("font_size", 11)
    identity_header.add_theme_color_override("font_color", Color("#79BFB1"))
    info.add_child(identity_header)

    _name_label = Label.new()
    _name_label.text = "SOFÍA TORRES"
    _name_label.add_theme_font_size_override("font_size", 26)
    _name_label.add_theme_color_override("font_color", Color("#F4F6F2"))
    info.add_child(_name_label)

    _age_label = Label.new()
    _age_label.add_theme_font_size_override("font_size", 13)
    _age_label.add_theme_color_override("font_color", Color("#B8C8C8"))
    info.add_child(_age_label)

    _description_label = Label.new()
    _description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _description_label.custom_minimum_size.y = 75.0
    _description_label.add_theme_font_size_override("font_size", 13)
    _description_label.add_theme_color_override("font_color", Color("#D3DEDA"))
    info.add_child(_description_label)

    var divider := HSeparator.new()
    info.add_child(divider)

    var stats_header := Label.new()
    stats_header.text = "ESTADÍSTICAS BASE"
    stats_header.add_theme_font_size_override("font_size", 11)
    stats_header.add_theme_color_override("font_color", Color("#79BFB1"))
    info.add_child(stats_header)

    _strength_bar = _make_stat_bar(info, "FUERZA", Color("#E6A85B"))
    _stamina_bar = _make_stat_bar(info, "RESISTENCIA", Color("#5CBBA5"))
    _discipline_bar = _make_stat_bar(info, "DISCIPLINA", Color("#79A9D9"))

    var selector_row := HBoxContainer.new()
    selector_row.add_theme_constant_override("separation", 8)
    info.add_child(selector_row)

    _previous_button = Button.new()
    _previous_button.text = "‹  ANTERIOR"
    _previous_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _previous_button.pressed.connect(_select_previous)
    selector_row.add_child(_previous_button)

    _next_button = Button.new()
    _next_button.text = "SIGUIENTE  ›"
    _next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _next_button.pressed.connect(_select_next)
    selector_row.add_child(_next_button)

    _selected_label = Label.new()
    _selected_label.text = "PERSONAJE 02 / 02"
    _selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _selected_label.add_theme_font_size_override("font_size", 10)
    _selected_label.add_theme_color_override("font_color", Color("#8FA6A5"))
    info.add_child(_selected_label)

    var right_panel := PanelContainer.new()
    right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    right_panel.add_theme_stylebox_override("panel", _card_style(Color("#10171D"), Color("#53616A")))
    body.add_child(right_panel)

    var previews := HBoxContainer.new()
    previews.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    previews.size_flags_vertical = Control.SIZE_EXPAND_FILL
    previews.add_theme_constant_override("separation", 10)
    right_panel.add_child(previews)

    var full_card := _make_preview_card(previews, "VISTA COMPLETA", Vector2i(390, 440), Vector3(2.1, 2.1, 4.5), Vector3(0.0, 0.95, 0.0), Vector2(330, 390))
    var portrait_card := _make_preview_card(previews, "RETRATO", Vector2i(260, 340), Vector3(0.0, 1.65, 3.2), Vector3(0.0, 1.55, 0.0), Vector2(230, 310))
    _preview_worlds.append(full_card)
    _preview_worlds.append(portrait_card)

    var palette_panel := PanelContainer.new()
    palette_panel.custom_minimum_size.y = 70.0
    palette_panel.add_theme_stylebox_override("panel", _card_style(Color("#151F27"), Color("#53616A")))
    content.add_child(palette_panel)

    var palette_content := HBoxContainer.new()
    palette_content.alignment = BoxContainer.ALIGNMENT_CENTER
    palette_content.add_theme_constant_override("separation", 14)
    palette_panel.add_child(palette_content)

    var palette_title := Label.new()
    palette_title.text = "PALETA PERSONAL"
    palette_title.add_theme_font_size_override("font_size", 11)
    palette_title.add_theme_color_override("font_color", Color("#79BFB1"))
    palette_content.add_child(palette_title)

    _palette_row = HBoxContainer.new()
    _palette_row.add_theme_constant_override("separation", 7)
    palette_content.add_child(_palette_row)

    var footer_spacer := Control.new()
    footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    palette_content.add_child(footer_spacer)

    var start_button := Button.new()
    start_button.text = "COMENZAR A VIVIR  →"
    start_button.custom_minimum_size = Vector2(240, 44)
    start_button.add_theme_color_override("font_color", Color("#10201F"))
    start_button.add_theme_color_override("font_hover_color", Color("#10201F"))
    start_button.add_theme_stylebox_override("normal", _accent_button_style())
    start_button.add_theme_stylebox_override("hover", _accent_button_style(Color("#9CE2D0")))
    start_button.pressed.connect(func() -> void:
        character_confirmed.emit(_character_ids[_selected_index])
    )
    palette_content.add_child(start_button)


func _window_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#0D141B")
    style.border_color = Color("#E8EFED")
    style.set_border_width_all(2)
    style.set_corner_radius_all(4)
    style.content_margin_left = 7.0
    style.content_margin_right = 7.0
    style.content_margin_top = 7.0
    style.content_margin_bottom = 7.0
    return style


func _titlebar_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#E6ECE8")
    style.set_corner_radius_all(0)
    style.content_margin_left = 12.0
    style.content_margin_right = 12.0
    style.content_margin_top = 4.0
    style.content_margin_bottom = 4.0
    return style


func _card_style(background: Color, border: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = border
    style.set_border_width_all(1)
    style.set_corner_radius_all(7)
    style.content_margin_left = 12.0
    style.content_margin_right = 12.0
    style.content_margin_top = 12.0
    style.content_margin_bottom = 12.0
    return style


func _accent_button_style(color: Color = Color("#79D5BE")) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.set_corner_radius_all(6)
    style.content_margin_left = 15.0
    style.content_margin_right = 15.0
    style.content_margin_top = 8.0
    style.content_margin_bottom = 8.0
    return style


func _make_stat_bar(parent: Node, label_text: String, tint: Color) -> ProgressBar:
    var row := HBoxContainer.new()
    parent.add_child(row)
    var label := Label.new()
    label.text = label_text
    label.custom_minimum_size.x = 105.0
    label.add_theme_font_size_override("font_size", 10)
    label.add_theme_color_override("font_color", Color("#B7C5C3"))
    row.add_child(label)

    var bar := ProgressBar.new()
    bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bar.custom_minimum_size.y = 12.0
    bar.min_value = 0.0
    bar.max_value = 100.0
    bar.show_percentage = false
    var background := StyleBoxFlat.new()
    background.bg_color = Color("#26333A")
    background.set_corner_radius_all(6)
    var fill := StyleBoxFlat.new()
    fill.bg_color = tint
    fill.set_corner_radius_all(6)
    bar.add_theme_stylebox_override("background", background)
    bar.add_theme_stylebox_override("fill", fill)
    row.add_child(bar)
    return bar


func _make_preview_card(parent: Node, title_text: String, viewport_size: Vector2i, camera_position: Vector3, target: Vector3, minimum: Vector2) -> Node3D:
    var card := PanelContainer.new()
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    card.size_flags_vertical = Control.SIZE_EXPAND_FILL
    card.custom_minimum_size = minimum
    card.add_theme_stylebox_override("panel", _card_style(Color("#0A1015"), Color("#2B3A42")))
    parent.add_child(card)

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 4)
    card.add_child(column)

    var caption := Label.new()
    caption.text = title_text
    caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    caption.add_theme_font_size_override("font_size", 10)
    caption.add_theme_color_override("font_color", Color("#8EAAA7"))
    column.add_child(caption)

    var viewport_container := SubViewportContainer.new()
    viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
    viewport_container.stretch = true
    column.add_child(viewport_container)

    var viewport := SubViewport.new()
    viewport.size = viewport_size
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    viewport.own_world_3d = true
    viewport_container.add_child(viewport)

    var scene_root := Node3D.new()
    scene_root.name = "PreviewWorld"
    viewport.add_child(scene_root)

    var world_environment := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("#101921")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("#D1E3E0")
    environment.ambient_light_energy = 0.85
    world_environment.environment = environment
    scene_root.add_child(world_environment)

    var camera := Camera3D.new()
    camera.position = camera_position
    camera.current = true
    camera.fov = 42.0
    scene_root.add_child(camera)
    camera.look_at(target, Vector3.UP)

    var key_light := DirectionalLight3D.new()
    key_light.rotation_degrees = Vector3(-28.0, -24.0, 0.0)
    key_light.light_energy = 1.7
    key_light.shadow_enabled = true
    scene_root.add_child(key_light)

    var fill_light := OmniLight3D.new()
    fill_light.position = Vector3(-2.2, 2.4, 1.6)
    fill_light.light_color = Color("#73BFB1")
    fill_light.light_energy = 0.55
    fill_light.omni_range = 8.0
    scene_root.add_child(fill_light)

    return scene_root


func _select_previous() -> void:
    _select_index((_selected_index - 1 + _character_ids.size()) % _character_ids.size())


func _select_next() -> void:
    _select_index((_selected_index + 1) % _character_ids.size())


func _select_index(index: int) -> void:
    _selected_index = index
    var character_id: String = _character_ids[_selected_index]
    var data: Dictionary = CHARACTER_DATA[character_id]

    _name_label.text = str(data["name"])
    _age_label.text = str(data["age"])
    _description_label.text = str(data["description"])
    _strength_bar.value = float(data["strength"])
    _stamina_bar.value = float(data["stamina"])
    _discipline_bar.value = float(data["discipline"])
    _selected_label.text = "PERSONAJE %02d / %02d" % [_selected_index + 1, _character_ids.size()]

    for old_swatch in _palette_row.get_children():
        old_swatch.queue_free()
    for color in data["palette"]:
        var swatch := ColorRect.new()
        swatch.color = color
        swatch.custom_minimum_size = Vector2(27, 27)
        _palette_row.add_child(swatch)

    _refresh_previews(character_id)


func _refresh_previews(character_id: String) -> void:
    var path: String = MODEL_PATHS.get(character_id, "")
    var resource: Resource = load(path) if ResourceLoader.exists(path) else null
    for scene_root in _preview_worlds:
        for child in scene_root.get_children():
            if child is Node3D and child.name == "PreviewCharacter":
                child.queue_free()
        if resource is PackedScene:
            var model := (resource as PackedScene).instantiate() as Node3D
            model.name = "PreviewCharacter"
            model.rotation.y = PI
            model.scale = Vector3.ONE * 0.92
            scene_root.add_child(model)
        else:
            _add_fallback_preview(scene_root)


func _add_fallback_preview(parent: Node3D) -> void:
    var mannequin := MeshInstance3D.new()
    var capsule := CapsuleMesh.new()
    capsule.radius = 0.36
    capsule.height = 1.65
    mannequin.mesh = capsule
    mannequin.position.y = 0.85
    var fallback_material := StandardMaterial3D.new()
    fallback_material.albedo_color = Color("#79BFB1")
    mannequin.material_override = fallback_material
    parent.add_child(mannequin)
