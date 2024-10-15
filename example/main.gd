extends CharacterBody2D


#region ComponentReferences
# This region is generated automatically, but you can safely move it's location in the script
const HealthControllerComponent = preload("res://example/health_control.gd")
@onready var _health_controller: HealthControllerComponent = %HealthController
const OneshotAreaComponent = preload("res://example/oneshot_area.gd")
@onready var area: OneshotAreaComponent = %OneshotArea
#endregion


func _ready() -> void:
	# Doesn't work with static type checking
	# print('I have {0} hp!'.format([%HealthController.hp]))
	
	# Works with static type checking
	print('I have {0} hp!'.format([_health_controller.hp]))
