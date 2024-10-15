extends Area2D

@export var oneshot := false


func _ready() -> void:
	if oneshot:
		self.area_entered.connect(queue_free)
		self.body_entered.connect(queue_free)
