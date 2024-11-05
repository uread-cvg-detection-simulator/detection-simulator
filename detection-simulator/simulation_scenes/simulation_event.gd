extends Node2D
class_name SimulationEventExporterManual

var description: String = ""
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

signal event_triggered(SimulationEventManual)


# Called when the node enters the scene tree for the first time.
func _ready():
	PlayTimer.connect("start_playing", self._start_playing)
	PlayTimer.connect("stop_playing", self._stop_playing)

# When PlayTimer starts playing, connect to the agents' follow_waypoints state
func _start_playing():
	if PlayTimer.exporting:
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

		_running = false

# Evaluate if the event should be triggered
func _evaluate_send_events():
	var num_triggered = 0

	for triggered in _agent_triggered:
		if triggered:
			num_triggered += 1

	if mode == Mode.ON_EACH_AGENT:
		event_triggered.emit(self)
	elif mode == Mode.ON_EACH_AGENT_EXCEPT_FIRST:
		if num_triggered > 1:
			event_triggered.emit(self)
	elif mode == Mode.ON_EACH_AGENT_EXCEPT_LAST:
		if num_triggered < _agent_triggered.size() - 1:
			event_triggered.emit(self)
	elif mode == Mode.ON_EACH_AGENT_EXCEPT_FIRST_AND_LAST:
		if num_triggered > 1 and num_triggered < _agent_triggered.size() - 1:
			event_triggered.emit(self)
	elif mode == Mode.ON_ALL_AGENTS:
		if num_triggered == _agent_triggered.size():
			event_triggered.emit(self)


# Called when an agent starts moving (when leaving a waypoint)
func _on_start_moving(agent_id: int, waypoint_id: int):
	var index = waypoints.find([agent_id, waypoint_id])

	assert(index != -1)

	_agent_state[index] = AgentState.LEFT

	if trigger_type == TriggerType.ON_START or trigger_type == TriggerType.ON_BOTH:
		_agent_triggered[index] = true

	_evaluate_send_events()

# Called when an agent stops moving (when arriving at a waypoint)
func _on_stop_moving(agent_id: int, waypoint_id: int):
	var index = waypoints.find([agent_id, waypoint_id])

	assert(index != -1)

	_agent_state[index] = AgentState.ARRIVED

	if trigger_type == TriggerType.ON_STOP or trigger_type == TriggerType.ON_BOTH:
		_agent_triggered[index] = true

	_evaluate_send_events()

