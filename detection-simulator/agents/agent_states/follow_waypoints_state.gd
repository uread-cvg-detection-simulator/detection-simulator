extends StateMachineState

# Virtual function. Receives events from the `_unhandled_input()` callback.
func handle_input(_event: InputEvent) -> void:
	pass

# Virtual function. Corresponds to the `_process()` callback.
func update(_delta: float) -> void:
	pass

var playing_waypoint: Waypoint = null ## The waypoint that the agent is currently moving towards
var playing_last_waypoint: Waypoint = null ## The last waypoint
var playing_target: Vector2 = Vector2.INF ## The target position of the next move
var playing_speed: float = 1.0 ## The speed at which the agent will move

@export var base_agent: Agent = null

# Virtual function. Corresponds to the `_physics_process()` callback.
func physics_update(delta: float) -> void:
	if not owner.disabled:
		# Update position
		# TODO: use navigation system
		owner.global_position = owner.global_position.move_toward(playing_target, playing_speed * delta)

		# If reached target, update target information with next waypoint if there is one
		if owner.global_position == playing_target:
			# If previous node is an exit node, set it's linked_ready to true (so the vehicle can move on)
			if playing_waypoint.pt_previous and playing_waypoint.pt_previous.waypoint_type == Waypoint.WaypointType.EXIT:
				playing_waypoint.pt_previous.linked_ready = true

			# If current node is an enter node, set it's linked_ready to true (so the vehicle can move on) and transition to hidden_follow_vehicle
			if playing_waypoint.waypoint_type == Waypoint.WaypointType.ENTER:
				playing_waypoint.linked_ready = true

				var transition_dict: Dictionary = {"vehicle" : playing_waypoint.vehicle_wp.enter_vehicle}

				# Prepare for when we exit the vehicle
				if playing_waypoint.pt_next and playing_waypoint.pt_next.waypoint_type == Waypoint.WaypointType.EXIT:
					transition_dict["exit_waypoint"] = playing_waypoint.pt_next

					# If the WP after the exit is a normal WP, update the target information to it
					if playing_waypoint.pt_next.pt_next and playing_waypoint.pt_next.pt_next.waypoint_type == Waypoint.WaypointType.WAYPOINT:
						_update_target_information(playing_waypoint.pt_next.pt_next, false)

				state_machine.transition_to("hidden_follow_vehicle", transition_dict)

			# Else if there is a next node, update target information to it
			elif playing_waypoint.pt_next:
				_update_target_information(playing_waypoint.pt_next)
			# Else if there is no next node, set the current node's linked_ready to true and transition to idle
			else:
				playing_waypoint.linked_ready = true
				state_machine.transition_to("idle")

func _update_target_information(waypoint: Waypoint, transition: bool = true):
	var current_time = PlayTimer.current_time
	var old_waypoint = playing_waypoint if playing_waypoint else owner.waypoints.starting_node

	var playing_next_move_time : float = 0.0
	
	if old_waypoint.param_start_time:
		# If waypoint has a start time parameter, set the playing_next_move_time to that
		playing_next_move_time = old_waypoint.param_start_time
	elif old_waypoint.param_wait_time:
		# Calculate the time at which the next move will be played
		playing_next_move_time = current_time + old_waypoint.param_wait_time

	# Set the speed from the current waypoint
	playing_speed = old_waypoint.param_speed_mps * 64.0 # TODO: get this from grid-lines

	# Set the target position
	playing_target = waypoint.global_position

	# Update the current waypoint
	if playing_last_waypoint:
		playing_last_waypoint.linked_ready = false

	playing_last_waypoint = playing_waypoint
	playing_waypoint = waypoint

	if transition:
		state_machine.transition_to("wait_waypoint_conditions", {
			"playing_next_move_time": playing_next_move_time,
			"playing_waypoint": playing_waypoint,
			"playing_last_waypoint": playing_last_waypoint,
		})


# Virtual function. Called by the state machine upon changing the active state. The `msg` parameter
# is a dictionary with arbitrary data the state can use to initialize itself.
func enter(_msg := {}, old_state_name: String = "") -> bool:
	if old_state_name == "editor_state":
		playing_target = Vector2.INF
		playing_speed = 1.0
		playing_waypoint = null
		playing_last_waypoint = null

		_update_target_information(owner.waypoints.starting_node)

	return true

# Virtual function. Called by the state machine before changing the active state. Use this function
# to clean up the state.
func exit() -> void:
	pass

