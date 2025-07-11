extends GdUnitTestSuite

## Test that event waypoint indices are updated when waypoints are inserted or deleted

const TestFuncs = preload("res://test/editor/test_funcs.gd")

var editor_scene = "res://simulation_scenes/editor.tscn"
var runner = null
var event_emitter = null

func before():
	runner = auto_free(scene_runner(editor_scene))

func before_test():
	event_emitter = runner.get_property("event_emittor")
	# Clear any existing events from previous tests
	event_emitter._manual_events.clear()

func test_event_index_update_after_waypoint_insertion():
	# Create agent
	var agent = TestFuncs.spawn_and_get_agent(Vector2.ZERO, runner)

	# Add some waypoints using the test pattern
	var wp_1 = TestFuncs.spawn_waypoint_from(agent, Vector2(1.0, 0.0), runner)  # index 0
	var wp_2 = TestFuncs.spawn_waypoint_from(wp_1, Vector2(2.0, 0.0), runner)  # index 1
	var wp_3 = TestFuncs.spawn_waypoint_from(wp_2, Vector2(3.0, 0.0), runner)  # index 2

	# Create an event that references waypoints at indices 1 and 2
	var event = SimulationEventExporterManual.new()
	event.waypoints = [[agent.agent_id, 1], [agent.agent_id, 2]]
	event_emitter.manual_event_add(event)

	# Insert a waypoint after the first one (at index 1)
	agent.waypoints.insert_after(wp_1, TestFuncs.metres_to_pixels(Vector2(1.5, 0.0)))

	# Check that event waypoint indices have been updated
	# The event should now reference indices 2 and 3 (shifted by 1)
	var updated_event = event_emitter._manual_events[0]
	assert_that(updated_event.waypoints[0][1]).is_equal(2)  # Was 1, now should be 2
	assert_that(updated_event.waypoints[1][1]).is_equal(3)  # Was 2, now should be 3

func test_event_index_update_after_waypoint_deletion():
	# Create agent
	var agent = TestFuncs.spawn_and_get_agent(Vector2.ZERO, runner)

	# Add some waypoints
	var wp_1 = TestFuncs.spawn_waypoint_from(agent, Vector2(1.0, 0.0), runner)  # index 0
	var wp_2 = TestFuncs.spawn_waypoint_from(wp_1, Vector2(2.0, 0.0), runner)  # index 1
	var wp_3 = TestFuncs.spawn_waypoint_from(wp_2, Vector2(3.0, 0.0), runner)  # index 2
	var wp_4 = TestFuncs.spawn_waypoint_from(wp_3, Vector2(4.0, 0.0), runner)  # index 3

	# Create an event that references waypoints at indices 2 and 3
	var event = SimulationEventExporterManual.new()
	event.waypoints = [[agent.agent_id, 2], [agent.agent_id, 3]]
	event_emitter.manual_event_add(event)

	# Delete waypoint at index 1 (should shift indices 2 and 3 to 1 and 2)
	agent.waypoints.delete_waypoint(wp_2)

	# Check that event waypoint indices have been updated
	# Find the event we just added by checking for our agent_id
	var updated_event = null
	for test_event in event_emitter._manual_events:
		if test_event.waypoints.size() > 0 and test_event.waypoints[0][0] == agent.agent_id:
			updated_event = test_event
			break

	assert_that(updated_event).is_not_null()
	assert_that(updated_event.waypoints[0][1]).is_equal(1)  # Was 2, now should be 1
	assert_that(updated_event.waypoints[1][1]).is_equal(2)  # Was 3, now should be 2

