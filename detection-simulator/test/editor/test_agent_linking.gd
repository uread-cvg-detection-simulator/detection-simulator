extends GdUnitTestSuite

const TestFuncs = preload("res://test/editor/test_funcs.gd")

var editor_scene = "res://simulation_scenes/editor.tscn"
var runner: GdUnitSceneRunner = null
var agent: Agent = null
var agent_two: Agent = null


func before():
	runner = auto_free(scene_runner(editor_scene))

func before_test():
	agent = TestFuncs.spawn_and_get_agent(Vector2.ZERO, runner)
	agent_two = TestFuncs.spawn_and_get_agent(Vector2(0, 5), runner)

	runner.simulate_frames(1)

func after_test():
	agent.free()
	agent_two.free()
	agent = null
	agent_two = null

	runner.set_property("_last_id", 0)

	if PlayTimer.play:
		runner.invoke("_on_play_button_pressed")

	runner.simulate_frames(1)

func test_multiple_agents_with_waypoints():
	assert_object(agent).is_not_null()
	assert_object(agent_two).is_not_null()

	# Create two waypoints for each agent at X = 1 and X = 2
	var wp_agent_one_1: Waypoint = TestFuncs.spawn_waypoint_from(agent, Vector2(1, 0), runner)
	await await_idle_frame()
	var wp_agent_one_2: Waypoint = TestFuncs.spawn_waypoint_from(wp_agent_one_1, Vector2(2, 0), runner)
	await await_idle_frame()
	var wp_agent_two_1: Waypoint = TestFuncs.spawn_waypoint_from(agent_two, Vector2(1, 5), runner)
	await await_idle_frame()
	var wp_agent_two_2: Waypoint = TestFuncs.spawn_waypoint_from(wp_agent_two_1, Vector2(2, 5), runner)
	await await_idle_frame()

	pass

func test_link_in_place():
	assert_object(agent).is_not_null()
	assert_object(agent_two).is_not_null()

	# Create two waypoints for each agent at X = 1 and X = 2
	var wp_agent_one_1: Waypoint = TestFuncs.spawn_waypoint_from(agent, Vector2(1, 0), runner)
	var wp_agent_one_2: Waypoint = TestFuncs.spawn_waypoint_from(wp_agent_one_1, Vector2(2, 0), runner)

	var wp_agent_two_1: Waypoint = TestFuncs.spawn_waypoint_from(agent_two, Vector2(1, 5), runner)
	var wp_agent_two_2: Waypoint = TestFuncs.spawn_waypoint_from(wp_agent_two_1, Vector2(2, 5), runner)

	# Link the first points of both agents
	wp_agent_one_1.link_waypoint(wp_agent_two_1)

	runner.simulate_frames(1)
	await await_idle_frame()

	assert_array(wp_agent_one_1.linked_nodes).has_size(1)
	assert_array(wp_agent_two_1.linked_nodes).has_size(1)

	assert_object(wp_agent_one_1.linked_nodes[0]).is_same(wp_agent_two_1)
	assert_object(wp_agent_two_1.linked_nodes[0]).is_same(wp_agent_one_1)
