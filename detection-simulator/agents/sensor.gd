extends Node2D
class_name Sensor

@export_group("Parameters")
@export var sensor_fov_degrees: float = 90.0 : set = _set_sensor_fov
@export var sensor_distance: float = 100 : set = _set_sensor_distance
@export var detection_line_width: float = 3.0
@export var detection_line_colour: Color = Color.RED
@export var draw_sensor_detections: bool = true
@export var draw_vision_cone: bool = true: set = _set_draw_cone
@export var disabled: bool = false : set = _set_disabled
@export var clickable: bool = true

@export_group("Internal")
@export var vision_cone: VisionCone2D = null
@export var selection_area: SelectionArea2D = null
@export var selection_area_collision: CollisionPolygon2D = null
@export var context_menu: PopupMenu = null
@export var sprite: Sprite2D = null

var sensor_id: int = -1
var current_detections: Array[Agent] = []

enum ContextMenuIDs {
	DELETE,
	PROPERTIES,
}

# Called when the node enters the scene tree for the first time.
func _ready():
	sensor_fov_degrees = sensor_fov_degrees
	draw_vision_cone = draw_vision_cone
	sensor_distance = sensor_distance

	# Create menu items and connect
	context_menu.add_item("Delete Sensor", ContextMenuIDs.DELETE)
	context_menu.add_item("Properties", ContextMenuIDs.PROPERTIES)
	context_menu.connect("id_pressed", self._context_menu)

func get_save_data() -> Dictionary:
	var data = {
		"sensor_version" : 2,
		"sensor_fov_degrees": sensor_fov_degrees,
		"rotation_degrees": vision_cone.rotation_degrees,
		"sensor_distance" : sensor_distance,
		"global_position": {
			"x": global_position.x,
			"y": global_position.y
		}
	}

	return data

func load_save_data(data: Dictionary):
	if data.has("sensor_version"):
		if data["sensor_version"] <= 2:
			sensor_fov_degrees = data["sensor_fov_degrees"]
			vision_cone.rotation_degrees = data["rotation_degrees"]
			global_position = Vector2(data["global_position"]["x"], data["global_position"]["y"])

			if data["sensor_version"] == 1:
				sensor_distance = 500 / 64.0
			elif data["sensor_version"] >= 2:
				sensor_distance = data["sensor_distance"]
		else:
			print_debug("Sensor version not supported")
	else:
		print_debug("Sensor version not found")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _context_menu(id: ContextMenuIDs):
	match id:
		ContextMenuIDs.DELETE:
			print_debug("Deleted Sensor %d" % sensor_id)
			selection_area.selected = false

			var undo_action = UndoRedoAction.new()
			undo_action.action_name = "Delete Sensor"

			var sensor_ref = undo_action.action_store_method(UndoRedoAction.DoType.Do, TreeFuncs.get_sensor_with_id, [sensor_id])

			undo_action.action_method(UndoRedoAction.DoType.Do, GroupHelpers.remove_node_from_group, [sensor_ref, "sensor"], sensor_ref)
			undo_action.action_property_ref(UndoRedoAction.DoType.Do, sensor_ref, "disabled", true)

			undo_action.action_property_ref(UndoRedoAction.DoType.Undo, sensor_ref, "disabled", false)
			undo_action.action_method(UndoRedoAction.DoType.Undo, GroupHelpers.add_node_to_group, [sensor_ref, "sensor"], sensor_ref)

			undo_action.action_object_call_ref(UndoRedoAction.DoType.OnRemoval, sensor_ref, "_free_if_not_in_group")

			UndoSystem.add_action(undo_action)
		ContextMenuIDs.PROPERTIES:
			selection_area.selected = true

func _free_if_not_in_group():
	if not is_in_group("sensor"):
		queue_free()

func _set_sensor_fov(new_value: float):
	sensor_fov_degrees = new_value

	if vision_cone:
		vision_cone.angle_deg = new_value
		vision_cone.ray_count = int(new_value / 3)
		vision_cone.recalculate_vision(true)

func _set_sensor_distance(new_value: float):
	sensor_distance = new_value

	if vision_cone:
		vision_cone.max_distance = new_value * 64.0

func _set_draw_cone(new_value: bool):
	draw_vision_cone = new_value

	if vision_cone:
		vision_cone.debug_shape = true

func _on_vision_cone_area_body_entered(body):
	if body is Agent:
		current_detections.append(body)

func _on_vision_cone_area_body_exited(body):
	if body is Agent:
		current_detections.erase(body)

func _set_disabled(new_value: bool):
	disabled = new_value

	selection_area_collision.disabled = new_value
	visible = not visible


func _on_mouse_click(button, event):
	if event.is_action_pressed("mouse_menu") and clickable:
		var mouse_pos = MousePosition.mouse_global_position
		var mouse_rel_pos = MousePosition.mouse_relative_position
		var window_size = get_window().size / 2

		# Popup the window
		context_menu.popup(Rect2i(mouse_rel_pos.x + window_size.x, mouse_rel_pos.y + window_size.y, context_menu.size.x, context_menu.size.y))

		print_debug("Right click at (%.2f, %.2f)" % [float(mouse_pos.x) / 64, - float(mouse_pos.y) / 64])

var _dragged = false
var _drag_start_pos = null

func _on_mouse_hold_start():
	if clickable:
		_dragged = true
		_drag_start_pos = global_position

func _on_mouse_hold_end():
	_dragged = false

	if _drag_start_pos:
		if _drag_start_pos != global_position:
			var undo_action = UndoRedoAction.new()

			undo_action.action_name = "Move Sensor %d" % sensor_id


			var ref = undo_action.action_store_method(UndoRedoAction.DoType.Do, TreeFuncs.get_sensor_with_id, [sensor_id])
			undo_action.action_property_ref(UndoRedoAction.DoType.Do, ref, "global_position", global_position)
			undo_action.action_property_ref(UndoRedoAction.DoType.Undo, ref, "global_position", _drag_start_pos)

			undo_action.manual_add_item_to_store(self, ref)

			UndoSystem.add_action(undo_action, false)


		_drag_start_pos = null

func _unhandled_input(event):
	if event is InputEventMouseMotion and _dragged and clickable:
		self.global_position = get_global_mouse_position()

func _on_selection_toggled(selection):
	sprite.material.set_shader_parameter("selected", selection)
