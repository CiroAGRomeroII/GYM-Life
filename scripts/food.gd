extends Area3D
class_name GymLifeFood

var food_name: String = "Comida"
var hunger_gain: float = 20.0
var energy_gain: float = 4.0
var happiness_gain: float = 4.0


func setup(name_text: String, hunger_value: float, energy_value: float, happiness_value: float) -> void:
	food_name = name_text
	hunger_gain = hunger_value
	energy_gain = energy_value
	happiness_gain = happiness_value


func interaction_label() -> String:
	return "Comer " + food_name


func interact(player: Node) -> void:
	if player.has_method("eat_food"):
		player.eat_food(food_name, hunger_gain, energy_gain, happiness_gain)
	queue_free()
