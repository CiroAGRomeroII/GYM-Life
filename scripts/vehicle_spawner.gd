extends Node3D
class_name GymLifeVehicleSpawner

const VEHICLE_SCENE: PackedScene = preload("res://scenes/vehicle.tscn")
const INVALID_POSITION: Vector3 = Vector3(0.0, -10000.0, 0.0)
const SPAWN_CLEARANCE_SIZE: Vector3 = Vector3(3.10, 2.45, 6.10)

# Velocidades máximas expresadas en km/h. La física del vehículo convierte
# estos valores a m/s antes de mover el CharacterBody3D.
const VEHICLE_CATALOG: Array[Dictionary] = [
	{
		"label": "Landyroamer",
		"file": "res://assets/vehicles/Landyroamer.fbx",
		"yaw": 0.0,
		"class": "MÍNIMA",
		"body_size": Vector3(2.08, 1.92, 5.10),
		"nitro_multiplier": 1.28,
		"max_speed_kmh": 55.0,
		"reverse_speed_kmh": 18.0,
		"acceleration": 4.8,
		"braking_power": 13.0,
		"rolling_drag": 3.0,
		"steering_rate": 1.25
	},
	{
		"label": "Beatall",
		"file": "res://assets/vehicles/Beatall.fbx",
		"yaw": 0.0,
		"class": "MEDIA",
		"body_size": Vector3(2.06, 1.68, 4.90),
		"nitro_multiplier": 1.32,
		"max_speed_kmh": 95.0,
		"reverse_speed_kmh": 28.0,
		"acceleration": 8.0,
		"braking_power": 15.0,
		"rolling_drag": 2.8,
		"steering_rate": 1.12
	},
	{
		"label": "Tristar Racer",
		"file": "res://assets/vehicles/Tristar Racer.fbx",
		"yaw": 180.0,
		"class": "MÁXIMA",
		"body_size": Vector3(2.12, 1.48, 5.15),
		"nitro_multiplier": 1.38,
		"max_speed_kmh": 185.0,
		"reverse_speed_kmh": 42.0,
		"acceleration": 15.0,
		"braking_power": 20.0,
		"rolling_drag": 2.2,
		"steering_rate": 0.92
	},
	{
		"label": "Toyoyo",
		"file": "res://assets/vehicles/Toyoyo Highlight.fbx",
		"yaw": 0.0,
		"class": "MEDIA",
		"body_size": Vector3(2.02, 1.72, 4.92),
		"nitro_multiplier": 1.32,
		"max_speed_kmh": 110.0,
		"reverse_speed_kmh": 30.0,
		"acceleration": 8.8,
		"braking_power": 16.0,
		"rolling_drag": 2.6,
		"steering_rate": 1.08
	},
	{
		"label": "DocLorean",
		"file": "res://assets/vehicles/docLorean.fbx",
		"yaw": 180.0,
		"class": "MÁXIMA",
		"body_size": Vector3(2.08, 1.55, 5.00),
		"nitro_multiplier": 1.36,
		"max_speed_kmh": 165.0,
		"reverse_speed_kmh": 38.0,
		"acceleration": 12.5,
		"braking_power": 18.0,
		"rolling_drag": 2.3,
		"steering_rate": 0.98
	}
]

@export_range(1, 8, 1) var maximum_live_vehicles: int = 4
@export_range(3.0, 12.0, 0.5) var spawn_distance: float = 7.8

var selected_index: int = 0
var _spawned_vehicles: Array[GymLifeVehicle] = []


func _ready() -> void:
	add_to_group("vehicle_spawner")


func cycle_vehicle() -> void:
	selected_index = (selected_index + 1) % VEHICLE_CATALOG.size()
	var selected: Dictionary = VEHICLE_CATALOG[selected_index]
	var prompt: String = "%s · VELOCIDAD %s · MÁX. %.0f km/h · G para crear" % [
		str(selected["label"]),
		str(selected["class"]),
		float(selected["max_speed_kmh"])
	]
	get_tree().call_group("game_hud", "set_prompt", prompt)


