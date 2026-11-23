extends Area3D
class_name GymLifeSleepSpot

@export var mattress_root_offset: Vector3 = Vector3(0.0, 1.0, 0.0)
var label_text: String = "Dormir"


func setup(prompt_text: String = "Dormir y recuperar energía") -> void:
	label_text = prompt_text


func interaction_label() -> String:
	return label_text


func interact(player: Node) -> void:
	if player != null and player.has_method("sleep"):
		var bed_position := global_position - mattress_root_offset
		player.call("sleep", bed_position)
