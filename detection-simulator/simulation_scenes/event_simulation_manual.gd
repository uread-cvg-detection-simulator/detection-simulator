extends Node2D
class_name SimulationEventExporterManual

var description: String = ""
var export_string: String = ""
var type: String = ""

enum Mode {
	ON_EACH_AGENT,
	ON_EACH_AGENT_EXCEPT_FIRST,
	ON_EACH_AGENT_EXCEPT_LAST,
	ON_EACH_AGENT_EXCEPT_FIRST_AND_LAST,
	ON_ALL_AGENTS,
}

var mode: Mode = Mode.ON_EACH_AGENT

enum TriggerType {
	ON_START,
	ON_STOP,
	ON_BOTH,
}

var trigger_type: TriggerType = TriggerType.ON_START

enum AgentState {
	NOT_ARRIVED,
	ARRIVED,
	LEFT,
}

# Triggered states (same order as waypoints)
var _agent_state: Array[AgentState] = []
var _agent_triggered: Array[bool] = []

# Waypoint ids (agent_id, waypoint_id)
var waypoints: Array = []

var _signal_connect_funcs: Array = []

var _running: bool = false

signal event_triggered(event: SimulationEventExporterManual, trigger_targets: Array)

func get_save_data() -> Dictionary:
	var save_data = {
		"event_version": 1,
		"description": description,
		"type": type,
		"mode": mode,
		"trigger_type": trigger_type,
		"waypoints": waypoints,
	}

	return save_data

func load_save_data(data: Dictionary, propagate_to_wps: bool = true):
	if data.has("event_version"):
		if data["event_version"] <= 1:
			description = data["description"]
			type = data["type"]
			mode = data["mode"]
			trigger_type = data["trigger_type"]
			waypoints = data["waypoints"]

			if propagate_to_wps:
				add_event_to_waypoints()
		else:
			print_debug("Unknown event version %s" % data["event_version"])
	else:
		print_debug("Event version not found in save data")

func equals(other: SimulationEventExporterManual) -> bool:

	var self_dict = get_save_data()
	var other_dict = other.get_save_data()

	return dict_equals(self_dict, other_dict)

func dict_equals(self_dict: Dictionary, other_dict: Dictionary):
	for key in self_dict:
		if not other_dict.has(key):
			return false

		var self_value = self_dict[key]
		var other_value = other_dict[key]

		if typeof(self_value) == TYPE_DICTIONARY:
			if !dict_equals(self_value, other_value):
				return false
		if typeof(self_value) == TYPE_ARRAY:
			if !array_equals(self_value, other_value):
				return false
		else:
			if self_value != other_value:
				return false

	return true

func array_equals(self_array: Array, other_array: Array):

	if self_array.size() != other_array.size():
		return false

	for idx in range(0, self_array.size()):
		var self_value = self_array[0]
		var other_value = other_array[0]

		if typeof(self_value) == TYPE_DICTIONARY:
			if !dict_equals(self_value, other_value):
				return false
		if typeof(self_value) == TYPE_ARRAY:
			if !array_equals(self_value, other_value):
				return false
		else:
			if self_value != other_value:
				return false

	return true

func add_event_to_waypoints():
	for waypoint in waypoints:
		var agent_id = waypoint[0]
		var waypoint_id = waypoint[1]

		add_event_to_waypoint(agent_id, waypoint_id)

func remove_event_from_waypoints():
	for waypoint in waypoints:
		var agent_id = waypoint[0]
		var waypoint_id = waypoint[1]

		remove_event_from_waypoint(agent_id, waypoint_id)

func add_event_to_waypoint(agent_id: int, waypoint_id: int):
	var agent = TreeFuncs.get_agent_with_id(agent_id)
	var wp = agent.waypoints.get_waypoint(waypoint_id)

	wp.add_event(self)

func remove_event_from_waypoint(agent_id: int, waypoint_id: int):
	var agent = TreeFuncs.get_agent_with_id(agent_id)
	var wp = agent.waypoints.get_waypoint(waypoint_id)

	wp.remove_event(self, false)

func remove_waypoint(agent_id: int, waypoint_id: int):
	var index = find_in_waypoints(agent_id, waypoint_id)

	assert(index != -1)

	waypoints.remove_at(index)
	remove_event_from_waypoint(agent_id, waypoint_id)

func add_waypoint(agent_id: int, waypoint_id: int):
	waypoints.append([agent_id, waypoint_id])
	add_event_to_waypoint(agent_id, waypoint_id)

