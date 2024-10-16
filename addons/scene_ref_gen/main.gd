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
	var script_path: StringName = &''
	
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
	
	func add_parsed_typedef(typedef_line: String) -> bool:
		var regex := RegEx.new()
		regex.compile('const\\s*{0}\\s*=\\s*preload\\([\'"](.*)[\'"]\\)'.format([type]))
		var result := regex.search(typedef_line)
		if result == null:
			return false
		script_path = result.strings[1]
		return true
	
	func is_valid_for(component: Node) -> bool:
		const Outer = preload('res://addons/scene_ref_gen/main.gd')
		
		var component_script_path: StringName
		if component.get_script() != null:
			component_script_path = (component.get_script() as Script).resource_path
		else:
			component_script_path = ''
		
		return (
			component.name == component_name and
			Outer._get_component_type(component) == type and
			component_script_path == script_path
		)


const ComponentsInspector = preload('res://addons/scene_ref_gen/inspector/inspector.gd')

const REGION_NAME = 'ComponentReferences'

var _components_inspector: ComponentsInspector

var _expanded_by_default := true


func _get_unique_nodes(root: Node, owner_node: Node) -> Array[Node]:
	var nodes: Array[Node] = []
	for child in root.get_children():
		if child.unique_name_in_owner and child.owner == owner_node:
			nodes.append(child)
		nodes.append_array(_get_unique_nodes(child, owner_node))
	return nodes


func _find_region_start_line(source_code: String) -> int:
	var lines := source_code.split('\n')
	for i in range(len(lines)):
		if lines[i].begins_with('#region ' + REGION_NAME):
			return i
	return -1


func _find_type_definition_line_number(
	source_code: String, 
	type: StringName, 
	region_start_line: int = -1
) -> int:
	var lines := source_code.split('\n')
	var regex := RegEx.new()
	regex.compile('const\\s*{0}\\s*=\\s*preload\\([\'"].*[\'"]\\)'.format([type]))
	if region_start_line == -1:
		region_start_line = _find_region_start_line(source_code)
	for i in range(region_start_line + 1, len(lines)):
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
			
			var type_def_line := _find_type_definition_line_number(code_edit.text, ref_info.type, region_start_line)
			
			if state == ReferenceState.NONE:
				code_edit.remove_line_at(i)
				if type_def_line != -1:
					code_edit.remove_line_at(type_def_line)
			else:
				var component := root.get_node('%' + component_name)
				var type := _get_component_type(component)
				var private_prefix := '_' if state == ReferenceState.PRIVATE else ''
				code_edit.set_line(i, '@onready var {0}{1}: {2} = %{3}'.format(
					[private_prefix, ref_info.variable_name, type, ref_info.component_name
				]))
				if not _is_component_type_global(component):
					var type_def := 'const {0} = preload("{1}")'.format([
						type, (component.get_script() as Script).resource_path
					])
					if type_def_line != -1:
						code_edit.set_line(type_def_line, type_def)
					else:
						code_edit.insert_line_at(i, type_def)
				elif type_def_line != -1:
					code_edit.remove_line_at(type_def_line)
			
			return
	
	#EditorInterface.save_scene()



func _replace_reference_node_name(new_name: StringName, old_name: StringName) -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null or root.get_script() == null:
		return
	
	var script := root.get_script() as Script
	
	var script_editor := EditorInterface.get_script_editor()
	EditorInterface.edit_script(script)
	var code_edit: CodeEdit = script_editor.get_current_editor().get_base_editor()
	if '%' + old_name + '\n' not in code_edit.text:
		return		
	EditorInterface.edit_script(script, _find_region_start_line(code_edit.text))
	EditorInterface.mark_scene_as_unsaved()
	code_edit.text = code_edit.text.replace('%' + old_name + '\n', '%' + new_name + '\n')


func _on_unique_node_renamed(node: Node, old_name: StringName) -> void:
	assert(not node.renamed.is_connected(_on_unique_node_renamed.bind(node, node.name)))
	_replace_reference_node_name(node.name, old_name)
	node.renamed.connect(_on_unique_node_renamed.bind(node, node.name), CONNECT_ONE_SHOT)


func _update(_arg: Variant=null) -> void:
	var root := EditorInterface.get_edited_scene_root()
	
	if root.get_script() == null:
		return
	
	if root.scene_file_path == '':  # Scene which is not saved to disk yet
		# FIXME: obviously this isn't ideal, but when there is an inherited scene I don't know
		# how to check for that without it being saved
		return 
	
	var bundled := (load(root.scene_file_path) as PackedScene)._bundled
	if root.get_script() not in (bundled['variants'] as Array):
		return  # Script is from an inherited scene, ignore it then
	
	var unique_nodes = _get_unique_nodes(root, root)
	var unique_names: Array[StringName]
	for node in _get_unique_nodes(root, root):
		if not node.renamed.is_connected(_on_unique_node_renamed.bind(node, node.name)):
			node.renamed.connect(_on_unique_node_renamed.bind(node, node.name), CONNECT_ONE_SHOT)
		unique_names.append(node.name)
	
	var ref_states := {}
	for node_name in unique_names:
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
				
				var typedef_line_number := _find_type_definition_line_number(
					script.source_code, ref_info.type, region_start_line
				)
				if typedef_line_number != -1:
					ref_info.add_parsed_typedef(lines[typedef_line_number])
				
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
