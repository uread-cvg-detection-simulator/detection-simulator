class_name AgentTarget
extends Sprite2D

var disabled: bool = true : set = _set_disabled
@onready var _collision_shape = $RigidBody2D/CollisionShape2D

var initialised = false

# Called when the node enters the scene tree for the first time.
func _ready():
	initialised = true

	_set_disabled(disabled)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _set_disabled(new_disabled):
	if new_disabled:
		visible = false

		if initialised:
			_collision_shape.disabled = true
	else:
		visible = true

		if initialised:
			_collision_shape.disabled = false
	
	disabled = new_disabled
