extends GdUnitTestSuite

var editor_scene = "res://simulation_scenes/editor.tscn"
var runner = null

var agent_one: Agent = null
var agent_two: Agent = null
var agent_one_wps: Array = []
var agent_two_wps: Array = []

var event_emitter = null

func before():
	runner = auto_free(scene_runner(editor_scene))

func before_test():
	event_emitter = runner.get_property("event_emittor")
	UndoSystem.clear_history()

	# Create two agents with waypoints for testing
	agent_one = TestFuncs.spawn_and_get_agent(Vector2.ZERO, runner)
	agent_two = TestFuncs.spawn_and_get_agent(Vector2(0, 1), runner)

	agent_one_wps.append(TestFuncs.spawn_waypoint_from(agent_one, Vector2(1, 0), runner))
	agent_one_wps.append(TestFuncs.spawn_waypoint_from(agent_one_wps[-1], Vector2(2, 0), runner))

	agent_two_wps.append(TestFuncs.spawn_waypoint_from(agent_two, Vector2(1, 1), runner))
	agent_two_wps.append(TestFuncs.spawn_waypoint_from(agent_two_wps[-1], Vector2(2, 1), runner))

	await await_millis(50)

func after_test():
	# Clear undo history first, then clean up events
	UndoSystem.clear_history()
	
	# Properly remove events from waypoints before clearing
	for event in event_emitter._manual_events:
		if is_instance_valid(event):
			event.remove_event_from_waypoints()
	
	# Clear all events from the emitter
	event_emitter._manual_events.clear()
	event_emitter._undo_stored_events.clear()
	
	if agent_one != null and is_instance_valid(agent_one):
		agent_one.queue_free()
	if agent_two != null and is_instance_valid(agent_two):
		agent_two.queue_free()
	
	agent_one_wps.clear()
	agent_two_wps.clear()
	agent_one = null
	agent_two = null

## Test: Single agent with single event - event should be deleted and restored on undo
func test_single_agent_single_event_deletion():
	# Create event for agent_one
	var event = TestFuncs.create_manual_event_for_agent(agent_one, agent_one_wps[0], "Agent One Event", "Test Type")
	TestFuncs.add_event_to_emitter(event, runner)
	
	await await_millis(50)
	
	# Verify event exists and is connected
	var events_with_agent = TestFuncs.validate_agent_in_events(agent_one.agent_id, runner)
	assert_int(events_with_agent.size()).is_equal(1)
	assert_bool(TestFuncs.validate_event_waypoint_connections(events_with_agent[0])).is_true()
	
	# Delete the agent
	assert_bool(TestFuncs.simulate_agent_deletion(agent_one)).is_true()
	
	await await_millis(50)
	
	# Verify event is deleted
	events_with_agent = TestFuncs.validate_agent_in_events(agent_one.agent_id, runner)
	assert_int(events_with_agent.size()).is_equal(0)
	assert_int(event_emitter._manual_events.size()).is_equal(0)
	
	# Undo deletion
	assert_bool(UndoSystem.undo()).is_true()
	
	await await_millis(50)
	
	# Verify event is restored
	events_with_agent = TestFuncs.validate_agent_in_events(agent_one.agent_id, runner)
	assert_int(events_with_agent.size()).is_equal(1)
	assert_int(event_emitter._manual_events.size()).is_equal(1)
	
	var restored_event = events_with_agent[0]
	assert_bool(TestFuncs.validate_event_waypoint_connections(restored_event)).is_true()

