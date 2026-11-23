extends Node3D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const GYM_SCENE := preload("res://scenes/gym.tscn")
const CRYSTAL_SCENE := preload("res://scenes/crystal.tscn")

var selected_character: String = "female"
var player: GymLifePlayer
var hud: GymLifeHUD
var menu: GymLifeCharacterSelect
var menu_layer: CanvasLayer
var hud_layer: CanvasLayer
var vehicle_spawner: GymLifeVehicleSpawner
var day_night: GymLifeDayNightCycle
var world_environment: WorldEnvironment
var environment_data: Environment
var sun_light: DirectionalLight3D
var sky_material: ProceduralSkyMaterial
var crystal_count: int = 0
var total_crystals: int = 5


func _ready() -> void:
	_setup_input_map()
	_setup_environment()
	_create_day_night_controller()
	_build_city()
	_build_gym()
	_build_food_stand()
	_build_sleeping_spot()
	_build_vehicle()
	_build_crystals()
	_create_audio_manager()
	_create_hud()
	_create_character_menu()


func _setup_input_map() -> void:
	_add_key_action("move_forward", KEY_W)
	_add_key_action("move_forward", KEY_UP)
	_add_key_action("move_back", KEY_S)
	_add_key_action("move_back", KEY_DOWN)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_left", KEY_LEFT)
	_add_key_action("move_right", KEY_D)
	_add_key_action("move_right", KEY_RIGHT)
	_add_key_action("jump", KEY_SPACE)
	_add_key_action("vehicle_brake", KEY_SPACE)
	_add_key_action("interact", KEY_E)
	_add_key_action("run", KEY_SHIFT)
	_add_key_action("enter_vehicle", KEY_F)
	_add_key_action("climb", KEY_C)
	_add_key_action("spawn_vehicle", KEY_G)
	_add_key_action("next_vehicle", KEY_R)
	_add_key_action("nitro", KEY_SHIFT)
	_add_key_action("toggle_cursor", KEY_TAB)


func _add_key_action(action_name: String, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for existing in InputMap.action_get_events(action_name):
		if existing is InputEventKey and (existing as InputEventKey).physical_keycode == keycode:
			return
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action_name, event)


func _setup_environment() -> void:
	world_environment = WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	environment_data = Environment.new()
	environment_data.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.30, 0.49, 0.66)
	sky_material.sky_horizon_color = Color(0.72, 0.78, 0.82)
	sky_material.ground_bottom_color = Color(0.13, 0.16, 0.18)
	sky_material.ground_horizon_color = Color(0.53, 0.57, 0.58)
	sky.sky_material = sky_material
	environment_data.sky = sky
	environment_data.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment_data.ambient_light_color = Color(0.68, 0.73, 0.78)
	environment_data.ambient_light_energy = 0.76
	environment_data.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment_data
	add_child(world_environment)

	sun_light = DirectionalLight3D.new()
	sun_light.name = "SunLight"
	sun_light.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun_light.light_energy = 1.05
	sun_light.light_color = Color(1.0, 0.965, 0.91)
	sun_light.shadow_enabled = true
	add_child(sun_light)


func _create_day_night_controller() -> void:
	day_night = GymLifeDayNightCycle.new()
	day_night.name = "DayNightCycle"
	add_child(day_night)
	day_night.configure(sun_light, world_environment)
	day_night.time_changed.connect(_on_time_changed)


