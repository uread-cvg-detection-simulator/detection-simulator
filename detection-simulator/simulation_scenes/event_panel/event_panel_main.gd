extends Control
class_name EventPanel

@onready var _internal_panel : EventPanelContainer = $PanelContainer

var event_emitter: SimulationEventExporter = null
var _current_event: SimulationEventExporterManual = null

enum EventStatus {
	NEW,
	EDIT
}

var _status: EventStatus = EventStatus.NEW

func _ready():
	_internal_panel.waypoint_base_node = self

func new_event():
	_current_event = SimulationEventExporterManual.new()
	_status = EventStatus.NEW
	_internal_panel.delete_button.disabled = true
	_internal_panel.delete_button.visible = false

func load_event(current_event: SimulationEventExporterManual):
	_current_event = current_event
	_status = EventStatus.EDIT
	_internal_panel.delete_button.disabled = false
	_internal_panel.delete_button.visible = true

	# Set the GUI elements
	_internal_panel.description_edit.text = current_event.description
	_internal_panel.type_edit.text = current_event.type

	match current_event.trigger_type:
		SimulationEventExporterManual.TriggerType.ON_STOP:
			_internal_panel.select(0)
		SimulationEventExporterManual.TriggerType.ON_START:
			_internal_panel.select(1)
		SimulationEventExporterManual.TriggerType.ON_BOTH:
			_internal_panel.select(2)

	match _current_event.mode:
		SimulationEventExporterManual.Mode.ON_EACH_AGENT:
			_internal_panel.select(0)
		SimulationEventExporterManual.Mode.ON_EACH_AGENT_EXCEPT_FIRST:
			_internal_panel.select(1)
		SimulationEventExporterManual.Mode.ON_EACH_AGENT_EXCEPT_LAST:
			_internal_panel.select(2)
		SimulationEventExporterManual.Mode.ON_EACH_AGENT_EXCEPT_FIRST_AND_LAST:
			_internal_panel.select(3)
		SimulationEventExporterManual.Mode.ON_ALL_AGENTS:
			_internal_panel.select(4)

	# Waypoints
	# TODO Handle if waypoint id changes
	for wps in current_event.waypoints:
		_internal_panel.create_new_waypoint(wps[0], wps[1])

	_internal_panel._order_wps()


func _on_cancel_button_pressed():
	queue_free()

func _on_save_button_pressed():
	_current_event.remove_event_from_waypoints()

	if _status == EventStatus.NEW:
		_set_event_data(_current_event)

		event_emitter.manual_event_add(_current_event)
	else:
		var event_index = event_emitter._manual_events.find(_current_event)
		var duplicate_event = _current_event.duplicate()

		var undo_action = UndoRedoAction.new()
		undo_action.action_name = "Edit event"

		var event_ref = undo_action.action_store_method(UndoRedoAction.DoType.Do, func(index):
			var event = event_emitter._manual_events[index]
			return event
		, [event_index])

		if _current_event.description != duplicate_event.description:
			undo_action.action_property_ref(UndoRedoAction.DoType.Do, event_ref, "description", duplicate_event.description)
			undo_action.action_property_ref(UndoRedoAction.DoType.Undo, event_ref, "description", _current_event.description)

		if _current_event.type != duplicate_event.type:
			undo_action.action_property_ref(UndoRedoAction.DoType.Do, event_ref, "type", duplicate_event.type)
			undo_action.action_property_ref(UndoRedoAction.DoType.Undo, event_ref, "type", _current_event.type)

		if _current_event.trigger_type != duplicate_event.trigger_type:
			undo_action.action_property_ref(UndoRedoAction.DoType.Do, event_ref, "trigger_type", duplicate_event.trigger_type)
			undo_action.action_property_ref(UndoRedoAction.DoType.Undo, event_ref, "trigger_type", _current_event.trigger_type)

		if _current_event.mode != duplicate_event.mode:
			undo_action.action_property_ref(UndoRedoAction.DoType.Do, event_ref, "mode", duplicate_event.mode)
			undo_action.action_property_ref(UndoRedoAction.DoType.Undo, event_ref, "mode", _current_event.mode)

		# Waypoints

		# Remove all wps not in duplicate
		for wp in _current_event.waypoints:
			var agent_id = wp[0]
			var waypoint_id = wp[1]

			if not duplicate_event.waypoints.has(wp):
				# Remove event from wp
				undo_action.action_object_call_ref(UndoRedoAction.DoType.Do, event_ref, "remove_waypoint", [agent_id, waypoint_id])
				undo_action.action_object_call_ref(UndoRedoAction.DoType.Undo, event_ref, "add_waypoint", [agent_id, waypoint_id])

		# Add all wps not in current
		for wp in duplicate_event.waypoints:
			var agent_id = wp[0]
			var waypoint_id = wp[1]

			if not _current_event.waypoints.has(wp):
				# Add event to wp
				undo_action.action_object_call_ref(UndoRedoAction.DoType.Do, event_ref, "add_waypoint", [agent_id, waypoint_id])
				undo_action.action_object_call_ref(UndoRedoAction.DoType.Undo, event_ref, "remove_waypoint", [agent_id, waypoint_id])

		UndoSystem.add_action(undo_action)

	queue_free()


func _set_event_data(event):
	event.description = _internal_panel.description_edit.text
	event.type = _internal_panel.type_edit.text

	match _internal_panel.trigger_type:
		0:
			event.trigger_type = SimulationEventExporterManual.TriggerType.ON_STOP
		1:
			event.trigger_type = SimulationEventExporterManual.TriggerType.ON_START
		2:
			event.trigger_type = SimulationEventExporterManual.TriggerType.ON_BOTH

	match _internal_panel.mode:
		0:
			event.mode = SimulationEventExporterManual.Mode.ON_EACH_AGENT
		1:
			event.mode = SimulationEventExporterManual.Mode.ON_EACH_AGENT_EXCEPT_FIRST
		2:
			event.mode = SimulationEventExporterManual.Mode.ON_EACH_AGENT_EXCEPT_LAST
		3:
			event.mode = SimulationEventExporterManual.Mode.ON_EACH_AGENT_EXCEPT_FIRST_AND_LAST
		4:
			event.mode = SimulationEventExporterManual.Mode.ON_ALL_AGENTS

	event.waypoints = []

	for wp in _internal_panel.current_waypoint_list:
		event.waypoints.append([wp._agent_id, wp._waypoint_id])


func _on_delete_button_pressed():
	if _status == EventStatus.EDIT:
		event_emitter.manual_event_del(_current_event)

	queue_free()
