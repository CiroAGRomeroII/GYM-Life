extends Node3D
class_name GymLifeGym


func _ready() -> void:
	_build_room()
	_build_equipment()


func _material(color: Color, rough: float = 0.75, metal: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	mat.metallic = metal
	return mat


func _add_solid_box(node_name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 1
	body.name = node_name
	body.position = pos
	add_child(body)
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = _material(color)
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)


func _build_room() -> void:
	_add_solid_box("GymFloor", Vector3(0, -0.15, 0), Vector3(18.0, 0.3, 14.0), Color(0.13, 0.16, 0.19))
	_add_solid_box("BackWall", Vector3(0, 3.0, -7.0), Vector3(18.0, 6.0, 0.3), Color(0.08, 0.12, 0.17))
	_add_solid_box("LeftWall", Vector3(-9.0, 3.0, 0), Vector3(0.3, 6.0, 14.0), Color(0.11, 0.15, 0.19))
	_add_solid_box("RightWall", Vector3(9.0, 3.0, 0), Vector3(0.3, 6.0, 14.0), Color(0.11, 0.15, 0.19))
	# Hueco de acceso centrado de 3.8 m: deja holgura real para la cápsula
	# del jugador incluso al acercarse en diagonal a la puerta.
	_add_solid_box("FrontLeft", Vector3(-5.45, 3.0, 7.0), Vector3(7.1, 6.0, 0.3), Color(0.10, 0.14, 0.18))
	_add_solid_box("FrontRight", Vector3(5.45, 3.0, 7.0), Vector3(7.1, 6.0, 0.3), Color(0.10, 0.14, 0.18))
	_add_solid_box("RoofBeam", Vector3(0, 5.9, -1.2), Vector3(18.0, 0.25, 11.6), Color(0.055, 0.075, 0.09))

	var entry_door := Node3D.new()
	entry_door.name = "GymEntryDoor"
	entry_door.set_script(load("res://scripts/interactions/door.gd"))
	entry_door.set("door_width", 3.6)
	entry_door.set("door_height", 2.55)
	entry_door.set("prompt_text", "Abrir / cerrar entrada del gimnasio")
	entry_door.set("open_angle_degrees", -105.0)
	entry_door.position = Vector3(-1.8, 0.0, 6.82)
	add_child(entry_door)

	var gym_sign := Label3D.new()
	gym_sign.text = "GYM LIFE  |  ENTRENA Y DISFRUTA"
	gym_sign.font_size = 44
	gym_sign.modulate = Color(0.45, 0.96, 0.76)
	gym_sign.position = Vector3(0, 4.6, 7.12)
	gym_sign.rotation.y = PI
	add_child(gym_sign)

	var light := OmniLight3D.new()
	light.position = Vector3(0, 4.5, 0)
	light.light_energy = 1.35
	light.omni_range = 25.0
	light.light_color = Color(0.82, 0.94, 1.0)
	add_child(light)


func _spawn_machine(label_text: String, file_name: String, machine_position: Vector3, scale_value: float, gain: float, fallback_color: Color) -> void:
	var model_root := Node3D.new()
	model_root.name = file_name.get_basename()
	model_root.position = machine_position
	model_root.scale = Vector3.ONE * scale_value
	add_child(model_root)

	var asset_path := "res://assets/gym/FBX/%s" % file_name
	var packed := load(asset_path)
	if packed is PackedScene:
		model_root.add_child((packed as PackedScene).instantiate())
	else:
		_add_fallback_machine(model_root, fallback_color)

	# Los modelos importados son visuales: este volumen simple evita atravesar
	# las máquinas sin depender de colisiones internas del FBX.
	var blocker := StaticBody3D.new()
	blocker.name = "Blocker_" + file_name.get_basename()
	blocker.position = machine_position + Vector3(0.0, 0.68, 0.0)
	blocker.collision_layer = 1
	blocker.collision_mask = 1
	add_child(blocker)
	var blocker_shape := CollisionShape3D.new()
	var blocker_box := BoxShape3D.new()
	blocker_box.size = Vector3(1.8, 1.35, 1.7)
	blocker_shape.shape = blocker_box
	blocker.add_child(blocker_shape)

	var area := Area3D.new()
	area.name = "Use_" + label_text.replace(" ", "")
	area.position = machine_position + Vector3(0, 0.9, 0)
	area.collision_layer = 2
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	area.set_script(load("res://scripts/gym_machine.gd"))
	area.call("setup", label_text, gain)
	var detection := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.65
	detection.shape = sphere
	area.add_child(detection)
	add_child(area)

	var tag := Label3D.new()
	tag.text = label_text
	tag.font_size = 26
	tag.modulate = Color(0.87, 0.97, 1.0)
	tag.position = machine_position + Vector3(0, 2.4, 0)
	add_child(tag)


func _add_fallback_machine(parent: Node3D, color: Color) -> void:
	var mat := _material(color, 0.38, 0.55)
	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(1.6, 0.2, 1.4)
	base.mesh = base_mesh
	base.position.y = 0.18
	base.material_override = mat
	parent.add_child(base)
	var post := MeshInstance3D.new()
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.18, 1.5, 0.18)
	post.mesh = post_mesh
	post.position = Vector3(0, 0.95, -0.35)
	post.material_override = mat
	parent.add_child(post)
	var bar := MeshInstance3D.new()
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(1.9, 0.12, 0.12)
	bar.mesh = bar_mesh
	bar.position = Vector3(0, 1.7, -0.35)
	bar.material_override = mat
	parent.add_child(bar)


func _build_equipment() -> void:
	_spawn_machine("Cinta de correr", "Treadmill_1_Main.fbx", Vector3(-5.6, 0.0, -2.5), 1.0, 7.0, Color(0.22, 0.45, 0.58))
	_spawn_machine("Press de banca", "Bench_Press.fbx", Vector3(0.0, 0.0, -2.5), 1.0, 9.0, Color(0.28, 0.32, 0.38))
	_spawn_machine("Mancuernas", "Dumbbells_1.fbx", Vector3(5.2, 0.0, -2.0), 1.0, 6.0, Color(0.54, 0.58, 0.62))
	_spawn_machine("Bicicleta", "Exercise_Bike.fbx", Vector3(-5.2, 0.0, 2.2), 1.0, 8.0, Color(0.24, 0.42, 0.48))
	_spawn_machine("Polea", "PullDown_Ac_1.fbx", Vector3(0.0, 0.0, 2.3), 1.0, 10.0, Color(0.35, 0.40, 0.48))
	_spawn_machine("Remo", "Stationary_Rowing_Machine.fbx", Vector3(5.2, 0.0, 2.2), 1.0, 8.0, Color(0.22, 0.38, 0.42))


func _add_teleporter(node_name: String, pos: Vector3, destination: Vector3, label_text: String) -> void:
	var area := Area3D.new()
	area.name = node_name
	area.position = pos
	area.collision_layer = 2
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	area.set_script(load("res://scripts/teleport_area.gd"))
	area.call("setup", destination, label_text)
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.8
	collision.shape = shape
	area.add_child(collision)
	add_child(area)


func _build_teleporters() -> void:
	_add_teleporter("GymEntrance", Vector3(0, 0.9, 8.5), global_position + Vector3(0, 0.1, 4.5), "Entrar al gimnasio")
	_add_teleporter("GymExit", Vector3(0, 0.9, 5.2), global_position + Vector3(0, 0.1, 10.5), "Salir del gimnasio")