# Called when the node enters the scene tree for the first time.
func _ready():
	PlayTimer.connect("start_playing", self._start_playing)
	PlayTimer.connect("stop_playing", self._stop_playing)

# When PlayTimer starts playing, connect to the agents' follow_waypoints state
func _start_playing():
	for waypoint in waypoints:
		var agent_id = waypoint[0]
		var waypoint_id = waypoint[1]

		var agent = TreeFuncs.get_agent_with_id(agent_id)

		var follow_waypoints_state = agent.state_machine.get_node("follow_waypoints")

		var start_func = func(last_wp, _wp): if (last_wp == waypoint_id): _on_start_moving(agent_id, last_wp)
		var stop_func = func(_last_wp, wp): if (wp == waypoint_id): _on_stop_moving(agent_id, wp)

		follow_waypoints_state.start_follow.connect(start_func)
		follow_waypoints_state.stop_follow.connect(stop_func)

		_signal_connect_funcs.append([agent_id, start_func, stop_func])

		_agent_state.append(AgentState.NOT_ARRIVED)
		_agent_triggered.append(false)

	_running = true

# When PlayTimer stops playing, disconnect from the agents' follow_waypoints state
func _stop_playing():
	if _running:
		for signal_connect_func in _signal_connect_funcs:
			var agent_id = signal_connect_func[0]
			var start_func = signal_connect_func[1]
			var stop_func = signal_connect_func[2]

			var agent = TreeFuncs.get_agent_with_id(agent_id)

			var follow_waypoints_state = agent.state_machine.get_node("follow_waypoints")

			follow_waypoints_state.start_follow.disconnect(start_func)
			follow_waypoints_state.stop_follow.disconnect(stop_func)

		_signal_connect_funcs.clear()
		_running = false

	_agent_triggered.clear()

# Evaluate if the event should be triggered
func _evaluate_send_events(triggered_index: int):
	var num_triggered = 0
	var other_triggered = []

	var index = 0
	for triggered in _agent_triggered:
		if triggered:
			num_triggered += 1
			if int(index) != int(triggered_index):
				other_triggered.append(int(index))
		index += 1

	if mode == Mode.ON_EACH_AGENT:
		event_triggered.emit(self, [triggered_index])
	elif mode == Mode.ON_EACH_AGENT_EXCEPT_FIRST:
		if num_triggered > 1:
			event_triggered.emit(self, [triggered_index] + other_triggered)
	elif mode == Mode.ON_EACH_AGENT_EXCEPT_LAST:
		if num_triggered < _agent_triggered.size() - 1:
			event_triggered.emit(self, [triggered_index] + other_triggered)
	elif mode == Mode.ON_EACH_AGENT_EXCEPT_FIRST_AND_LAST:
		if num_triggered > 1 and num_triggered < _agent_triggered.size() - 1:
			event_triggered.emit(self, [triggered_index] + other_triggered)
	elif mode == Mode.ON_ALL_AGENTS:
		if num_triggered == _agent_triggered.size():
			event_triggered.emit(self, [triggered_index] + other_triggered)


# Called when an agent starts moving (when leaving a waypoint)
func _on_start_moving(agent_id: int, waypoint_id: int):
	var index = find_in_waypoints(agent_id, waypoint_id)

	assert(index != -1)

	_agent_state[index] = AgentState.LEFT

	if !_agent_triggered[index]:
		if trigger_type == TriggerType.ON_START or trigger_type == TriggerType.ON_BOTH:
			_agent_triggered[index] = true

		_evaluate_send_events(index)

# Called when an agent stops moving (when arriving at a waypoint)
func _on_stop_moving(agent_id: int, waypoint_id: int):

	var index = find_in_waypoints(agent_id, waypoint_id)

	assert(index != -1)

	_agent_state[index] = AgentState.ARRIVED

	if !_agent_triggered[index]:
		if trigger_type == TriggerType.ON_STOP or trigger_type == TriggerType.ON_BOTH:
			_agent_triggered[index] = true

		_evaluate_send_events(index)

func find_in_waypoints(agent_id: int, waypoint_id: int):
	var index = -1

	for i in waypoints.size():
		var wp_agent_id = waypoints[i][0]
		var wp_waypoint_id = waypoints[i][1]

		if agent_id == wp_agent_id and wp_waypoint_id == waypoint_id:
			index = i

	return index
