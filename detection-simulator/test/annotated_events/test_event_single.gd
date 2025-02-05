extends GdUnitTestSuite

var editor_scene = "res://simulation_scenes/editor.tscn"
var runner = null

var event_emitter = null
var event_triggered = false

func before():
	runner = auto_free(scene_runner(editor_scene))

func before_test():
	event_emitter = runner.get_property("event_emittor")


func store_event(type: String, description: String, time: String, targets: Array):
	event_triggered = true


func test_event_on_arrival():
	# Spawn the agent
	var agent = TestFuncs.spawn_and_get_agent(Vector2.ZERO, runner)

	# Create two wps (middle one to have event)
	var wp_1 = TestFuncs.spawn_waypoint_from(agent, Vector2(1.0, 0.0), runner)
	var wp_2 = TestFuncs.spawn_waypoint_from(wp_1, Vector2(2.0, 0.0), runner)

	# Create Event on wp_1
	var event = SimulationEventExporterManual.new()
	event.description = "Passed Waypoint"
	event.type = "Test Type"
	event.trigger_type = SimulationEventExporterManual.TriggerType.ON_STOP
	event.mode = SimulationEventExporterManual.Mode.ON_EACH_AGENT
	event.waypoints = [[agent.agent_id, wp_1.get_waypoint_index()]]

	event_emitter.manual_event_add(event)

	event_emitter.event_emitter.connect(store_event)

	# Run simulation and test for event poll
	#signal event_triggered(event: SimulationEventExporterManual, trigger_targets: Array)

	await await_idle_frame()
	runner.invoke("_on_play_button_pressed")

	await runner.await_signal_on(event_emitter._manual_events[0], "event_triggered", [], 3000)
	await await_millis(50)

	assert_bool(event_triggered).is_true()

	await await_idle_frame()
	runner.invoke("_on_play_button_pressed")

	agent.queue_free()

	event_emitter.manual_event_del(event)
	event.queue_free()

	event_emitter.event_emitter.disconnect(store_event)
