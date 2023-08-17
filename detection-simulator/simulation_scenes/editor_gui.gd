extends CanvasLayer

@onready var play_bar = $PlayBar
@onready var properties = $Properties
@onready var properties_grid_container = $Properties/MarginContainer/VBoxContainer/ScrollContainer/GridContainer

var properties_open: bool = false : set = _properties_open_changed

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

func _add_editable_property(name: String, initial_value: String):
	var label = Label.new()
	label.text = name
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var value_label = LineEdit.new()
	value_label.text = initial_value

	properties_grid_container.add_child(label)
	properties_grid_container.add_child(value_label)

	# Add a signal to the LineEdit to update the property
	#value_label.connect("text_changed", self._on_property_changed, [name, value_label])

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

func _on_grouped(group: String, node: Node):
	if group == "selected":
		properties_open = true

		# Remove all children from properties_grid_container
		for child in properties_grid_container.get_children():
			properties_grid_container.remove_child(child)
			child.queue_free()

		if node.parent_object is Agent:
			var agent = node.parent_object

			# Add agent_id to properties
			_add_property("Agent ID", str(agent.agent_id))

		if node.parent_object is Waypoint:

			var waypoint: Waypoint = node.parent_object
			var agent: Agent = waypoint.parent_object

			var waypoint_index = agent.waypoints.get_waypoint_index(waypoint)

			# Add agent_id and waypoint_index to properties
			_add_property("Agent ID", str(agent.agent_id))
			_add_property("Waypoint Index", str(waypoint_index))


func _on_ungrouped(group: String, node: Node):
	if group == "selected":
		properties_open = false
