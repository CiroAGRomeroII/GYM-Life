extends Node3D
class_name GymLifeDoor

@export_range(0.8, 4.0, 0.1) var door_width: float = 1.8
@export_range(1.8, 3.5, 0.1) var door_height: float = 2.4
@export_range(-140.0, 140.0, 1.0) var open_angle_degrees: float = -100.0
@export var prompt_text: String = "Abrir / cerrar puerta"
@export var door_color: Color = Color(0.30, 0.22, 0.16)
@export var portal_enabled: bool = false
@export var portal_inside_offset: Vector3 = Vector3(0.9, 0.08, -2.8)
@export var portal_outside_offset: Vector3 = Vector3(0.9, 0.08, 2.4)
@export_range(1.2, 3.0, 0.1) var interaction_radius: float = 1.8

var _is_open: bool = false
var _door_leaf: Node3D
var _door_body: AnimatableBody3D
var _door_collision_shape: CollisionShape3D
var _tween: Tween


func _ready() -> void:
    _build_door()
    add_to_group("doors")


func _build_door() -> void:
    # El pivote está en la bisagra izquierda. Solo la hoja rota; las zonas
    # de interacción permanecen fijas a ambos lados del umbral.
    _door_leaf = Node3D.new()
    _door_leaf.name = "DoorLeafPivot"
    add_child(_door_leaf)

    _door_body = AnimatableBody3D.new()
    _door_body.name = "DoorCollisionBody"
    _door_body.collision_layer = 1
    _door_body.collision_mask = 1
    _door_body.sync_to_physics = true
    _door_leaf.add_child(_door_body)

    _door_collision_shape = CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(door_width, door_height, 0.12)
    _door_collision_shape.shape = shape
    _door_collision_shape.position = Vector3(door_width * 0.5, door_height * 0.5, 0.0)
    _door_body.add_child(_door_collision_shape)

    var panel := MeshInstance3D.new()
    panel.name = "DoorPanel"
    var mesh := BoxMesh.new()
    mesh.size = Vector3(door_width, door_height, 0.10)
    panel.mesh = mesh
    panel.position = _door_collision_shape.position
    var panel_material := StandardMaterial3D.new()
    panel_material.albedo_color = door_color
    panel_material.roughness = 0.68
    panel_material.metallic = 0.05
    panel.material_override = panel_material
    _door_leaf.add_child(panel)

    var handle := MeshInstance3D.new()
    var handle_mesh := SphereMesh.new()
    handle_mesh.radius = 0.045
    handle_mesh.height = 0.09
    handle.mesh = handle_mesh
    handle.position = Vector3(door_width - 0.15, door_height * 0.48, -0.07)
    var handle_material := StandardMaterial3D.new()
    handle_material.albedo_color = Color(0.78, 0.68, 0.45)
    handle_material.metallic = 0.82
    handle_material.roughness = 0.25
    handle.material_override = handle_material
    _door_leaf.add_child(handle)

    _add_interaction_zone(
        "OutsideInteraction", Vector3(door_width * 0.5, 1.1, 0.0)
    )
    if portal_enabled:
        _add_interaction_zone(
            "InsideInteraction", portal_inside_offset + Vector3(0.0, 1.02, 0.0)
        )


func _add_interaction_zone(zone_name: String, local_position: Vector3) -> void:
    var area := Area3D.new()
    area.name = zone_name
    area.position = local_position
    area.collision_layer = 2
    area.collision_mask = 0
    area.monitoring = false
    area.monitorable = true
    add_child(area)
    var area_shape := SphereShape3D.new()
    area_shape.radius = interaction_radius
    var area_collision := CollisionShape3D.new()
    area_collision.shape = area_shape
    area.add_child(area_collision)


func _set_door_collision_enabled(enabled: bool) -> void:
    if is_instance_valid(_door_body):
        _door_body.collision_layer = 1 if enabled else 0
        _door_body.collision_mask = 1 if enabled else 0
    if is_instance_valid(_door_collision_shape):
        _door_collision_shape.set_deferred("disabled", not enabled)


func interaction_label() -> String:
    if portal_enabled:
        return "E  Entrar / salir"
    return "Cerrar puerta" if _is_open else prompt_text


func interact(player: Node) -> void:
    if _door_leaf == null:
        return
    _is_open = not _is_open
    if _tween != null and _tween.is_running():
        _tween.kill()

    # La hoja es visual y animada. Su collider se desactiva al abrir para que
    # nunca quede una barrera invisible por desincronización del AnimatableBody3D.
    # Al cerrar, se vuelve a habilitar solamente cuando termina la animación.
    if _is_open:
        _set_door_collision_enabled(false)

    var target_yaw: float = deg_to_rad(open_angle_degrees if _is_open else 0.0)
    _tween = create_tween()
    _tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
    _tween.tween_property(_door_leaf, "rotation:y", target_yaw, 0.42)
    if not _is_open:
        _tween.tween_callback(Callable(self, "_set_door_collision_enabled").bind(true))

    if portal_enabled and player != null and player.has_method("teleport_to"):
        var inside_position: Vector3 = global_transform * portal_inside_offset
        var outside_position: Vector3 = global_transform * portal_outside_offset
        var player_position: Vector3 = (player as Node3D).global_position
        var is_inside: bool = player_position.distance_squared_to(inside_position) < player_position.distance_squared_to(outside_position)
        var destination: Vector3 = outside_position if is_inside else inside_position
        player.call("teleport_to", destination)
