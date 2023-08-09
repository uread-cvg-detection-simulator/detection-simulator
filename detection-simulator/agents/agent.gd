class_name Agent
extends Node2D

@onready var camera: Camera2D = null
@export var colour: Color = Color.WHITE : set = _set_sprite_colour ## The colour of the target
@export var clickable: bool = true

var agent_id: int = 0 : set = _set_agent_id ## The agent target id
signal agent_id_set(old_id, new_id) ## Signals whenever the agent id is set

enum AgentType {
	Circle,
	SquareTarget,
	Invisible,
}

@onready var _type_map = {AgentType.Circle : $circle_target, AgentType.SquareTarget : $square_target}
@export var type_default_colours = {AgentType.Circle : Color.GREEN, AgentType.SquareTarget : Color.WHITE}
@onready var _current_agent: AgentTarget = null
var agent_type: AgentType = AgentType.Circle : set = _set_agent_type

@onready var context_menu: PopupMenu = $ContextMenu
@onready var waypoints = $waypoints

enum ContextMenuIDs {
	DELETE
}

#signal deleted(id) ## Signals when the agent has been manually deletec

var initialised: bool = false ## Specifies whether the module is initialised
var disabled: bool = false : set = _set_disabled ## Disables everything internally

# Called when the node enters the scene tree for the first time.
func _ready():
	initialised = true

	_set_agent_type(agent_type)

	# Create menu items and connect
	context_menu.add_item("Delete Agent", ContextMenuIDs.DELETE)
	context_menu.connect("id_pressed", self._context_menu)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

## Sets the colour of the target sprite (replaces the white with whichever colour is passed in the argument)
func _set_sprite_colour(new_colour: Color):
	colour = new_colour

	if initialised and _current_agent != null:
		_current_agent.material.set_shader_parameter("new_colour", Vector4(new_colour.r, new_colour.g, new_colour.b, new_colour.a))

## Handles when agent is selected
func _on_selected(selected: bool):
	if initialised and _current_agent != null:
		print_debug("Agent %d selected" % [agent_id])
		_current_agent.material.set_shader_parameter("selected", selected)

var _moving = false ## defines whether the agent is being dragged
var _moving_start_pos = null

## Handles when mouse is being held
func _on_hold():
	_moving = true
	_moving_start_pos = global_position

## Handles when mouse has stopped being held
func _on_hold_stop():
	_moving = false

	if _moving_start_pos:
		var undo_action = UndoRedoAction.new()
		undo_action._action_name = "Move Agent %d" % agent_id


		var ref = undo_action.action_create_args_ref(UndoRedoAction.DoType.Do, TreeFuncs.get_agent_with_id, [agent_id])
		undo_action.action_property_ref(UndoRedoAction.DoType.Do, ref, "global_position", global_position)
		undo_action.action_property_ref(UndoRedoAction.DoType.Undo, ref, "global_position", _moving_start_pos)

		UndoSystem.add_action(undo_action, false)

		undo_action._item_store.add_to_store(ref, self)

		_moving_start_pos = null

func _on_mouse(mouse, event):
	if event.is_action_pressed("mouse_menu") and camera != null and clickable:
		var mouse_pos = get_global_mouse_position()
		var mouse_rel_pos = mouse_pos - camera.global_position
		var window_size = get_window().size / 2

		# Popup the window
		context_menu.popup(Rect2i(mouse_rel_pos.x + window_size.x, mouse_rel_pos.y + window_size.y, context_menu.size.x, context_menu.size.y))

		print_debug("Right click at (%.2f, %.2f)" % [float(mouse_pos.x) / 64, - float(mouse_pos.y) / 64])

func _unhandled_input(event):
	if event is InputEventMouseMotion and _moving and clickable:
		var tmp_event: InputEventMouseMotion = event

		self.global_position = get_global_mouse_position()

		# TODO: handle moving other selected nodes in non-exclusive mode

## Sets the agent id, and calls the relevant signal
func _set_agent_id(new_agent_id):
	emit_signal("agent_id_set", agent_id, new_agent_id)
	agent_id = new_agent_id

func _set_agent_type(new_agent_type: AgentType):
	if initialised:
		# Disable previous
		if _current_agent != null:
			_current_agent.disabled = true
			_current_agent._selection_area.disconnect("selection_toggled", self._on_selected)
			_current_agent._selection_area.disconnect("mouse_hold_start", self._on_hold)
			_current_agent._selection_area.disconnect("mouse_hold_end", self._on_hold_stop)
			_current_agent._selection_area.disconnect("mouse_click", self._on_mouse)

		# Enable new
		if new_agent_type != AgentType.Invisible:
			_current_agent = _type_map[new_agent_type]
			_current_agent.disabled = false
			_current_agent._selection_area.connect("selection_toggled", self._on_selected)
			_current_agent._selection_area.connect("mouse_hold_start", self._on_hold)
			_current_agent._selection_area.connect("mouse_hold_end", self._on_hold_stop)
			_current_agent._selection_area.connect("mouse_click", self._on_mouse)

			_set_sprite_colour(type_default_colours[new_agent_type])
		else:
			_current_agent = null

	agent_type = new_agent_type

func _set_disabled(new_value: bool):
	if _current_agent != null:
		_current_agent.disabled = new_value
	
	disabled = new_value
	visible = not new_value

func _free_if_not_in_group():
	if not is_in_group("agent"):
		queue_free()

func _context_menu(id: ContextMenuIDs):
	match id:
		ContextMenuIDs.DELETE:
			print_debug("Deleted Agent %d" % [agent_id])
			var undo_action = UndoRedoAction.new()
			undo_action._action_name = "Deleted Agent %d" % [agent_id]
			
			var ref = undo_action.action_create_args_ref(UndoRedoAction.DoType.Do, TreeFuncs.get_agent_with_id, [agent_id])
			undo_action._item_store.add_to_store(ref, self)
			
			undo_action.action_object_call_ref(UndoRedoAction.DoType.Do, ref, "remove_from_group", ["agent"])
			undo_action.action_property_ref(UndoRedoAction.DoType.Do, ref, "disabled", true)
			
			undo_action.action_property_ref(UndoRedoAction.DoType.Undo, ref, "disabled", false)
			undo_action.action_object_call_ref(UndoRedoAction.DoType.Undo, ref, "add_to_group", ["agent"])
			
			undo_action.action_object_call_ref(UndoRedoAction.DoType.OnRemoval, ref, "_free_if_not_in_group")
			
			UndoSystem.add_action(undo_action)

