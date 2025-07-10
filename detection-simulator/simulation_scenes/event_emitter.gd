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
				remove_child(old_event)

			_manual_events.clear()

			for event_data in data["manual_events"]:
				var event = SimulationEventExporterManual.new()

				event.load_save_data(event_data)

				_manual_events.append(event)
				add_child(event)
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

		undo_action.action_object_call(UndoRedoAction.DoType.Do, self, "_delete_event_internal", [index])

		######
		# Undo
		######

		undo_action.action_object_call(UndoRedoAction.DoType.Undo, self, "_restore_event_internal", [index, event_ref], [event_ref])

		UndoSystem.add_action(undo_action)

## Internal function to delete an event without creating an undo action
## Used by both manual_event_del and remove_agent_from_events
func _delete_event_internal(event_index: int):
	var event = _manual_events[event_index]
	event.remove_event_from_waypoints()
	remove_child(event)
	_manual_events.remove_at(event_index)
	_undo_stored_events.append(event)
	if PlayTimer.start_playing.is_connected(event._start_playing):
		PlayTimer.start_playing.disconnect(event._start_playing)
	if PlayTimer.stop_playing.is_connected(event._stop_playing):
		PlayTimer.stop_playing.disconnect(event._stop_playing)

## Internal function to restore an event without creating an undo action
## Used by both manual_event_del and restore_agent_to_events
func _restore_event_internal(event_index: int, event: SimulationEventExporterManual):
	_manual_events.insert(event_index, event)
	_undo_stored_events.erase(event)
	add_child(event)
	event.add_event_to_waypoints()
	PlayTimer.start_playing.connect(event._start_playing)
	PlayTimer.stop_playing.connect(event._stop_playing)

## Analyzes which events involve this agent and returns data about what changes need to be made
func get_agent_events(agent_id: int) -> Dictionary:
	var event_data = {
		"events_to_remove": [],         # Events that only involve this agent
		"events_to_modify": [],         # Events that involve multiple agents
		"removed_waypoints": {},        # Waypoints to remove from events (event_index -> waypoint_indices)
		"original_waypoints": {},       # Original waypoint data for restoration (event_index -> waypoint_data_array)
		"removed_event_objects": []     # Direct references to removed events for restoration
	}
	
	for event_index in range(_manual_events.size()):
		var event = _manual_events[event_index]
		var agent_waypoints = []
		var agent_waypoint_data = []
		var other_waypoints = []
		
		# Separate waypoints involving this agent from others
		for wp_index in range(event.waypoints.size()):
			var waypoint_data = event.waypoints[wp_index]
			if waypoint_data[0] == agent_id:
				agent_waypoints.append(wp_index)
				agent_waypoint_data.append(waypoint_data.duplicate())
			else:
				other_waypoints.append(wp_index)
		
		if agent_waypoints.size() > 0:
			if other_waypoints.size() == 0:
				# Event only involves this agent - mark for complete removal
				event_data["events_to_remove"].append(event_index)
				event_data["removed_event_objects"].append(event)
			else:
				# Event involves multiple agents - mark for modification
				event_data["events_to_modify"].append(event_index)
				event_data["removed_waypoints"][event_index] = agent_waypoints
				event_data["original_waypoints"][event_index] = agent_waypoint_data
	
	return event_data

## Actually removes the agent from events and deletes events if necessary
## This function only performs the removal, undo is handled separately
func remove_agent_from_events(agent_id: int, event_data: Dictionary):
	# IMPORTANT: Process modifications BEFORE deletions to avoid index corruption
	
	# First, modify events that involve multiple agents
	for event_index in event_data["events_to_modify"]:
		var event = _manual_events[event_index]
		var waypoint_indices = event_data["removed_waypoints"][event_index]
		
		# Remove waypoints in reverse order to maintain indices
		waypoint_indices.sort()
		waypoint_indices.reverse()
		
		for wp_index in waypoint_indices:
			var waypoint_data = event.waypoints[wp_index]
			var wp_agent_id = waypoint_data[0]
			var wp_waypoint_id = waypoint_data[1]
			
			# Remove from waypoint
			var agent = TreeFuncs.get_agent_with_id(wp_agent_id)
			if agent != null:
				var wp = agent.waypoints.get_waypoint(wp_waypoint_id)
				if wp != null:
					wp.remove_event(event, false)
			
			# Remove from event's waypoint list
			event.waypoints.remove_at(wp_index)
	
	# Then, remove events that only involve this agent (in reverse order to maintain indices)
	var events_to_remove = event_data["events_to_remove"]
	events_to_remove.sort()
	events_to_remove.reverse()
	
	for event_index in events_to_remove:
		_delete_event_internal(event_index)

