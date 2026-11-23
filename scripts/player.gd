extends CharacterBody3D
class_name GymLifePlayer

signal stats_changed(hunger: float, energy: float, happiness: float, fitness: float)
signal crystals_updated(total: int)
signal prompt_changed(text: String)
signal sound_requested(sound_name: String)
signal time_skip_requested(hours: float)

const MODEL_PATHS := {
	"male": "res://assets/characters/male/Superhero_Male_FullBody.gltf",
	"female": "res://assets/characters/female/Superhero_Female_FullBody.gltf"
}
const MOUSE_SENSITIVITY: float = 0.0045
const ANIMATION_STATES: Array[String] = ["idle", "walk", "run", "eat", "exercise", "sleep", "climb"]

@export_category("Movimiento")
@export var walk_speed: float = 4.8
@export var run_speed: float = 7.2
@export var jump_velocity: float = 5.0
@export var acceleration: float = 20.0

@export_category("Modelo humanoide")
@export_range(1.5, 2.0, 0.01) var target_model_height: float = 1.72
@export var model_axis_correction_degrees: Vector3 = Vector3.ZERO
@export_range(-180.0, 180.0, 1.0) var model_front_yaw_degrees: float = 180.0

@export_category("Escalada")
@export var climb_speed: float = 3.2
@export var climb_ray_length: float = 1.55

@onready var body_collision: CollisionShape3D = $CollisionShape3D
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var interaction_area: Area3D = $InteractionArea
@onready var visual: Node3D = $Visual
@onready var climb_ray: RayCast3D = $ClimbRay

var selected_character: String = "female"
var hunger: float = 88.0
var energy: float = 90.0
var happiness: float = 76.0
var fitness: float = 12.0
var crystals: int = 0

var _model: Node3D
var _model_half_depth: float = 0.15
var _skeleton: Skeleton3D
var _animation_player: AnimationPlayer
var _animation_tree: AnimationTree
var _state_playback: AnimationNodeStateMachinePlayback
var _skeleton_path: NodePath
var _animation_state: String = ""
var _lock_timer: float = 0.0
var _stats_timer: float = 0.0
var _current_prompt: String = ""
var _footstep_timer: float = 0.0
var _active_vehicle: Node3D
var _is_in_vehicle: bool = false
var _is_sleeping: bool = false
var _is_climbing: bool = false
var _climb_target: Object
var _climb_top_y: float = INF
var _collision_mask_before_climb: int = 1
var _arm_rest_poses: Dictionary = {}
var _arm_eat_poses: Dictionary = {}
var _arm_climb_poses: Dictionary = {}
var _viewmodel_root: Node3D
var _viewmodel_arms: Dictionary = {}
var _viewmodel_hands: Dictionary = {}
var _viewmodel_time: float = 0.0


func _ready() -> void:
	add_to_group("player")
	collision_layer = 1
	collision_mask = 1
	floor_snap_length = 0.28
	floor_max_angle = deg_to_rad(48.0)
	safe_margin = 0.03

	# Punto de vista en el espacio libre de la cabeza: el cuerpo importado no se
	# renderiza durante gameplay. Solo se dibujan brazos/manos en espacio de cámara.
	camera_pivot.position = Vector3(0.0, 1.66, -0.035)
	camera_pivot.rotation = Vector3.ZERO
	camera.position = Vector3.ZERO
	camera.fov = 82.0
	camera.near = 0.06
	camera.far = 300.0
	camera.current = true
	climb_ray.enabled = true
	climb_ray.position.y = 0.55
	climb_ray.collision_mask = 1
	climb_ray.collide_with_bodies = true
	climb_ray.collide_with_areas = false
	climb_ray.exclude_parent = true
	climb_ray.target_position = Vector3(0.0, 0.0, -climb_ray_length)

	interaction_area.collision_layer = 0
	interaction_area.collision_mask = 2
	interaction_area.monitoring = true
	interaction_area.monitorable = false
	visual.visible = false
	_create_first_person_hands()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	set_process_input(true)
	_emit_stats()


func configure_character(character_id: String) -> void:
	# El selector 3D (cuerpo completo y retrato) vive en su propia escena y no
	# se modifica. En gameplay usamos un POV limpio: cámara + brazos procedurales.
	selected_character = character_id if MODEL_PATHS.has(character_id) else "female"
	for child in visual.get_children():
		child.queue_free()
	_model = null
	_skeleton = null
	_animation_player = null
	_animation_tree = null
	_state_playback = null
	_animation_state = ""
	visual.visible = false
	if not is_instance_valid(_viewmodel_root):
		_create_first_person_hands()
	_set_animation("idle")


