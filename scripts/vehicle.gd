extends CharacterBody3D
class_name GymLifeVehicle

@export_category("Modelo y colisión")
@export_file("*.fbx", "*.gltf", "*.glb") var model_file: String = "res://assets/vehicles/Landyroamer.fbx"
@export_range(-180.0, 180.0, 1.0) var model_yaw_offset_degrees: float = 0.0
@export var body_size: Vector3 = Vector3(2.08, 1.72, 5.05)

@export_category("Conducción")
@export_enum("MÍNIMA", "MEDIA", "MÁXIMA") var speed_class_label: String = "MEDIA"
@export_range(35.0, 220.0, 5.0) var max_speed_kmh: float = 95.0
@export_range(10.0, 70.0, 1.0) var reverse_speed_kmh: float = 26.0
@export_range(1.0, 20.0, 0.5) var acceleration: float = 8.0
@export_range(4.0, 30.0, 0.5) var braking_power: float = 15.0
@export_range(0.5, 8.0, 0.1) var rolling_drag: float = 2.6
@export_range(0.3, 2.5, 0.05) var steering_rate: float = 1.05
@export_range(1.0, 2.0, 0.05) var nitro_multiplier: float = 1.32
@export_range(5.0, 100.0, 1.0) var nitro_drain_per_second: float = 32.0
@export_range(1.0, 50.0, 1.0) var nitro_recharge_per_second: float = 11.0

@onready var body_collision: CollisionShape3D = $CollisionShape3D
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var interaction_area: Area3D = $InteractionArea
@onready var visual: Node3D = $Visual
@onready var engine_audio: AudioStreamPlayer3D = $EngineAudio

# La velocidad se guarda en m/s y se presenta al jugador en km/h.
var speed: float = 0.0
var driver: Node
var nitro_amount: float = 100.0
var _fallback_art: Node3D
var _wheel_nodes: Array[Node3D] = []
var _front_wheels: Array[Node3D] = []
var _cockpit_root: Node3D
var _steering_wheel: Node3D
var _gear_lever: Node3D
var _right_arm: MeshInstance3D
var _right_hand: MeshInstance3D
var _last_gear: int = -99
var _gear_tween: Tween
var _mouse_sensitivity: float = 0.0045
var _look_yaw: float = 0.0
var _look_pitch: float = 0.0
var _impact_cooldown: float = 0.0
var _entry_exit_lock: float = 0.0


func configure_profile(profile: Dictionary) -> void:
	# Se llama antes de entrar al árbol, para que la hitbox nazca con el perfil.
	speed_class_label = str(profile.get("class", "MEDIA"))
	max_speed_kmh = float(profile.get("max_speed_kmh", 95.0))
	reverse_speed_kmh = float(profile.get("reverse_speed_kmh", 26.0))
	acceleration = float(profile.get("acceleration", 8.0))
	braking_power = float(profile.get("braking_power", 15.0))
	rolling_drag = float(profile.get("rolling_drag", 2.6))
	steering_rate = float(profile.get("steering_rate", 1.05))
	var configured_body_size: Variant = profile.get("body_size", body_size)
	if configured_body_size is Vector3:
		body_size = configured_body_size
	nitro_multiplier = float(profile.get("nitro_multiplier", 1.32))


func _ready() -> void:
	add_to_group("vehicles")
	collision_layer = 1
	collision_mask = 1
	floor_snap_length = 0.34
	floor_max_angle = deg_to_rad(48.0)
	safe_margin = 0.035
	floor_stop_on_slope = true
	body_collision.position = Vector3(0.0, body_size.y * 0.5, 0.0)
	var box := BoxShape3D.new()
	box.size = body_size
	body_collision.shape = box
	body_collision.disabled = false

	interaction_area.position = Vector3(0.0, 0.8, 0.0)
	interaction_area.collision_layer = 2
	interaction_area.collision_mask = 0
	interaction_area.monitoring = false
	interaction_area.monitorable = true
	# Cámara colocada en el asiento del conductor, nunca en el centro del modelo.
	camera_pivot.position = Vector3(-0.34, 1.42, 0.20)
	camera_pivot.rotation = Vector3.ZERO
	camera.position = Vector3.ZERO
	camera.fov = 82.0
	camera.near = 0.06
	camera.far = 350.0
	camera.current = false

	_create_fallback_car()
	_load_vehicle_model()
	_create_driver_cockpit()
	_configure_engine_audio()


