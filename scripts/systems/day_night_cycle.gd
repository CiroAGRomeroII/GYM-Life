extends Node
class_name GymLifeDayNightCycle

signal time_changed(hours: float, clock_text: String)

@export_range(4.0, 90.0, 1.0) var full_day_minutes: float = 24.0
@export_range(0.0, 23.99, 0.25) var start_hour: float = 8.0

var time_hours: float = 8.0
var _sun: DirectionalLight3D
var _environment: Environment
var _sky_material: ProceduralSkyMaterial


func configure(sun: DirectionalLight3D, world_environment: WorldEnvironment) -> void:
	_sun = sun
	_environment = world_environment.environment if is_instance_valid(world_environment) else null
	_sky_material = null
	if _environment != null and _environment.sky != null:
		var sky_resource: Material = _environment.sky.sky_material
		if sky_resource is ProceduralSkyMaterial:
			_sky_material = sky_resource as ProceduralSkyMaterial
	time_hours = start_hour
	_apply_lighting()


func _process(delta: float) -> void:
	if full_day_minutes <= 0.0:
		return
	var hours_per_second: float = 24.0 / (full_day_minutes * 60.0)
	time_hours = fposmod(time_hours + hours_per_second * delta, 24.0)
	_apply_lighting()


func advance_hours(amount: float) -> void:
	time_hours = fposmod(time_hours + amount, 24.0)
	_apply_lighting()


func get_clock_text() -> String:
	var total_minutes: int = posmod(int(round(time_hours * 60.0)), 24 * 60)
	var hour_value: int = int(floor(float(total_minutes) / 60.0))
	var minute_value: int = posmod(total_minutes, 60)
	return "%02d:%02d" % [hour_value, minute_value]


func _apply_lighting() -> void:
	# Daylight reaches 1 at noon and 0 at night. Smooth curves avoid abrupt
	# luminance changes while preserving a readable nighttime ambient level.
	var daylight: float = clampf(sin((time_hours - 6.0) * PI / 12.0), 0.0, 1.0)
	var twilight: float = maxf(
		1.0 - clampf(absf(time_hours - 6.0) / 2.0, 0.0, 1.0),
		1.0 - clampf(absf(time_hours - 18.0) / 2.0, 0.0, 1.0)
	)

	if is_instance_valid(_sun):
		_sun.rotation_degrees.x = -90.0 + (time_hours - 12.0) * 15.0
		_sun.light_energy = lerpf(0.035, 1.05, daylight)
		_sun.light_color = Color(0.48, 0.56, 0.72).lerp(Color(1.0, 0.965, 0.91), daylight)
		_sun.shadow_enabled = daylight > 0.12

	if _environment != null:
		_environment.ambient_light_energy = lerpf(0.32, 0.76, daylight)
		_environment.ambient_light_color = Color(0.25, 0.31, 0.43).lerp(
			Color(0.68, 0.73, 0.78), daylight
		)

	if _sky_material != null:
		_sky_material.sky_top_color = Color(0.025, 0.045, 0.085).lerp(
			Color(0.30, 0.49, 0.66), daylight
		)
		_sky_material.sky_horizon_color = Color(0.10, 0.13, 0.19).lerp(
			Color(0.72, 0.78, 0.82), daylight
		)
		if twilight > 0.01:
			_sky_material.sky_horizon_color = _sky_material.sky_horizon_color.lerp(
				Color(0.82, 0.48, 0.34), twilight * 0.30
			)
	time_changed.emit(time_hours, get_clock_text())
