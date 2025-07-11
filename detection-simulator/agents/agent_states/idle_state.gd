extends StateMachineState

# Virtual function. Receives events from the `_unhandled_input()` callback.
func handle_input(_event: InputEvent) -> void:
	pass

var hidden_from_view: bool = false

# Virtual function. Corresponds to the `_process()` callback.
func update(_delta: float) -> void:
	if hidden_from_view:
		owner.visible = false

# Virtual function. Corresponds to the `_physics_process()` callback.
func physics_update(_delta: float) -> void:
	pass

# Virtual function. Called by the state machine upon changing the active state. The `msg` parameter
# is a dictionary with arbitrary data the state can use to initialize itself.
func enter(msg := {}, _old_state_name: String = "") -> bool:
	if "hidden" in msg:
		hidden_from_view = msg["hidden"]
	else:
		hidden_from_view = false

	owner.playing_finished = true

	return true

# Virtual function. Called by the state machine before changing the active state. Use this function
# to clean up the state.
func exit() -> void:
	if hidden_from_view:
		owner.visible = true
