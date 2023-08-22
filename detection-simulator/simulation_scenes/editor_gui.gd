extends CanvasLayer

@export_group("Play Bar")
@export var play_bar : PanelContainer = null
@export var play_bar_container : HBoxContainer = null
@export var play_bar_container_spacer : Control = null

@export_group("Properties")
@export var properties : PanelContainer = null
@export var properties_grid_container : GridContainer = null

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
		elif properties_current_node.parent_object is Sensor:
			var sensor = properties_current_node.parent_object

			# If disabled, disable all properties and close
			if sensor.disabled:
				_clear_properties()
				properties_open = false
				return

			if not properties_dict.is_empty():
				properties_dict["Sensor ID"].text = str(sensor.sensor_id)
				properties_dict["Location"].text = "(%.2f, %.2f)" % [sensor.global_position.x / 64.0, -sensor.global_position.y / 64.0]


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
					var old_value = agent.waypoints.starting_node.param_speed_mps

					if value != null and old_value != value:
						agent.waypoints.starting_node.param_speed_mps = value

						#######
						# Add undo/redo action for agent.waypoints.starting_node.param_speed_mps
						#######

						var new_action = UndoRedoAction.new()
						new_action.action_name = "Change A%d Speed %f -> %f" % [agent.agent_id, old_value, new_value]


						# Add a reference to the starting node
						var waypoint_ref = new_action.action_store_method(UndoRedoAction.DoType.Do, func(agent_id: int):
							var agent_ = TreeFuncs.get_agent_with_id(agent_id)
							return agent_.waypoints.starting_node
						, [agent.agent_id])

						new_action.manual_add_item_to_store(agent.waypoints.starting_node, waypoint_ref)

						# Update/restore the value
						new_action.action_property_ref(UndoRedoAction.DoType.Do, waypoint_ref, "param_speed_mps", value)
						new_action.action_property_ref(UndoRedoAction.DoType.Undo, waypoint_ref, "param_speed_mps", old_value)

						# Update the label
						new_action.action_method(UndoRedoAction.DoType.Do, func(agent_id, new_value):
							if "Speed" in properties_editable_dict and "Agent ID" in properties_dict:
								if properties_dict["Agent ID"].text == str(agent_id):
									properties_editable_dict["Speed"].text = str(new_value)
							, [agent.agent_id, value])

						new_action.action_method(UndoRedoAction.DoType.Undo, func(agent_id, old_value):
							if "Speed" in properties_editable_dict and "Agent ID" in properties_dict:
								if properties_dict["Agent ID"].text == str(agent_id):
									properties_editable_dict["Speed"].text = str(old_value)
							, [agent.agent_id, old_value])


						# Add the action to the undo system
						UndoSystem.add_action(new_action, false)
			)

			var wait_time = str(agent.waypoints.starting_node.param_wait_time) if agent.waypoints.starting_node.param_wait_time != null else "0"

			_add_editable_property("Wait (s)", wait_time,
				func(new_value: String):
					var value = _on_editable_change("Wait (s)", EditablePropertyType.TYPE_FLOAT, new_value)
					var old_value = agent.waypoints.starting_node.param_wait_time

					# If value is null (unparseable) or the same as the old value, return
					if value == null or old_value == value:
						return

					# If value is 0, set it to null
					if value == 0:
						value = null

					# Update the value
					agent.waypoints.starting_node.param_wait_time = value

					######
					# Add undo/redo action for agent.waypoints.starting_node.param_wait_time
					######

					var new_action = UndoRedoAction.new()
					new_action.action_name = "Change A%d Wait %f -> %f" % [agent.agent_id, old_value, new_value]

					# Add a reference to the starting node
					var waypoint_ref = new_action.action_store_method(UndoRedoAction.DoType.Do, func(agent_id: int):
						var agent_ = TreeFuncs.get_agent_with_id(agent_id)
						return agent_.waypoints.starting_node
					, [agent.agent_id])

					new_action.manual_add_item_to_store(agent.waypoints.starting_node, waypoint_ref)

					# Update/restore the value
					new_action.action_property_ref(UndoRedoAction.DoType.Do, waypoint_ref, "param_wait_time", value)
					new_action.action_property_ref(UndoRedoAction.DoType.Undo, waypoint_ref, "param_wait_time", old_value)

					# Update the label
					new_action.action_method(UndoRedoAction.DoType.Do, func(agent_id, new_value):
						if "Wait (s)" in properties_editable_dict and "Agent ID" in properties_dict:
							if properties_dict["Agent ID"].text == str(agent_id):
								properties_editable_dict["Wait (s)"].text = str(new_value) if new_value != null else "0"
						, [agent.agent_id, value])

					new_action.action_method(UndoRedoAction.DoType.Undo, func(agent_id, old_value):
						if "Wait (s)" in properties_editable_dict and "Agent ID" in properties_dict:
							if properties_dict["Agent ID"].text == str(agent_id):
								properties_editable_dict["Wait (s)"].text = str(old_value) if old_value != null else "0"
						, [agent.agent_id, old_value])

					UndoSystem.add_action(new_action, false)
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
					var old_value = waypoint.param_speed_mps

					# If value is null (unparseable) or the same as the old value, ignore
					if value != null and old_value != value:
						# Update the value
						waypoint.param_speed_mps = value

						######
						# Add undo/redo action for waypoint.param_speed_mps
						######

						var new_action = UndoRedoAction.new()
						new_action.action_name = "Change Speed"

						# Add a reference to the waypoint
						var waypoint_ref = new_action.action_store_method(UndoRedoAction.DoType.Do, func(agent_id: int):
							var agent_ = TreeFuncs.get_agent_with_id(agent_id)
							return agent_.waypoints.waypoints[waypoint_index]
						, [agent.agent_id])

						new_action.manual_add_item_to_store(waypoint, waypoint_ref)

						# Update/restore the value
						new_action.action_property_ref(UndoRedoAction.DoType.Do, waypoint_ref, "param_speed_mps", value)
						new_action.action_property_ref(UndoRedoAction.DoType.Undo, waypoint_ref, "param_speed_mps", old_value)

						# Update the label
						new_action.action_method(UndoRedoAction.DoType.Do, func(agent_id, new_value):
							if "Speed" in properties_editable_dict and "Agent ID" in properties_dict and "Waypoint Index" in properties_dict:
								if properties_dict["Agent ID"].text == str(agent_id) and properties_dict["Waypoint Index"].text == str(waypoint_index):
									properties_editable_dict["Speed"].text = str(new_value)
							, [agent.agent_id, value])

						new_action.action_method(UndoRedoAction.DoType.Undo, func(agent_id, old_value):
							if "Speed" in properties_editable_dict and "Agent ID" in properties_dict and "Waypoint Index" in properties_dict:
								if properties_dict["Agent ID"].text == str(agent_id) and properties_dict["Waypoint Index"].text == str(waypoint_index):
									properties_editable_dict["Speed"].text = str(old_value)
							, [agent.agent_id, old_value])

						# Add the action to the undo system
						UndoSystem.add_action(new_action, false)
			)

			var wait_time = str(waypoint.param_wait_time) if waypoint.param_wait_time != null else "0"

			_add_editable_property("Wait (s)", wait_time,
				func(new_value: String):
					var value = _on_editable_change("Wait (s)", EditablePropertyType.TYPE_FLOAT, new_value)
					var old_value = waypoint.param_wait_time

					# If value is null (unparseable) or the same as the old value, return
					if value == null or old_value == value:
						return

					# If value is 0, set it to null
					if value == 0:
						value = null

					# Update the value
					waypoint.param_wait_time = value

					######
					# Add undo/redo action for waypoint.param_wait_time
					######

					var new_action = UndoRedoAction.new()
					new_action.action_name = "Change A%d W%d Wait %f -> %f" % [agent.agent_id, waypoint_index, old_value, new_value]

					# Add a reference to the waypoint
					var waypoint_ref = new_action.action_store_method(UndoRedoAction.DoType.Do, func(agent_id: int):
						var agent_ = TreeFuncs.get_agent_with_id(agent_id)
						return agent_.waypoints.waypoints[waypoint_index]
					, [agent.agent_id])

					new_action.manual_add_item_to_store(waypoint, waypoint_ref)

					# Update/restore the value
					new_action.action_property_ref(UndoRedoAction.DoType.Do, waypoint_ref, "param_wait_time", value)
					new_action.action_property_ref(UndoRedoAction.DoType.Undo, waypoint_ref, "param_wait_time", old_value)

					# Update the label
					new_action.action_method(UndoRedoAction.DoType.Do, func(agent_id, new_value):
						if "Wait (s)" in properties_editable_dict and "Agent ID" in properties_dict and "Waypoint Index" in properties_dict:
							if properties_dict["Agent ID"].text == str(agent_id) and properties_dict["Waypoint Index"].text == str(waypoint_index):
								properties_editable_dict["Wait (s)"].text = str(new_value) if new_value != null else "0"
						, [agent.agent_id, value])

					new_action.action_method(UndoRedoAction.DoType.Undo, func(agent_id, old_value):
						if "Wait (s)" in properties_editable_dict and "Agent ID" in properties_dict and "Waypoint Index" in properties_dict:
							if properties_dict["Agent ID"].text == str(agent_id) and properties_dict["Waypoint Index"].text == str(waypoint_index):
								properties_editable_dict["Wait (s)"].text = str(old_value) if old_value != null else "0"
						, [agent.agent_id, old_value])

					# Add the action to the undo system
					UndoSystem.add_action(new_action, false)
			)

		if node.parent_object is Sensor:
			var sensor: Sensor = node.parent_object

			_add_property("Sensor ID", str(sensor.sensor_id))
			_add_property("Location", "(%.2f, %.2f)" % [sensor.global_position.x / 64.0, sensor.global_position.y / 64.0])

			_add_editable_property("Rotation", str(sensor.vision_cone.rotation_degrees),
				func(new_value: String):
					var value = _on_editable_change("Rotation", EditablePropertyType.TYPE_FLOAT, new_value)
					var old_value = sensor.vision_cone.rotation_degrees

					# If value is null (unparseable) or the same as the old value, return
					if value == null or old_value == value:
						return

					# Update the value
					sensor.vision_cone.rotation_degrees = value

					######
					# Add undo/redo action for sensor.vision_cone.rotation_degrees
					######

					var new_action = UndoRedoAction.new()
					new_action.action_name = "Set Sensor Rotation"

					# Add a reference to the sensor
					var sensor_ref = new_action.action_store_method(UndoRedoAction.DoType.Do, func(sensor_id): return TreeFuncs.get_sensor_with_id(sensor_id).vision_cone, [sensor.sensor_id])
					new_action.manual_add_item_to_store(sensor, sensor_ref)

					# Update/restore the value
					new_action.action_property_ref(UndoRedoAction.DoType.Do, sensor_ref, "rotation_degrees", new_value)
					new_action.action_property_ref(UndoRedoAction.DoType.Undo, sensor_ref, "rotation_degrees", old_value)

					# Update the label
					new_action.action_method(UndoRedoAction.DoType.Do, func(sensor_id, new_value):
						if "Rotation" in properties_editable_dict and "Sensor ID" in properties_dict:
							if properties_dict["Sensor ID"].text == str(sensor_id):
								properties_editable_dict["Rotation"].text = str(new_value)
						, [sensor.sensor_id, new_value])

					new_action.action_method(UndoRedoAction.DoType.Undo, func(sensor_id, old_value):
						if "Rotation" in properties_editable_dict and "Sensor ID" in properties_dict:
							if properties_dict["Sensor ID"].text == str(sensor_id):
								properties_editable_dict["Rotation"].text = str(old_value)
						, [sensor.sensor_id, old_value])

					# Add the action to the undo system
					UndoSystem.add_action(new_action, false)
			)

			_add_editable_property("FoV", str(sensor.sensor_fov_degrees),
				func(new_value: String):
					var value = _on_editable_change("FoV", EditablePropertyType.TYPE_FLOAT, new_value)
					var old_value = sensor.sensor_fov_degrees

					# If value is null (unparseable) or the same as the old value, return
					if value == null or old_value == value:
						return

					# Update the value
					sensor.sensor_fov_degrees = value

					######
					# Add undo/redo action for sensor.sensor_fov_degrees
					######

					var new_action = UndoRedoAction.new()
					new_action.action_name = "Set Sensor FoV"

					# Add a reference to the sensor
					var sensor_ref = new_action.action_store_method(UndoRedoAction.DoType.Do, TreeFuncs.get_sensor_with_id, [sensor.sensor_id])
					new_action.manual_add_item_to_store(sensor, sensor_ref)

					# Update/restore the value
					new_action.action_property_ref(UndoRedoAction.DoType.Do, sensor_ref, "sensor_fov_degrees", new_value)
					new_action.action_property_ref(UndoRedoAction.DoType.Undo, sensor_ref, "sensor_fov_degrees", old_value)

					# Update the label
					new_action.action_method(UndoRedoAction.DoType.Do, func(sensor_id, new_value):
						if "FoV" in properties_editable_dict and "Sensor ID" in properties_dict:
							if properties_dict["Sensor ID"].text == str(sensor_id):
								properties_editable_dict["FoV"].text = str(new_value)
						, [sensor.sensor_id, new_value])

					new_action.action_method(UndoRedoAction.DoType.Undo, func(sensor_id, old_value):
						if "FoV" in properties_editable_dict and "Sensor ID" in properties_dict:
							if properties_dict["Sensor ID"].text == str(sensor_id):
								properties_editable_dict["FoV"].text = str(old_value)
						, [sensor.sensor_id, old_value])

					# Add the action to the undo system
					UndoSystem.add_action(new_action, false)
			)

			_add_editable_property("Distance", str(sensor.sensor_distance),
				func(new_value: String):
					var value = _on_editable_change("Distance", EditablePropertyType.TYPE_FLOAT, new_value)
					var old_value = sensor.sensor_distance

					# If value is null (unparseable) or the same as the old value, return
					if value == null or old_value == value:
						return

					# Update the value
					sensor.sensor_distance = value

					######
					# Add undo/redo action for sensor.sensor_distance
					######

					var new_action = UndoRedoAction.new()
					new_action.action_name = "Set Sensor Distance"

					# Add a reference to the sensor
					var sensor_ref = new_action.action_store_method(UndoRedoAction.DoType.Do, TreeFuncs.get_sensor_with_id, [sensor.sensor_id])
					new_action.manual_add_item_to_store(sensor, sensor_ref)

					# Update/restore the value
					new_action.action_property_ref(UndoRedoAction.DoType.Do, sensor_ref, "sensor_distance", new_value)
					new_action.action_property_ref(UndoRedoAction.DoType.Undo, sensor_ref, "sensor_distance", old_value)

					# Update the label
					new_action.action_method(UndoRedoAction.DoType.Do, func(sensor_id, new_value):
						if "Distance" in properties_editable_dict and "Sensor ID" in properties_dict:
							if properties_dict["Sensor ID"].text == str(sensor_id):
								properties_editable_dict["Distance"].text = str(new_value)
						, [sensor.sensor_id, new_value])

					new_action.action_method(UndoRedoAction.DoType.Undo, func(sensor_id, old_value):
						if "Distance" in properties_editable_dict and "Sensor ID" in properties_dict:
							if properties_dict["Sensor ID"].text == str(sensor_id):
								properties_editable_dict["Distance"].text = str(old_value)
						, [sensor.sensor_id, old_value])

					# Add the action to the undo system
					UndoSystem.add_action(new_action, false)
			)


func _on_ungrouped(group: String, node: Node):
	if group == "selected":
		if node == properties_current_node:
			properties_open = false
			properties_current_node = null