func _create_fallback_car() -> void:
	_fallback_art = Node3D.new()
	_fallback_art.name = "ProceduralVehicleFallback"
	visual.add_child(_fallback_art)
	var body_material := _material(Color(0.08, 0.34, 0.56), 0.28, 0.32)
	var glass_material := _material(Color(0.08, 0.16, 0.21, 0.88), 0.18, 0.0)
	var tire_material := _material(Color(0.018, 0.022, 0.028), 0.90, 0.0)
	_add_box(_fallback_art, "Body", Vector3(0.0, body_size.y * 0.48, 0.0), Vector3(body_size.x * 0.94, body_size.y * 0.35, body_size.z * 0.94), body_material)
	_add_box(_fallback_art, "Cabin", Vector3(0.0, body_size.y * 0.84, 0.18), Vector3(body_size.x * 0.76, body_size.y * 0.40, body_size.z * 0.43), glass_material)
	_wheel_nodes.clear()
	_front_wheels.clear()
	var wheel_sides: Array[float] = [-1.0, 1.0]
	var wheel_positions: Array[float] = [-1.0, 1.0]
	for side_value in wheel_sides:
		var side: float = side_value
		for longitudinal_value in wheel_positions:
			var longitudinal: float = longitudinal_value
			var wheel := MeshInstance3D.new()
			wheel.name = "Wheel_%s_%s" % [str(side), str(longitudinal)]
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.34
			cylinder.bottom_radius = 0.34
			cylinder.height = 0.22
			wheel.mesh = cylinder
			wheel.position = Vector3(side * body_size.x * 0.50, 0.34, longitudinal * body_size.z * 0.34)
			wheel.rotation.z = PI * 0.5
			wheel.material_override = tire_material
			_fallback_art.add_child(wheel)
			_wheel_nodes.append(wheel)
			if longitudinal < 0.0:
				_front_wheels.append(wheel)