func test_event_index_update_preserves_other_agents():
	# Create two agents
	var agent1 = TestFuncs.spawn_and_get_agent(Vector2.ZERO, runner)
	var agent2 = TestFuncs.spawn_and_get_agent(Vector2(5.0, 0.0), runner)

	# Add waypoints to both
	var agent1_wp1 = TestFuncs.spawn_waypoint_from(agent1, Vector2(1.0, 0.0), runner)  # agent1 index 0
	var agent1_wp2 = TestFuncs.spawn_waypoint_from(agent1_wp1, Vector2(2.0, 0.0), runner)  # agent1 index 1
	var agent2_wp1 = TestFuncs.spawn_waypoint_from(agent2, Vector2(6.0, 0.0), runner)  # agent2 index 0
	var agent2_wp2 = TestFuncs.spawn_waypoint_from(agent2_wp1, Vector2(7.0, 0.0), runner)  # agent2 index 1

	# Create an event referencing both agents
	var event = SimulationEventExporterManual.new()
	event.waypoints = [[agent1.agent_id, 1], [agent2.agent_id, 1]]
	event_emitter.manual_event_add(event)

	# Insert waypoint for agent1 only
	agent1.waypoints.insert_after(agent1_wp1, TestFuncs.metres_to_pixels(Vector2(1.5, 0.0)))

	# Check that only agent1's indices are updated
	# Find the event that references both agents
	var updated_event = null
	for test_event in event_emitter._manual_events:
		if test_event.waypoints.size() >= 2 and \
		   ((test_event.waypoints[0][0] == agent1.agent_id and test_event.waypoints[1][0] == agent2.agent_id) or \
		    (test_event.waypoints[0][0] == agent2.agent_id and test_event.waypoints[1][0] == agent1.agent_id)):
			updated_event = test_event
			break

	assert_that(updated_event).is_not_null()
	# Check agent1's index was updated and agent2's remained the same
	if updated_event.waypoints[0][0] == agent1.agent_id:
		assert_that(updated_event.waypoints[0][1]).is_equal(2)  # agent1: was 1, now 2
		assert_that(updated_event.waypoints[1][1]).is_equal(1)  # agent2: should remain 1
	else:
		assert_that(updated_event.waypoints[1][1]).is_equal(2)  # agent1: was 1, now 2
		assert_that(updated_event.waypoints[0][1]).is_equal(1)  # agent2: should remain 1

func test_event_index_undo_redo():
	# Create agent
	var agent = TestFuncs.spawn_and_get_agent(Vector2.ZERO, runner)

	# Add waypoints
	var wp_1 = TestFuncs.spawn_waypoint_from(agent, Vector2(1.0, 0.0), runner)  # index 0
	var wp_2 = TestFuncs.spawn_waypoint_from(wp_1, Vector2(2.0, 0.0), runner)  # index 1

	# Create event
	var event = SimulationEventExporterManual.new()
	event.waypoints = [[agent.agent_id, 1]]

	# Store original index (should be 1)
	var original_index = 1

	event_emitter.manual_event_add(event)

	# Insert waypoint
	agent.waypoints.insert_after(wp_1, TestFuncs.metres_to_pixels(Vector2(1.5, 0.0)))

	# Verify index was updated
	# Find the event for this agent
	var updated_event = null
	for test_event in event_emitter._manual_events:
		if test_event.waypoints.size() > 0 and test_event.waypoints[0][0] == agent.agent_id:
			updated_event = test_event
			break

	assert_that(updated_event).is_not_null()
	assert_that(updated_event.waypoints[0][1]).is_equal(original_index + 1)

	# Undo the insertion
	assert_bool(UndoSystem.undo()).is_true()

	# Verify index was restored
	# Find the event for this agent again
	var restored_event = null
	for test_event in event_emitter._manual_events:
		if test_event.waypoints.size() > 0 and test_event.waypoints[0][0] == agent.agent_id:
			restored_event = test_event
			break

	assert_that(restored_event).is_not_null()
	assert_that(restored_event.waypoints[0][1]).is_equal(original_index)

func test_event_index_undo_redo_after_deletion():
	# Create agent
	var agent = TestFuncs.spawn_and_get_agent(Vector2.ZERO, runner)

	# Add waypoints
	var wp_1 = TestFuncs.spawn_waypoint_from(agent, Vector2(1.0, 0.0), runner)  # index 0
	var wp_2 = TestFuncs.spawn_waypoint_from(wp_1, Vector2(2.0, 0.0), runner)  # index 1
	var wp_3 = TestFuncs.spawn_waypoint_from(wp_2, Vector2(3.0, 0.0), runner)  # index 2

	# Create event referencing waypoint at index 2
	var event = SimulationEventExporterManual.new()
	event.waypoints = [[agent.agent_id, 2]]

	# Store original index (should be 2)
	var original_index = 2

	event_emitter.manual_event_add(event)

	# Delete waypoint at index 1 (wp_2)
	agent.waypoints.delete_waypoint(wp_2)

	# Verify index was updated (should be decremented from 2 to 1)
	# Find the event for this agent
	var updated_event = null
	for test_event in event_emitter._manual_events:
		if test_event.waypoints.size() > 0 and test_event.waypoints[0][0] == agent.agent_id:
			updated_event = test_event
			break

	assert_that(updated_event).is_not_null()
	assert_that(updated_event.waypoints[0][1]).is_equal(original_index - 1)  # Should be 1

	# Undo the deletion
	assert_bool(UndoSystem.undo()).is_true()

	# Verify index was restored to original value
	# Find the event for this agent again
	var restored_event = null
	for test_event in event_emitter._manual_events:
		if test_event.waypoints.size() > 0 and test_event.waypoints[0][0] == agent.agent_id:
			restored_event = test_event
			break

	assert_that(restored_event).is_not_null()
	assert_that(restored_event.waypoints[0][1]).is_equal(original_index)  # Should be back to 2