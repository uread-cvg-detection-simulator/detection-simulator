extends Node2D
class_name StateMachine

# Original Source: https://www.gdquest.com/tutorial/godot/design-patterns/finite-state-machine/
# Modified: Jonathan Boyle

# Generic state machine. Initializes states and delegates engine callbacks
# (_physics_process, _unhandled_input) to the active state.

# Emitted when transitioning to a new state.
signal transitioned(state_name)

# Path to the initial active state. We export it to be able to pick the initial state in the inspector.
@export var initial_state: StateMachineState = null
@export var states_visible: bool = false : set = _set_states_visible
@export var label: Label = null

# The current active state. At the start of the game, we get the `initial_state`.
var state: StateMachineState = null
var all_states: Dictionary = {}

func _ready() -> void:
	if initial_state:

		state = initial_state

		await owner.ready

		# The state machine assigns itself to the State objects' state_machine property.
		for child in get_children():
			if child is StateMachineState:
				child.state_machine = self
				all_states[child.name] = child

		child_entered_tree.connect(_on_child_enter)
		child_exiting_tree.connect(_on_child_exit)

		state.enter()

		if label:
			label.text = state.name

		print_debug("SM [ %s ] - Initialised" % owner.name)

		states_visible = states_visible
	else:
		printerr("SM [ %s ] - No states?" % owner.name)
		queue_free()

# The state machine subscribes to node callbacks and delegates them to the state objects.
func _unhandled_input(event: InputEvent) -> void:
	if state:
		state.handle_input(event)


func _process(delta: float) -> void:
	if state:
		state.update(delta)


func _physics_process(delta: float) -> void:
	if state:
		state.physics_update(delta)


## This function calls the current state's exit() function, then changes the active state,
## and calls its enter function.
## It optionally takes a `msg` dictionary to pass to the next state's enter() function.
func transition_to(target_state_name: String, msg: Dictionary = {}) -> void:
	# Safety check, you could use an assert() here to report an error if the state name is incorrect.
	# We don't use an assert here to help with code reuse. If you reuse a state in different state machines
	# but you don't want them all, they won't be able to transition to states that aren't in the scene tree.
	if not target_state_name in all_states.keys():
		return

	var old_state = state
	var old_state_name = state.name

	var new_state = all_states[target_state_name]
	var state_ok = new_state.enter(msg, old_state_name)

	if state_ok:
		print_debug("SM [ %s ] : Transitioned [ %s ] -> [ %s ]" % [owner.name, old_state_name, target_state_name])

		old_state.exit()
		state = new_state
		transitioned.emit(state.name)

		if label:
			label.text = state.name
	else:
		print_debug("SM [ %s ] : Transition failed [ %s ] -> [ %s ]" % [owner.name, old_state_name, target_state_name])

func _on_child_enter(node):
	if node is StateMachineState:
		var node_name = node.name
		node.state_machine = self

		if node_name not in all_states.keys():
			all_states[node_name] = node
		else:
			printerr("Duplicate node %s added to state machine %s" % [node_name, name])

func _on_child_exit(node):
	if node is StateMachineState:
		all_states.erase(node.name)

func _set_states_visible(value):
	states_visible = value

	if label:
		label.visible = value
