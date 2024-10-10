extends Node2D

@export var a: int
@export var b: int
#@export var array: Array[NodePath]
@export var limited_array: Array[NodePath]
@export var dict: Dictionary
@export_custom(PROPERTY_HINT_NODE_PATH_VALID_TYPES, 'int') var custom_limited_path: NodePath
@export_node_path('Node2D', 'AnimationMixer') var limited_path: NodePath
@export_node_path var unlimited_path: NodePath
@export var another: Node
@export var resource_with_paths: Resource
@export var int_array: Array[int]

# Called when the node enters the scene tree for the first time.
#func _ready() -> void:
	#print(array)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
