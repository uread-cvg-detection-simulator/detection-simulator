extends GdUnitTestSuite

func spawn_waypoint_from(selected_object, position: Vector2, runner: GdUnitSceneRunner) -> Waypoint:
	var selection = null
	var agent = null

	if selected_object is Agent:
		selection = selected_object._current_agent._selection_area
		agent = selected_object
	if selected_object is Waypoint:
		selection = selected_object._selection_area
		agent = selected_object.parent_object

	assert_object(selection).is_not_null()
	selection.selected = true

	var position_mod: Vector2 = metres_to_pixels(position)

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

func spawn_and_get_agent(position: Vector2, runner: GdUnitSceneRunner) -> Agent:
	var position_mod: Vector2 = metres_to_pixels(position)

	runner.invoke("spawn_agent", position_mod)

	var id: int = runner.get_property("_last_id")
	var agent: Agent = TreeFuncs.get_agent_with_id(id)

	return agent

func metres_to_pixels(metre_vector: Vector2) -> Vector2:
	return Vector2(metre_vector.x * 64.0, metre_vector.y * -64.0)
