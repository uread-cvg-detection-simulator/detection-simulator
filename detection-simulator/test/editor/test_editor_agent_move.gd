extends GdUnitTestSuite

var editor_scene = "res://simulation_scenes/editor.tscn"
var runner = null
var agent: Agent = null

func before():
	runner = auto_free(scene_runner(editor_scene))

func before_test():
	agent = TestFuncs.spawn_and_get_agent(Vector2.ZERO, runner)

func after_test():
	agent.free()
	agent = null
	runner.set_property("_last_id", 0)

	if PlayTimer.play:
		runner.invoke("_on_play_button_pressed")

func test_agent_move_one_waypoint():
	var new_waypoint: Waypoint = TestFuncs.spawn_waypoint_from(agent, Vector2(1, 0), runner)
	assert_object(new_waypoint).is_not_null()

	runner.invoke("_on_play_button_pressed")
	var timeout = (1.0 / 1.42) * 1000

	await runner.await_signal("play_agents_finished", [], timeout + 100)

func test_agent_move_two_waypoints():
	var waypoint_one: Waypoint = TestFuncs.spawn_waypoint_from(agent, Vector2(1, 0), runner)
	assert_object(waypoint_one).is_not_null()

	var waypoint_two: Waypoint = TestFuncs.spawn_waypoint_from(waypoint_one, Vector2(1, 1), runner)
	assert_object(waypoint_two).is_not_null()

	runner.invoke("_on_play_button_pressed")
	var timeout = (1.0 + 1.0 / 1.42) * 1000

	await runner.await_signal("play_agents_finished", [], timeout + 100)

func test_agent_move_one_waypoint_speed():
	var new_waypoint: Waypoint = TestFuncs.spawn_waypoint_from(agent, Vector2(1, 0), runner)
	assert_object(new_waypoint).is_not_null()

	var origin_waypoint: Waypoint = agent.waypoints.get_waypoint(-1)
	assert_object(origin_waypoint).is_not_null()

	origin_waypoint.param_speed_mps = 2.84

	runner.invoke("_on_play_button_pressed")
	var timeout = (1.0 / 2.84) * 1000

	await runner.await_signal("play_agents_finished", [], timeout + 100)

func test_agent_move_two_waypoints_speed():
	var waypoint_one: Waypoint = TestFuncs.spawn_waypoint_from(agent, Vector2(1, 0), runner)
	assert_object(waypoint_one).is_not_null()

	waypoint_one.param_speed_mps = 2.84

	var waypoint_two: Waypoint = TestFuncs.spawn_waypoint_from(waypoint_one, Vector2(1, 1), runner)
	assert_object(waypoint_two).is_not_null()

	runner.invoke("_on_play_button_pressed")
	var timeout = ((1.0 / 2.84) + (1.0 / 1.42)) * 1000

	await runner.await_signal("play_agents_finished", [], timeout + 100)

