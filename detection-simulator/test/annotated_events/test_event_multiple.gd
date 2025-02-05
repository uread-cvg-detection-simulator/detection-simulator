extends GdUnitTestSuite

var editor_scene = "res://simulation_scenes/editor.tscn"
var runner = null

var event_emitter = null
var event_triggered = false

var agent_one: Agent = null
var agent_two: Agent = null

var agent_one_wps: Array = []
var agent_two_wps: Array = []
var stored_events: Array = []

func before():
	runner = auto_free(scene_runner(editor_scene))

func before_test():
	event_emitter = runner.get_property("event_emittor")
	event_emitter.event_emitter.connect(store_event)

	agent_one = TestFuncs.spawn_and_get_agent(Vector2.ZERO, runner)
	agent_two = TestFuncs.spawn_and_get_agent(Vector2(-1, 1), runner)


	agent_one_wps.append(TestFuncs.spawn_waypoint_from(agent_one, Vector2(1, 0), runner))
	agent_two_wps.append(TestFuncs.spawn_waypoint_from(agent_two, Vector2(1, 1), runner))

	agent_one_wps[-1].link_waypoint(agent_two_wps[-1])

	agent_one_wps.append(TestFuncs.spawn_waypoint_from(agent_one_wps[-1], Vector2(2, 0), runner))
	agent_two_wps.append(TestFuncs.spawn_waypoint_from(agent_two_wps[-1], Vector2(2, 1), runner))


func after_test():
	stored_events.clear()
	agent_one.queue_free()
	agent_two.queue_free()

	agent_one_wps.clear()
	agent_two_wps.clear()

func store_event(type: String, description: String, time: String, targets: Array):
	stored_events.append([type, description, time, targets])

func test_event_multiple_each_arrival():
	var event = SimulationEventExporterManual.new()
	event.description = "Join Area"
	event.type = "Test Type"
	event.trigger_type = SimulationEventExporterManual.TriggerType.ON_STOP
	event.mode = SimulationEventExporterManual.Mode.ON_EACH_AGENT
	event.waypoints = [[agent_one.agent_id, agent_one_wps[0].get_waypoint_index()],
					   [agent_two.agent_id, agent_two_wps[0].get_waypoint_index()]]

	event_emitter.manual_event_add(event)

	runner.invoke("_on_play_button_pressed")
	await await_signal_on(agent_one.state_machine, "transitioned", ["wait_waypoint_conditions"], 2000)
	await await_millis(50)

	var first_event_count = count_type("Test Type")
	assert_int(first_event_count).is_equal(1)


	await await_signal_on(agent_one.state_machine, "transitioned", ["follow_waypoints"], 2000)
	await await_millis(500)

	var second_event_count = count_type("Test Type")
	assert_int(second_event_count).is_equal(2)


func count_type(type: String) -> int:
	var count = 0

	for event in stored_events:
		if event[0] == type:
			count += 1

	return count
