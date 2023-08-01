class_name Agent
extends Node2D

@export var colour: Color = Color.WHITE : set = _set_sprite_colour ## The colour of the target

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


var initialised: bool = false ## Specifies whether the module is initialised

# Called when the node enters the scene tree for the first time.
func _ready():
	initialised = true

	_set_agent_type(agent_type)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

## Sets the colour of the target sprite (replaces the white with whichever colour is passed in the argument)
func _set_sprite_colour(new_colour: Color):
	colour = new_colour

	if initialised and _current_agent != null:
		_current_agent.material.set_shader_parameter("new_colour", Vector4(new_colour.r, new_colour.g, new_colour.b, new_colour.a))

func _on_selected(selected: bool):
	if initialised and _current_agent != null:
		print_debug("Agent %d selected" % [agent_id])
		_current_agent.material.set_shader_parameter("selected", selected)

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

		# Enable new
		if new_agent_type != AgentType.Invisible:
			_current_agent = _type_map[new_agent_type]
			_current_agent.disabled = false
			_current_agent._selection_area.connect("selection_toggled", self._on_selected)

			_set_sprite_colour(type_default_colours[new_agent_type])
		else:
			_current_agent = null

	agent_type = new_agent_type


