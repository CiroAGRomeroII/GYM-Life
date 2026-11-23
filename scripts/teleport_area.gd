extends Area3D
class_name GymLifeTeleportArea

var destination: Vector3 = Vector3.ZERO
var prompt_text: String = "Entrar"


func setup(target: Vector3, label_text: String) -> void:
	destination = target
	prompt_text = label_text


func interaction_label() -> String:
	return prompt_text


func interact(player: Node) -> void:
	if player.has_method("teleport_to"):
		player.teleport_to(destination)
