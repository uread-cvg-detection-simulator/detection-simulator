extends StateMachineState

# Virtual function. Receives events from the `_unhandled_input()` callback.
func handle_input(_event: InputEvent) -> void:
	pass

# Virtual function. Corresponds to the `_process()` callback.
func update(_delta: float) -> void:
	pass

# Virtual function. Corresponds to the `_physics_process()` callback.
func physics_update(_delta: float) -> void:
	pass

# Virtual function. Called by the state machine upon changing the active state. The `msg` parameter
# is a dictionary with arbitrary data the state can use to initialize itself.
func enter(_msg := {}, _old_state_name: String = "") -> bool:
	owner.clickable = true

	owner.waypoints.starting_node.linked_ready = false

	for waypoint in owner.waypoints.waypoints:
		waypoint.linked_ready = false

	owner.global_position = owner.waypoints.starting_node.global_position
	owner.waypoints.clickable = true

	return true

# Virtual function. Called by the state machine before changing the active state. Use this function
# to clean up the state.
func exit() -> void:
	pass
