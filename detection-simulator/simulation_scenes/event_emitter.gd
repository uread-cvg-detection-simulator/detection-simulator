extends Node2D
class_name SimulationEventExporter

@export_group("Scene")
@export var editor_base: ScenarioEditor = null

var exporting: bool = false
var save_base: String = ""

var event_fileaccess: FileAccess = null

var enter_exit_stats: Array = []

# Tuple of event and lambda for signal
var _manual_events: Array = []
var _undo_stored_events: Array = []

# Signals with a type and description whenever an event is triggered
signal event_emitter(type: String, description: String, time: String, targets: Array)

# Called when the node enters the scene tree for the first time.
func _ready():
	PlayTimer.connect("start_playing", self._start_playing)
	PlayTimer.connect("stop_playing", self._stop_playing)

func get_save_data() -> Dictionary:
	var save_data = {
		"event_emitter_version": 1,
		"manual_events": []
	}

	for event in _manual_events:
		save_data["manual_events"].append(event.get_save_data())

	return save_data

func load_save_data(data: Dictionary):
	if data.has("event_emitter_version"):
		if data["event_emitter_version"] <= 1:

			for old_event in _manual_events:
				for wps in old_event.waypoints:
					var agent_id = wps[0]
					var waypoint_id = wps[1]

					var agent = TreeFuncs.get_agent_with_id(agent_id)
					var waypoint = agent.waypoints.get_waypoint(waypoint_id)

					waypoint.remove_event(old_event, false)

			_manual_events.clear()

			for event_data in data["manual_events"]:
				var event = SimulationEventExporterManual.new()

				event.load_save_data(event_data)

				_manual_events.append(event)
		else:
			print_debug("Unknown event emitter version %s" % data["event_emitter_version"])
	else:
		print_debug("Event emitter version not found in save data")


## Receive a signal from the PlayTimer to start
func _start_playing():
	if PlayTimer.exporting:
		save_base = editor_base.save_path_export_base

	exporting = true

	var agents = get_tree().get_nodes_in_group("agent")

	for agent in agents:
		var hidden_state = agent.state_machine.get_node("hidden_follow_vehicle")

		hidden_state.vehicle_enter.connect(self._auto_event_vehicle_enter)
		hidden_state.vehicle_exit.connect(self._auto_event_vehicle_exit)

		enter_exit_stats.push_back(hidden_state)

	for event in _manual_events:
		event.event_triggered.connect(self._manual_event_trigger)


## Receive a signal from the PlayTimer to stop
func _stop_playing():
	save_base = ""
	exporting = false

	if event_fileaccess != null:
		event_fileaccess.store_string("]")
		event_fileaccess.close()
		event_fileaccess = null

	for hidden_state in enter_exit_stats:
		if is_instance_valid(hidden_state):
			hidden_state.vehicle_enter.disconnect(self._auto_event_vehicle_enter)
			hidden_state.vehicle_exit.disconnect(self._auto_event_vehicle_exit)

	for event in _manual_events:
		event.event_triggered.disconnect(self._manual_event_trigger)

	enter_exit_stats.clear()

func _auto_event_vehicle_enter(agent_id_entrant: int, agent_id_vehicle: int):
	var entrant = TreeFuncs.get_agent_with_id(agent_id_entrant)
	var vehicle = TreeFuncs.get_agent_with_id(agent_id_vehicle)

	var targets: Array = []

	targets.push_back({
		"id": agent_id_entrant,
		"class": entrant._type_string[entrant.agent_type]
	})

	targets.push_back({
		"id": agent_id_vehicle,
		"class": vehicle._type_string[vehicle.agent_type]
	})

	var description = "%s %d has entered %s %d" % [entrant._type_string[entrant.agent_type], agent_id_entrant, vehicle._type_string[vehicle.agent_type], agent_id_vehicle]
	var type = "VEHICLE ENTERED"
	var position_array = [{"x": entrant.global_position.x, "y": entrant.global_position.y}]
	var timestamp_ms = PlayTimer.current_time * 1000

	_create_event(description, type, position_array, timestamp_ms, targets)

func _auto_event_vehicle_exit(agent_id_entrant: int, agent_id_vehicle: int):
	var entrant = TreeFuncs.get_agent_with_id(agent_id_entrant)
	var vehicle = TreeFuncs.get_agent_with_id(agent_id_vehicle)

	var targets: Array = []

	targets.push_back({
		"id": agent_id_entrant,
		"class": entrant._type_string[entrant.agent_type]
	})

	targets.push_back({
		"id": agent_id_vehicle,
		"class": vehicle._type_string[vehicle.agent_type]
	})

	var description = "%s %d has exited %s %d" % [entrant._type_string[entrant.agent_type], agent_id_entrant, vehicle._type_string[vehicle.agent_type], agent_id_vehicle]
	var type = "VEHICLE EXITED"
	var position_array = [{"x": entrant.global_position.x, "y": entrant.global_position.y}]
	var timestamp_ms = PlayTimer.current_time * 1000

	_create_event(description, type, position_array, timestamp_ms, targets)