# Los glTF incluidos ya son Y-up. No se les aplica una rotación X/Z global:
# hacerlo convertiría un humanoide erguido en un cuerpo acostado.
# Se centra el pivot, se ajusta la altura y se deja el mínimo del modelo en Y=0.
func _create_first_person_hands() -> void:
	if is_instance_valid(_viewmodel_root):
		_viewmodel_root.queue_free()
	_viewmodel_root = Node3D.new()
	_viewmodel_root.name = "FirstPersonHands"
	camera.add_child(_viewmodel_root)
	_viewmodel_root.position = Vector3.ZERO

	var sleeve_material := StandardMaterial3D.new()
	sleeve_material.albedo_color = Color(0.075, 0.16, 0.22)
	sleeve_material.roughness = 0.82
	var cuff_material := StandardMaterial3D.new()
	cuff_material.albedo_color = Color(0.13, 0.25, 0.30)
	cuff_material.roughness = 0.72
	var skin_material := StandardMaterial3D.new()
	skin_material.albedo_color = Color(0.70, 0.47, 0.34)
	skin_material.roughness = 0.88

	var arm_sides: Array[float] = [-1.0, 1.0]
	for side_value in arm_sides:
		var side: float = side_value
		var key: String = "left" if side < 0.0 else "right"
		# Brazos con volumen más natural: hombro y antebrazo menos finos.
		var upper := _make_viewmodel_limb(key + "_upper_arm", 0.102, sleeve_material)
		var forearm := _make_viewmodel_limb(key + "_forearm", 0.091, sleeve_material)
		var cuff := _make_viewmodel_limb(key + "_cuff", 0.087, cuff_material)
		_viewmodel_root.add_child(upper)
		_viewmodel_root.add_child(forearm)
		_viewmodel_root.add_child(cuff)

		var hand_root := Node3D.new()
		hand_root.name = key + "_hand"
		_viewmodel_root.add_child(hand_root)

		# Palma más ancha y algo aplanada, con dorso separado para dar lectura 3D.
		var palm := MeshInstance3D.new()
		var palm_mesh := SphereMesh.new()
		palm_mesh.radius = 0.091
		palm_mesh.height = 0.145
		palm.mesh = palm_mesh
		palm.scale = Vector3(1.16, 0.86, 1.38)
		palm.material_override = skin_material
		hand_root.add_child(palm)

		var hand_back := MeshInstance3D.new()
		var hand_back_mesh := SphereMesh.new()
		hand_back_mesh.radius = 0.067
		hand_back_mesh.height = 0.072
		hand_back.mesh = hand_back_mesh
		hand_back.scale = Vector3(1.18, 0.52, 1.28)
		hand_back.position = Vector3(0.0, 0.035, -0.025)
		hand_back.material_override = skin_material
		hand_root.add_child(hand_back)

		# Los dedos siguen el eje -Z de la mano (hacia delante), no quedan verticales.
		for finger_index in range(4):
			var finger_x: float = (float(finger_index) - 1.5) * 0.034
			var finger := MeshInstance3D.new()
			var finger_mesh := CapsuleMesh.new()
			finger_mesh.radius = 0.019
			finger_mesh.height = 0.108
			finger.mesh = finger_mesh
			finger.position = Vector3(finger_x, -0.006, -0.105)
			finger.rotation.x = -PI * 0.5
			finger.material_override = skin_material
			hand_root.add_child(finger)

			var knuckle := MeshInstance3D.new()
			var knuckle_mesh := SphereMesh.new()
			knuckle_mesh.radius = 0.021
			knuckle_mesh.height = 0.034
			knuckle.mesh = knuckle_mesh
			knuckle.position = Vector3(finger_x, 0.006, -0.063)
			knuckle.scale = Vector3(1.0, 0.78, 1.0)
			knuckle.material_override = skin_material
			hand_root.add_child(knuckle)

		# Pulgar enfrentado a los otros dedos, con una base más gruesa.
		var thumb := MeshInstance3D.new()
		var thumb_mesh := CapsuleMesh.new()
		thumb_mesh.radius = 0.025
		thumb_mesh.height = 0.12
		thumb.mesh = thumb_mesh
		thumb.position = Vector3(-side * 0.094, -0.006, -0.043)
		thumb.rotation = Vector3(-0.45, 0.0, side * 0.76)
		thumb.material_override = skin_material
		hand_root.add_child(thumb)

		var thumb_pad := MeshInstance3D.new()
		var thumb_pad_mesh := SphereMesh.new()
		thumb_pad_mesh.radius = 0.034
		thumb_pad_mesh.height = 0.052
		thumb_pad.mesh = thumb_pad_mesh
		thumb_pad.position = Vector3(-side * 0.073, -0.002, -0.065)
		thumb_pad.material_override = skin_material
		hand_root.add_child(thumb_pad)

		upper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		forearm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cuff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		palm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_viewmodel_arms[key] = {"upper": upper, "forearm": forearm, "cuff": cuff}
		_viewmodel_hands[key] = hand_root
		_update_viewmodel_arm(key,
			Vector3(side * 0.43, -0.39, -0.43),
			Vector3(side * 0.48, -0.61, -0.64),
			Vector3(side * 0.39, -0.80, -0.84)
		)


func _make_viewmodel_limb(limb_name: String, radius: float, surface: Material) -> MeshInstance3D:
	var limb := MeshInstance3D.new()
	limb.name = limb_name
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = radius * 2.2
	limb.mesh = capsule
	limb.material_override = surface
	limb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return limb


func _pose_viewmodel_capsule(limb: MeshInstance3D, start_point: Vector3, end_point: Vector3, radius: float) -> void:
	var segment: Vector3 = end_point - start_point
	var segment_length: float = maxf(segment.length(), 0.035)
	var capsule := limb.mesh as CapsuleMesh
	if capsule != null:
		capsule.radius = radius
		capsule.height = segment_length + radius * 2.0
	var midpoint: Vector3 = (start_point + end_point) * 0.5
	var limb_basis := Basis(Quaternion(Vector3.UP, segment.normalized()))
	limb.transform = Transform3D(limb_basis, midpoint)


