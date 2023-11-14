extends GdUnitTestSuite

var editor_scene = "res://simulation_scenes/editor.tscn"
var runner = null
var agent: Agent = null

func before():
	runner = auto_free(scene_runner(editor_scene))

func before_test():
	agent = _spawn_and_get_agent(Vector2.ZERO)

func after_test():
	agent.free()
	agent = null
	runner.set_property("_last_id", 0)

	if PlayTimer.play:
		runner.invoke("_on_play_button_pressed")

func test_agent_move_one_waypoint():
	var new_waypoint: Waypoint = _spawn_waypoint_from(agent, Vector2(1, 0))
	assert_object(new_waypoint).is_not_null()

	runner.invoke("_on_play_button_pressed")
	var timeout = (1.0 / 1.42) * 1000

	await runner.await_signal("play_agents_finished", [], timeout + 50)

func test_agent_move_two_waypoints():
	var waypoint_one: Waypoint = _spawn_waypoint_from(agent, Vector2(1, 0))
	assert_object(waypoint_one).is_not_null()

	var waypoint_two: Waypoint = _spawn_waypoint_from(waypoint_one, Vector2(1, 1))
	assert_object(waypoint_two).is_not_null()

	runner.invoke("_on_play_button_pressed")
	var timeout = (1.0 + 1.0 / 1.42) * 1000

	await runner.await_signal("play_agents_finished", [], timeout + 50)

func test_agent_move_one_waypoint_speed():
	var new_waypoint: Waypoint = _spawn_waypoint_from(agent, Vector2(1, 0))
	assert_object(new_waypoint).is_not_null()

	var origin_waypoint: Waypoint = agent.waypoints.get_waypoint(-1)
	assert_object(origin_waypoint).is_not_null()

	origin_waypoint.param_speed_mps = 2.84

	runner.invoke("_on_play_button_pressed")
	var timeout = (1.0 / 2.84) * 1000

	await runner.await_signal("play_agents_finished", [], timeout + 50)

func test_agent_move_two_waypoints_speed():
	var waypoint_one: Waypoint = _spawn_waypoint_from(agent, Vector2(1, 0))
	assert_object(waypoint_one).is_not_null()

	waypoint_one.param_speed_mps = 2.84

	var waypoint_two: Waypoint = _spawn_waypoint_from(waypoint_one, Vector2(1, 1))
	assert_object(waypoint_two).is_not_null()

	runner.invoke("_on_play_button_pressed")
	var timeout = ((1.0 / 2.84) + (1.0 / 1.42)) * 1000

	await runner.await_signal("play_agents_finished", [], timeout + 100)

func _spawn_waypoint_from(selected_object, position: Vector2) -> Waypoint:
	var selection = null

	if selected_object is Agent:
		selection = selected_object._current_agent._selection_area
	if selected_object is Waypoint:
		selection = selected_object._selection_area

	assert_object(selection).is_not_null()
	selection.selected = true

	var position_mod: Vector2 = Vector2(position.x * 64.0, position.y * 64.0)

	runner.set_property("_right_click_position", position_mod)
	runner.invoke("_on_empty_menu_press", ScenarioEditor.empty_menu_enum.CREATE_WAYPOINT)

	# Get waypoints object
	var waypoints = agent.waypoints

	# Get index of selected object to get the new waypoint

	var new_waypoint: Waypoint = null

	if selected_object is Agent:
		new_waypoint = waypoints.get_waypoint(0)

	if selected_object is Waypoint:
		var selected_index = waypoints.get_waypoint_index(selected_object)
		new_waypoint = waypoints.get_waypoint(selected_index + 1)

	assert_object(new_waypoint).is_not_null()

	return new_waypoint

func _spawn_and_get_agent(position: Vector2) -> Agent:
	runner.invoke("spawn_agent", position)

	var id: int = runner.get_property("_last_id")
	var agent: Agent = TreeFuncs.get_agent_with_id(id)

	return agent