func _mat(color: Color, roughness: float = 0.82, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _add_box(parent: Node3D, node_name: String, local_position: Vector3, size: Vector3, color: Color, solid: bool = true) -> Node3D:
	var root: Node3D
	if solid:
		root = StaticBody3D.new()
		(root as StaticBody3D).collision_layer = 1
		(root as StaticBody3D).collision_mask = 1
	else:
		root = Node3D.new()
	root.name = node_name
	root.position = local_position
	parent.add_child(root)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _mat(color)
	root.add_child(mesh_instance)

	if solid:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		root.add_child(collision)
	return root


func _build_city() -> void:
	_add_box(self, "Ground", Vector3(0, -0.28, 0), Vector3(220, 0.55, 180), Color(0.24, 0.43, 0.27))
	_add_box(self, "MainAvenue", Vector3(0, 0.015, 0), Vector3(174, 0.12, 10), Color(0.12, 0.14, 0.16), false)
	_add_box(self, "CrossStreetNorth", Vector3(-20, 0.02, 0), Vector3(9, 0.13, 150), Color(0.12, 0.14, 0.16), false)
	_add_box(self, "CrossStreetSouth", Vector3(20, 0.02, 0), Vector3(9, 0.13, 150), Color(0.12, 0.14, 0.16), false)

	for x in range(-80, 81, 8):
		_add_box(self, "RoadCenterDash_%d" % x, Vector3(x, 0.09, 0), Vector3(3.2, 0.035, 0.13), Color(0.96, 0.78, 0.25), false)
	for z in range(-70, 71, 8):
		_add_box(self, "RoadDash_N_%d" % z, Vector3(-20, 0.10, z), Vector3(0.13, 3.2, 0.035), Color(0.93, 0.91, 0.78), false)
		_add_box(self, "RoadDash_S_%d" % z, Vector3(20, 0.10, z), Vector3(0.13, 3.2, 0.035), Color(0.93, 0.91, 0.78), false)

	# A few native Quaternius street modules are included in the supplied city pack.
	_place_city_scene("Street_4WayIntersection.gltf", Vector3(0, 0.12, 0), 0.52)
	_place_city_scene("Street_2Lane.gltf", Vector3(0, 0.12, -18), 0.95)
	_place_city_scene("Street_2Lane.gltf", Vector3(0, 0.12, 18), 0.95)
	_place_city_scene("Street_2Lane.gltf", Vector3(-20, 0.12, -18), 0.95, PI / 2.0)
	_place_city_scene("Street_2Lane.gltf", Vector3(20, 0.12, 18), 0.95, PI / 2.0)

	_place_building("Building_Small_1.gltf", Vector3(-37, 0, -7), Vector3(-1, 8.5, -5), Vector3(12.5, 17, 14.5))
	_place_building("Building_Medium_2_001.gltf", Vector3(-12, 0, -29), Vector3(0, 12.5, -6), Vector3(15, 25, 13))
	_place_building("Building_Large_2.gltf", Vector3(45, 0, -25), Vector3(1, 14, -8), Vector3(20.6, 28, 16.6))
	_place_building("Building_Small_1.gltf", Vector3(47, 0, 18), Vector3(-1, 8.5, -5), Vector3(12.5, 17, 14.5))
	_place_building("Building_Medium_2_001.gltf", Vector3(-40, 0, 26), Vector3(0, 12.5, -6), Vector3(15, 25, 13))
	# Nuevo distrito exterior: edificios de menor densidad que amplían la zona explorable.
	_place_building("Building_Small_1.gltf", Vector3(-78, 0, -48), Vector3(-1, 8.5, -5), Vector3(12.5, 17, 14.5))
	_place_building("Building_Medium_2_001.gltf", Vector3(78, 0, -48), Vector3(0, 12.5, -6), Vector3(15, 25, 13))
	_place_building("Building_Large_2.gltf", Vector3(78, 0, 48), Vector3(1, 14, -8), Vector3(20.6, 28, 16.6))
	_place_building("Building_Small_1.gltf", Vector3(-78, 0, 52), Vector3(-1, 8.5, -5), Vector3(12.5, 17, 14.5))

	_build_park()
	_build_lamp_posts()


func _place_city_scene(file_name: String, at: Vector3, scale_value: float = 1.0, yaw: float = 0.0) -> void:
	var path := "res://assets/city/%s" % file_name
	var resource := load(path)
	if resource is PackedScene:
		var instance := (resource as PackedScene).instantiate() as Node3D
		instance.position = at
		instance.rotation.y = yaw
		instance.scale = Vector3.ONE * scale_value
		add_child(instance)


func _place_building(file_name: String, at: Vector3, collision_center: Vector3, collision_size: Vector3) -> void:
	var building := StaticBody3D.new()
	building.collision_layer = 1
	building.collision_mask = 1
	building.name = file_name.get_basename()
	building.add_to_group("escalable")
	building.set_meta("climb_top_y", at.y + collision_center.y + collision_size.y * 0.5)
	building.position = at
	add_child(building)

	var asset_path := "res://assets/city/%s" % file_name
	var packed := load(asset_path) if ResourceLoader.exists(asset_path) else null
	if packed is PackedScene:
		building.add_child((packed as PackedScene).instantiate())

	# Envolvente escalable de altura completa. El hueco de puerta solo existe
	# en planta baja; la fachada continúa desde el dintel hasta el tejado para
	# que el RayCast pueda seguir detectando una superficie al subir.
	var width: float = maxf(6.0, collision_size.x - 0.55)
	var depth: float = maxf(6.0, collision_size.z - 0.55)
	var wall_height: float = maxf(3.35, collision_size.y)
	var wall_center_y: float = collision_center.y
	var thickness: float = 0.36
	var half_width: float = collision_size.x * 0.5
	var half_depth: float = collision_size.z * 0.5
	var center_x: float = collision_center.x
	var center_z: float = collision_center.z
	var door_width: float = 1.85
	_add_building_collision(building, "InteriorWallLeft", Vector3(center_x - half_width + thickness * 0.5, wall_center_y, center_z), Vector3(thickness, wall_height, depth))
	_add_building_collision(building, "InteriorWallRight", Vector3(center_x + half_width - thickness * 0.5, wall_center_y, center_z), Vector3(thickness, wall_height, depth))
	_add_building_collision(building, "InteriorWallBack", Vector3(center_x, wall_center_y, center_z - half_depth + thickness * 0.5), Vector3(width, wall_height, thickness))
	var front_width: float = maxf(0.8, (width - door_width) * 0.5)
	var front_z: float = center_z + half_depth - thickness * 0.5
	_add_building_collision(building, "FrontWallLeft", Vector3(center_x - door_width * 0.5 - front_width * 0.5, wall_center_y, front_z), Vector3(front_width, wall_height, thickness))
	_add_building_collision(building, "FrontWallRight", Vector3(center_x + door_width * 0.5 + front_width * 0.5, wall_center_y, front_z), Vector3(front_width, wall_height, thickness))
	var upper_front_height: float = maxf(0.0, wall_height - 3.0)
	if upper_front_height > 0.15:
		_add_building_collision(building, "FrontFacadeAboveDoor", Vector3(center_x, -wall_height * 0.5 + 3.0 + upper_front_height * 0.5 + wall_center_y, front_z), Vector3(door_width, upper_front_height, thickness))
	_add_building_collision(building, "FrontDoorLintel", Vector3(center_x, 2.82, front_z), Vector3(door_width, 0.36, thickness))
	var roof_center_y: float = collision_center.y + collision_size.y * 0.5 - 0.16
	_add_building_collision(building, "RoofWalkable", Vector3(center_x, roof_center_y, center_z), Vector3(width, 0.32, depth))
	var interior_floor := MeshInstance3D.new()
	interior_floor.name = "InteriorFloor"
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(width - 0.8, 0.12, depth - 0.8)
	interior_floor.mesh = floor_mesh
	interior_floor.position = Vector3(center_x, 0.04, center_z)
	interior_floor.material_override = _mat(Color(0.38, 0.34, 0.28), 0.9)
	building.add_child(interior_floor)

	# Mobiliario sencillo para que la entrada a las casas tenga un interior legible.
	var furniture := Node3D.new()
	furniture.name = "InteriorFurniture"
	building.add_child(furniture)
	_add_box(furniture, "SofaBase", Vector3(center_x - 1.55, 0.42, center_z - 0.25), Vector3(2.2, 0.48, 0.82), Color(0.22, 0.29, 0.33), false)
	_add_box(furniture, "SofaBack", Vector3(center_x - 1.55, 0.92, center_z - 0.60), Vector3(2.2, 0.68, 0.20), Color(0.18, 0.24, 0.29), false)
	_add_box(furniture, "CoffeeTable", Vector3(center_x + 1.45, 0.42, center_z + 0.35), Vector3(1.25, 0.12, 0.75), Color(0.30, 0.20, 0.13), false)
	_add_box(furniture, "TVConsole", Vector3(center_x, 0.42, center_z - half_depth + 1.0), Vector3(2.3, 0.55, 0.42), Color(0.10, 0.12, 0.13), false)
	_add_building_collision(building, "SofaCollision", Vector3(center_x - 1.55, 0.55, center_z - 0.25), Vector3(2.2, 0.9, 0.82))
	_add_building_collision(building, "CoffeeTableCollision", Vector3(center_x + 1.45, 0.42, center_z + 0.35), Vector3(1.25, 0.45, 0.75))
	_add_building_collision(building, "TVConsoleCollision", Vector3(center_x, 0.42, center_z - half_depth + 1.0), Vector3(2.3, 0.75, 0.42))

	var ceiling_light := OmniLight3D.new()
	ceiling_light.name = "InteriorLight"
	ceiling_light.position = Vector3(center_x, 2.95, center_z)
	ceiling_light.light_color = Color(1.0, 0.90, 0.75)
	ceiling_light.light_energy = 0.65
	ceiling_light.omni_range = 8.0
	building.add_child(ceiling_light)

	var door := Node3D.new()
	door.name = "HouseDoor"
	door.set_script(load("res://scripts/interactions/door.gd"))
	door.set("door_width", door_width)
	door.set("door_height", 2.35)
	door.set("prompt_text", "Entrar / salir de la casa")
	door.set("portal_enabled", true)
	door.set("portal_inside_offset", Vector3(door_width * 0.5, 0.08, -2.8))
	door.set("portal_outside_offset", Vector3(door_width * 0.5, 0.08, 2.4))
	door.position = Vector3(at.x + center_x - door_width * 0.5, at.y, at.z + center_z + half_depth - 0.12)
	door.set("open_angle_degrees", -100.0)
	add_child(door)


func _add_building_collision(parent: StaticBody3D, node_name: String, local_position: Vector3, size: Vector3) -> void:
	var collision := CollisionShape3D.new()
	collision.name = node_name
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = local_position
	parent.add_child(collision)


func _build_park() -> void:
	_add_box(self, "Park", Vector3(0, 0.015, 29), Vector3(62, 0.12, 28), Color(0.28, 0.50, 0.29), false)
	var tree_positions: Array[Vector3] = [
		Vector3(-20.0, 0.0, 23.0), Vector3(-14.3, 0.0, 27.0),
		Vector3(-8.6, 0.0, 31.0), Vector3(-2.9, 0.0, 23.0),
		Vector3(2.8, 0.0, 27.0), Vector3(8.5, 0.0, 31.0),
		Vector3(14.2, 0.0, 23.0), Vector3(19.9, 0.0, 27.0),
		Vector3(56.0, 0.0, 34.0), Vector3(63.0, 0.0, 41.0),
		Vector3(70.0, 0.0, 34.0), Vector3(77.0, 0.0, 41.0)
	]
	for index in range(tree_positions.size()):
		_create_climbable_tree(index, tree_positions[index])


func _create_climbable_tree(index: int, tree_position: Vector3) -> void:
	var trunk_body := StaticBody3D.new()
	trunk_body.name = "ClimbableTree_%02d" % index
	trunk_body.position = tree_position
	trunk_body.collision_layer = 1
	trunk_body.collision_mask = 1
	trunk_body.add_to_group("escalable")
	trunk_body.set_meta("climb_top_y", tree_position.y + 5.93)
	add_child(trunk_body)

	var trunk := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.20
	cylinder.bottom_radius = 0.31
	cylinder.height = 5.80
	trunk.mesh = cylinder
	trunk.position.y = 2.90
	trunk.material_override = _mat(Color(0.31, 0.20, 0.12))
	trunk_body.add_child(trunk)

	var trunk_collision := CollisionShape3D.new()
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = 0.30
	trunk_shape.height = 5.80
	trunk_collision.shape = trunk_shape
	trunk_collision.position.y = 2.90
	trunk_body.add_child(trunk_collision)

	# Plataforma invisible bajo la copa: permite terminar la escalada y recoger
	# el cristal sin atravesar las hojas ni quedarse suspendido en el aire.
	var crown_platform := CollisionShape3D.new()
	var platform_shape := CylinderShape3D.new()
	platform_shape.radius = 1.08
	platform_shape.height = 0.24
	crown_platform.shape = platform_shape
	crown_platform.position.y = 5.81
	trunk_body.add_child(crown_platform)

	var crown := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.42
	sphere.height = 2.75
	crown.mesh = sphere
	crown.position = tree_position + Vector3(0.0, 5.28, 0.0)
	crown.material_override = _mat(Color(0.18 + 0.02 * float(index % 3), 0.38, 0.22))
	add_child(crown)

func _build_lamp_posts() -> void:
	for x in [-30.0, -10.0, 10.0, 30.0]:
		var pole := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.07
		cylinder.bottom_radius = 0.10
		cylinder.height = 5.0
		pole.mesh = cylinder
		pole.position = Vector3(x, 2.5, -1.8)
		pole.material_override = _mat(Color(0.15, 0.18, 0.20), 0.4, 0.7)
		add_child(pole)
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(x, 4.9, -1.8)
		lamp.light_energy = 0.65
		lamp.omni_range = 13.0
		add_child(lamp)


func _build_gym() -> void:
	var gym := GYM_SCENE.instantiate() as GymLifeGym
	gym.position = Vector3(22, 0, -8)
	add_child(gym)


func _build_food_stand() -> void:
	# Kiosco abierto: laterales y pared trasera, dejando libre la zona de atención.
	_add_box(self, "FoodShopBack", Vector3(-23, 1.7, 14.65), Vector3(10, 3.4, 0.28), Color(0.93, 0.90, 0.82), true)
	_add_box(self, "FoodShopLeft", Vector3(-27.86, 1.7, 12), Vector3(0.28, 3.4, 5.3), Color(0.93, 0.90, 0.82), true)
	_add_box(self, "FoodShopRight", Vector3(-18.14, 1.7, 12), Vector3(0.28, 3.4, 5.3), Color(0.93, 0.90, 0.82), true)
	# Mostrador dividido en dos módulos. El pasillo central queda alineado con
	# la puerta y permanece libre para entrar y alcanzar los alimentos.
	_add_box(self, "FoodCounterLeft", Vector3(-26.2, 0.95, 12), Vector3(3.6, 0.55, 2.4), Color(0.30, 0.19, 0.13), true)
	_add_box(self, "FoodCounterRight", Vector3(-19.8, 0.95, 12), Vector3(3.6, 0.55, 2.4), Color(0.30, 0.19, 0.13), true)
	_add_box(self, "FoodAwning", Vector3(-23, 3.6, 12), Vector3(10.2, 0.22, 5.8), Color(0.07, 0.47, 0.40), false)
	# Fachada comercial con dos paños y una puerta funcional al centro.
	# Fachada frontal con vano libre de 3.4 m, centrado en x=-23.
	_add_box(self, "FoodFrontLeft", Vector3(-26.35, 1.7, 9.35), Vector3(3.3, 3.4, 0.28), Color(0.88, 0.86, 0.78), true)
	_add_box(self, "FoodFrontRight", Vector3(-19.65, 1.7, 9.35), Vector3(3.3, 3.4, 0.28), Color(0.88, 0.86, 0.78), true)
	var food_door := Node3D.new()
	food_door.name = "FoodShopDoor"
	food_door.set_script(load("res://scripts/interactions/door.gd"))
	food_door.set("door_width", 3.2)
	food_door.set("door_height", 2.45)
	food_door.set("prompt_text", "Entrar / salir del restaurante")
	food_door.set("open_angle_degrees", -100.0)
	food_door.position = Vector3(-24.6, 0.0, 9.22)
	add_child(food_door)

	var food_sign := Label3D.new()
	food_sign.text = "FRESH FOOD  |  COMIDA"
	food_sign.font_size = 38
	food_sign.modulate = Color(0.10, 0.28, 0.24)
	food_sign.position = Vector3(-23, 3.1, 9.05)
	food_sign.rotation.y = 0.0
	add_child(food_sign)

	var foods := [
		["Manzana", "Apple.obj", 20.0, 8.0, 7.0],
		["Banana", "Banana.obj", 24.0, 12.0, 7.0],
		["Brócoli", "Broccoli.obj", 22.0, 7.0, 8.0],
		["Pollo", "ChickenLeg.obj", 28.0, 16.0, 6.0],
		["Aguacate", "Avocado.obj", 22.0, 12.0, 8.0],
		["Hamburguesa", "Cheeseburger.obj", 32.0, 13.0, 11.0],
		["Pizza", "Pizza_Slice.obj", 26.0, 10.0, 10.0]
	]
	for index in range(foods.size()):
		var data: Array = foods[index]
		var food_position := Vector3(-27.0 + float(index) * 1.35, 1.5, 12.0)
		_spawn_food(str(data[0]), str(data[1]), food_position, float(data[2]), float(data[3]), float(data[4]))


func _spawn_food(label_text: String, model_file: String, at: Vector3, hunger_gain: float, energy_gain: float, happiness_gain: float) -> void:
	var area := Area3D.new()
	area.name = "Food_" + label_text.replace(" ", "")
	area.position = at
	area.collision_layer = 2
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	area.set_script(load("res://scripts/food.gd"))
	area.call("setup", label_text, hunger_gain, energy_gain, happiness_gain)
	add_child(area)

	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.3
	collision.shape = sphere
	area.add_child(collision)

	var model_path := "res://assets/food/%s" % model_file
	var resource := load(model_path)
	var model_instance: Node3D
	if resource is Mesh:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = resource as Mesh
		model_instance = mesh_instance
	elif resource is PackedScene:
		model_instance = (resource as PackedScene).instantiate() as Node3D
	else:
		var fallback := MeshInstance3D.new()
		var sphere_mesh := SphereMesh.new()
		sphere_mesh.radius = 0.34
		sphere_mesh.height = 0.55
		fallback.mesh = sphere_mesh
		fallback.material_override = _mat(Color(0.88, 0.35, 0.18))
		model_instance = fallback
	model_instance.scale = Vector3.ONE * 0.42
	area.add_child(model_instance)

	var tag := Label3D.new()
	tag.text = label_text
	tag.font_size = 22
	tag.position = Vector3(0, 0.8, 0)
	tag.modulate = Color(0.12, 0.14, 0.16)
	area.add_child(tag)


func _build_sleeping_spot() -> void:
	# Zona de descanso con cama y una interacción sencilla.
	var bed_position := Vector3(-15.0, 0.0, 36.0)
	_add_box(self, "RestBedBase", bed_position + Vector3(0.0, 0.28, 0.0), Vector3(1.45, 0.5, 2.5), Color(0.22, 0.15, 0.12), true)
	_add_box(self, "RestBedMattress", bed_position + Vector3(0.0, 0.62, 0.0), Vector3(1.32, 0.22, 2.35), Color(0.78, 0.82, 0.78), false)
	_add_box(self, "RestBedPillow", bed_position + Vector3(0.0, 0.78, -0.91), Vector3(0.78, 0.12, 0.35), Color(0.92, 0.91, 0.84), false)

	var area := Area3D.new()
	area.name = "SleepSpot"
	area.position = bed_position + Vector3(0.0, 1.0, 0.0)
	area.collision_layer = 2
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	area.set_script(load("res://scripts/interactions/sleep_spot.gd"))
	area.call("setup", "Dormir 8 horas")
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 2.3
	collision.shape = shape
	area.add_child(collision)
	add_child(area)

	var rest_sign := Label3D.new()
	rest_sign.text = "ZONA DE DESCANSO  |  E"
	rest_sign.font_size = 24
	rest_sign.modulate = Color(0.84, 0.94, 0.90)
	rest_sign.position = bed_position + Vector3(0.0, 1.8, -1.3)
	add_child(rest_sign)


func _build_vehicle() -> void:
	# No se colocan coches estáticos: el catálogo se genera bajo demanda con G.
	vehicle_spawner = GymLifeVehicleSpawner.new()
	vehicle_spawner.name = "VehicleSpawner"
	add_child(vehicle_spawner)


func _build_crystals() -> void:
	# Tres cristales en azoteas y dos en copas de árboles: todos requieren escalar.
	var crystal_positions: Array[Vector3] = [
		Vector3(-37.0, 17.45, -7.0),
		Vector3(-12.0, 25.45, -29.0),
		Vector3(45.0, 28.45, -25.0),
		Vector3(-14.3, 5.72, 27.0),
		Vector3(70.0, 5.72, 34.0)
	]
	for index in range(crystal_positions.size()):
		var crystal := CRYSTAL_SCENE.instantiate() as GymLifeCrystal
		crystal.name = "Crystal_%02d" % (index + 1)
		crystal.position = crystal_positions[index]
		crystal.collected.connect(_on_crystal_collected)
		add_child(crystal)

func _create_audio_manager() -> void:
	var audio := Node.new()
	audio.name = "AudioManager"
	audio.set_script(load("res://scripts/audio_manager.gd"))
	add_child(audio)


func _create_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.name = "HUDLayer"
	add_child(hud_layer)

	hud = GymLifeHUD.new()
	hud.name = "GameHUD"
	hud.add_to_group("game_hud")
	hud.visible = false
	hud_layer.add_child(hud)


func _create_character_menu() -> void:
	menu_layer = CanvasLayer.new()
	menu_layer.name = "CharacterSelect"
	add_child(menu_layer)

	menu = GymLifeCharacterSelect.new()
	menu.character_confirmed.connect(_start_game)
	menu_layer.add_child(menu)


func _start_game(character_id: String) -> void:
	selected_character = character_id
	if is_instance_valid(menu_layer):
		menu_layer.queue_free()

	player = PLAYER_SCENE.instantiate() as GymLifePlayer
	player.name = "Player"
	add_child(player)
	player.global_position = Vector3(0.0, 0.03, 9.0)
	player.configure_character(selected_character)

	player.stats_changed.connect(_on_stats_changed)
	player.crystals_updated.connect(_on_crystals_updated)
	player.prompt_changed.connect(_on_prompt_changed)
	player.sound_requested.connect(_on_sound_requested)
	player.time_skip_requested.connect(_on_time_skip_requested)

	hud.visible = true
	hud.update_stats(player.hunger, player.energy, player.happiness, player.fitness)
	hud.set_crystals(crystal_count, total_crystals)
	hud.set_clock(day_night.time_hours, day_night.get_clock_text())
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_stats_changed(hunger: float, energy: float, happiness: float, fitness: float) -> void:
	if is_instance_valid(hud):
		hud.update_stats(hunger, energy, happiness, fitness)


func _on_crystals_updated(total: int) -> void:
	crystal_count = total
	if is_instance_valid(hud):
		hud.set_crystals(crystal_count, total_crystals)
	if crystal_count >= total_crystals:
		_sound("victory")


func _on_crystal_collected(body: Node) -> void:
	if player != null and body == player:
		player.register_crystal()


func _on_prompt_changed(message: String) -> void:
	if is_instance_valid(hud):
		hud.set_prompt(message)


func _on_sound_requested(sound_name: String) -> void:
	_sound(sound_name)


func _sound(sound_name: String) -> void:
	get_tree().call_group("audio_manager", "play_sfx", sound_name)


func _on_time_skip_requested(hours: float) -> void:
	if is_instance_valid(day_night):
		day_night.advance_hours(hours)


func _on_time_changed(hours: float, clock_text: String) -> void:
	if is_instance_valid(hud):
		hud.set_clock(hours, clock_text)


func set_driving(active: bool) -> void:
	if is_instance_valid(hud):
		hud.set_driving(active)


func set_drive_speed(speed_kmh: float, maximum_kmh: float = 0.0, speed_class: String = "", nitro_percent: float = 0.0) -> void:
	if is_instance_valid(hud):
		hud.set_drive_speed(speed_kmh, maximum_kmh, speed_class, nitro_percent)


