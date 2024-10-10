extends CharacterBody2D


#region ComponentReferences
# This region is generated automatically, but you can safely move it's location in the script
@onready var _data: Node = %Data
const HealthControllerComponent = preload("res://health_control.gd")
@onready var _health_controller: HealthControllerComponent = %HealthController
#endregion
