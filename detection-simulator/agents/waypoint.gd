class_name Waypoint
extends Node2D

@onready var pt_next: Node2D = null
@onready var pt_previous: Node2D = null

@onready var sprite = $Sprite2D
@onready var collision_shape = $SelectionArea2D/CollisionPolygon2D

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
