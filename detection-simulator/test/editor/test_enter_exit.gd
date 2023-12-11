extends GdUnitTestSuite

var editor_scene = "res://simulation_scenes/editor.tscn"
var runner = null
var agent: Agent = null
var agent_two: Agent = null

var wp_agent_one_1: Waypoint = null

var wp_agent_two_1: Waypoint = null
var wp_agent_two_2: Waypoint = null

func before():
	runner = auto_free(scene_runner(editor_scene))

func before_test():
	agent = TestFuncs.spawn_and_get_agent(Vector2.ZERO, runner)
	agent_two = TestFuncs.spawn_and_get_agent(Vector2(0, 1), runner)

	# Create two waypoints for each agent at X = 1 and X = 2
	wp_agent_one_1 = TestFuncs.spawn_waypoint_from(agent, Vector2(1, 0), runner)
	assert_object(wp_agent_one_1).is_not_null().override_failure_message("WP A1W1 is Null")
	await await_idle_frame()

	wp_agent_two_1 = TestFuncs.spawn_waypoint_from(agent_two, Vector2(1, 1), runner)
	assert_object(wp_agent_two_1).is_not_null().override_failure_message("WP A2W1 is Null")
	await await_idle_frame()

	wp_agent_two_2 = TestFuncs.spawn_waypoint_from(wp_agent_two_1, Vector2(2, 1), runner)
	assert_object(wp_agent_two_2).is_not_null().override_failure_message("WP A2W1 is Null")
	await await_idle_frame()




func after_test():
	agent.free()
	agent_two.free()
	agent = null
	agent_two = null

	wp_agent_one_1 = null
	wp_agent_two_1 = null
	wp_agent_two_2 = null

	runner.set_property("_last_id", 0)
	UndoSystem.clear_history()

	if PlayTimer.play:
		runner.invoke("_on_play_button_pressed")


func test_agent_enter_context_no_selection_no_option():
	assert_object(agent).is_not_null()
	assert_object(agent_two).is_not_null()
	assert_object(wp_agent_one_1).is_not_null()
	assert_object(wp_agent_two_1).is_not_null()
	assert_object(wp_agent_two_2).is_not_null()


	# Check right click PopupMenu (waypoint.context_menu) does not contain "Enter Vehicle"
	wp_agent_two_1._prepare_menu()
	assert_bool(_find_string_in_context_menu(wp_agent_two_1.context_menu, "Enter Vehicle")).is_false()

	await await_idle_frame()
	pass

func test_agent_enter_context_selection_option_nonvehicle():
	assert_object(agent).is_not_null()
	assert_object(agent_two).is_not_null()
	assert_object(wp_agent_one_1).is_not_null()
	assert_object(wp_agent_two_1).is_not_null()
	assert_object(wp_agent_two_2).is_not_null()

	agent_two.agent_type = Agent.AgentType.PersonTarget

	# Check right click PopupMenu (waypoint.context_menu) does contain "Enter Vehicle"
	# after selecting a waypoint of another agent
	wp_agent_one_1._selection_area.selected = true
	await await_idle_frame()

	wp_agent_two_1._prepare_menu()
	assert_bool(_find_string_in_context_menu(wp_agent_two_1.context_menu, "Enter Vehicle")).is_false()

func test_agent_enter_context_selection_option_vehicle():
	assert_object(agent).is_not_null()
	assert_object(agent_two).is_not_null()
	assert_object(wp_agent_one_1).is_not_null()
	assert_object(wp_agent_two_1).is_not_null()
	assert_object(wp_agent_two_2).is_not_null()

	agent_two.agent_type = Agent.AgentType.BoatTarget

	# Check right click PopupMenu (waypoint.context_menu) does contain "Enter Vehicle"
	# after selecting a waypoint of another agent
	wp_agent_one_1._selection_area.selected = true
	await await_idle_frame()

	wp_agent_two_1._prepare_menu()
	assert_bool(_find_string_in_context_menu(wp_agent_two_1.context_menu, "Enter Vehicle")).is_true()

func test_agent_enter_context_selection_option_on_click():
	assert_object(agent).is_not_null()
	assert_object(agent_two).is_not_null()
	assert_object(wp_agent_one_1).is_not_null()
	assert_object(wp_agent_two_1).is_not_null()
	assert_object(wp_agent_two_2).is_not_null()

	agent_two.agent_type = Agent.AgentType.BoatTarget

	wp_agent_one_1._selection_area.selected = true
	await await_idle_frame()

	# TODO - Figure out how to do this by simulating mouse movements

	wp_agent_two_1._popup_menu_at_mouse()
	assert_bool(_find_string_in_context_menu(wp_agent_two_1.context_menu, "Enter Vehicle")).is_true()

	await await_idle_frame()
	pass

