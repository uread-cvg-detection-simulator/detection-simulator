extends GdUnitTestSuite

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


func enter_vehicle(wp_individual: Waypoint, wp_enter: Waypoint):
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




func test_agent_exit_on_last_vehicle_wp():

	var wp_enter = TestFuncs.spawn_waypoint_from(agent_vehicle, Vector2(1, 1), runner)
	var wp_exit = TestFuncs.spawn_waypoint_from(wp_enter, Vector2(2, 1), runner)

	var wp_agent_before_enter = TestFuncs.spawn_waypoint_from(agent_person, Vector2(1, 0.5), runner)

	await await_idle_frame()
	enter_vehicle(wp_agent_before_enter, wp_enter)
	exit_vehicle(agent_person, wp_exit)

	var wp_agent_after_exit = get_after_exit_waypoint(wp_agent_before_enter)

	if wp_agent_after_exit == null:
		assert_object(wp_agent_after_exit).is_not_null()
		return

	wp_agent_after_exit.global_position = TestFuncs.metres_to_pixels(Vector2(2, 0.5))

	var final_wp = TestFuncs.spawn_waypoint_from(wp_agent_after_exit, Vector2(3, 0), runner)
	await await_idle_frame()


	runner.invoke("_on_play_button_pressed")
	var timeout = 10 * 1000

	await runner.await_signal("play_agents_finished", [], timeout + 100)
	assert_bool(wp_agent_after_exit.linked_ready).is_true()
