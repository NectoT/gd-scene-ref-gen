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
	if object != EditorInterface.get_edited_scene_root() or object.get_script() == null:
		return false
	
	var root := EditorInterface.get_edited_scene_root()
	
	if root.scene_file_path == '':  # Scene which is not saved to disk yet
		# FIXME: obviously this isn't ideal, but when there is an inherited scene I don't know
		# how to check for that without it being saved
		return false
	
	var bundled := (load(root.scene_file_path) as PackedScene)._bundled
	if root.get_script() not in (bundled['variants'] as Array):
		return false  # Script is from an inherited scene, ignore it then
	
	return true


func _parse_begin(object: Object) -> void:
	_control = ComponentInspectorControlScene.instantiate()
	add_custom_control(_control)
	await _control.ready
	control_created.emit()