func _manual_event_trigger(event: SimulationEventExporterManual, trigger_targets: Array):
	var description = event.description
	var type = event.type
	var triggered_index = trigger_targets[0]
	var other_indexes = trigger_targets.slice(1)
	var timestamp_ms = PlayTimer.current_time * 1000

	var targets: Array = [event.waypoints[triggered_index][0]]
	var triggered_agent_wp = TreeFuncs.get_agent_with_id(event.waypoints[triggered_index][0]).waypoints.get_waypoint(event.waypoints[triggered_index][1])
	var other_agents_wps = []

	for index in other_indexes:
		targets.push_back(event.waypoints[index][0])
		other_agents_wps.append(TreeFuncs.get_agent_with_id(event.waypoints[index][0]).waypoints.get_waypoint(event.waypoints[index][1]))

	# Get centre of all agents
	# TODO: Add a bounding box option

	var centre = triggered_agent_wp.global_position

	for agent in other_agents_wps:
		centre += agent.global_position

	centre /= other_agents_wps.size() + 1

	var position_array = [{"x": centre.x, "y": centre.y}]

	_create_event(description, type, position_array, timestamp_ms, targets)

func get_manual_event_index(idx: int) -> SimulationEventExporterManual:
	return _manual_events[idx]

func manual_event_known(event_info: SimulationEventExporterManual) -> int:
	if _manual_events.is_empty():
		return -1

	for ev_idx in range(0,_manual_events.size()):
		if event_info.equals(_manual_events[ev_idx]):
			return ev_idx

	return -1

func manual_event_add(event_info: SimulationEventExporterManual):

	var known_index = manual_event_known(event_info)

	if known_index == -1:

		var undo_action = UndoRedoAction.new()
		undo_action.action_name = "Add Manual Event"

		var event_data = event_info.get_save_data()

		######
		# Do
		######

		# TODO: Actually add the argument to the store, instead of using the save data
		var event_ref = undo_action.action_store_method(UndoRedoAction.DoType.Do, func(data):
			var event = SimulationEventExporterManual.new()
			event.load_save_data(data)

			return event
		, [event_data])
		undo_action.manual_add_item_to_store(event_info, event_ref)

		undo_action.action_method(UndoRedoAction.DoType.Do, func(emitter, event):
			emitter._manual_events.append(event)
		, [self, event_ref], [event_ref])

		undo_action.action_object_call(UndoRedoAction.DoType.Do, self, "add_child", [event_ref], [event_ref])

		######
		# Undo
		######

		undo_action.action_object_call_ref(UndoRedoAction.DoType.Undo, event_ref, "remove_event_from_waypoints")
		undo_action.action_object_call(UndoRedoAction.DoType.Undo, self, "remove_child", [event_ref], [event_ref])

		undo_action.action_method(UndoRedoAction.DoType.Undo, func(emitter, event):
			emitter._manual_events.erase(event)
		, [self, event_ref], [event_ref])

		UndoSystem.add_action(undo_action)

func manual_event_del(event_info: SimulationEventExporterManual):

	var index = manual_event_known(event_info)

	if index != -1:
		var undo_action = UndoRedoAction.new()
		undo_action.action_name = "Delete Manual Event"

		######
		# Do
		######
		var event_ref = undo_action.action_store_method(UndoRedoAction.DoType.Do, func(index):
			var event = _manual_events[index]
			return event
		, [index])

		undo_action.action_object_call(UndoRedoAction.DoType.Do, self, "remove_child", [event_ref], [event_ref])
		undo_action.action_object_call_ref(UndoRedoAction.DoType.Do, event_ref, "remove_event_from_waypoints")
		undo_action.action_method(UndoRedoAction.DoType.Do, func(index, event):
			_manual_events.remove_at(index)
			_undo_stored_events.append(event)
			PlayTimer.start_playing.disconnect(event._start_playing)
			PlayTimer.stop_playing.disconnect(event._stop_playing)
		, [index, event_ref], [event_ref])

		######
		# Undo
		######

		undo_action.action_method(UndoRedoAction.DoType.Undo, func(index, event):
			_manual_events.insert(index, event)
			_undo_stored_events.erase(event)
			PlayTimer.start_playing.connect(event._start_playing)
			PlayTimer.stop_playing.connect(event._stop_playing)
		, [index, event_ref], [event_ref])

		undo_action.action_object_call(UndoRedoAction.DoType.Undo, self, "add_child", [event_ref], [event_ref])
		undo_action.action_object_call_ref(UndoRedoAction.DoType.Undo, event_ref, "add_event_to_waypoints")

		UndoSystem.add_action(undo_action)



func _create_event(description: String, type: String, position_array: Array, timestamp_ms: int, targets: Array):
	var event = {
		"event_type" : type,
		"event_description": description,
		"position" : position_array,
		"timestamp_ms" : timestamp_ms,
		"targets": targets
	}

	var time = timestamp_ms / 1000
	var time_string = "%02d:%02d:%02d" % [int(time) / 3600, (int(time) / 60) % 60, int(time) % 60]

	event_emitter.emit(type, description, time_string, targets)

	if PlayTimer.exporting:
		if event_fileaccess == null:
			event_fileaccess = FileAccess.open(save_base + "_events.json", FileAccess.WRITE)
			event_fileaccess.store_string("[")
		else:
			event_fileaccess.store_string(",")

		event_fileaccess.store_string(JSON.stringify(event))