func _update_viewmodel_arm(side: String, shoulder: Vector3, elbow: Vector3, wrist: Vector3) -> void:
	if not _viewmodel_arms.has(side) or not _viewmodel_hands.has(side):
		return
	var parts: Dictionary = _viewmodel_arms[side]
	_pose_viewmodel_capsule(parts["upper"] as MeshInstance3D, shoulder, elbow, 0.102)
	_pose_viewmodel_capsule(parts["forearm"] as MeshInstance3D, elbow, wrist, 0.091)
	var cuff_start: Vector3 = wrist - (wrist - elbow).normalized() * 0.12
	_pose_viewmodel_capsule(parts["cuff"] as MeshInstance3D, cuff_start, wrist, 0.087)
	(_viewmodel_hands[side] as Node3D).position = wrist


func _update_first_person_hands(delta: float) -> void:
	if not is_instance_valid(_viewmodel_root):
		return
	_viewmodel_time += delta
	_viewmodel_root.visible = not _is_in_vehicle and not _is_sleeping
	if not _viewmodel_root.visible:
		return
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	var moving: bool = horizontal_speed > 0.35 and is_on_floor()
	var bob: float = sin(_viewmodel_time * (12.0 if horizontal_speed > run_speed - 0.1 else 8.0)) * (0.018 if moving else 0.004)
	var left_shoulder := Vector3(-0.43, -0.39 + bob, -0.43)
	var left_elbow := Vector3(-0.48, -0.61 + bob, -0.64)
	var left_wrist := Vector3(-0.39, -0.80 + bob, -0.84)
	var right_shoulder := Vector3(0.43, -0.39 + bob, -0.43)
	var right_elbow := Vector3(0.48, -0.61 + bob, -0.64)
	var right_wrist := Vector3(0.39, -0.80 + bob, -0.84)
	var action_phase: float = fposmod(_viewmodel_time, 1.35) / 1.35
	match _animation_state:
		"eat":
			var reach: float = 1.0 - absf(action_phase * 2.0 - 1.0)
			right_elbow = right_elbow.lerp(Vector3(0.24, -0.38, -0.63), 0.80)
			right_wrist = right_wrist.lerp(Vector3(0.11, -0.13 + reach * 0.025, -0.62), 0.96)
			left_wrist = left_wrist.lerp(Vector3(-0.12, -0.58, -0.76), 0.35)
		"exercise":
			var curl: float = 0.5 + 0.5 * sin(_viewmodel_time * 5.0)
			left_elbow.y -= curl * 0.16
			left_wrist.y -= curl * 0.30
			right_elbow.y -= (1.0 - curl) * 0.16
			right_wrist.y -= (1.0 - curl) * 0.30
		"climb":
			left_elbow.y += 0.22
			left_wrist.y += 0.40
			right_elbow.y += 0.22
			right_wrist.y += 0.40
	_update_viewmodel_arm("left", left_shoulder, left_elbow, left_wrist)
	_update_viewmodel_arm("right", right_shoulder, right_elbow, right_wrist)


func _normalize_humanoid_model(model: Node3D) -> void:
	var bounds := _get_model_bounds(model)
	if bounds.size.y <= 0.05:
		model.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(model_front_yaw_degrees)), Vector3.ZERO)
		return

	# La corrección X/Z es opcional para GLB externos con otro eje vertical.
	# Los modelos suministrados ya son Y-up: su corrección correcta es (0,0,0).
	var axis_euler := Vector3(
		deg_to_rad(model_axis_correction_degrees.x),
		deg_to_rad(model_axis_correction_degrees.y),
		deg_to_rad(model_axis_correction_degrees.z)
	)
	var axis_basis := Basis.from_euler(axis_euler)
	var yaw_basis := Basis(Vector3.UP, deg_to_rad(model_front_yaw_degrees))
	var final_basis := yaw_basis * axis_basis
	var corrected_bounds := _transform_aabb(bounds, final_basis)
	var fit_scale := target_model_height / maxf(corrected_bounds.size.y, 0.001)
	fit_scale = clampf(fit_scale, 0.01, 100.0)
	var corrected_center := corrected_bounds.position + corrected_bounds.size * 0.5
	# X/Z centrados; Y se desplaza por el mínimo, no por el centro, para que
	# los pies queden apoyados en Y=0 respecto al CharacterBody3D.
	var model_origin := Vector3(
		-corrected_center.x,
		-corrected_bounds.position.y,
		-corrected_center.z
	) * fit_scale
	model.transform = Transform3D(final_basis.scaled(Vector3.ONE * fit_scale), model_origin)

	# El pivot de sueño se calcula con la AABB ya rotada y con la traslación
	# real del modelo. Así el punto más bajo queda exactamente en el colchón.
	var sleep_rotation := Basis(Vector3.RIGHT, -PI * 0.5)
	var lying_basis := sleep_rotation * final_basis
	var lying_bounds := _transform_aabb(bounds, lying_basis)
	var lying_translation := sleep_rotation * model_origin
	_model_half_depth = maxf(0.0, -(lying_bounds.position.y * fit_scale + lying_translation.y))
	_improve_character_meshes(model)


func _transform_aabb(source: AABB, transform_basis: Basis) -> AABB:
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


func _improve_character_meshes(model: Node3D) -> void:
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var source_material := mesh_instance.mesh.surface_get_material(surface_index)
			if source_material is StandardMaterial3D:
				var material_copy := (source_material as StandardMaterial3D).duplicate() as StandardMaterial3D
				material_copy.roughness = clampf(material_copy.roughness, 0.58, 0.90)
				material_copy.metallic = 0.0
				mesh_instance.set_surface_override_material(surface_index, material_copy)


