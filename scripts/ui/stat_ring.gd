extends Control
class_name GymLifeStatRing

@export var ring_color: Color = Color(0.28, 0.83, 0.70)
@export var ring_thickness: float = 6.0

var progress: float = 1.0
var _tween: Tween


func _ready() -> void:
    custom_minimum_size = Vector2(76, 76)
    queue_redraw()


func set_progress(value: float) -> void:
    var target := clampf(value / 100.0, 0.0, 1.0)
    if _tween != null and _tween.is_running():
        _tween.kill()
    _tween = create_tween()
    _tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    _tween.tween_property(self, "progress", target, 0.28)


func _process(_delta: float) -> void:
    queue_redraw()


func _draw() -> void:
    var center := size * 0.5
    var radius := minf(size.x, size.y) * 0.38
    draw_arc(center, radius, 0.0, TAU, 64, Color(0.22, 0.27, 0.32, 0.9), ring_thickness, true)
    if progress > 0.001:
        draw_arc(
            center,
            radius,
            -PI * 0.5,
            -PI * 0.5 + TAU * progress,
            64,
            ring_color,
            ring_thickness,
            true
        )
