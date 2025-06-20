class_name SimRoot
extends Node2D

@export var editor: ScenarioEditor = null
@export var image_loader: BackgroundImageLoader = null

var bg_image: Sprite2D = null
var bg_image_buffer = null
var bg_offset: Vector2 = Vector2.ZERO
var bg_scale_marker: Vector2 = Vector2.ZERO

func switch_to_editor(image: Sprite2D, centre_marker: Vector2, scale_marker: Vector2, scale: float):
	image_loader.process_mode = Node.PROCESS_MODE_DISABLED
	image_loader.visible = false
	remove_child(image_loader)

	if image != null:
		editor.export_scale = scale
		bg_offset = centre_marker
		bg_scale_marker = scale_marker

		image.global_position = centre_marker
		bg_image = image

		add_child(bg_image)
		bg_image.visible = true
		bg_image.scale = Vector2(editor.ui_scale, editor.ui_scale)
		bg_image.global_position = -centre_marker * editor.ui_scale

		bg_image_buffer = Marshalls.raw_to_base64(bg_image.texture.get_image().save_jpg_to_buffer(1.0))

	editor.process_mode = Node.PROCESS_MODE_INHERIT
	add_child(editor)
	editor.visible = true

func switch_to_loader():
	editor.process_mode = Node.PROCESS_MODE_DISABLED
	editor.visible = false
	remove_child(editor)

	image_loader.process_mode = Node.PROCESS_MODE_INHERIT
	add_child(image_loader)
	image_loader.visible = true

	if bg_image != null:
		remove_child(bg_image)

		bg_image.global_position = Vector2.ZERO
		bg_image.scale = Vector2.ONE

		image_loader._start_with_sprite(bg_image, bg_offset, bg_scale_marker, editor.export_scale)
		bg_image = null
		bg_image_buffer = null
	else:
		image_loader._start()


func _ready():
	if DisplayServer.screen_get_dpi(0) > 120:
		get_window().content_scale_size = Vector2i(0.5,0.5)
		
	
	image_loader.process_mode = Node.PROCESS_MODE_DISABLED
	image_loader.visible = false
	remove_child(image_loader)


func _process(delta):
	pass

func _exit_tree():
	if editor:
		editor.queue_free()
	if image_loader:
		image_loader.queue_free()
