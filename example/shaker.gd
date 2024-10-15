extends Node

@export var shaked_node: Node2D

var shake_amount: float = 0


func _physics_process(delta: float) -> void:
	var dir := Vector2.from_angle(randf_range(0, 2 * PI))
	shaked_node.global_position += dir * randf_range(-shake_amount, shake_amount) * delta
