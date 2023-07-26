class_name Agent
extends Node2D

@export var colour: Color = Color.WHITE : set = _set_sprite_colour
@onready var sprite_to_colour_change: Sprite2D = $sprite

var initialised: bool = false

# Called when the node enters the scene tree for the first time.
func _ready():
	initialised = true

	if colour != Color.WHITE:
		_set_sprite_colour(colour)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _set_sprite_colour(new_colour: Color):
	colour = new_colour

	if initialised:
		sprite_to_colour_change.material.set_shader_parameter("new_colour", Vector4(new_colour.r, new_colour.g, new_colour.b, new_colour.a))

