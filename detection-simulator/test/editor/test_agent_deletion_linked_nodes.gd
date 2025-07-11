extends GdUnitTestSuite

const TestFuncs = preload("res://test/editor/test_funcs.gd")

var editor_scene = "res://simulation_scenes/editor.tscn"
var runner = null

var agent_one: Agent = null
var agent_two: Agent = null
var agent_three: Agent = null
var agent_one_wps: Array = []
var agent_two_wps: Array = []
var agent_three_wps: Array = []

func before():
	runner = auto_free(scene_runner(editor_scene))

func before_test():
	UndoSystem.clear_history()

	# Create three agents with waypoints for testing
	agent_one = TestFuncs.spawn_and_get_agent(Vector2.ZERO, runner)
	agent_two = TestFuncs.spawn_and_get_agent(Vector2(0, 1), runner)
	agent_three = TestFuncs.spawn_and_get_agent(Vector2(1, 0), runner)

	# Create waypoints for each agent
	agent_one_wps.append(TestFuncs.spawn_waypoint_from(agent_one, Vector2(1, 0), runner))
	agent_one_wps.append(TestFuncs.spawn_waypoint_from(agent_one_wps[-1], Vector2(2, 0), runner))

	agent_two_wps.append(TestFuncs.spawn_waypoint_from(agent_two, Vector2(1, 1), runner))
	agent_two_wps.append(TestFuncs.spawn_waypoint_from(agent_two_wps[-1], Vector2(2, 1), runner))

	agent_three_wps.append(TestFuncs.spawn_waypoint_from(agent_three, Vector2(1, -1), runner))
	agent_three_wps.append(TestFuncs.spawn_waypoint_from(agent_three_wps[-1], Vector2(2, -1), runner))

	await await_millis(50)

func after_test():
	# Clear undo history first
	UndoSystem.clear_history()

	# Clean up agents
	if agent_one != null and is_instance_valid(agent_one):
		agent_one.queue_free()
	if agent_two != null and is_instance_valid(agent_two):
		agent_two.queue_free()
	if agent_three != null and is_instance_valid(agent_three):
		agent_three.queue_free()

	agent_one_wps.clear()
	agent_two_wps.clear()
	agent_three_wps.clear()
	agent_one = null
	agent_two = null
	agent_three = null

## Test: Simple bidirectional link between two agents, delete one agent
func test_simple_bidirectional_link_deletion():
	# Link waypoints between agent_one and agent_two
	TestFuncs.link_waypoints(agent_one_wps[0], agent_two_wps[0])

	await await_millis(50)

	# Verify the link is established bidirectionally
	assert_bool(TestFuncs.validate_waypoints_linked(agent_one_wps[0], agent_two_wps[0])).is_true()
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_one)).is_equal(1)
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_two)).is_equal(1)

	# Delete agent_one
	assert_bool(TestFuncs.simulate_agent_deletion(agent_one)).is_true()

	await await_millis(50)

	# Verify agent_two no longer has any linked waypoints
	assert_bool(TestFuncs.validate_agent_has_no_linked_waypoints(agent_two)).is_true()
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_two)).is_equal(0)

	# Undo deletion
	assert_bool(UndoSystem.undo()).is_true()

	await await_millis(50)

	# Verify the link is restored
	assert_bool(TestFuncs.validate_waypoints_linked(agent_one_wps[0], agent_two_wps[0])).is_true()
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_one)).is_equal(1)
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_two)).is_equal(1)

## Test: Multiple links from one agent to multiple other agents
func test_multiple_links_single_agent_deletion():
	# Create multiple links from agent_one to both agent_two and agent_three
	TestFuncs.link_waypoints(agent_one_wps[0], agent_two_wps[0])
	TestFuncs.link_waypoints(agent_one_wps[1], agent_three_wps[0])

	await await_millis(50)

	# Verify all links are established
	assert_bool(TestFuncs.validate_waypoints_linked(agent_one_wps[0], agent_two_wps[0])).is_true()
	assert_bool(TestFuncs.validate_waypoints_linked(agent_one_wps[1], agent_three_wps[0])).is_true()
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_one)).is_equal(2)
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_two)).is_equal(1)
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_three)).is_equal(1)

	# Delete agent_one
	assert_bool(TestFuncs.simulate_agent_deletion(agent_one)).is_true()

	await await_millis(50)

	# Verify both other agents have no linked waypoints
	assert_bool(TestFuncs.validate_agent_has_no_linked_waypoints(agent_two)).is_true()
	assert_bool(TestFuncs.validate_agent_has_no_linked_waypoints(agent_three)).is_true()

	# Undo deletion
	assert_bool(UndoSystem.undo()).is_true()

	await await_millis(50)

	# Verify all links are restored
	assert_bool(TestFuncs.validate_waypoints_linked(agent_one_wps[0], agent_two_wps[0])).is_true()
	assert_bool(TestFuncs.validate_waypoints_linked(agent_one_wps[1], agent_three_wps[0])).is_true()
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_one)).is_equal(2)
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_two)).is_equal(1)
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_three)).is_equal(1)