## Test: Single agent with multiple events - all events should be deleted and restored
func test_single_agent_multiple_events_deletion():
	# Create multiple events for agent_one
	var event1 = TestFuncs.create_manual_event_for_agent(agent_one, agent_one_wps[0], "Agent One Event 1", "Test Type 1")
	var event2 = TestFuncs.create_manual_event_for_agent(agent_one, agent_one_wps[1], "Agent One Event 2", "Test Type 2")
	
	TestFuncs.add_event_to_emitter(event1, runner)
	TestFuncs.add_event_to_emitter(event2, runner)
	
	await await_millis(50)
	
	# Verify both events exist
	var events_with_agent = TestFuncs.validate_agent_in_events(agent_one.agent_id, runner)
	assert_int(events_with_agent.size()).is_equal(2)
	assert_int(event_emitter._manual_events.size()).is_equal(2)
	
	# Delete the agent
	assert_bool(TestFuncs.simulate_agent_deletion(agent_one)).is_true()
	
	await await_millis(50)
	
	# Verify all events are deleted
	events_with_agent = TestFuncs.validate_agent_in_events(agent_one.agent_id, runner)
	assert_int(events_with_agent.size()).is_equal(0)
	assert_int(event_emitter._manual_events.size()).is_equal(0)
	
	# Undo deletion
	assert_bool(UndoSystem.undo()).is_true()
	
	await await_millis(50)
	
	# Verify all events are restored
	events_with_agent = TestFuncs.validate_agent_in_events(agent_one.agent_id, runner)
	assert_int(events_with_agent.size()).is_equal(2)
	assert_int(event_emitter._manual_events.size()).is_equal(2)
	
	for restored_event in events_with_agent:
		assert_bool(TestFuncs.validate_event_waypoint_connections(restored_event)).is_true()

## Test: Multi-agent event with deleted agent - event should be modified (agent removed) and restored
func test_multi_agent_event_partial_deletion():
	# Create event with both agents
	var event = TestFuncs.create_manual_event_for_agent(agent_one, agent_one_wps[0], "Multi Agent Event", "Test Type")
	# Add agent_two to the same event
	event.waypoints.append([agent_two.agent_id, agent_two_wps[0].get_waypoint_index()])
	
	TestFuncs.add_event_to_emitter(event, runner)
	
	await await_millis(50)
	
	# Verify event exists with both agents
	var events_with_agent_one = TestFuncs.validate_agent_in_events(agent_one.agent_id, runner)
	var events_with_agent_two = TestFuncs.validate_agent_in_events(agent_two.agent_id, runner)
	assert_int(events_with_agent_one.size()).is_equal(1)
	assert_int(events_with_agent_two.size()).is_equal(1)
	assert_int(event.waypoints.size()).is_equal(2)
	
	# Delete agent_one
	assert_bool(TestFuncs.simulate_agent_deletion(agent_one)).is_true()
	
	await await_millis(50)
	
	# Verify event still exists but only contains agent_two
	events_with_agent_one = TestFuncs.validate_agent_in_events(agent_one.agent_id, runner)
	events_with_agent_two = TestFuncs.validate_agent_in_events(agent_two.agent_id, runner)
	assert_int(events_with_agent_one.size()).is_equal(0)
	assert_int(events_with_agent_two.size()).is_equal(1)
	assert_int(event_emitter._manual_events.size()).is_equal(1)
	
	var modified_event = events_with_agent_two[0]
	assert_int(modified_event.waypoints.size()).is_equal(1)
	assert_int(modified_event.waypoints[0][0]).is_equal(agent_two.agent_id)
	
	# Undo deletion
	assert_bool(UndoSystem.undo()).is_true()
	
	await await_millis(50)
	
	# Verify event is restored with both agents
	events_with_agent_one = TestFuncs.validate_agent_in_events(agent_one.agent_id, runner)
	events_with_agent_two = TestFuncs.validate_agent_in_events(agent_two.agent_id, runner)
	assert_int(events_with_agent_one.size()).is_equal(1)
	assert_int(events_with_agent_two.size()).is_equal(1)
	
	var restored_event = events_with_agent_one[0]
	assert_int(restored_event.waypoints.size()).is_equal(2)
	assert_bool(TestFuncs.validate_event_waypoint_connections(restored_event)).is_true()

