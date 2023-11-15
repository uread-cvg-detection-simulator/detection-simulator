extends GdUnitTestSuite

var editor_scene = "res://simulation_scenes/editor.tscn"
var runner = null
var agent: Agent = null
var agent_two: Agent = null

func before():
	runner = auto_free(scene_runner(editor_scene))

func before_test():
	agent = _spawn_and_get_agent(Vector2.ZERO)
	agent_two = _spawn_and_get_agent(Vector2(0, 5))

func after_test():
	agent.free()
	agent_two.free()
	agent = null
	agent_two = null

	runner.set_property("_last_id", 0)

	if PlayTimer.play:
		runner.invoke("_on_play_button_pressed")


func test_multiple_agents_with_waypoints():
	assert_object(agent).is_not_null()
	assert_object(agent_two).is_not_null()

	# Create two waypoints for each agent at X = 1 and X = 2
	var wp_agent_one_1 = _spawn_waypoint_from(agent, Vector2(1, 0))
	var wp_agent_one_2 = _spawn_waypoint_from(wp_agent_one_1, Vector2(2, 0))

	var wp_agent_two_1 = _spawn_waypoint_from(agent_two, Vector2(1, 5))
	var wp_agent_two_2 = _spawn_waypoint_from(wp_agent_two_1, Vector2(2, 5))

func test_link_in_place():
	assert_object(agent).is_not_null()
	assert_object(agent_two).is_not_null()

	# Create two waypoints for each agent at X = 1 and X = 2
	var wp_agent_one_1 = _spawn_waypoint_from(agent, Vector2(1, 0))
	var wp_agent_one_2 = _spawn_waypoint_from(wp_agent_one_1, Vector2(2, 0))

	var wp_agent_two_1 = _spawn_waypoint_from(agent_two, Vector2(1, 5))
	var wp_agent_two_2 = _spawn_waypoint_from(wp_agent_two_1, Vector2(2, 5))

	# Link the first points of both agents




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
