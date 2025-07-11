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

func test_enter_exit_deletion_index_zero_scenario():
	# Scenario: Agent 1 enters vehicle immediately (ENTER at index 0)
	# Agent 2 moves to separate location, Agent 1 exits, Agent 2 continues

	# Create vehicle waypoints: starting -> enter_point -> exit_point -> final_point
	var wp_vehicle_enter = TestFuncs.spawn_waypoint_from(agent_vehicle, Vector2(1, 1), runner)
	var wp_vehicle_exit = TestFuncs.spawn_waypoint_from(wp_vehicle_enter, Vector2(2, 1), runner)
	var wp_vehicle_final = TestFuncs.spawn_waypoint_from(wp_vehicle_exit, Vector2(3, 1), runner)

	await await_idle_frame()

	# Agent 1 enters the vehicle immediately (this creates ENTER at index 0)
	# Use starting position (fake_start) as the individual waypoint
	TestFuncs.enter_vehicle(agent_person.waypoints.starting_node, wp_vehicle_enter, runner)

	# Get the enter waypoint (should be at index 0)
	var enter_wp = agent_person.waypoints.get_waypoint(0)
	assert_object(enter_wp).is_not_null()
	assert_int(enter_wp.waypoint_type).is_equal(Waypoint.WaypointType.ENTER)

	# Agent 1 exits at vehicle exit point, Agent 2 continues to final point
	TestFuncs.exit_vehicle(agent_person, wp_vehicle_exit)
	var exit_wp = TestFuncs.get_after_exit_waypoint(agent_person.waypoints.starting_node)
	assert_object(exit_wp).is_not_null()

	# Verify the waypoint chain before deletion
	var initial_person_count = len(agent_person.waypoints.waypoints)
	var starting_node_next_before = agent_person.waypoints.starting_node.pt_next
	assert_object(starting_node_next_before).is_same(enter_wp)

	# Delete the ENTER waypoint (at index 0)
	agent_person.waypoints.delete_waypoint(agent_person.waypoints.starting_node.pt_next)

	# Verify both ENTER and EXIT waypoints are deleted
	var after_delete_count = len(agent_person.waypoints.waypoints)
	assert_int(after_delete_count).is_less(initial_person_count)

	# Critical check: starting_node should still have correct pt_next link
	var starting_node_next_after = agent_person.waypoints.starting_node.pt_next
	if len(agent_person.waypoints.waypoints) > 0:
		assert_object(starting_node_next_after).is_same(agent_person.waypoints.waypoints[0])
	else:
		assert_object(starting_node_next_after).is_null()

	await await_idle_frame()

	# Test undo - should restore both waypoints and links
	UndoSystem.undo()

	# Verify restoration
	var after_undo_count = len(agent_person.waypoints.waypoints)
	assert_int(after_undo_count).is_equal(initial_person_count)

	# Critical check: starting_node pt_next should be restored to ENTER waypoint
	var starting_node_next_restored = agent_person.waypoints.starting_node.pt_next
	var restored_enter_wp = agent_person.waypoints.get_waypoint(0)
	assert_object(starting_node_next_restored).is_same(restored_enter_wp)

	# Test redo
	UndoSystem.redo()

	# Verify deletion again and linking
	var after_redo_count = len(agent_person.waypoints.waypoints)
	assert_int(after_redo_count).is_equal(after_delete_count)

	var starting_node_next_final = agent_person.waypoints.starting_node.pt_next
	if len(agent_person.waypoints.waypoints) > 0:
		assert_object(starting_node_next_final).is_same(agent_person.waypoints.get_waypoint(0))
		# Verify pt_previous links back correctly
		var first_waypoint_final = agent_person.waypoints.get_waypoint(0)
		assert_object(first_waypoint_final.pt_previous).is_same(agent_person.waypoints.starting_node)
	else:
		assert_object(starting_node_next_final).is_null()

func test_exit_deletion_with_vehicle_continuation():
	# Test deleting EXIT waypoint when vehicle has waypoints after the exit

	# Create vehicle waypoints: starting -> enter_point -> exit_point -> final_point
	var wp_vehicle_enter = TestFuncs.spawn_waypoint_from(agent_vehicle, Vector2(1, 1), runner)
	var wp_vehicle_exit = TestFuncs.spawn_waypoint_from(wp_vehicle_enter, Vector2(2, 1), runner)
	var wp_vehicle_final = TestFuncs.spawn_waypoint_from(wp_vehicle_exit, Vector2(3, 1), runner)

	await await_idle_frame()

	# Agent 1 enters immediately
	TestFuncs.enter_vehicle(agent_person.waypoints.starting_node, wp_vehicle_enter, runner)

	# Agent 1 exits at exit point, vehicle continues to final point
	TestFuncs.exit_vehicle(agent_person, wp_vehicle_exit)

	var exit_wp = TestFuncs.get_after_exit_waypoint(agent_person.waypoints.starting_node)
	assert_object(exit_wp).is_not_null()

	var initial_count = len(agent_person.waypoints.waypoints)

	await await_idle_frame()

	# Delete the EXIT waypoint
	agent_person.waypoints.delete_waypoint(exit_wp.pt_previous)

	# Verify both ENTER and EXIT are deleted
	var after_delete_count = len(agent_person.waypoints.waypoints)
	assert_int(after_delete_count).is_less(initial_count)

	# Verify waypoint chain integrity
	var starting_node_next = agent_person.waypoints.starting_node.pt_next
	if len(agent_person.waypoints.waypoints) > 0:
		assert_object(starting_node_next).is_same(agent_person.waypoints.get_waypoint(0))
		# Verify pt_previous links back correctly
		var first_waypoint = agent_person.waypoints.get_waypoint(0)
		assert_object(first_waypoint.pt_previous).is_same(agent_person.waypoints.starting_node)
	else:
		assert_object(starting_node_next).is_null()