func spawn_vehicle(player: Node3D) -> GymLifeVehicle:
	if player == null or not is_instance_valid(player):
		return null

	_cleanup_spawned()
	while _count_live_vehicles() >= maximum_live_vehicles:
		var parked_index: int = _find_parked_vehicle_index()
		if parked_index < 0:
			get_tree().call_group(
				"game_hud",
				"set_prompt",
				"Todos los vehículos están ocupados. Baja de uno para crear otro."
			)
			return null
		var parked_vehicle: GymLifeVehicle = _spawned_vehicles[parked_index]
		if is_instance_valid(parked_vehicle):
			parked_vehicle.queue_free()
		_spawned_vehicles.remove_at(parked_index)

	var data: Dictionary = VEHICLE_CATALOG[selected_index]
	var spawn_position: Vector3 = _find_clear_ground_position(player)
	if spawn_position.y < -999.0:
		get_tree().call_group(
			"game_hud",
			"set_prompt",
			"No hay espacio libre delante. Muévete a una zona despejada y vuelve a pulsar G."
		)
		return null

	var vehicle: GymLifeVehicle = VEHICLE_SCENE.instantiate() as GymLifeVehicle
	if vehicle == null:
		push_error("No se pudo instanciar scenes/vehicle.tscn")
		return null

	vehicle.name = "Vehicle_%s_%02d" % [str(data["label"]).replace(" ", ""), _spawned_vehicles.size() + 1]
	vehicle.model_file = str(data["file"])
	vehicle.model_yaw_offset_degrees = float(data["yaw"])
	vehicle.configure_profile(data)
	get_parent().add_child(vehicle)
	vehicle.global_position = spawn_position
	vehicle.global_rotation = Vector3(0.0, player.global_rotation.y, 0.0)
	vehicle.reset_physics_interpolation()
	_spawned_vehicles.append(vehicle)

	var success_prompt: String = "%s creado · %s · velocidad máxima %.0f km/h. Acércate y pulsa F." % [
		str(data["label"]), str(data["class"]), float(data["max_speed_kmh"])
	]
	get_tree().call_group("game_hud", "set_prompt", success_prompt)
	return vehicle


func _find_clear_ground_position(player: Node3D) -> Vector3:
	var forward: Vector3 = -player.global_transform.basis.z.normalized()
	var right: Vector3 = player.global_transform.basis.x.normalized()
	var origin: Vector3 = player.global_position
	var candidates: Array[Vector3] = [
		origin + forward * spawn_distance,
		origin + forward * (spawn_distance + 2.5) + right * 2.8,
		origin + forward * (spawn_distance + 2.5) - right * 2.8,
		origin + right * 5.0,
		origin - right * 5.0
	]

	for candidate in candidates:
		var ground_position: Vector3 = _raycast_ground(candidate, player)
		if ground_position.y < -999.0:
			continue
		if _is_spawn_volume_clear(ground_position, player, player.global_rotation.y):
			return ground_position + Vector3.UP * 0.05
	return INVALID_POSITION


func _raycast_ground(candidate: Vector3, player: Node3D) -> Vector3:
	var ray_start: Vector3 = candidate + Vector3.UP * 18.0
	var ray_end: Vector3 = candidate + Vector3.DOWN * 32.0
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.collision_mask = 1
	query.collide_with_areas = false

	var excluded: Array[RID] = []
	if player is CollisionObject3D:
		excluded.append((player as CollisionObject3D).get_rid())

	for attempt in range(16):
		query.exclude = excluded
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return INVALID_POSITION

		var collider: Object = hit.get("collider")
		if collider is CollisionObject3D and collider is Node:
			var collider_node: Node = collider as Node
			if collider_node.is_in_group("escalable") or collider_node.is_in_group("vehicles"):
				excluded.append((collider as CollisionObject3D).get_rid())
				continue
		var hit_position: Vector3 = hit.get("position", INVALID_POSITION)
		return hit_position

	return INVALID_POSITION


func _is_spawn_volume_clear(ground_position: Vector3, player: Node3D, yaw: float) -> bool:
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = SPAWN_CLEARANCE_SIZE

	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(
		Basis(Vector3.UP, yaw),
		ground_position + Vector3.UP * (SPAWN_CLEARANCE_SIZE.y * 0.5 + 0.08)
	)
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var excluded: Array[RID] = []
	if player is CollisionObject3D:
		excluded.append((player as CollisionObject3D).get_rid())
	query.exclude = excluded

	var overlaps: Array[Dictionary] = get_world_3d().direct_space_state.intersect_shape(query, 8)
	return overlaps.is_empty()


func _find_parked_vehicle_index() -> int:
	for index in range(_spawned_vehicles.size()):
		var vehicle: GymLifeVehicle = _spawned_vehicles[index]
		if is_instance_valid(vehicle) and vehicle.driver == null:
			return index
	return -1


func _cleanup_spawned() -> void:
	for index in range(_spawned_vehicles.size() - 1, -1, -1):
		if not is_instance_valid(_spawned_vehicles[index]):
			_spawned_vehicles.remove_at(index)


func _count_live_vehicles() -> int:
	var total: int = 0
	for vehicle in _spawned_vehicles:
		if is_instance_valid(vehicle):
			total += 1
	return total
