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

# Signals with a type and description whenever an event is triggered
signal event_emitter(type: String, description: String, time: String)

# Called when the node enters the scene tree for the first time.
func _ready():
	PlayTimer.connect("start_playing", self._start_playing)
	PlayTimer.connect("stop_playing", self._stop_playing)


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

func manual_event_add(event_info: SimulationEventExporterManual):
	_manual_events.append(event_info)

	add_child(event_info)

func manual_event_del(event_info: SimulationEventExporterManual):

	if _manual_events.has(event_info):
		remove_child(event_info)

		for waypoint_info in event_info.waypoints:
			var agent_id = waypoint_info[0]
			var waypoint_id = waypoint_info[1]

			var agent = TreeFuncs.get_agent_with_id(agent_id)
			var waypoint = agent.waypoints.get_waypoint(waypoint_id)

			waypoint.remove_event(event_info, false)



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

	event_emitter.emit(type, description, time_string)

	if PlayTimer.exporting:
		if event_fileaccess == null:
			event_fileaccess = FileAccess.open(save_base + "_events.json", FileAccess.WRITE)
			event_fileaccess.store_string("[")
		else:
			event_fileaccess.store_string(",")

		event_fileaccess.store_string(JSON.stringify(event))

