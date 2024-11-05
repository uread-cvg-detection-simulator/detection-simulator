extends VBoxContainer
class_name GUINotifier

@export var template: PanelContainer = null
@export var template_scene: PackedScene = null

func _ready():
	if template != null:
		remove_child(template)

func new_notification(text: String):
	var new_notification: EventNotifierTemplate = template_scene.instantiate()

	new_notification.label.text = ""
	
	var text_size = new_notification.label.get_theme_default_font().get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, size.x)

	new_notification.custom_minimum_size = text_size + Vector2(10, 10)
	new_notification.label.custom_minimum_size = text_size
	new_notification.label.text = text
	new_notification.modulate = Color(1.0, 1.0, 1.0, 0.0)

	var notification_tween = create_tween()
	notification_tween.tween_property(new_notification, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.5)
	notification_tween.tween_interval(5.0)
	notification_tween.tween_property(new_notification, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.5)
	notification_tween.tween_callback(func():
		remove_child(new_notification)
	)

	add_child(new_notification)

func event_receiver(type: String, description: String, time: String):
	new_notification("%s - %s @ %s" % [type, description, time])