func _load_vehicle_model() -> void:
	if not ResourceLoader.exists(model_file):
		push_warning("No se encontró el modelo de vehículo: " + model_file)
		return
	var resource: Resource = load(model_file)
	if not (resource is PackedScene):
		push_warning("El recurso del vehículo no es una PackedScene: " + model_file)
		return
	var imported_model := (resource as PackedScene).instantiate() as Node3D
	if imported_model == null:
		push_warning("No se pudo instanciar el modelo: " + model_file)
		return
	# Coloca el modelo dentro del árbol antes de consultar transformaciones globales.
	# Esto evita una AABB vacía o incorrecta cuando el FBX tiene nodos anidados.
	var fit_root := Node3D.new()
	fit_root.name = "VehicleRealScaleRoot"
	visual.add_child(fit_root)
	fit_root.add_child(imported_model)
	var raw_bounds: AABB = _get_model_bounds(imported_model)
	if raw_bounds.size.x <= 0.001 or raw_bounds.size.y <= 0.001 or raw_bounds.size.z <= 0.001:
		fit_root.queue_free()
		push_warning("El modelo no tiene una AABB válida: " + model_file)
		return

	# Orienta automáticamente el eje horizontal más largo en Z (frente/atrás).
	var base_yaw: float = deg_to_rad(model_yaw_offset_degrees)
	var yaw_candidates: Array[float] = [base_yaw, base_yaw + PI * 0.5, base_yaw - PI * 0.5, base_yaw + PI]
	var best_yaw: float = base_yaw
	var oriented_bounds: AABB = _transform_model_aabb(raw_bounds, Basis(Vector3.UP, best_yaw))
	var best_ratio: float = oriented_bounds.size.z / maxf(oriented_bounds.size.x, 0.001)
	for candidate_yaw: float in yaw_candidates:
		var candidate_bounds: AABB = _transform_model_aabb(raw_bounds, Basis(Vector3.UP, candidate_yaw))
		var ratio: float = candidate_bounds.size.z / maxf(candidate_bounds.size.x, 0.001)
		if ratio > best_ratio:
			best_ratio = ratio
			best_yaw = candidate_yaw
			oriented_bounds = candidate_bounds

	# Normalización UNIFORME: los modelos conservan sus proporciones originales.
	# Se busca una envolvente de coche real (aprox. 4,4–5,6 m de largo,
	# 1,75–2,35 m de ancho y 1,25–2,15 m de alto) sin estirar cada eje.
	var target_dimensions: Vector3 = body_size
	var fit_x: float = target_dimensions.x / maxf(oriented_bounds.size.x, 0.001)
	var fit_y: float = target_dimensions.y / maxf(oriented_bounds.size.y, 0.001)
	var fit_z: float = target_dimensions.z / maxf(oriented_bounds.size.z, 0.001)
	var uniform_scale: float = clampf(maxf(fit_x, maxf(fit_y, fit_z)), 0.00001, 100000.0)
	var scaled_dimensions: Vector3 = oriented_bounds.size * uniform_scale
	# Limita dimensiones extremas de assets con unidades de exportación erróneas.
	var maximum_correction: float = minf(
		2.35 / maxf(scaled_dimensions.x, 0.001),
		minf(2.15 / maxf(scaled_dimensions.y, 0.001), 5.60 / maxf(scaled_dimensions.z, 0.001))
	)
	uniform_scale *= minf(1.0, maximum_correction)
	scaled_dimensions = oriented_bounds.size * uniform_scale
	# Si el asset es especialmente pequeño, aumenta el conjunto uniformemente,
	# siempre dentro de las dimensiones máximas físicas anteriores.
	var minimum_correction: float = maxf(
		1.0,
		maxf(1.75 / maxf(scaled_dimensions.x, 0.001), maxf(1.25 / maxf(scaled_dimensions.y, 0.001), 4.40 / maxf(scaled_dimensions.z, 0.001)))
	)
	var safe_enlargement: float = minf(
		2.35 / maxf(scaled_dimensions.x, 0.001),
		minf(2.15 / maxf(scaled_dimensions.y, 0.001), 5.60 / maxf(scaled_dimensions.z, 0.001))
	)
	uniform_scale *= minf(minimum_correction, safe_enlargement)
	scaled_dimensions = oriented_bounds.size * uniform_scale

	var bounds_center: Vector3 = Vector3(
		oriented_bounds.position.x + oriented_bounds.size.x * 0.5,
		oriented_bounds.position.y,
		oriented_bounds.position.z + oriented_bounds.size.z * 0.5
	)
	fit_root.scale = Vector3.ONE * uniform_scale
	imported_model.transform = Transform3D(
		Basis(Vector3.UP, best_yaw),
		-bounds_center
	)

	# Hitbox ajustada a la AABB resultante del modelo ya escalado; 2 % de
	# tolerancia para no engancharse en bordillos y accesorios pequeños.
	var fitted_size: Vector3 = scaled_dimensions * 0.98
	var fitted_box := body_collision.shape as BoxShape3D
	if fitted_box == null:
		fitted_box = BoxShape3D.new()
		body_collision.shape = fitted_box
	fitted_box.size = fitted_size
	body_collision.position = Vector3(0.0, fitted_size.y * 0.5, 0.0)
	body_size = fitted_size
	camera_pivot.position = Vector3(-0.34, clampf(fitted_size.y * 0.82, 1.20, 1.55), 0.20)
	_fallback_art.visible = false

func _get_model_bounds(model: Node3D) -> AABB:
	var combined := AABB()
	var found_mesh := false
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var mesh_bounds := mesh_instance.get_aabb()
		var relative_transform := model.global_transform.affine_inverse() * mesh_instance.global_transform
		for corner_index in range(8):
			var corner := Vector3(
				mesh_bounds.position.x + (mesh_bounds.size.x if (corner_index & 1) != 0 else 0.0),
				mesh_bounds.position.y + (mesh_bounds.size.y if (corner_index & 2) != 0 else 0.0),
				mesh_bounds.position.z + (mesh_bounds.size.z if (corner_index & 4) != 0 else 0.0)
			)
			var point := relative_transform * corner
			if not found_mesh:
				combined = AABB(point, Vector3.ZERO)
				found_mesh = true
			else:
				combined = combined.expand(point)
	return combined if found_mesh else AABB()


func _transform_model_aabb(source: AABB, transform_basis: Basis) -> AABB:
	var result := AABB()
	var found_point := false
	for corner_index in range(8):
		var corner := Vector3(
			source.position.x + (source.size.x if (corner_index & 1) != 0 else 0.0),
			source.position.y + (source.size.y if (corner_index & 2) != 0 else 0.0),
			source.position.z + (source.size.z if (corner_index & 4) != 0 else 0.0)
		)
		var point := transform_basis * corner
		if not found_point:
			result = AABB(point, Vector3.ZERO)
			found_point = true
		else:
			result = result.expand(point)
	return result if found_point else AABB()