func _get_model_bounds(model: Node3D) -> AABB:
	var combined := AABB()
	var found_mesh := false
	var mesh_nodes := model.find_children("*", "MeshInstance3D", true, false)
	for node in mesh_nodes:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var mesh_bounds := mesh_instance.get_aabb()
		var local_transform := model.global_transform.affine_inverse() * mesh_instance.global_transform
		for corner_index in range(8):
			var corner := Vector3(
				mesh_bounds.position.x + (mesh_bounds.size.x if (corner_index & 1) != 0 else 0.0),
				mesh_bounds.position.y + (mesh_bounds.size.y if (corner_index & 2) != 0 else 0.0),
				mesh_bounds.position.z + (mesh_bounds.size.z if (corner_index & 4) != 0 else 0.0)
			)
			var point_in_model := local_transform * corner
			if not found_mesh:
				combined = AABB(point_in_model, Vector3.ZERO)
				found_mesh = true
			else:
				combined = combined.expand(point_in_model)
	return combined if found_mesh else AABB()


func _create_fallback_character() -> void:
	var body_mesh := MeshInstance3D.new()
	body_mesh.name = "FallbackBody"
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.31
	capsule.height = 1.48
	body_mesh.mesh = capsule
	body_mesh.position.y = 0.84
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color(0.12, 0.46, 0.72)
	body_material.roughness = 0.68
	body_mesh.material_override = body_material
	visual.add_child(body_mesh)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.22
	head_mesh.height = 0.44
	head.mesh = head_mesh
	head.position.y = 1.67
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.88, 0.66, 0.48)
	head.material_override = skin
	head.visible = false
	visual.add_child(head)


func _setup_character_animations(model: Node3D) -> void:
	var skeleton_nodes := model.find_children("*", "Skeleton3D", true, false)
	if skeleton_nodes.is_empty():
		return
	_skeleton = skeleton_nodes[0] as Skeleton3D
	if _skeleton == null:
		return

	_skeleton_path = visual.get_path_to(_skeleton)
	_build_humanoid_pose_library()
	_animation_player = AnimationPlayer.new()
	_animation_player.name = "CharacterAnimations"
	_animation_player.root_node = NodePath("..")
	visual.add_child(_animation_player)

	var library := AnimationLibrary.new()
	for state in ANIMATION_STATES:
		library.add_animation(state, _make_animation(state))
	_animation_player.add_animation_library("", library)

	var state_machine := AnimationNodeStateMachine.new()
	for state in ANIMATION_STATES:
		var animation_node := AnimationNodeAnimation.new()
		animation_node.animation = StringName(state)
		state_machine.add_node(state, animation_node)

	# Todas las acciones pueden volver a locomoción sin quedarse atrapadas
	# en una transición que no haya sido declarada.
	for from_state in ANIMATION_STATES:
		for to_state in ANIMATION_STATES:
			if from_state == to_state:
				continue
			var transition := AnimationNodeStateMachineTransition.new()
			transition.xfade_time = 0.16
			transition.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
			state_machine.add_transition(from_state, to_state, transition)

	_animation_tree = AnimationTree.new()
	_animation_tree.name = "CharacterAnimationTree"
	_animation_tree.tree_root = state_machine
	_animation_tree.anim_player = NodePath("../CharacterAnimations")
	visual.add_child(_animation_tree)
	_animation_tree.active = true
	_state_playback = _animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	if _state_playback != null:
		_state_playback.start("idle")


func _apply_first_person_head_mask() -> void:
	# Se oculta únicamente la cabeza del modelo durante el gameplay en primera
	# persona. El selector usa instancias independientes y conserva el rostro.
	if _skeleton == null:
		return
	var head_index: int = _skeleton.find_bone("Head")
	if head_index >= 0:
		_skeleton.set_bone_pose_scale(head_index, Vector3(0.001, 0.001, 0.001))
	var neck_index: int = _skeleton.find_bone("neck_01")
	if neck_index >= 0:
		_skeleton.set_bone_pose_scale(neck_index, Vector3(0.32, 0.32, 0.32))


func _make_animation(state: String) -> Animation:
	var animation := Animation.new()
	animation.resource_name = state
	var duration := 2.0
	match state:
		"walk":
			duration = 0.82
		"run":
			duration = 0.58
		"eat":
			duration = 1.45
		"exercise":
			duration = 1.25
		"climb":
			duration = 0.95
		"sleep":
			duration = 3.0
		_:
			duration = 2.4
	animation.length = duration
	animation.loop_mode = Animation.LOOP_NONE if state == "eat" else Animation.LOOP_LINEAR

	var bone_names: Array[String] = [
		"thigh_l", "thigh_r", "calf_l", "calf_r",
		"clavicle_l", "clavicle_r", "upperarm_l", "upperarm_r",
		"lowerarm_l", "lowerarm_r", "hand_l", "hand_r",
		"spine_01", "spine_02", "spine_03", "neck_01", "Head"
	]
	for bone_name in bone_names:
		if _skeleton.find_bone(bone_name) < 0:
			continue
		var track := animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(track, NodePath(str(_skeleton_path) + ":" + bone_name))
		animation.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
		for key_index in range(5):
			var phase := float(key_index) / 4.0
			animation.track_insert_key(track, duration * phase, _bone_rotation_for_state(state, bone_name, phase))
	return animation


