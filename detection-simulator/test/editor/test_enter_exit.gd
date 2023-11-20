extends GdUnitTestSuite

var editor_scene = "res://simulation_scenes/editor.tscn"
var runner = null
var agent: Agent = null
var agent_two: Agent = null

var wp_agent_one_1: Waypoint = null
var wp_agent_one_2: Waypoint = null

var wp_agent_two_1: Waypoint = null
var wp_agent_two_2: Waypoint = null

func before():
	runner = auto_free(scene_runner(editor_scene))

func before_test():
	agent = TestFuncs.spawn_and_get_agent(Vector2.ZERO, runner)
	agent_two = TestFuncs.spawn_and_get_agent(Vector2(0, 5), runner)

	# Create two waypoints for each agent at X = 1 and X = 2
	wp_agent_one_1 = TestFuncs.spawn_waypoint_from(agent, Vector2(1, 0), runner)
	assert_object(wp_agent_one_1).is_not_null().override_failure_message("WP A1W1 is Null")
	await await_idle_frame()

	wp_agent_one_2 = TestFuncs.spawn_waypoint_from(wp_agent_one_1, Vector2(2, 0), runner)
	assert_object(wp_agent_one_1).is_not_null().override_failure_message("WP A1W2 is Null")
	await await_idle_frame()

	wp_agent_two_1 = TestFuncs.spawn_waypoint_from(agent_two, Vector2(1, 5), runner)
	assert_object(wp_agent_one_1).is_not_null().override_failure_message("WP A2W1 is Null")
	await await_idle_frame()

	wp_agent_two_2 = TestFuncs.spawn_waypoint_from(wp_agent_two_1, Vector2(2, 5), runner)
	assert_object(wp_agent_one_1).is_not_null().override_failure_message("WP A2W1 is Null")
	await await_idle_frame()



func after_test():
	agent.free()
	agent_two.free()
	agent = null
	agent_two = null

	wp_agent_one_1 = null
	wp_agent_one_2 = null
	wp_agent_two_1 = null
	wp_agent_two_2 = null

	runner.set_property("_last_id", 0)

	if PlayTimer.play:
		runner.invoke("_on_play_button_pressed")


func test_agent_enter_context_no_selection_no_option():
	assert_object(agent).is_not_null()
	assert_object(agent_two).is_not_null()
	assert_object(wp_agent_one_1).is_not_null()
	assert_object(wp_agent_one_2).is_not_null()
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
	assert_object(wp_agent_one_2).is_not_null()
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
	assert_object(wp_agent_one_2).is_not_null()
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
	assert_object(wp_agent_one_2).is_not_null()
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

func _find_string_in_context_menu(context_menu: PopupMenu, string: String):
	var string_found: bool = false

	for i in range(context_menu.item_count):
		var item = context_menu.get_item_text(i)
		if item == string:
			string_found = true
			break

	return string_found

