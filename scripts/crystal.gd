extends Area3D
class_name GymLifeCrystal

signal collected(player: Node)

@onready var crystal_mesh: MeshInstance3D = $CrystalMesh
var _age: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_age += delta
	crystal_mesh.rotate_y(delta * 1.35)
	crystal_mesh.position.y = 0.9 + sin(_age * 2.2) * 0.13


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		collected.emit(body)
		queue_free()
