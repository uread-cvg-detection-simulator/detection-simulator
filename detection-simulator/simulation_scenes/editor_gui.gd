extends CanvasLayer

@onready var play_bar = $PlayBar
@onready var play_bar_container = $PlayBar/HBoxContainer
@onready var play_bar_container_spacer = $PlayBar/HBoxContainer/Spacer
@onready var properties = $Properties
@onready var properties_grid_container = $Properties/MarginContainer/VBoxContainer/ScrollContainer/GridContainer

var properties_open: bool = false : set = _properties_open_changed
var properties_current_node: Node = null
var properties_dict: Dictionary = {}
var properties_editable_dict: Dictionary = {}

func _ready():
	get_tree().get_root().connect("size_changed", self._on_size_changed)

	_on_size_changed()

	GroupHelpers.connect("node_grouped", self._on_grouped)
	GroupHelpers.connect("node_ungrouped", self._on_ungrouped)

func _on_size_changed():
	# Modify Properties size to
	var viewport_size = get_viewport().size

	properties.size.y = viewport_size.y - play_bar.size.y
	_properties_open_changed(properties_open)

	resize_spacer()


func resize_spacer():
	# Modify Properties size to
	var viewport_size = get_viewport().size
	
	# Expand "Spacer" (child node of play_bar_container) to fill the remaining space between previous and subsequent nodes
	var play_bar_previous_size = 0
	var play_bar_next_size = 0
	var spacer_found = false

	for child in play_bar_container.get_children():
		if child == play_bar_container_spacer:
			spacer_found = true
			continue

		if not spacer_found:
			play_bar_previous_size += child.size.x
		else:
			play_bar_next_size += child.size.x

	play_bar_container_spacer.custom_minimum_size.x = viewport_size.x - play_bar_previous_size - play_bar_next_size - 20

func _properties_open_changed(value):
	properties_open = value

	var viewport_size = get_viewport().size

	if properties_open:
		properties.position.x = viewport_size.x - properties.size.x
	else:
		properties.position.x = viewport_size.x + 1


func _on_propeties_button_pressed():
	properties_open = false


func _add_property(name: String, value: String):
	var label = Label.new()
	label.text = name
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var value_label = Label.new()
	value_label.text = value

	properties_grid_container.add_child(label)
	properties_grid_container.add_child(value_label)

	properties_dict[name] = value_label

func _add_editable_property(name: String, initial_value: String, callback: Callable):
	var label = Label.new()
	label.text = name
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var value_label = LineEdit.new()
	value_label.text = initial_value

	properties_grid_container.add_child(label)
	properties_grid_container.add_child(value_label)

	# Add a signal to the LineEdit to update the property
	value_label.connect("text_changed", callback)

	properties_editable_dict[name] = value_label

func _add_editable_check(name: String, initial_value: bool):
	var label = Label.new()
	label.text = name
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var value_label = CheckButton.new()
	value_label.pressed = initial_value

	properties_grid_container.add_child(label)
	properties_grid_container.add_child(value_label)

	# Add a signal to the LineEdit to update the property
	#value_label.connect("pressed", self._on_property_changed, [name, value_label])

enum EditablePropertyType {
	TYPE_STRING,
	TYPE_INT,
	TYPE_FLOAT,
}

## Validate the value of a property
func _on_editable_change(name: String, edit_type: EditablePropertyType, value: String):
	if edit_type == EditablePropertyType.TYPE_STRING:
		return value
	elif edit_type == EditablePropertyType.TYPE_INT:

		if value.is_valid_int():
			var label = properties_editable_dict[name]
			label.set("theme_override_colors/font_color", null)
			return value.to_int()
		else:
			var label = properties_editable_dict[name]
			label.set("theme_override_colors/font_color", Color(1, 0, 0))
			return null
	elif edit_type == EditablePropertyType.TYPE_FLOAT:

		if value.is_valid_float():
			var label = properties_editable_dict[name]
			label.set("theme_override_colors/font_color", null)
			return value.to_float()
		else:
			var label = properties_editable_dict[name]
			label.set("theme_override_colors/font_color", Color(1, 0, 0))
			return null

