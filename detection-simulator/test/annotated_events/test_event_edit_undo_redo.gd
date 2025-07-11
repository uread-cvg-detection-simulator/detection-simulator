extends GdUnitTestSuite

const TestFuncs = preload("res://test/editor/test_funcs.gd")

var editor_scene = "res://simulation_scenes/editor.tscn"
var runner = null

var agent_one: Agent = null
var agent_one_wps: Array = []

var event_emitter = null

func before():
	runner = auto_free(scene_runner(editor_scene))

func before_test():
	event_emitter = runner.get_property("event_emittor")

	UndoSystem.clear_history()

	agent_one = TestFuncs.spawn_and_get_agent(Vector2.ZERO, runner)

	agent_one_wps.append(TestFuncs.spawn_waypoint_from(agent_one, Vector2(1, 0), runner))
	agent_one_wps.append(TestFuncs.spawn_waypoint_from(agent_one_wps[-1], Vector2(2, 0), runner))

	await await_millis(50)

func after_test():
	agent_one.queue_free()
	agent_one_wps.clear()

	UndoSystem.clear_history()

func test_event_edit_undo_redo():

	var event = SimulationEventExporterManual.new()
	event.description = "Join Area"
	event.type = "Test Type"
	event.trigger_type = SimulationEventExporterManual.TriggerType.ON_STOP
	event.mode = SimulationEventExporterManual.Mode.ON_EACH_AGENT
	event.waypoints = [[agent_one.agent_id, agent_one_wps[0].get_waypoint_index()]]

	event_emitter.manual_event_add(event)

	var stored_event_idx = event_emitter.manual_event_known(event)
	var stored_event = event_emitter._manual_events[stored_event_idx]

	await await_millis(50)
	runner.invoke("edit_event", stored_event)
	await await_millis(50)

	var event_panel = runner.get_property("_current_event_panel")
	event_panel._internal_panel.description_edit.text = "Test Description"
	event_panel._on_save_button_pressed()

	await await_millis(50)

	UndoSystem.undo()
	UndoSystem.undo()
	UndoSystem.redo()
	UndoSystem.redo()
