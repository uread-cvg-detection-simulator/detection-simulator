extends StateMachineState

# Virtual function. Receives events from the `_unhandled_input()` callback.
func handle_input(_event: InputEvent) -> void:
	pass

var vehicle: Agent = null
var exit_waypoint: Waypoint = null

signal vehicle_enter(owner_id: int, vehicle_id: int)
signal vehicle_exit(owner_id: int, vehicle_id: int)

# Virtual function. Corresponds to the `_process()` callback.
func update(_delta: float) -> void:
	pass

# Virtual function. Corresponds to the `_physics_process()` callback.
func physics_update(_delta: float) -> void:
	if vehicle:
		owner.global_position = vehicle.global_position

func _vehicle_state_change(state: String):
	if state == "idle":
		state_machine.transition_to("idle", {"hidden": true})
	elif state == "wait_waypoint_conditions":
		if exit_waypoint and exit_waypoint.vehicle_wp.linked_ready:
			state_machine.transition_to("follow_waypoints")

# Virtual function. Called by the state machine upon changing the active state. The `msg` parameter
# is a dictionary with arbitrary data the state can use to initialize itself.
func enter(msg := {}, _old_state_name: String = "") -> bool:
	if "vehicle" in msg:
		vehicle = msg["vehicle"]
	else:
		print_debug("ERROR: No vehicle passed to state. Transitioning to IDLE")
		state_machine.transition_to("idle")
		return false

	if vehicle == null:
		print_debug("ERROR: Null vehicle passed to state. Transitioning to IDLE")
		state_machine.transition_to("idle")
		return false

	if "exit_waypoint" in msg:
		exit_waypoint = msg["exit_waypoint"]

	owner.visible = false
	vehicle.state_machine.transitioned.connect(self._vehicle_state_change)

	vehicle_enter.emit(owner.agent_id, vehicle.agent_id)

	return true

# Virtual function. Called by the state machine before changing the active state. Use this function
# to clean up the state.
func exit() -> void:
	if vehicle:
		vehicle.state_machine.transitioned.disconnect(self._vehicle_state_change)

	vehicle_exit.emit(owner.agent_id, vehicle.agent_id)

	vehicle = null
	owner.visible = true