## Test: Complex web of interconnected links
func test_complex_interconnected_links():
	# Create a complex web of links
	TestFuncs.link_waypoints(agent_one_wps[0], agent_two_wps[0])
	TestFuncs.link_waypoints(agent_one_wps[1], agent_three_wps[0])
	TestFuncs.link_waypoints(agent_two_wps[1], agent_three_wps[1])

	await await_millis(50)

	# Verify all links
	assert_bool(TestFuncs.validate_waypoints_linked(agent_one_wps[0], agent_two_wps[0])).is_true()
	assert_bool(TestFuncs.validate_waypoints_linked(agent_one_wps[1], agent_three_wps[0])).is_true()
	assert_bool(TestFuncs.validate_waypoints_linked(agent_two_wps[1], agent_three_wps[1])).is_true()

	# Initial link counts: agent_one=2, agent_two=2, agent_three=2
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_one)).is_equal(2)
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_two)).is_equal(2)
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_three)).is_equal(2)

	# Delete agent_one (should remove 2 links)
	assert_bool(TestFuncs.simulate_agent_deletion(agent_one)).is_true()

	await await_millis(50)

	# Verify remaining links: agent_two=1, agent_three=1 (only the agent_two<->agent_three link remains)
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_two)).is_equal(1)
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_three)).is_equal(1)
	assert_bool(TestFuncs.validate_waypoints_linked(agent_two_wps[1], agent_three_wps[1])).is_true()

	# Undo deletion
	assert_bool(UndoSystem.undo()).is_true()

	await await_millis(50)

	# Verify all links are restored
	assert_bool(TestFuncs.validate_waypoints_linked(agent_one_wps[0], agent_two_wps[0])).is_true()
	assert_bool(TestFuncs.validate_waypoints_linked(agent_one_wps[1], agent_three_wps[0])).is_true()
	assert_bool(TestFuncs.validate_waypoints_linked(agent_two_wps[1], agent_three_wps[1])).is_true()
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_one)).is_equal(2)
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_two)).is_equal(2)
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_three)).is_equal(2)

## Test: Multiple sequential agent deletions with complex links
func test_multiple_sequential_deletions():
	# Create interconnected links
	TestFuncs.link_waypoints(agent_one_wps[0], agent_two_wps[0])
	TestFuncs.link_waypoints(agent_one_wps[1], agent_three_wps[0])
	TestFuncs.link_waypoints(agent_two_wps[1], agent_three_wps[1])

	await await_millis(50)

	# Initial state: all agents have 2 links each
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_one)).is_equal(2)
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_two)).is_equal(2)
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_three)).is_equal(2)

	# Delete agent_one first
	assert_bool(TestFuncs.simulate_agent_deletion(agent_one)).is_true()
	await await_millis(50)

	# Now agent_two and agent_three should have 1 link each
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_two)).is_equal(1)
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_three)).is_equal(1)

	# Delete agent_two second
	assert_bool(TestFuncs.simulate_agent_deletion(agent_two)).is_true()
	await await_millis(50)

	# Now agent_three should have no links
	assert_bool(TestFuncs.validate_agent_has_no_linked_waypoints(agent_three)).is_true()

	# Undo agent_two deletion
	assert_bool(UndoSystem.undo()).is_true()
	await await_millis(50)

	# agent_two and agent_three should have their link restored
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_two)).is_equal(1)
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_three)).is_equal(1)
	assert_bool(TestFuncs.validate_waypoints_linked(agent_two_wps[1], agent_three_wps[1])).is_true()

	# Undo agent_one deletion
	assert_bool(UndoSystem.undo()).is_true()
	await await_millis(50)

	# All original links should be restored
	assert_bool(TestFuncs.validate_waypoints_linked(agent_one_wps[0], agent_two_wps[0])).is_true()
	assert_bool(TestFuncs.validate_waypoints_linked(agent_one_wps[1], agent_three_wps[0])).is_true()
	assert_bool(TestFuncs.validate_waypoints_linked(agent_two_wps[1], agent_three_wps[1])).is_true()
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_one)).is_equal(2)
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_two)).is_equal(2)
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_three)).is_equal(2)

