extends Area3D
class_name GymLifeMachine

var machine_name: String = "Entrenar"
var fitness_gain: float = 8.0
var _cooldown: float = 0.0


func setup(label_text: String, gain: float) -> void:
	machine_name = label_text
	fitness_gain = gain


func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)


func interaction_label() -> String:
	return "Usar " + machine_name


func interact(player: Node) -> void:
	if _cooldown > 0.0:
		return
	if player.has_method("perform_exercise"):
		player.perform_exercise(machine_name, fitness_gain)
		_cooldown = 2.5