func _create_driver_cockpit() -> void:
	# Componentes de cabina fijados al chasis: tablero, volante, manos y palanca.
	# La cámara puede girar de forma independiente sin arrastrar el interior.
	_cockpit_root = Node3D.new()
	_cockpit_root.name = "FirstPersonCockpit"
	# El cockpit queda fijo al chasis, no pegado a la cámara: al mirar 360 grados
	# con el ratón el tablero/volante permanecen en su sitio físico.
	add_child(_cockpit_root)
	_cockpit_root.position = camera_pivot.position
	_add_cockpit_box("Dashboard", Vector3(0.0, -0.50, -0.62), Vector3(1.38, 0.20, 0.42), Color(0.055, 0.075, 0.085))
	_add_cockpit_box("InstrumentPanel", Vector3(0.0, -0.39, -0.79), Vector3(0.76, 0.12, 0.08), Color(0.025, 0.12, 0.15))

	_steering_wheel = Node3D.new()
	_steering_wheel.name = "SteeringWheelRig"
	_steering_wheel.position = Vector3(0.0, -0.28, -0.66)
	_cockpit_root.add_child(_steering_wheel)
	var rim := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.18
	torus.outer_radius = 0.225
	torus.rings = 12
	torus.ring_segments = 24
	rim.mesh = torus
	rim.rotation = Vector3.ZERO # plano vertical mirando al conductor
	rim.material_override = _material(Color(0.035, 0.045, 0.05), 0.45, 0.35)
	_steering_wheel.add_child(rim)
	var hub := MeshInstance3D.new()
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = 0.055
	hub_mesh.bottom_radius = 0.055
	hub_mesh.height = 0.08
	hub.mesh = hub_mesh
	hub.rotation.x = PI * 0.5
	hub.material_override = _material(Color(0.12, 0.15, 0.17), 0.35, 0.55)
	_steering_wheel.add_child(hub)

	var sleeve_material := _material(Color(0.10, 0.20, 0.28), 0.85, 0.0)
	var skin_material := _material(Color(0.72, 0.49, 0.34), 0.86, 0.0)
	var cockpit_sides: Array[float] = [-1.0, 1.0]
	for side_value in cockpit_sides:
		var side: float = side_value
		var arm := MeshInstance3D.new()
		var arm_mesh := CapsuleMesh.new()
		arm_mesh.radius = 0.078
		arm_mesh.height = 0.50
		arm.mesh = arm_mesh
		arm.position = Vector3(side * 0.30, -0.22, 0.02)
		arm.rotation.z = side * -0.36
		arm.material_override = sleeve_material
		_steering_wheel.add_child(arm)
		var hand := MeshInstance3D.new()
		var hand_mesh := SphereMesh.new()
		hand_mesh.radius = 0.088
		hand_mesh.height = 0.145
		hand.mesh = hand_mesh
		hand.scale = Vector3(1.17, 0.86, 1.34)
		hand.position = Vector3(side * 0.18, 0.02, -0.005)
		hand.material_override = skin_material
		_steering_wheel.add_child(hand)
		# Dedos cortos y más gruesos envuelven el aro del volante.
		for finger_index in range(3):
			var cockpit_finger := MeshInstance3D.new()
			var cockpit_finger_mesh := CapsuleMesh.new()
			cockpit_finger_mesh.radius = 0.019
			cockpit_finger_mesh.height = 0.095
			cockpit_finger.mesh = cockpit_finger_mesh
			cockpit_finger.position = Vector3(side * 0.18, -0.035 - float(finger_index) * 0.035, -0.065)
			cockpit_finger.rotation.x = -PI * 0.5
			cockpit_finger.material_override = skin_material
			_steering_wheel.add_child(cockpit_finger)
		if side > 0.0:
			_right_arm = arm
			_right_hand = hand

	_add_cockpit_box("GearConsole", Vector3(0.42, -0.54, -0.42), Vector3(0.28, 0.14, 0.32), Color(0.07, 0.085, 0.09))
	_gear_lever = Node3D.new()
	_gear_lever.name = "GearLever"
	_gear_lever.position = Vector3(0.42, -0.43, -0.48)
	_cockpit_root.add_child(_gear_lever)
	var shaft := MeshInstance3D.new()
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.018
	shaft_mesh.bottom_radius = 0.025
	shaft_mesh.height = 0.24
	shaft.mesh = shaft_mesh
	shaft.position.y = 0.12
	shaft.material_override = _material(Color(0.16, 0.18, 0.19), 0.35, 0.65)
	_gear_lever.add_child(shaft)
	var knob := MeshInstance3D.new()
	var knob_mesh := SphereMesh.new()
	knob_mesh.radius = 0.055
	knob_mesh.height = 0.10
	knob.mesh = knob_mesh
	knob.position.y = 0.25
	knob.material_override = _material(Color(0.09, 0.10, 0.11), 0.3, 0.15)
	_gear_lever.add_child(knob)