## Restores events after agent deletion is undone
func restore_agent_to_events(agent_id: int, event_data: Dictionary):
	# Restore modified events first (add back agent waypoints)
	for event_index in event_data["events_to_modify"]:
		if event_index < _manual_events.size():
			var event = _manual_events[event_index]
			var waypoint_indices = event_data["removed_waypoints"][event_index]
			var original_waypoints = event_data["original_waypoints"][event_index]
			
			# Restore waypoints in original order
			waypoint_indices.sort()
			
			# Restore each waypoint that was removed
			for i in range(waypoint_indices.size()):
				var wp_index = waypoint_indices[i]
				var original_waypoint_data = original_waypoints[i]
				
				# Insert back into event's waypoint list at original position
				event.waypoints.insert(wp_index, original_waypoint_data)
				
				# Add back to waypoint using proper agent/waypoint lookup
				var wp_agent_id = original_waypoint_data[0]
				var wp_waypoint_id = original_waypoint_data[1]
				
				var agent = TreeFuncs.get_agent_with_id(wp_agent_id)
				if agent != null:
					var wp = agent.waypoints.get_waypoint(wp_waypoint_id)
					if wp != null:
						wp.add_event(event)
	
	# Restore completely removed events (in original order)
	var events_to_restore = event_data["events_to_remove"]
	var removed_event_objects = event_data["removed_event_objects"]
	
	# Create pairs of (index, event) and sort by index
	var restore_pairs = []
	for i in range(events_to_restore.size()):
		restore_pairs.append([events_to_restore[i], removed_event_objects[i]])
	restore_pairs.sort_custom(func(a, b): return a[0] < b[0])
	
	# Restore events in original order using direct references
	for pair in restore_pairs:
		var event_index = pair[0]
		var event_object = pair[1]
		_restore_event_internal(event_index, event_object)

## Cleanup method for OnRemoval - removes event objects from stored events when undo action is discarded
func cleanup_stored_events_for_agent(_agent_id: int, event_data: Dictionary):
	var removed_event_objects = event_data["removed_event_objects"]
	
	# Remove the stored event objects from _undo_stored_events
	# These are the same object references that were added to _undo_stored_events by _delete_event_internal
	for event_object in removed_event_objects:
		if is_instance_valid(event_object):
			_undo_stored_events.erase(event_object)

func _create_event(description: String, type: String, position_array: Array, timestamp_ms: int, targets: Array):

	var description_format = ""

	if typeof(targets[0]) != TYPE_DICTIONARY:
		description_format = description.format({"t": int(targets[0])})
	else:
		description_format = description.format({"t": int(targets[0].id)})

	var out_targets = []

	for target in targets:
		if typeof(target) != TYPE_DICTIONARY:
			var agent_id = int(target)
			var agent: Agent = TreeFuncs.get_agent_with_id(agent_id)

			out_targets.push_back({
				"id": agent_id,
				"class": agent._type_string[agent.agent_type],
			})
		else:
			out_targets.push_back(target)

	var event = {
		"event_type" : type,
		"event_description": description_format,
		"position" : position_array,
		"timestamp_ms" : timestamp_ms,
		"targets": out_targets
	}

	var time = timestamp_ms / 1000
	var time_string = "%02d:%02d:%02d" % [int(time) / 3600, (int(time) / 60) % 60, int(time) % 60]

	event_emitter.emit(type, description_format, time_string, targets)

	if PlayTimer.exporting:
		if event_fileaccess == null:
			event_fileaccess = FileAccess.open(save_base + "_events.json", FileAccess.WRITE)
			event_fileaccess.store_string("[")
		else:
			event_fileaccess.store_string(",")

		event_fileaccess.store_string(JSON.stringify(event))
