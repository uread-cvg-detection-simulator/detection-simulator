class_name BackgroundImageLoader
extends Node2D

@export var root_scene: SimRoot = null

@export_group("Internal Nodes")
@export var file_dialogue: FileDialog = null
@export var sprite: Sprite2D = null
@export var camera: ImageLoaderCamera = null
@export var main_gui: CanvasLayer = null
@export var button_centre: Button = null
@export var button_scale: Button = null
@export var button_cancel: Button = null
@export var button_finished: Button = null
@export var button_load: Button = null
@export var label_status: Label = null
@export var edit_scale: TextEdit = null

@export var marker_centre: Sprite2D = null
@export var marker_scale: Sprite2D = null
@export var label_size: Label = null

var _setting_marker: bool = false
var _marker_to_place: Sprite2D = null

var default_text: String = ""
var image_scale: float = 1.0

func _ready():
	if get_tree().root == self:
		_start()

func _start():
	camera.can_scroll = false
	button_finished.disabled = true
	marker_centre.visible = false
	marker_scale.visible = false

	if file_dialogue:
		file_dialogue.visible = true

	default_text = label_status.text
	_set_status_bar()

func _start_with_sprite(new_sprite: Sprite2D, centre_position: Vector2, scale_position: Vector2, scale: float):
	marker_centre.global_position = centre_position
	marker_scale.global_position = scale_position
	marker_centre.visible = true
	marker_scale.visible = true
	label_size.visible = true
	button_finished.disabled = false

	image_scale = scale
	label_size.text = "%f" % scale

	if sprite != null:
		remove_child(sprite)

	sprite = new_sprite
	add_child(sprite)

func _on_file_dialog_file_selected(path):
	var image: Image = Image.load_from_file(path)
	var texture: ImageTexture = ImageTexture.create_from_image(image)

	sprite.texture = texture
	camera.can_scroll = true

func _process(delta):
	MousePosition.set_mouse_position(get_local_mouse_position(), get_viewport().get_mouse_position())

	if marker_centre.visible and marker_scale.visible:
		label_size.global_position = (marker_centre.global_position + marker_scale.global_position) / 2.0

		var x_dist = (absf(marker_centre.position.x - marker_scale.position.x) * image_scale) / 64.0
		var y_dist = (absf(marker_centre.position.y - marker_scale.position.y) * image_scale) / 64.0

		var dist = sqrt(pow(x_dist, 2) + pow(y_dist, 2))

		label_size.text = "%.2fm" % dist

	queue_redraw()
	_set_status_bar()

func _draw():
	if marker_centre.visible and marker_scale.visible:
		draw_line(marker_centre.position, marker_scale.position, Color.BLACK, 5)


func _unhandled_input(event):
	if _setting_marker and event.is_action_pressed("mouse_selected"):
		_setting_marker = false
		button_scale.disabled = false
		button_centre.disabled = false
		button_load.disabled = false
		camera.can_scroll = true

		_marker_to_place.visible = true
		_marker_to_place.global_position = MousePosition.mouse_global_position

		if marker_centre.visible and marker_scale.visible:
			button_finished.disabled = false
			label_size.visible = true




func _set_status_bar():
	var status_line = ""

	if marker_centre.visible:
		status_line += "Centre: (%.2f,%.2f)" % [marker_centre.position.x, marker_centre.position.y]
	else:
		status_line += "Centre: Not Set"

	status_line += " -- "

	if marker_scale.visible:
		status_line += "Scale Marker: (%.2f,%.2f)" % [marker_scale.position.x, marker_scale.position.y]
	else:
		status_line += "Scale Marker: Not Set"

	label_status.text = status_line
	main_gui._on_size_changed()


func _on_button_centre_pressed():
	button_scale.disabled = true
	button_centre.disabled = true
	button_load.disabled = true
	camera.can_scroll = false

	_marker_to_place = marker_centre
	_setting_marker = true


func _on_button_scale_pressed():
	button_scale.disabled = true
	button_centre.disabled = true
	camera.can_scroll = false

	_marker_to_place = marker_scale
	_setting_marker = true


func _on_text_edit_scale_value_text_changed():
	if edit_scale.text.is_valid_float():
		image_scale = edit_scale.text.to_float()


func _on_button_finished_pressed():
	if root_scene:
		if sprite:
			remove_child(sprite)
			root_scene.switch_to_editor(sprite, marker_centre.global_position, marker_scale.global_position, image_scale)
			sprite = null

