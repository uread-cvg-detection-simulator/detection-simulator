extends StateMachineState

# Virtual function. Receives events from the `_unhandled_input()` callback.
func handle_input(_event: InputEvent) -> void:
	pass

var playing_next_move_time: float = 0.0 ## The time at which the next move will be played
var playing_waypoint: Waypoint = null ## The waypoint that the agent is currently moving towards
var playing_last_waypoint: Waypoint = null ## The last waypoint
var ignore_linked_nodes: Array[Waypoint] = []

# Virtual function. Corresponds to the `_process()` callback.
func update(_delta: float) -> void:
	pass

# Virtual function. Corresponds to the `_physics_process()` callback.
func physics_update(_delta: float) -> void:
	if _check_ready():
		state_machine.transition_to("follow_waypoints")

func _check_ready() -> bool:
	if playing_next_move_time < PlayTimer.current_time:
		var ready = true
		var max_wait_time = 0

		playing_last_waypoint.linked_ready = true

		# Wait until all linked nodes are ready
		for node in playing_last_waypoint.linked_nodes:
			if node in ignore_linked_nodes:
				continue

			if not node.linked_ready:
				ready = false
			else:
				if node.pt_next == null:
					if node.param_wait_time:
						if playing_last_waypoint.param_wait_time and node.param_wait_time < playing_last_waypoint.param_wait_time:
							continue

						max_wait_time = max(node.param_wait_time, max_wait_time)
						ignore_linked_nodes.append(node)
						ready = false
					else:
						continue

		if max_wait_time != 0 and not ready:
			var diff = (max_wait_time - (playing_last_waypoint.param_wait_time if playing_last_waypoint.param_wait_time else 0))
			playing_next_move_time = PlayTimer.current_time + diff

		return ready
	else:
		return false

# Virtual function. Called by the state machine upon changing the active state. The `msg` parameter
# is a dictionary with arbitrary data the state can use to initialize itself.
func enter(msg := {}, _old_state_name: String = "") -> bool:
	if "playing_last_waypoint" in msg:
		playing_last_waypoint = msg["playing_last_waypoint"]

	if "playing_waypoint" in msg:
		playing_waypoint = msg["playing_waypoint"]

	if "playing_last_waypoint" in msg:
		playing_next_move_time = msg["playing_next_move_time"]

	if _check_ready():
		return false

	return true

# Virtual function. Called by the state machine before changing the active state. Use this function
# to clean up the state.
func exit() -> void:
	ignore_linked_nodes.clear()
	playing_waypoint = null
	playing_last_waypoint = null
	playing_next_move_time = 0.0
