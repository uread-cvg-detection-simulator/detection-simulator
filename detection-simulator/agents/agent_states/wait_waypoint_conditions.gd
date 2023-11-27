extends StateMachineState

# Virtual function. Receives events from the `_unhandled_input()` callback.
func handle_input(_event: InputEvent) -> void:
	pass

var playing_next_move_time: float = 0.0 ## The time at which the next move will be played
var playing_waypoint: Waypoint = null ## The waypoint that the agent is currently moving towards
var playing_last_waypoint: Waypoint = null ## The last waypoint
var ignore_linked_nodes: Array[Waypoint] = []
var comp_signal: CompositeSignal = null
var waiting_for_signal: bool = false

func _ready():
	comp_signal = CompositeSignal.new()
	add_child(comp_signal)

# Virtual function. Corresponds to the `_process()` callback.
func update(_delta: float) -> void:
	pass

# Virtual function. Corresponds to the `_physics_process()` callback.
func physics_update(_delta: float) -> void:
	if _check_ready():
		state_machine.transition_to("follow_waypoints")


func _check_ready() -> bool:
	if playing_next_move_time < PlayTimer.current_time and not waiting_for_signal:

		# Set that we are at the waypoint
		if playing_last_waypoint:
			playing_last_waypoint.linked_ready = true

		# Check if our links are all ready
		if not _determine_wait_time():
			return false

		if owner.is_vehicle and playing_last_waypoint and (playing_last_waypoint.enter_nodes.size() > 0 or playing_last_waypoint.exit_nodes.size() > 0):
			# Check if we are a vehicle and we have enter/exit waypoints

			# If it's an ENTER waypoint, we need to tell it who we are
			if playing_last_waypoint.waypoint_type == Waypoint.WaypointType.ENTER:
				playing_last_waypoint.enter_vehicle = owner # TODO: Reset this when we leave the waypoint

			# Check enter/exit nodes for linked_ready status
			var check_enter_ready = true

			for node in playing_last_waypoint.enter_nodes:
				if not node.linked_ready:
					check_enter_ready = false
					comp_signal.add_signal(node.linked_ready_changed)

			for node in playing_last_waypoint.exit_nodes:
				if not node.linked_ready:
					check_enter_ready = false
					comp_signal.add_signal(node.linked_ready_changed)

			# If all enter/exit nodes are ready, transition to follow_waypoints
			if check_enter_ready:
				state_machine.transition_to("follow_waypoints")
				waiting_for_signal = true
				return true
			else:

				comp_signal.finished.connect(self._transition_to_follow_waypoints)
				return false

		elif not owner.is_vehicle and playing_waypoint.waypoint_type == Waypoint.WaypointType.ENTER:
			# Check if we are not a vehicle and the next waypoint is an ENTER waypoint

			# Is the ENTER node linked_ready? If not, await it
			if not playing_waypoint.vehicle_wp.linked_ready:
				comp_signal.add_signal(playing_waypoint.vehicle_wp.linked_ready_changed)
				comp_signal.finished.connect(self._transition_to_follow_waypoints)
				waiting_for_signal = true
				return false

			# Transition to follow_waypoints
			state_machine.transition_to("follow_waypoints")
			return true
		elif not owner.is_vehicle and playing_last_waypoint and playing_last_waypoint.waypoint_type == Waypoint.WaypointType.ENTER:
			# Check if we are not a vehicle and the current waypoint is an ENTER waypoint

			state_machine.transition_to("hidden_follow_vehicle", {"vehicle": playing_last_waypoint.enter_vehicle})
			return true
		
		return true

		# var ready = true

		# if playing_last_waypoint:
		# 	ready = _determine_wait_time()

		# return ready
	else:
		return false

func _transition_to_follow_waypoints(_num_connected) -> void:
	state_machine.transition_to("follow_waypoints")
	comp_signal.finished.disconnect(self._transition_to_follow_waypoints)
	waiting_for_signal = false

func _determine_wait_time() -> bool:
	var ready = true

	var max_wait_time = 0

	if playing_last_waypoint:
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
