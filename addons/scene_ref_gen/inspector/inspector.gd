extends EditorInspectorPlugin

signal control_created

const ComponentInspectorControlScene = preload('res://addons/scene_ref_gen/inspector/ComponentsInspectorControl.tscn')
const ComponentInspectorControl = preload('res://addons/scene_ref_gen/inspector/components_inspector_control.gd')

var _control: ComponentInspectorControl

func has_control() -> bool:
	return _control != null


func get_control() -> ComponentInspectorControl:
	return _control


func _can_handle(object: Object) -> bool:
	return object == EditorInterface.get_edited_scene_root() and object.get_script() != null


func _parse_begin(object: Object) -> void:
	_control = ComponentInspectorControlScene.instantiate()
	add_custom_control(_control)
	await _control.ready
	control_created.emit()