# La pose de reposo se calcula a partir de los vectores reales del esqueleto
# importado. No se supone que todos los GLB tengan los mismos ejes de hombro.
func _build_humanoid_pose_library() -> void:
	_arm_rest_poses.clear()
	_arm_eat_poses.clear()
	_arm_climb_poses.clear()

	# El array tipado evita que `side` se infiera como Variant en Godot 4.3.
	var sides: Array[String] = ["l", "r"]
	for side in sides:
		var side_name: String = str(side)
		var upper_name: String = "upperarm_" + side_name
		var lower_name: String = "lowerarm_" + side_name
		var outward: float = 0.14 if side_name == "l" else -0.14
		var down_direction := Vector3(outward, -0.985, 0.015).normalized()
		var down_pose := _calculate_segment_pose(upper_name, lower_name, down_direction)
		_arm_rest_poses[upper_name] = down_pose.get("pose", Quaternion.IDENTITY)

		var climb_direction := Vector3(outward * 0.25, 0.16, 0.987).normalized()
		var climb_pose := _calculate_segment_pose(upper_name, lower_name, climb_direction)
		_arm_climb_poses[upper_name] = climb_pose.get("pose", Quaternion.IDENTITY)

	# Comer: el brazo derecho se orienta hacia delante y el antebrazo hacia
	# arriba/centro. El torso, la cabeza y el brazo izquierdo no se inclinan.
	var eat_upper := _calculate_segment_pose(
		"upperarm_r", "lowerarm_r", Vector3(-0.18, -0.52, 0.835).normalized()
	)
	var eat_parent_delta: Quaternion = eat_upper.get("global_delta", Quaternion.IDENTITY)
	var eat_lower := _calculate_segment_pose(
		"lowerarm_r", "hand_r", Vector3(0.40, 0.67, 0.63).normalized(), eat_parent_delta
	)
	_arm_eat_poses["upperarm_r"] = eat_upper.get("pose", Quaternion.IDENTITY)
	_arm_eat_poses["lowerarm_r"] = eat_lower.get("pose", Quaternion.IDENTITY)


# Convierte una dirección deseada del segmento en una rotación de pose local.
# Skeleton3D define la pose con respecto al rest y a los huesos padre.
func _calculate_segment_pose(
	bone_name: String,
	child_name: String,
	desired_direction: Vector3,
	parent_global_delta: Quaternion = Quaternion.IDENTITY
) -> Dictionary:
	if _skeleton == null:
		return {"pose": Quaternion.IDENTITY, "global_delta": parent_global_delta}
	var bone_index := _skeleton.find_bone(bone_name)
	var child_index := _skeleton.find_bone(child_name)
	if bone_index < 0 or child_index < 0:
		return {"pose": Quaternion.IDENTITY, "global_delta": parent_global_delta}

	var bone_global_rest := _skeleton.get_bone_global_rest(bone_index)
	var child_global_rest := _skeleton.get_bone_global_rest(child_index)
	var segment := child_global_rest.origin - bone_global_rest.origin
	if segment.length_squared() < 0.000001 or desired_direction.length_squared() < 0.000001:
		return {"pose": Quaternion.IDENTITY, "global_delta": parent_global_delta}

	var current_direction := (parent_global_delta * segment).normalized()
	var correction_global := Quaternion(current_direction, desired_direction.normalized())
	var parent_index := _skeleton.get_bone_parent(bone_index)
	var parent_rest_rotation := Quaternion.IDENTITY
	if parent_index >= 0:
		parent_rest_rotation = _skeleton.get_bone_global_rest(parent_index).basis.orthonormalized().get_rotation_quaternion()
	var bone_rest_rotation := _skeleton.get_bone_rest(bone_index).basis.orthonormalized().get_rotation_quaternion()
	var bone_global_rest_rotation := bone_global_rest.basis.orthonormalized().get_rotation_quaternion()
	var parent_actual_rotation := parent_global_delta * parent_rest_rotation
	var bone_target_global_rotation := correction_global * parent_global_delta * bone_global_rest_rotation
	var pose_local := bone_rest_rotation.inverse() * parent_actual_rotation.inverse() * bone_target_global_rotation
	var global_delta := (correction_global * parent_global_delta).normalized()
	return {"pose": pose_local.normalized(), "global_delta": global_delta}


