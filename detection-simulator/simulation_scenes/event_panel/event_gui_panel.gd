extends Control
class_name EventPanelContainer

@export_group("Interactable GUI Elements")
@export var description_edit: TextEdit = null
@export var type_edit: TextEdit = null
@export var trigger_item_list: ItemList = null
@export var trigger_overall_item_list: ItemList = null
@export var delete_button: Button = null

@export var wp_add_new: Control = null

@export var template_waypoints: PackedScene = null
@export var waypoint_base_node: Control = null

var current_waypoint_list: Array = []
var waiting_for_waypoint: bool = false

# Called when the node enters the scene tree for the first time.
func _ready():
	if !trigger_item_list.is_anything_selected():
		trigger_item_list.select(0)

	if !trigger_overall_item_list.is_anything_selected():
		trigger_overall_item_list.select(0)


func _on_new_waypoint_button_pressed():
	# Hide GUI
	visible = false
	waiting_for_waypoint = true

	# Wait for new waypoint to be selected
	GroupHelpers.node_grouped.connect(self._on_new_waypoint_selected)

func _on_new_waypoint_selected(group: String, node: Node):
	if group == "selected":
		if node.parent_object is Waypoint:
			var wp = node.parent_object
			var agent = wp.parent_object

			# Create new waypoint
			create_new_waypoint(agent.agent_id, agent.waypoints.get_waypoint_index(wp))

			# Return GUI to normal
			visible = true
			waiting_for_waypoint = false
			GroupHelpers.node_grouped.disconnect(self._on_new_waypoint_selected)

func create_new_waypoint(agent_id: int, waypoint_id: int):
	# Create new waypoint
	var new_wp = template_waypoints.instantiate()

	new_wp.set_info(agent_id, waypoint_id)
	new_wp.delete_signal.connect(self._delete_wp_receiver)

	# Add to gui
	current_waypoint_list.append(new_wp)
	waypoint_base_node.add_child(new_wp)

	_order_wps()


func _order_wps():
	var index: int = 0

	for wp in current_waypoint_list:
		wp.set_index(index)
		waypoint_base_node.move_child(wp, index)

		index = index + 1

func _delete_wp_receiver(_agent_id: int, _waypoint_id: int, index: int):
	var wp_gui = current_waypoint_list[index]

	wp_gui.queue_free()
