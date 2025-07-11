extends GdUnitTestSuite

const TestFuncs = preload("res://test/editor/test_funcs.gd")

var editor_scene = "res://simulation_scenes/editor.tscn"
var runner = null
var agent_person: Agent = null
var agent_vehicle: Agent = null

func before():
	runner = auto_free(scene_runner(editor_scene))

func before_test():
	agent_person = TestFuncs.spawn_and_get_agent(Vector2.ZERO, runner)
	agent_vehicle = TestFuncs.spawn_and_get_agent(Vector2(0, 1), runner)

	agent_vehicle.agent_type = Agent.AgentType.BoatTarget

func after():
	if PlayTimer.play:
		runner.invoke("_on_play_button_pressed")

func test_undo_redo_enter_exit_deletion():
	# Create a basic waypoint chain with enter/exit
	var wp_before = TestFuncs.spawn_waypoint_from(agent_person, Vector2(1, 0), runner)
	var wp_vehicle = TestFuncs.spawn_waypoint_from(agent_vehicle, Vector2(1, 1), runner)
	var wp_vehicle_after = TestFuncs.spawn_waypoint_from(wp_vehicle, Vector2(2, 1), runner)

	await await_idle_frame()

	# Create enter waypoint
	TestFuncs.enter_vehicle(wp_before, wp_vehicle, runner)
	var enter_wp = TestFuncs.get_enter_waypoint(wp_before)
	assert_object(enter_wp).is_not_null()

	# Create exit waypoint
	TestFuncs.exit_vehicle(agent_person, wp_vehicle_after)

	# Count waypoints before deletion
	var initial_count = len(agent_person.waypoints.waypoints)

	# Delete the enter waypoint
	agent_person.waypoints.delete_waypoint(enter_wp)

	# Verify deletion
	var after_delete_count = len(agent_person.waypoints.waypoints)
	assert_int(after_delete_count).is_less(initial_count)

	# Verify waypoint chain integrity after deletion
	var starting_node_next = agent_person.waypoints.starting_node.pt_next
	if len(agent_person.waypoints.waypoints) > 0:
		assert_object(starting_node_next).is_same(agent_person.waypoints.get_waypoint(0))
		# Verify pt_previous links back correctly
		var first_waypoint = agent_person.waypoints.get_waypoint(0)
		assert_object(first_waypoint.pt_previous).is_same(agent_person.waypoints.starting_node)
	else:
		assert_object(starting_node_next).is_null()

	# Undo the deletion - should restore both waypoints with single undo
	UndoSystem.undo()

	# Verify both waypoints are restored
	var after_undo_count = len(agent_person.waypoints.waypoints)
	assert_int(after_undo_count).is_equal(initial_count)

	# Verify waypoint chain integrity after undo
	var starting_node_next_restored = agent_person.waypoints.starting_node.pt_next
	assert_object(starting_node_next_restored).is_same(agent_person.waypoints.get_waypoint(0))
	# Verify pt_previous links back correctly
	var first_waypoint_restored = agent_person.waypoints.get_waypoint(0)
	assert_object(first_waypoint_restored.pt_previous).is_same(agent_person.waypoints.starting_node)

	# Redo the deletion - should delete both waypoints with single redo
	UndoSystem.redo()

	# Verify deletion again
	var after_redo_count = len(agent_person.waypoints.waypoints)
	assert_int(after_redo_count).is_equal(after_delete_count)

	# Verify waypoint chain integrity after redo
	var starting_node_next_redo = agent_person.waypoints.starting_node.pt_next
	if len(agent_person.waypoints.waypoints) > 0:
		assert_object(starting_node_next_redo).is_same(agent_person.waypoints.get_waypoint(0))
		# Verify pt_previous links back correctly
		var first_waypoint_redo = agent_person.waypoints.get_waypoint(0)
		assert_object(first_waypoint_redo.pt_previous).is_same(agent_person.waypoints.starting_node)
	else:
		assert_object(starting_node_next_redo).is_null()