func test_agent_enter_on_click():
	assert_object(agent).is_not_null()
	assert_object(agent_two).is_not_null()
	assert_object(wp_agent_one_1).is_not_null()
	assert_object(wp_agent_two_1).is_not_null()
	assert_object(wp_agent_two_2).is_not_null()

	agent_two.agent_type = Agent.AgentType.BoatTarget

	wp_agent_one_1._selection_area.selected = true
	await await_idle_frame()

	wp_agent_two_1._on_enter_vehicle()

	# Check A1's last waypoint is an Enter Vehicle type
	var last_wp: Waypoint = agent.waypoints.get_waypoint(agent.waypoints.waypoints.size() -1)
	assert_that(last_wp.waypoint_type == Waypoint.WaypointType.ENTER)

	# Check the last wp is disabled
	assert_bool(last_wp.disabled).is_true()

	# Check last_wp is in wp_agent_two_1's enter_nodes list
	assert_bool(wp_agent_two_1.enter_nodes.has(last_wp)).is_true()

	# Check wp_agent_two_1 is the last_wp's vehicle
	assert_object(last_wp.vehicle_wp).is_same(wp_agent_two_1)

func test_agent_enter_undo_redo():
	assert_object(agent).is_not_null()
	assert_object(agent_two).is_not_null()
	assert_object(wp_agent_one_1).is_not_null()
	assert_object(wp_agent_two_1).is_not_null()
	assert_object(wp_agent_two_2).is_not_null()

	agent_two.agent_type = Agent.AgentType.BoatTarget

	wp_agent_one_1._selection_area.selected = true
	await await_idle_frame()

	wp_agent_two_1._on_enter_vehicle()

	agent.waypoints.get_waypoint(agent.waypoints.waypoints.size() -1)

	# Undo and check
	assert_bool(UndoSystem.undo()).is_true()

	# Check A1's last waypoint is NOT Enter Vehicle type
	var last_wp: Waypoint = agent.waypoints.get_waypoint(agent.waypoints.waypoints.size() -1)
	assert_that(last_wp.waypoint_type == Waypoint.WaypointType.WAYPOINT)

	# Check wp_agent_two_1's enter_nodes list is empty
	assert_bool(wp_agent_two_1.enter_nodes.is_empty()).is_true()

	# Redo and check
	assert_bool(UndoSystem.redo()).is_true()

	# Check A1's last waypoint is an Enter Vehicle type
	last_wp = agent.waypoints.get_waypoint(agent.waypoints.waypoints.size() -1)
	assert_that(last_wp.waypoint_type == Waypoint.WaypointType.ENTER)

	# Check wp_agent_two_1's enter_nodes list is NOT empty
	assert_bool(wp_agent_two_1.enter_nodes.is_empty()).is_false()

func test_vehicle_wait_for_entrant():
	assert_object(agent).is_not_null()
	assert_object(agent_two).is_not_null()
	assert_object(wp_agent_one_1).is_not_null()
	assert_object(wp_agent_two_1).is_not_null()
	assert_object(wp_agent_two_2).is_not_null()

	agent_two.agent_type = Agent.AgentType.BoatTarget

	agent_two._move(agent_two.global_position, TestFuncs.metres_to_pixels(Vector2(0.5, 1)))
	await await_idle_frame()

	wp_agent_one_1._selection_area.selected = true
	await await_idle_frame()

	wp_agent_two_1._on_enter_vehicle()

	# Start the simulation
	runner.invoke("_on_play_button_pressed")
	await await_idle_frame()

	await await_signal_on(agent_two.state_machine, "transitioned", ["wait_waypoint_conditions"], 2000)
	await await_signal_on(agent.state_machine, "transitioned", ["follow_waypoints"], 1000)

func test_entrant_wait_for_vehicle():
	assert_object(agent).is_not_null()
	assert_object(agent_two).is_not_null()
	assert_object(wp_agent_one_1).is_not_null()
	assert_object(wp_agent_two_1).is_not_null()
	assert_object(wp_agent_two_2).is_not_null()

	agent_two.agent_type = Agent.AgentType.BoatTarget

	agent._move(agent.global_position, TestFuncs.metres_to_pixels(Vector2(0.5, 0)))
	await await_idle_frame()

	wp_agent_one_1._selection_area.selected = true
	await await_idle_frame()

	wp_agent_two_1._on_enter_vehicle()

	# Start the simulation

	runner.invoke("_on_play_button_pressed")
	await await_idle_frame()

	await await_signal_on(agent.state_machine, "transitioned", ["wait_waypoint_conditions"], 2000)
	await await_signal_on(agent.state_machine, "transitioned", ["follow_waypoints"], 1000)