## Remove all children from properties_grid_container
func _clear_properties():
	properties_dict.clear()
	properties_editable_dict.clear()

	for child in properties_grid_container.get_children():
		properties_grid_container.remove_child(child)
		child.queue_free()

func _process(delta):
	if properties_current_node != null:
		if properties_current_node.parent_object is Agent:
			var agent = properties_current_node.parent_object

			# If disabled, disable all properties and close
			if agent.disabled:
				_clear_properties()
				properties_open = false
				return

			if not properties_dict.is_empty():
				# Update properties
				properties_dict["Agent ID"].text = str(agent.agent_id)
				properties_dict["Location"].text = "(%.2f, %.2f)" % [agent.global_position.x / 64.0, -agent.global_position.y / 64.0]

		elif properties_current_node.parent_object is Waypoint:
			var waypoint = properties_current_node.parent_object
			var agent = waypoint.parent_object

			# If disabled, disable all properties and close
			if agent.disabled:
				_clear_properties()
				properties_open = false
				return

			if not properties_dict.is_empty():
				# Update properties
				properties_dict["Agent ID"].text = str(agent.agent_id)
				properties_dict["Location"].text = "(%.2f, %.2f)" % [waypoint.global_position.x / 64.0, -waypoint.global_position.y / 64.0]

	else:
		if not properties_dict.is_empty() or not properties_editable_dict.is_empty():
			_clear_properties()


func _on_grouped(group: String, node: Node):
	if group == "selected":
		properties_open = true
		properties_current_node = node

		_clear_properties()

		if node.parent_object is Agent:
			var agent = node.parent_object

			# Add agent_id to properties
			_add_property("Agent ID", str(agent.agent_id))
			_add_property("Location", "(%.2f, %.2f)" % [agent.global_position.x / 64.0, -agent.global_position.y / 64.0])
			_add_editable_property("Speed", str(agent.waypoints.starting_node.param_speed_mps),
				func(new_value: String):
					var value = _on_editable_change("Speed", EditablePropertyType.TYPE_FLOAT, new_value)
					if value != null:
						agent.waypoints.starting_node.param_speed_mps = value
			)

			var wait_time = str(agent.waypoints.starting_node.param_wait_time) if agent.waypoints.starting_node.param_wait_time != null else "0"

			_add_editable_property("Wait (s)", wait_time,
				func(new_value: String):
					var value = _on_editable_change("Wait (s)", EditablePropertyType.TYPE_FLOAT, new_value)
					if value == 0:
						agent.waypoints.starting_node.param_wait_time = null
					elif value != null:
						agent.waypoints.starting_node.param_wait_time = value
			)

		if node.parent_object is Waypoint:

			var waypoint: Waypoint = node.parent_object
			var agent: Agent = waypoint.parent_object

			var waypoint_index = agent.waypoints.get_waypoint_index(waypoint)

			# Add agent_id and waypoint_index to properties
			_add_property("Agent ID", str(agent.agent_id))
			_add_property("Waypoint Index", str(waypoint_index))
			_add_property("Location", "(%.2f, %.2f)" % [waypoint.global_position.x / 64.0, -waypoint.global_position.y / 64.0])
			_add_editable_property("Speed", str(waypoint.param_speed_mps),
				func(new_value: String):
					var value = _on_editable_change("Speed", EditablePropertyType.TYPE_FLOAT, new_value)
					if value != null:
						waypoint.param_speed_mps = value
			)

			var wait_time = str(waypoint.param_wait_time) if waypoint.param_wait_time != null else "0"

			_add_editable_property("Wait (s)", wait_time,
				func(new_value: String):
					var value = _on_editable_change("Wait (s)", EditablePropertyType.TYPE_FLOAT, new_value)
					if value == 0:
						waypoint.param_wait_time = null
					elif value != null:
						waypoint.param_wait_time = value
			)


func _on_ungrouped(group: String, node: Node):
	if group == "selected":
		if node == properties_current_node:
			properties_open = false
			properties_current_node = null