# Todas las rotaciones de animación son poses locales respecto al rest del GLB.
# En idle los brazos quedan junto al torso; al andar solo oscilan unos grados.
func _bone_rotation_for_state(state: String, bone_name: String, phase: float) -> Quaternion:
	var cycle := sin(phase * TAU)
	var half_cycle := sin(phase * TAU + PI * 0.5)
	var is_left := bone_name.ends_with("_l")
	var base_pose: Quaternion = _arm_rest_poses.get(bone_name, Quaternion.IDENTITY)

	if bone_name == "upperarm_l" or bone_name == "upperarm_r":
		var swing := 0.0
		match state:
			"walk":
				swing = cycle * (0.095 if is_left else -0.095)
			"run":
				swing = cycle * (0.16 if is_left else -0.16)
			"exercise":
				swing = 0.18 + 0.035 * cycle
			"climb":
				return _arm_climb_poses.get(bone_name, base_pose)
			"eat":
				if not is_left:
					var eat_pose: Quaternion = _arm_eat_poses.get(bone_name, base_pose)
					return base_pose.slerp(eat_pose, _eat_reach(phase))
			"idle":
				swing = half_cycle * 0.008
		return (base_pose * Quaternion(Vector3(0.0, 0.0, 1.0), swing)).normalized()

	if bone_name == "lowerarm_r" and state == "eat":
		var eat_lower_pose: Quaternion = _arm_eat_poses.get(bone_name, Quaternion.IDENTITY)
		return Quaternion.IDENTITY.slerp(eat_lower_pose, _eat_reach(phase))

	if bone_name == "lowerarm_l" or bone_name == "lowerarm_r":
		var bend := 0.0
		match state:
			"walk":
				bend = 0.035 + absf(cycle) * 0.025
			"run":
				bend = 0.11 + absf(cycle) * 0.045
			"exercise":
				bend = 0.18
			"climb":
				bend = -0.28
		return Quaternion(Vector3.RIGHT, bend)

	if bone_name == "hand_r" and state == "eat":
		return Quaternion(Vector3.RIGHT, -0.08 * _eat_reach(phase))

	if bone_name == "thigh_l" or bone_name == "thigh_r":
		var leg_swing := 0.0
		match state:
			"walk":
				leg_swing = cycle * (0.34 if is_left else -0.34)
			"run":
				leg_swing = cycle * (0.54 if is_left else -0.54)
			"exercise":
				leg_swing = -0.12 + 0.08 * cycle
			"climb":
				leg_swing = cycle * (0.38 if is_left else -0.38)
		return Quaternion(Vector3.RIGHT, leg_swing)

	if bone_name == "calf_l" or bone_name == "calf_r":
		var knee := 0.0
		match state:
			"walk":
				knee = maxf(0.0, cycle if is_left else -cycle) * 0.28
			"run":
				knee = maxf(0.0, cycle if is_left else -cycle) * 0.48
			"climb":
				knee = maxf(0.0, cycle if is_left else -cycle) * 0.62
			"exercise":
				knee = 0.12 + maxf(0.0, cycle) * 0.08
		return Quaternion(Vector3.RIGHT, knee)

	if bone_name.begins_with("spine_"):
		var torso_angle := 0.0
		match state:
			"walk":
				torso_angle = half_cycle * 0.012
			"run":
				torso_angle = 0.022
			"eat":
				torso_angle = 0.0
			"exercise":
				torso_angle = -0.025 * maxf(0.0, cycle)
			"sleep":
				torso_angle = half_cycle * 0.012
			"idle":
				torso_angle = half_cycle * 0.006
		return Quaternion(Vector3.RIGHT, torso_angle)

	if bone_name == "Head" or bone_name == "neck_01":
		if state == "eat":
			return Quaternion(Vector3.RIGHT, 0.025 * sin(phase * TAU))
		if state == "sleep":
			return Quaternion(Vector3.RIGHT, 0.018 * sin(phase * TAU))
	return Quaternion.IDENTITY


func _eat_reach(phase: float) -> float:
	# La mano sube, hace una pausa breve en la boca y vuelve a bajar.
	if phase < 0.28:
		return smoothstep(0.0, 0.28, phase)
	if phase < 0.62:
		return 1.0
	return 1.0 - smoothstep(0.62, 1.0, phase)


func _set_animation(state: String) -> void:
	if state == _animation_state:
		return
	_animation_state = state
	if _state_playback != null:
		_state_playback.travel(state)
	elif _animation_player != null and _animation_player.has_animation(state):
		_animation_player.play(state, 0.16)


func _process(delta: float) -> void:
	# El cursor se captura al iniciar y al cerrar ajustes; TAB permite liberarlo
	# para pulsar los controles del HUD sin que el juego lo recapture cada frame.
	_update_first_person_hands(delta)
	if _is_in_vehicle or _is_sleeping:
		return
	_update_interaction_prompt()

	if Input.is_action_just_pressed("interact"):
		_try_interact()
	if Input.is_action_just_pressed("enter_vehicle"):
		_try_vehicle_interact()
	if Input.is_action_just_pressed("spawn_vehicle"):
		_call_vehicle_spawner("spawn_vehicle", self)
	if Input.is_action_just_pressed("next_vehicle"):
		_call_vehicle_spawner("cycle_vehicle")

	_stats_timer += delta
	if _stats_timer >= 0.30:
		_stats_timer = 0.0
		_emit_stats()


func _physics_process(delta: float) -> void:
	if _is_in_vehicle or _is_sleeping:
		return

	if _is_climbing:
		_update_climbing(delta)
		return

	if Input.is_action_pressed("climb") and _try_begin_climbing():
		_update_climbing(delta)
		return

	var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
	else:
		velocity.y -= gravity * delta

	if _lock_timer > 0.0:
		_lock_timer = maxf(0.0, _lock_timer - delta)
		velocity.x = move_toward(velocity.x, 0.0, 14.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 14.0 * delta)
		move_and_slide()
		return

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var player_basis: Basis = global_transform.basis
	var direction := player_basis * Vector3(input_dir.x, 0.0, input_dir.y)
	direction.y = 0.0
	direction = direction.normalized()

	var moving := direction.length() > 0.08
	var running := Input.is_action_pressed("run")
	var desired_speed := run_speed if running else walk_speed
	if moving:
		var target_velocity := direction * desired_speed
		velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)
		_set_animation("run" if running else "walk")
		hunger = maxf(0.0, hunger - delta * 0.035)
		energy = maxf(0.0, energy - delta * 0.018)
		_footstep_timer -= delta
		if _footstep_timer <= 0.0 and is_on_floor():
			sound_requested.emit("footstep")
			_footstep_timer = 0.31 if running else 0.46
	else:
		_footstep_timer = 0.0
		velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
		energy = minf(100.0, energy + delta * 0.12)
		_set_animation("idle")

	happiness = maxf(0.0, happiness - delta * 0.004)
	move_and_slide()


