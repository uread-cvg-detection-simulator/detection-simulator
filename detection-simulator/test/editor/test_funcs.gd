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

func find_string_in_context_menu(context_menu: PopupMenu, string: String):
	var string_found: bool = false

	for i in range(context_menu.item_count):
		var item = context_menu.get_item_text(i)
		if item == string:
			string_found = true
			break

	return string_found

func enter_vehicle(wp_individual: Waypoint, wp_enter: Waypoint, runner: GdUnitSceneRunner):
	wp_individual._selection_area.selected = true
	runner.simulate_frames(1)

	wp_enter._on_enter_vehicle()
	runner.simulate_frames(1)

func exit_vehicle(agent: Agent, wp_exit: Waypoint) -> bool:
	wp_exit._prepare_menu()

	if TestFuncs.find_string_in_context_menu(wp_exit.context_menu, "Exit Vehicle A%d" % agent.agent_id):
		wp_exit._context_menu_id_pressed(Waypoint.ContextMenuIDs.EXIT_VEHICLE + agent.agent_id)
		return true
	else:
		return false

func get_after_exit_waypoint(wp_before_enter: Waypoint) -> Waypoint:
	# Before Enter -> Enter -> Exit -> After Exit

	if wp_before_enter.pt_next == null:
		return null

	var wp_enter = wp_before_enter.pt_next

	if wp_enter.pt_next == null:
		return null

	var wp_exit = wp_enter.pt_next

	if wp_exit.pt_next == null:
		return null

	return wp_exit.pt_next
