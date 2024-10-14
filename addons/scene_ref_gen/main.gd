@tool
extends EditorPlugin

enum ReferenceState {
	NONE = 0,
	PRIVATE = 1,
	PUBLIC = 2
}


class ReferenceInfo:
	var private: bool
	var variable_name: String
	var component_name: StringName
	var type: StringName
	
	static func parse(line: String) -> ReferenceInfo:
		var regex := RegEx.new()
		regex.compile(
			'@onready\\s*var\\s*(?<private>_)?(?<variable_name>\\w*)\\s*:\\s*(?<type>\\w*)\\s*=\\s*%(?<component_name>\\w*)\\s*'
		)
		var result := regex.search(line)
		if result == null:
			return null
		
		var ref_info := ReferenceInfo.new()
		ref_info.private = result.get_string('private') == '_'
		ref_info.variable_name = result.get_string('variable_name')
		ref_info.type = result.get_string('type')
		ref_info.component_name = result.get_string('component_name')
		return ref_info
	
	func is_valid_for(component: Node) -> bool:
		const Outer = preload('res://addons/scene_ref_gen/main.gd')
		return (
			component.name == component_name and
			Outer._get_component_type(component) == type
		)


const ComponentsInspector = preload('res://addons/scene_ref_gen/inspector/inspector.gd')

const REGION_NAME = 'ComponentReferences'

var _components_inspector: ComponentsInspector

var _expanded_by_default := true


func _get_unique_names(root: Node, owner_node: Node) -> Array[StringName]:
	var names: Array[StringName] = []
	for child in root.get_children():
		if child.unique_name_in_owner and child.owner == owner_node:
			names.append(child.name)
		names.append_array(_get_unique_names(child, owner_node))
	return names


func _find_region_start_line(source_code: String) -> int:
	var lines := source_code.split('\n')
	for i in range(len(lines)):
		if lines[i].begins_with('#region ' + REGION_NAME):
			return i
	return -1


func _find_type_definition_line(source_code: String, type: StringName) -> int:
	var lines := source_code.split('\n')
	var regex := RegEx.new()
	regex.compile('const\\s*{0}\\s*=\\s*preload\\([\'"].*[\'"]\\)'.format([type]))
	for i in range(_find_region_start_line(source_code) + 1, len(lines)):
		if regex.search(lines[i]) != null:
			return i
	return -1


func _is_component_type_global(component: Node) -> bool:
	return (
		component.get_script() == null or 
		(component.get_script() as Script).get_global_name() != &''
	)


static func _get_component_type(component: Node) -> StringName:
	var type: StringName
	if component.get_script() == null:
		type = component.get_class()
	else:
		var component_script := component.get_script() as Script
		if component_script.get_global_name() != &'':
			type = component_script.get_global_name()
		else:
			var path := component_script.resource_path
			type = component.name + 'Component'
	
	return type


func _update_reference(component_name: StringName, state: ReferenceState) -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root.get_script() == null:
		return
	
	var script := root.get_script() as Script
	EditorInterface.edit_script(script)
	EditorInterface.mark_scene_as_unsaved()
	
	var code_edit: CodeEdit = EditorInterface.get_script_editor().get_current_editor().get_base_editor()
	var region_start_line = _find_region_start_line(code_edit.text)
	if region_start_line == -1:
		region_start_line = code_edit.get_line_count()
		code_edit.text += '\n'.join([
			'',
			'#region ' + REGION_NAME,
			'# This region is generated automatically, but you can safely move its location in the script',
			'#endregion'
		])
	
	for i in range(region_start_line + 1, code_edit.get_line_count()):
		if code_edit.get_line(i).begins_with('#endregion'):
			if state == ReferenceState.NONE:
				return
			
			EditorInterface.edit_script(script, i)
			
			var component := root.get_node('%' + component_name)
			var private_prefix := '_' if state == ReferenceState.PRIVATE else ''
			var type: StringName = _get_component_type(component)
			code_edit.insert_line_at(i, '@onready var {0}{1}: {2} = %{3}'.format([
				private_prefix, component_name.to_snake_case(), type, component_name
			]))
			if not _is_component_type_global(component):
				code_edit.insert_line_at(i, 'const {0} = preload("{1}")'.format([
					type, (component.get_script() as Script).resource_path
				]))
			return
		
		var ref_info := ReferenceInfo.parse(code_edit.get_line(i))
		if ref_info != null and ref_info.component_name == component_name:
			EditorInterface.edit_script(script, i)
			
			var type_def_line := _find_type_definition_line(code_edit.text, ref_info.type)
			
			if state == ReferenceState.NONE:
				code_edit.remove_line_at(i)
			else:
				var component := root.get_node('%' + component_name)
				var type := _get_component_type(component)
				var private_prefix := '_' if state == ReferenceState.PRIVATE else ''
				code_edit.set_line(i, '@onready var {0}{1}: {2} = %{3}'.format(
					[private_prefix, ref_info.variable_name, type, ref_info.component_name
				]))
				if not _is_component_type_global(component)and type_def_line == -1:
					code_edit.insert_line_at(i, 'const {0} = preload("{1}")'.format([
						type, (component.get_script() as Script).resource_path
					]))
			
			if (
				state == ReferenceState.NONE or 
				ref_info.type != _get_component_type(root.get_node('%' + component_name))
			):
				if type_def_line != -1:
					code_edit.remove_line_at(type_def_line)
			
			return
	
	#EditorInterface.save_scene()


func _update(_arg: Variant=null) -> void:
	var root := EditorInterface.get_edited_scene_root()
	
	if root.get_script() == null:
		return
	
	var bundled := (load(root.scene_file_path) as PackedScene)._bundled
	if root.get_script() not in (bundled['variants'] as Array):
		return  # Script is from an inherited scene, ignore it then
	
	var ref_states := {}
	for node_name in _get_unique_names(root, root):
		ref_states[node_name] = ReferenceState.NONE
	
	var script := root.get_script() as Script
	var lines := script.source_code.split('\n')
	var region_start_line := _find_region_start_line(script.source_code)
	if region_start_line != -1:
		for i in range(region_start_line + 1, len(lines)):
			if lines[i].begins_with('#endregion'):
				break
			var ref_info := ReferenceInfo.parse(lines[i])
			if ref_info != null:
				if ref_info.component_name not in ref_states:
					_update_reference(ref_info.component_name, ReferenceState.NONE)
					continue
				
				var state: ReferenceState
				if ref_info.private:
					state = ReferenceState.PRIVATE
					ref_states[ref_info.component_name] = state
				else:
					state = ReferenceState.PUBLIC
					ref_states[ref_info.component_name] = state
				var component := root.get_node('%' + ref_info.component_name)
				if not ref_info.is_valid_for(component):
					_update_reference(ref_info.component_name, state)
	
	if _components_inspector.has_control():
		var control := _components_inspector.get_control()
		for ref in ref_states:
			control.set_component_state(ref, ref_states[ref])


func _on_control_created() -> void:
	_components_inspector.get_control().reference_state_changed.connect(_update_reference)
	_components_inspector.get_control().expanded.connect(
		func(is_expanded: bool): _expanded_by_default = is_expanded
	)
	_components_inspector.get_control().ui_expanded = _expanded_by_default
	_update()


func _enter_tree() -> void:
	_components_inspector = ComponentsInspector.new()
	add_inspector_plugin(_components_inspector)
	scene_changed.connect(_update)
	scene_saved.connect(_update)
	_components_inspector.control_created.connect(_on_control_created)


func _exit_tree() -> void:
	remove_inspector_plugin(_components_inspector)
