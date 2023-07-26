class_name Agent
extends Node2D

@export var colour: Color = Color.WHITE : set = _set_sprite_colour ## The colour of the target
@onready var _sprite_to_colour_change: Sprite2D = $sprite ## The sprite object to change

var agent_id: int = 0 : set = _set_agent_id ## The agent target id
signal agent_id_set(old_id, new_id) ## Signals whenever the agent id is set

var initialised: bool = false ## Specifies whether the module is initialised

# Called when the node enters the scene tree for the first time.
func _ready():
	initialised = true

	# If the scene's default colour is not white, we need to call the sprite set to ensure that
	# the colour is correctly set.
	if colour != Color.WHITE:
		_set_sprite_colour(colour)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

## Sets the colour of the target sprite (replaces the white with whichever colour is passed in the argument)
func _set_sprite_colour(new_colour: Color):
	colour = new_colour

	if initialised:
		_sprite_to_colour_change.material.set_shader_parameter("new_colour", Vector4(new_colour.r, new_colour.g, new_colour.b, new_colour.a))

## Sets the agent id, and calls the relevant signal
func _set_agent_id(new_agent_id):
	emit_signal("agent_id_set", agent_id, new_agent_id)
	agent_id = new_agent_id
