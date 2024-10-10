@tool
extends VBoxContainer

class ReferenceStateRow:
	var component_name: StringName
	
	var label: Label
	
	var buttons: Array[CheckBox]
	
	const node_count := 4


enum ReferenceState {
	NONE = 0,
	PRIVATE = 1,
	PUBLIC = 2
}

signal reference_state_changed(component: StringName, new_state: ReferenceState)
signal expanded(is_expanded: bool)

var ui_expanded: bool:
	set(value):
		if not is_node_ready():
			await ready
		_expand_button.button_pressed = value
		_set_expanded(value)
	get:
		return _expand_button.button_pressed

var _component_rows: Array[ReferenceStateRow]

#region ComponentReferences
# This region is generated automatically, but you can safely move it's location in the script
@onready var _component_label_template: Label = %ComponentLabelTemplate
@onready var _radio_button_template: CheckBox = %RadioButtonTemplate
@onready var _expand_button: Button = %ExpandButton
@onready var _references_grid_container: GridContainer = %ReferencesGridContainer
#endregion

@onready var _component_rows_starting_index = _references_grid_container.get_child_count()


func _ready() -> void:
	_expand_button.icon = get_theme_icon('GuiTreeArrowDown', 'EditorIcons')


func _create_component_rows(component_name: StringName, state: ReferenceState) -> void:
	var label := _component_label_template.duplicate() as Label
	label.visible = true
	label.text = component_name
	label.tooltip_text = component_name
	var button_group = ButtonGroup.new()
	var buttons: Array[CheckBox]
	for i in range(3):
		var button := _radio_button_template.duplicate() as CheckBox
		button.visible = true
		button.button_group = button_group
		button.button_pressed = state == i
		button.pressed.connect(func(): reference_state_changed.emit(component_name, i))
		buttons.append(button)
	
	for i in range(len(_component_rows)):
		var row = _component_rows[i]
		if String(component_name) < String(row.component_name):
			_references_grid_container.add_child(label)
			_references_grid_container.move_child(
				label, _component_rows_starting_index + i * ReferenceStateRow.node_count
			)
			break
	
	if label.get_parent() == null:
		_references_grid_container.add_child(label)
	
	label.add_sibling(buttons[0])
	buttons[0].add_sibling(buttons[1])
	buttons[1].add_sibling(buttons[2])
	
	var new_row := ReferenceStateRow.new()
	new_row.component_name = component_name
	new_row.label = label
	new_row.buttons = buttons
	_component_rows.insert(
		(label.get_index() - _component_rows_starting_index) / ReferenceStateRow.node_count, new_row
	)


func _get_row_for_component(component_name: StringName) -> ReferenceStateRow:
	for row in _component_rows:
		if row.component_name == component_name:
			return row
	return null


func set_component_state(name: StringName, state: ReferenceState) -> void:
	var row := _get_row_for_component(name)
	if row != null:
		row.buttons[state].button_pressed = true
	else:
		_create_component_rows(name, state)


# In theory this method is useful to remove components that do not have unique
# names anymore, and as such need to be removed from UI. In practice, when a node
# is revoked of its name, it's usually done from the Editor, and the root node
# loses focus when that happens, so the UI will be created anew anyway.
#func remove_component(name: StringName) -> void:
	#pass


func _set_expanded(is_expanded: bool) -> void:
	_references_grid_container.visible = is_expanded
	if is_expanded:
		_expand_button.icon = get_theme_icon('GuiTreeArrowDown', 'EditorIcons')
	else:
		_expand_button.icon = get_theme_icon('GuiTreeArrowRight', 'EditorIcons')


func _on_expand_button_toggled(toggled_on: bool) -> void:
	expanded.emit(toggled_on)
	_set_expanded(toggled_on)