func _try_begin_climbing() -> bool:
	climb_ray.force_raycast_update()
	if not climb_ray.is_colliding():
		return false
	var collider := climb_ray.get_collider()
	if collider is Node and (collider as Node).is_in_group("escalable"):
		_climb_target = collider
		_climb_top_y = float((collider as Node).get_meta("climb_top_y", global_position.y + 8.0))
		_collision_mask_before_climb = collision_mask
		# El RayCast conserva su propia máscara, pero el CharacterBody deja de
		# empujar contra la pared mientras escala. Sin esto, la cápsula se atasca.
		collision_mask = 0
		_is_climbing = true
		velocity = Vector3.ZERO
		_set_animation("climb")
		sound_requested.emit("climb")
		return true
	return false


func _update_climbing(_delta: float) -> void:
	if not Input.is_action_pressed("climb"):
		_end_climbing()
		return

	var vertical_input: float = 0.0
	if Input.is_action_pressed("move_forward"):
		vertical_input += 1.0
	if Input.is_action_pressed("move_back"):
		vertical_input -= 1.0

	# Al perder el contacto del rayo cerca del borde superior, completar el
	# paso a la azotea antes de salir del estado de escalada.
	var top_threshold: float = _climb_top_y - 0.92
	if not climb_ray.is_colliding():
		if vertical_input > 0.0 and global_position.y >= top_threshold:
			_finish_climb_on_top()
		else:
			_end_climbing()
		return

	var collider: Object = climb_ray.get_collider()
	if collider != _climb_target or not (collider is Node and (collider as Node).is_in_group("escalable")):
		if vertical_input > 0.0 and global_position.y >= top_threshold:
			_finish_climb_on_top()
		else:
			_end_climbing()
		return

	velocity = Vector3(0.0, vertical_input * climb_speed, 0.0)
	move_and_slide()

	if vertical_input > 0.0 and global_position.y >= top_threshold:
		_finish_climb_on_top()
		return
	if vertical_input < 0.0 and global_position.y <= 0.08:
		_end_climbing()
		return
	if vertical_input == 0.0:
		velocity.y = 0.0
	_set_animation("climb")


func _finish_climb_on_top() -> void:
	# La base de la cápsula queda sobre el plano superior y el jugador avanza
	# ligeramente hacia dentro para no reaparecer suspendido delante del muro.
	global_position.y = _climb_top_y + 0.05
	global_position += -global_transform.basis.z.normalized() * 0.72
	_end_climbing()


func _end_climbing() -> void:
	_is_climbing = false
	_climb_target = null
	_climb_top_y = INF
	velocity.y = 0.0
	collision_mask = _collision_mask_before_climb
	_set_animation("idle")

func _input(event: InputEvent) -> void:
	if _is_sleeping or _is_in_vehicle or get_tree().paused:
		return
	# El ratón es exclusivo para mirar. TAB libera/captura el cursor sin bloquear
	# los botones del HUD ni las teclas de desplazamiento.
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mouse_motion := event as InputEventMouseMotion
		# El eje horizontal del ratón orienta al jugador; las teclas solo desplazan.
		rotation.y = wrapf(rotation.y - mouse_motion.relative.x * MOUSE_SENSITIVITY, -PI, PI)
		camera_pivot.rotation.x = clampf(
			camera_pivot.rotation.x - mouse_motion.relative.y * MOUSE_SENSITIVITY,
			deg_to_rad(-88.0),
			deg_to_rad(88.0)
		)

func _resolve_interactable(area: Area3D) -> Node:
	if area.has_method("interact"):
		return area
	var parent := area.get_parent()
	if parent != null and parent.has_method("interact"):
		return parent
	return null


func _update_interaction_prompt() -> void:
	var best_target: Node
	var best_is_vehicle := false
	var best_distance := INF
	for area in interaction_area.get_overlapping_areas():
		var target := _resolve_interactable(area)
		if target == null or not target.has_method("interaction_label"):
			continue
		var is_vehicle := target.is_in_group("vehicles")
		var distance := global_position.distance_to((target as Node3D).global_position) if target is Node3D else INF
		if distance < best_distance:
			best_distance = distance
			best_target = target
			best_is_vehicle = is_vehicle
	var next_prompt := ""
	if best_target != null:
		next_prompt = ("F  -  " if best_is_vehicle else "E  -  ") + str(best_target.call("interaction_label"))
	if next_prompt != _current_prompt:
		_current_prompt = next_prompt
		prompt_changed.emit(_current_prompt)


func _try_interact() -> void:
	var best_target: Node
	var best_distance := INF
	for area in interaction_area.get_overlapping_areas():
		var target := _resolve_interactable(area)
		if target == null or target.is_in_group("vehicles") or not target.has_method("interact"):
			continue
		var distance := global_position.distance_to((target as Node3D).global_position) if target is Node3D else INF
		if distance < best_distance:
			best_distance = distance
			best_target = target
	if best_target != null:
		sound_requested.emit("interact")
		best_target.call("interact", self)