## Test: Complex undo/redo scenario with multiple operations
func test_complex_undo_redo_scenario():
	# Create events for both agents
	var event1 = TestFuncs.create_manual_event_for_agent(agent_one, agent_one_wps[0], "Agent One Event", "Test Type")
	var event2 = TestFuncs.create_manual_event_for_agent(agent_two, agent_two_wps[0], "Agent Two Event", "Test Type")
	
	TestFuncs.add_event_to_emitter(event1, runner)
	TestFuncs.add_event_to_emitter(event2, runner)
	
	await await_millis(50)
	
	# Verify both events exist
	assert_int(event_emitter._manual_events.size()).is_equal(2)
	
	# Delete agent_one (should remove event1)
	assert_bool(TestFuncs.simulate_agent_deletion(agent_one)).is_true()
	await await_millis(50)
	assert_int(event_emitter._manual_events.size()).is_equal(1)
	
	# Delete agent_two (should remove event2)
	assert_bool(TestFuncs.simulate_agent_deletion(agent_two)).is_true()
	await await_millis(50)
	assert_int(event_emitter._manual_events.size()).is_equal(0)
	
	# Undo agent_two deletion (should restore event2)
	assert_bool(UndoSystem.undo()).is_true()
	await await_millis(50)
	assert_int(event_emitter._manual_events.size()).is_equal(1)
	var events_with_agent_two = TestFuncs.validate_agent_in_events(agent_two.agent_id, runner)
	assert_int(events_with_agent_two.size()).is_equal(1)
	
	# Undo agent_one deletion (should restore event1)
	assert_bool(UndoSystem.undo()).is_true()
	await await_millis(50)
	assert_int(event_emitter._manual_events.size()).is_equal(2)
	var events_with_agent_one = TestFuncs.validate_agent_in_events(agent_one.agent_id, runner)
	assert_int(events_with_agent_one.size()).is_equal(1)
	
	# Redo agent_one deletion
	assert_bool(UndoSystem.redo()).is_true()
	await await_millis(50)
	assert_int(event_emitter._manual_events.size()).is_equal(1)
	events_with_agent_one = TestFuncs.validate_agent_in_events(agent_one.agent_id, runner)
	assert_int(events_with_agent_one.size()).is_equal(0)
	
	# Redo agent_two deletion
	assert_bool(UndoSystem.redo()).is_true()
	await await_millis(50)
	assert_int(event_emitter._manual_events.size()).is_equal(0)

## Test: Edge case - agent deletion with no events
func test_agent_deletion_no_events():
	# Verify no events exist for agent_one
	var events_with_agent = TestFuncs.validate_agent_in_events(agent_one.agent_id, runner)
	assert_int(events_with_agent.size()).is_equal(0)
	
	# Delete agent_one (should work without issues)
	assert_bool(TestFuncs.simulate_agent_deletion(agent_one)).is_true()
	await await_millis(50)
	
	# Verify agent is disabled
	assert_bool(agent_one.disabled).is_true()
	
	# Undo deletion
	assert_bool(UndoSystem.undo()).is_true()
	await await_millis(50)
	
	# Verify agent is restored
	assert_bool(agent_one.disabled).is_false()

## Test: Edge case - event with invalid waypoint references
func test_event_with_invalid_references():
	# Create event for agent_one
	var event = TestFuncs.create_manual_event_for_agent(agent_one, agent_one_wps[0], "Agent One Event", "Test Type")
	TestFuncs.add_event_to_emitter(event, runner)
	
	await await_millis(50)
	
	# Manually corrupt event by adding invalid waypoint reference
	event.waypoints.append([9999, 9999])  # Non-existent agent and waypoint
	
	# Delete agent_one (should handle invalid references gracefully)
	assert_bool(TestFuncs.simulate_agent_deletion(agent_one)).is_true()
	await await_millis(50)
	
	# Verify deletion worked despite invalid references
	var events_with_agent = TestFuncs.validate_agent_in_events(agent_one.agent_id, runner)
	assert_int(events_with_agent.size()).is_equal(0)
	
	# Undo should also work
	assert_bool(UndoSystem.undo()).is_true()
	await await_millis(50)
	
	events_with_agent = TestFuncs.validate_agent_in_events(agent_one.agent_id, runner)
	assert_int(events_with_agent.size()).is_equal(1)