func test_entrant_enters_hidden_state_vehicle_moving():
	assert_object(agent).is_not_null()
	assert_object(agent_two).is_not_null()
	assert_object(wp_agent_one_1).is_not_null()
	assert_object(wp_agent_two_1).is_not_null()
	assert_object(wp_agent_two_2).is_not_null()

	agent_two.agent_type = Agent.AgentType.BoatTarget

	await await_idle_frame()

	wp_agent_one_1._selection_area.selected = true
	await await_idle_frame()

	wp_agent_two_1._on_enter_vehicle()

	# Start the simulation

	runner.invoke("_on_play_button_pressed")
	await await_idle_frame()

	await await_signal_on(agent_two.state_machine, "transitioned", ["wait_waypoint_conditions"], 2000)
	await await_signal_on(agent.state_machine, "transitioned", ["hidden_follow_vehicle"], 2000)

	assert_str(String(agent.state_machine.state.name)).is_equal("hidden_follow_vehicle")

	await await_millis(50)

	assert_str(String(agent_two.state_machine.state.name)).is_equal("follow_waypoints")

	await await_signal_on(agent_two.state_machine, "transitioned", ["idle"], 2000)
	await await_millis(50)
	assert_str(String(agent.state_machine.state.name)).is_equal("idle")

func test_exit_menu_button():
	assert_object(agent).is_not_null()
	assert_object(agent_two).is_not_null()
	assert_object(wp_agent_one_1).is_not_null()
	assert_object(wp_agent_two_1).is_not_null()
	assert_object(wp_agent_two_2).is_not_null()

	agent_two.agent_type = Agent.AgentType.BoatTarget

	await await_idle_frame()

	wp_agent_one_1._selection_area.selected = true
	await await_idle_frame()

	wp_agent_two_1._on_enter_vehicle()

	wp_agent_two_1._prepare_menu()
	wp_agent_two_2._prepare_menu()

	assert_bool(_find_string_in_context_menu(wp_agent_two_1.context_menu, "Exit Vehicle A1")).is_false()
	assert_bool(_find_string_in_context_menu(wp_agent_two_2.context_menu, "Exit Vehicle A1")).is_true()

func test_exit_menu_button_on_click():
	assert_object(agent).is_not_null()
	assert_object(agent_two).is_not_null()
	assert_object(wp_agent_one_1).is_not_null()
	assert_object(wp_agent_two_1).is_not_null()
	assert_object(wp_agent_two_2).is_not_null()

	agent_two.agent_type = Agent.AgentType.BoatTarget

	await await_idle_frame()

	wp_agent_one_1._selection_area.selected = true
	await await_idle_frame()

	wp_agent_two_1._on_enter_vehicle()

	wp_agent_two_1._prepare_menu()
	wp_agent_two_2._prepare_menu()

	var item_found = _find_string_in_context_menu(wp_agent_two_2.context_menu, "Exit Vehicle A1")
	assert_bool(item_found).is_true()

	if item_found:
		wp_agent_two_2._context_menu_id_pressed(Waypoint.ContextMenuIDs.EXIT_VEHICLE + 1)
		await await_idle_frame()

		# Check A1's last waypoint is NOT Enter/Exit Waypoint Type
		var last_wp: Waypoint = agent.waypoints.get_waypoint(agent.waypoints.waypoints.size() -1)
		assert_that(last_wp.waypoint_type == Waypoint.WaypointType.WAYPOINT)

func test_exit_menu_button_on_click_not_in_subsequent():
	assert_object(agent).is_not_null()
	assert_object(agent_two).is_not_null()
	assert_object(wp_agent_one_1).is_not_null()
	assert_object(wp_agent_two_1).is_not_null()
	assert_object(wp_agent_two_2).is_not_null()

	var wp_agent_two_3: Waypoint = TestFuncs.spawn_waypoint_from(wp_agent_two_2, Vector2(3, 1), runner)
	assert_object(wp_agent_two_3).is_not_null().override_failure_message("WP A2W1 is Null")
	await await_idle_frame()

	agent_two.agent_type = Agent.AgentType.BoatTarget

	await await_idle_frame()

	wp_agent_one_1._selection_area.selected = true
	await await_idle_frame()

	wp_agent_two_1._on_enter_vehicle()

	wp_agent_two_1._prepare_menu()
	wp_agent_two_2._prepare_menu()

	var item_found = _find_string_in_context_menu(wp_agent_two_2.context_menu, "Exit Vehicle A1")
	assert_bool(item_found).is_true()

	if item_found:
		wp_agent_two_2._context_menu_id_pressed(Waypoint.ContextMenuIDs.EXIT_VEHICLE + 1)
		await await_idle_frame()

		wp_agent_two_3._prepare_menu()
		var exit_in_subsequent = _find_string_in_context_menu(wp_agent_two_3.context_menu, "Exit Vehicle A1")
		assert_bool(exit_in_subsequent).is_false()


func _find_string_in_context_menu(context_menu: PopupMenu, string: String):
	var string_found: bool = false

	for i in range(context_menu.item_count):
		var item = context_menu.get_item_text(i)
		if item == string:
			string_found = true
			break

	return string_found