func _try_vehicle_interact() -> void:
	var best_vehicle: Node
	var best_distance := INF
	for area in interaction_area.get_overlapping_areas():
		var target := _resolve_interactable(area)
		if target == null or not target.is_in_group("vehicles"):
			continue
		var distance := global_position.distance_to((target as Node3D).global_position) if target is Node3D else INF
		if distance < best_distance:
			best_distance = distance
			best_vehicle = target
	if best_vehicle != null and best_vehicle.has_method("enter_driver"):
		best_vehicle.call("enter_driver", self)
	else:
		prompt_changed.emit("No hay un vehículo cerca. Pulsa G para crear uno.")


func _call_vehicle_spawner(method_name: String, argument: Variant = null) -> void:
	for spawner in get_tree().get_nodes_in_group("vehicle_spawner"):
		if spawner.has_method(method_name):
			if argument == null:
				spawner.call(method_name)
			else:
				spawner.call(method_name, argument)
			return


func _emit_stats() -> void:
	stats_changed.emit(hunger, energy, happiness, fitness)


func eat_food(_food_name: String, hunger_gain: float, energy_gain: float, happiness_gain: float) -> void:
	if _is_sleeping or _is_in_vehicle:
		return
	hunger = clampf(hunger + hunger_gain, 0.0, 100.0)
	energy = clampf(energy + energy_gain, 0.0, 100.0)
	happiness = clampf(happiness + happiness_gain, 0.0, 100.0)
	_lock_timer = 1.45
	_set_animation("eat")
	sound_requested.emit("eat")
	_emit_stats()


func perform_exercise(_exercise_name: String, fitness_gain: float) -> void:
	if energy < 8.0:
		prompt_changed.emit("Necesitas descansar o comer antes de entrenar.")
		return
	fitness = clampf(fitness + fitness_gain, 0.0, 100.0)
	energy = maxf(0.0, energy - 13.0)
	hunger = maxf(0.0, hunger - 7.0)
	happiness = clampf(happiness + 9.0, 0.0, 100.0)
	_lock_timer = 1.25
	_set_animation("exercise")
	sound_requested.emit("workout")
	_emit_stats()


func sleep(bed_position: Vector3 = Vector3.ZERO) -> void:
	if _is_sleeping or _is_in_vehicle:
		return
	_is_sleeping = true
	if is_instance_valid(_viewmodel_root):
		_viewmodel_root.visible = false
	_is_climbing = false
	_climb_target = null
	velocity = Vector3.ZERO
	_lock_timer = 0.0
	if bed_position == Vector3.ZERO:
		bed_position = global_position

	# El avatar de gameplay es una cámara con viewmodel de brazos. Al dormir
	# escondemos las manos y orientamos la vista hacia el techo/cielo.
	body_collision.set_deferred("disabled", true)
	interaction_area.monitoring = false
	collision_layer = 0
	collision_mask = 0
	global_position = bed_position + Vector3(0.0, 0.73 + _model_half_depth, 0.50)
	visual.position = Vector3.ZERO
	visual.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	camera_pivot.position = Vector3(0.0, 0.88, 0.12)
	camera_pivot.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	_set_animation("sleep")
	sound_requested.emit("sleep")

	await get_tree().create_timer(3.4).timeout
	if not is_inside_tree():
		return

	energy = 100.0
	hunger = maxf(0.0, hunger - 8.0)
	happiness = clampf(happiness + 12.0, 0.0, 100.0)
	time_skip_requested.emit(8.0)
	visual.rotation = Vector3.ZERO
	visual.position = Vector3.ZERO
	global_position = bed_position + Vector3(2.2, 0.03, 1.25)
	# Punto de vista en el espacio libre de la cabeza: el cuerpo importado no se
	# renderiza durante gameplay. Solo se dibujan brazos/manos en espacio de cámara.
	camera_pivot.position = Vector3(0.0, 1.64, 0.0)
	camera_pivot.rotation = Vector3.ZERO
	camera.position = Vector3.ZERO
	camera.fov = 82.0
	collision_layer = 1
	collision_mask = 1
	body_collision.set_deferred("disabled", false)
	interaction_area.monitoring = true
	_is_sleeping = false
	visual.visible = false
	if is_instance_valid(_viewmodel_root):
		_viewmodel_root.visible = true
	_set_animation("idle")
	_emit_stats()
	prompt_changed.emit("Descansaste 8 horas. ¡Energía recuperada!")


func register_crystal() -> void:
	crystals += 1
	crystals_updated.emit(crystals)
	sound_requested.emit("collect")


func teleport_to(destination: Vector3) -> void:
	velocity = Vector3.ZERO
	global_position = destination


func begin_driving(vehicle: Node3D) -> void:
	_active_vehicle = vehicle
	_is_in_vehicle = true
	_is_climbing = false
	_climb_target = null
	collision_layer = 0
	collision_mask = 0
	body_collision.set_deferred("disabled", true)
	interaction_area.monitoring = false
	visual.visible = false
	if is_instance_valid(_viewmodel_root):
		_viewmodel_root.visible = false
	camera.current = false
	set_physics_process(false)
	set_process(false)
	set_process_input(false)


func end_driving(exit_position: Vector3) -> void:
	_active_vehicle = null
	_is_in_vehicle = false
	global_position = exit_position
	velocity = Vector3.ZERO
	collision_layer = 1
	collision_mask = 1
	body_collision.set_deferred("disabled", false)
	interaction_area.monitoring = true
	visual.visible = false
	if is_instance_valid(_viewmodel_root):
		_viewmodel_root.visible = true
	camera_pivot.rotation.y = 0.0
	set_physics_process(true)
	set_process(true)
	set_process_input(true)
	camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

