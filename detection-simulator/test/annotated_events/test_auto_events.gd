extends GdUnitTestSuite

var editor_scene = "res://simulation_scenes/editor.tscn"
var runner = null

var event_emitter = null
var event_triggered = false

var agent_person: Agent = null
var agent_vehicle: Agent = null

var wp_agent_one_1: Waypoint = null

var wp_agent_two_1: Waypoint = null
var wp_agent_two_2: Waypoint = null

var stored_events: Array = []

func before():
	runner = auto_free(scene_runner(editor_scene))

func before_test():
	event_emitter = runner.get_property("event_emittor")
	event_emitter.event_emitter.connect(store_event)

	agent_person = TestFuncs.spawn_and_get_agent(Vector2.ZERO, runner)
	agent_vehicle = TestFuncs.spawn_and_get_agent(Vector2(0, 1), runner)
	agent_vehicle.agent_type = Agent.AgentType.BoatTarget

	var wp_enter = TestFuncs.spawn_waypoint_from(agent_vehicle, Vector2(1, 1), runner)
	var wp_exit = TestFuncs.spawn_waypoint_from(wp_enter, Vector2(2, 1), runner)
	var wp_veh_cont = TestFuncs.spawn_waypoint_from(wp_exit, Vector2(3, 1), runner)

	var wp_agent_before_enter = TestFuncs.spawn_waypoint_from(agent_person, Vector2(1, 0.5), runner)

	await await_idle_frame()
	TestFuncs.enter_vehicle(wp_agent_before_enter, wp_enter, runner)
	TestFuncs.exit_vehicle(agent_person, wp_exit)

	var wp_agent_after_exit = TestFuncs.get_after_exit_waypoint(wp_agent_before_enter)

	if wp_agent_after_exit == null:
		assert_object(wp_agent_after_exit).is_not_null()
		return

	wp_agent_after_exit.global_position = TestFuncs.metres_to_pixels(Vector2(2, 0.5))

	var final_wp = TestFuncs.spawn_waypoint_from(wp_agent_after_exit, Vector2(3, 0), runner)
	await await_idle_frame()

func after_test():
	stored_events.clear()
	agent_person.queue_free()
	agent_vehicle.queue_free()

func store_event(type: String, description: String, time: String):
	stored_events.append([type, description, time])

func test_agent_enter_event():
	# Start the simulation

	runner.invoke("_on_play_button_pressed")
	await await_idle_frame()

	await await_signal_on(agent_person.state_machine, "transitioned", ["hidden_follow_vehicle"], 2000)
	await await_millis(500)

	var vehicle_entered_count: int = 0

	for ev in stored_events:
		if ev[0] == "VEHICLE ENTERED":
			vehicle_entered_count += 1


	runner.invoke("_on_play_button_pressed")
	assert_int(vehicle_entered_count).is_equal(1)


func test_agent_exit_event():
	runner.invoke("_on_play_button_pressed")
	await await_idle_frame()

	await await_signal_on(agent_person.state_machine, "transitioned", ["hidden_follow_vehicle"], 2000)
	await await_millis(50)

	await await_signal_on(agent_person.state_machine, "transitioned", ["follow_waypoints"], 2000)
	await await_millis(500)

	var vehicle_exited_count: int = 0

	for ev in stored_events:
		if ev[0] == "VEHICLE EXITED":
			vehicle_exited_count += 1

	runner.invoke("_on_play_button_pressed")
	assert_int(vehicle_exited_count).is_equal(1)