## Test: Agent with no linked waypoints (edge case)
func test_agent_deletion_no_linked_waypoints():
	# Verify no links exist initially
	assert_bool(TestFuncs.validate_agent_has_no_linked_waypoints(agent_one)).is_true()
	assert_bool(TestFuncs.validate_agent_has_no_linked_waypoints(agent_two)).is_true()
	assert_bool(TestFuncs.validate_agent_has_no_linked_waypoints(agent_three)).is_true()

	# Delete agent with no links
	assert_bool(TestFuncs.simulate_agent_deletion(agent_one)).is_true()
	await await_millis(50)

	# Verify agent is disabled
	assert_bool(agent_one.disabled).is_true()

	# Other agents should be unaffected
	assert_bool(TestFuncs.validate_agent_has_no_linked_waypoints(agent_two)).is_true()
	assert_bool(TestFuncs.validate_agent_has_no_linked_waypoints(agent_three)).is_true()

	# Undo deletion
	assert_bool(UndoSystem.undo()).is_true()
	await await_millis(50)

	# Verify agent is restored with no links
	assert_bool(agent_one.disabled).is_false()
	assert_bool(TestFuncs.validate_agent_has_no_linked_waypoints(agent_one)).is_true()

## Test: Self-linking protection (waypoints from same agent should not link)
func test_self_linking_protection():
	# Try to link waypoints from the same agent (should not work)
	TestFuncs.link_waypoints(agent_one_wps[0], agent_one_wps[1])

	await await_millis(50)

	# Verify no self-links were created
	assert_bool(TestFuncs.validate_waypoints_not_linked(agent_one_wps[0], agent_one_wps[1])).is_true()
	assert_bool(TestFuncs.validate_agent_has_no_linked_waypoints(agent_one)).is_true()

## Test: Complex undo/redo scenario with links
func test_complex_undo_redo_with_links():
	# Create initial links
	TestFuncs.link_waypoints(agent_one_wps[0], agent_two_wps[0])
	TestFuncs.link_waypoints(agent_two_wps[1], agent_three_wps[0])

	await await_millis(50)

	# Verify initial state
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_one)).is_equal(1)
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_two)).is_equal(2)
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_three)).is_equal(1)

	# Delete agent_two (affects both links)
	assert_bool(TestFuncs.simulate_agent_deletion(agent_two)).is_true()
	await await_millis(50)

	# agent_one and agent_three should have no links
	assert_bool(TestFuncs.validate_agent_has_no_linked_waypoints(agent_one)).is_true()
	assert_bool(TestFuncs.validate_agent_has_no_linked_waypoints(agent_three)).is_true()

	# Undo deletion
	assert_bool(UndoSystem.undo()).is_true()
	await await_millis(50)

	# Verify links are restored
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_one)).is_equal(1)
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_two)).is_equal(2)
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_three)).is_equal(1)

	# Redo deletion
	assert_bool(UndoSystem.redo()).is_true()
	await await_millis(50)

	# Links should be removed again
	assert_bool(TestFuncs.validate_agent_has_no_linked_waypoints(agent_one)).is_true()
	assert_bool(TestFuncs.validate_agent_has_no_linked_waypoints(agent_three)).is_true()

## Test: Link cleanup when undo history is cleared
func test_link_cleanup_on_history_clear():
	# Create links
	TestFuncs.link_waypoints(agent_one_wps[0], agent_two_wps[0])

	await await_millis(50)

	# Verify link exists
	assert_bool(TestFuncs.validate_waypoints_linked(agent_one_wps[0], agent_two_wps[0])).is_true()

	# Delete agent_one
	assert_bool(TestFuncs.simulate_agent_deletion(agent_one)).is_true()
	await await_millis(50)

	# Verify link is removed
	assert_bool(TestFuncs.validate_agent_has_no_linked_waypoints(agent_two)).is_true()

	# Clear undo history (this should not cause issues)
	UndoSystem.clear_history()

	# agent_two should still have no links
	assert_bool(TestFuncs.validate_agent_has_no_linked_waypoints(agent_two)).is_true()

	# And we shouldn't be able to undo (since history was cleared)
	assert_bool(UndoSystem.undo()).is_false()