func _add_cockpit_box(node_name: String, local_position: Vector3, size: Vector3, color: Color) -> void:
	var part := MeshInstance3D.new()
	part.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.position = local_position
	part.material_override = _material(color, 0.55, 0.12)
	_cockpit_root.add_child(part)


func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var surface := StandardMaterial3D.new()
	surface.albedo_color = color
	surface.roughness = roughness
	surface.metallic = metallic
	return surface


func _add_box(parent: Node3D, node_name: String, local_position: Vector3, size: Vector3, surface_material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.position = local_position
	mesh_instance.material_override = surface_material
	parent.add_child(mesh_instance)


func _configure_engine_audio() -> void:
	engine_audio.volume_db = -7.0
	engine_audio.unit_size = 12.0
	engine_audio.max_distance = 45.0
	if ResourceLoader.exists("res://assets/audio/car_engine.wav"):
		var stream := load("res://assets/audio/car_engine.wav")
		if stream is AudioStreamWAV:
			var engine_stream := stream as AudioStreamWAV
			engine_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			if engine_stream.loop_end <= engine_stream.loop_begin:
				var bytes_per_sample: int = 1 if engine_stream.format == AudioStreamWAV.FORMAT_8_BITS else 2
				var channels: int = 2 if engine_stream.stereo else 1
				engine_stream.loop_begin = 0
				engine_stream.loop_end = int(float(engine_stream.data.size()) / float(bytes_per_sample * channels))
			engine_audio.stream = engine_stream


func interaction_label() -> String:
	return "Entrar al vehículo"


func interact(player: Node) -> void:
	enter_driver(player)


func enter_driver(player: Node) -> void:
	if driver != null or player == null:
		return
	driver = player
	_entry_exit_lock = 0.38
	speed = 0.0
	velocity = Vector3.ZERO
	_look_yaw = 0.0
	_look_pitch = 0.0
	if player is Node3D:
		_look_yaw = wrapf((player as Node3D).global_rotation.y - global_rotation.y, -PI, PI)
		var player_pivot := player.get_node_or_null("CameraPivot") as Node3D
		if player_pivot != null:
			_look_pitch = player_pivot.rotation.x
	camera_pivot.rotation = Vector3(_look_pitch, _look_yaw, 0.0)
	camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if driver.has_method("begin_driving"):
		driver.call("begin_driving", self)
	if engine_audio.stream != null and not engine_audio.playing:
		engine_audio.play()
	get_tree().call_group("game_hud", "set_driving", true)
	get_tree().call_group("game_hud", "set_drive_speed", 0.0, max_speed_kmh, speed_class_label, nitro_amount)
	get_tree().call_group("audio_manager", "play_sfx", "engine_start")


func exit_driver() -> void:
	if driver == null:
		return
	if absf(speed) > 1.25:
		get_tree().call_group("game_hud", "set_prompt", "Frena con ESPACIO antes de salir del vehículo.")
		return
	var old_driver: Node = driver
	driver = null
	speed = 0.0
	velocity.x = 0.0
	velocity.z = 0.0
	engine_audio.stop()
	camera.current = false
	var exit_position := _get_safe_exit_position()
	if is_instance_valid(old_driver) and old_driver is Node3D:
		(old_driver as Node3D).global_rotation.y = global_rotation.y + _look_yaw
		var player_pivot := old_driver.get_node_or_null("CameraPivot") as Node3D
		if player_pivot != null:
			player_pivot.rotation.x = _look_pitch
	if is_instance_valid(old_driver) and old_driver.has_method("end_driving"):
		old_driver.call("end_driving", exit_position)
	get_tree().call_group("game_hud", "set_driving", false)
	get_tree().call_group("game_hud", "set_drive_speed", 0.0)


func _get_safe_exit_position() -> Vector3:
	var side := global_transform.basis.x.normalized()
	var candidate := global_position + side * 2.0 + Vector3.UP * 3.0
	var query := PhysicsRayQueryParameters3D.create(candidate, candidate + Vector3.DOWN * 8.0)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		return hit.get("position", global_position) + Vector3.UP * 0.08
	return global_position + side * 2.0 + Vector3.UP * 0.08


func _input(event: InputEvent) -> void:
	if driver == null or get_tree().paused:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mouse_motion := event as InputEventMouseMotion
		# Giro horizontal ilimitado: cámara independiente de la dirección del coche.
		_look_yaw = wrapf(_look_yaw - mouse_motion.relative.x * _mouse_sensitivity, -PI, PI)
		_look_pitch = clampf(
			_look_pitch - mouse_motion.relative.y * _mouse_sensitivity,
			deg_to_rad(-82.0),
			deg_to_rad(82.0)
		)
		camera_pivot.rotation = Vector3(_look_pitch, _look_yaw, 0.0)

func _physics_process(delta: float) -> void:
	var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	if driver == null:
		speed = move_toward(speed, 0.0, rolling_drag * delta)
		var parked_forward := -global_transform.basis.z.normalized()
		velocity.x = move_toward(velocity.x, parked_forward.x * speed, 9.0 * delta)
		velocity.z = move_toward(velocity.z, parked_forward.z * speed, 9.0 * delta)
		move_and_slide()
		return

	if _impact_cooldown > 0.0:
		_impact_cooldown = maxf(0.0, _impact_cooldown - delta)
	if _entry_exit_lock > 0.0:
		_entry_exit_lock = maxf(0.0, _entry_exit_lock - delta)
	else:
		if Input.is_action_just_pressed("enter_vehicle"):
			exit_driver()
			return

	var throttle: float = Input.get_action_strength("move_forward")
	var reverse: float = Input.get_action_strength("move_back")
	var steering: float = Input.get_action_strength("move_left") - Input.get_action_strength("move_right")
	var braking: bool = Input.is_action_pressed("vehicle_brake")
	var nitro_requested: bool = Input.is_action_pressed("nitro") and throttle > 0.05 and nitro_amount > 0.0
	var active_max_kmh: float = max_speed_kmh * (nitro_multiplier if nitro_requested else 1.0)
	var max_forward_mps: float = active_max_kmh / 3.6
	var max_reverse_mps: float = reverse_speed_kmh / 3.6
	# Par recuperable: el primer tramo recibe más par para no quedar arrastrándose
	# al volver a acelerar después de una frenada o una parada completa.
	var speed_ratio_before: float = clampf(absf(speed) / maxf(max_forward_mps, 0.01), 0.0, 1.0)
	var launch_multiplier: float = lerpf(2.10, 1.0, speed_ratio_before)
	var active_acceleration: float = acceleration * launch_multiplier * (1.45 if nitro_requested else 1.0)

	if braking:
		speed = move_toward(speed, 0.0, braking_power * delta)
	elif throttle > 0.05:
		if speed < -0.15:
			speed = move_toward(speed, 0.0, braking_power * delta)
		else:
			speed = move_toward(speed, max_forward_mps, active_acceleration * throttle * delta)
	elif reverse > 0.05:
		if speed > 0.15:
			speed = move_toward(speed, 0.0, braking_power * delta)
		else:
			speed = move_toward(speed, -max_reverse_mps, acceleration * 0.95 * reverse * delta)
	else:
		# Rodadura: suficiente para desacelerar al soltar el acelerador,
		# pero sin arrastrar el coche tras una parada o una nueva aceleración.
		var coast_drag: float = maxf(0.22, rolling_drag * 0.10) + 0.0018 * speed * speed
		speed = move_toward(speed, 0.0, coast_drag * delta)
	if absf(speed) < 0.035:
		speed = 0.0

	if nitro_requested and not braking:
		nitro_amount = maxf(0.0, nitro_amount - nitro_drain_per_second * delta)
	else:
		nitro_amount = minf(100.0, nitro_amount + nitro_recharge_per_second * delta)

	var speed_ratio: float = clampf(absf(speed) / maxf(max_forward_mps, 0.01), 0.0, 1.0)
	if absf(speed) > 0.25:
		var steering_factor: float = lerpf(1.0, 0.36, speed_ratio)
		rotation.y += steering * steering_rate * steering_factor * signf(speed) * delta

	var forward := -global_transform.basis.z.normalized()
	var desired_velocity: Vector3 = forward * speed
	# La velocidad longitudinal es la autoridad del tren motriz; evitar un segundo
	# suavizado sobre velocity elimina el efecto de salida lenta tras detenerse.
	velocity.x = desired_velocity.x
	velocity.z = desired_velocity.z
	move_and_slide()

	for wheel in _wheel_nodes:
		wheel.rotate_object_local(Vector3.UP, -speed * delta / 0.34)
	for front_wheel in _front_wheels:
		front_wheel.rotation.y = -steering * 0.34
	if is_instance_valid(_steering_wheel):
		_steering_wheel.rotation.z = -steering * 0.62

	var current_gear: int = -1 if speed < -0.5 else (0 if absf(speed) < 0.5 else int(floor(absf(speed) / 9.0)) + 1)
	if current_gear != _last_gear:
		_last_gear = current_gear
		_animate_gear_shift()

	# No penalizar el contacto normal con el suelo: CharacterBody3D suele
	# reportarlo como slide collision en todos los fotogramas. La versión
	# anterior multiplicaba la velocidad por 0.60 incluso al rodar sobre una
	# superficie plana, dejando el coche casi sin aceleración al reanudar.
	# Solo reducimos velocidad ante un impacto frontal real.
	if absf(speed) > 2.0 and _impact_cooldown <= 0.0:
		var travel_direction: Vector3 = -global_transform.basis.z.normalized() * signf(speed)
		for collision_index in range(get_slide_collision_count()):
			var slide_collision: KinematicCollision3D = get_slide_collision(collision_index)
			var collision_normal: Vector3 = slide_collision.get_normal()
			if collision_normal.y >= 0.55:
				continue # suelo y rampas no son impactos contra la carrocería
			var horizontal_normal := Vector3(collision_normal.x, 0.0, collision_normal.z)
			if horizontal_normal.length_squared() < 0.01:
				continue
			var closing_speed: float = travel_direction.dot(-horizontal_normal.normalized())
			if closing_speed > 0.30:
				speed = signf(speed) * maxf(0.0, absf(speed) * 0.78 - 0.75)
				_impact_cooldown = 0.32
				velocity.x = -global_transform.basis.z.x * speed
				velocity.z = -global_transform.basis.z.z * speed
				break

	if engine_audio.stream != null:
		# El motor permanece en ralentí mientras hay conductor y sube de tono
		# según las RPM simuladas; al salir del auto se detiene en exit_driver().
		if not engine_audio.playing:
			engine_audio.play()
		engine_audio.pitch_scale = lerpf(0.82, 1.58, speed_ratio) + (0.18 if nitro_requested else 0.0)
	get_tree().call_group("game_hud", "set_drive_speed", absf(speed) * 3.6, active_max_kmh, speed_class_label, nitro_amount)


func _animate_gear_shift() -> void:
	if _gear_tween != null and _gear_tween.is_running():
		_gear_tween.kill()
	_gear_tween = create_tween()
	if is_instance_valid(_right_hand) and is_instance_valid(_right_arm):
		# La mano derecha deja el volante, acciona la palanca y vuelve al aro.
		_gear_tween.tween_property(_right_hand, "position", Vector3(0.42, 0.06, 0.22), 0.11)
		_gear_tween.parallel().tween_property(_right_arm, "position", Vector3(0.31, -0.04, 0.13), 0.11)
	if is_instance_valid(_gear_lever):
		_gear_tween.tween_property(_gear_lever, "rotation:x", -0.16, 0.08)
		_gear_tween.tween_property(_gear_lever, "rotation:x", 0.0, 0.14)
	if is_instance_valid(_right_hand) and is_instance_valid(_right_arm):
		_gear_tween.tween_property(_right_hand, "position", Vector3(0.18, 0.02, -0.005), 0.16)
		_gear_tween.parallel().tween_property(_right_arm, "position", Vector3(0.30, -0.22, 0.02), 0.16)
