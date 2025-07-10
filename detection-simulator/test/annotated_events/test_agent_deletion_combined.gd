extends GdUnitTestSuite

var editor_scene = "res://simulation_scenes/editor.tscn"
var runner = null

var agent_one: Agent = null
var agent_two: Agent = null
var agent_three: Agent = null
var agent_one_wps: Array = []
var agent_two_wps: Array = []
var agent_three_wps: Array = []

var event_emitter = null

func before():
	runner = auto_free(scene_runner(editor_scene))

func before_test():
	event_emitter = runner.get_property("event_emittor")
	UndoSystem.clear_history()

	# Create three agents with waypoints for testing
	agent_one = TestFuncs.spawn_and_get_agent(Vector2.ZERO, runner)
	agent_two = TestFuncs.spawn_and_get_agent(Vector2(0, 1), runner)
	agent_three = TestFuncs.spawn_and_get_agent(Vector2(1, 0), runner)

	# Create waypoints for each agent
	agent_one_wps.append(TestFuncs.spawn_waypoint_from(agent_one, Vector2(1, 0), runner))
	agent_one_wps.append(TestFuncs.spawn_waypoint_from(agent_one_wps[-1], Vector2(2, 0), runner))

	agent_two_wps.append(TestFuncs.spawn_waypoint_from(agent_two, Vector2(1, 1), runner))
	agent_two_wps.append(TestFuncs.spawn_waypoint_from(agent_two_wps[-1], Vector2(2, 1), runner))

	agent_three_wps.append(TestFuncs.spawn_waypoint_from(agent_three, Vector2(1, -1), runner))
	agent_three_wps.append(TestFuncs.spawn_waypoint_from(agent_three_wps[-1], Vector2(2, -1), runner))

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
	
	# Clean up agents
	if agent_one != null and is_instance_valid(agent_one):
		agent_one.queue_free()
	if agent_two != null and is_instance_valid(agent_two):
		agent_two.queue_free()
	if agent_three != null and is_instance_valid(agent_three):
		agent_three.queue_free()
	
	agent_one_wps.clear()
	agent_two_wps.clear()
	agent_three_wps.clear()
	agent_one = null
	agent_two = null
	agent_three = null

## Test: Agent deletion with both events and linked nodes
func test_combined_events_and_linked_nodes_deletion():
	# Create linked nodes
	TestFuncs.link_waypoints(agent_one_wps[0], agent_two_wps[0])
	TestFuncs.link_waypoints(agent_two_wps[1], agent_three_wps[0])
	
	# Create events
	var event1 = TestFuncs.create_manual_event_for_agent(agent_one, agent_one_wps[0], "Agent One Event", "Test Type")
	var event2 = TestFuncs.create_manual_event_for_agent(agent_two, agent_two_wps[0], "Agent Two Event", "Test Type")
	
	# Create multi-agent event
	var multi_event = TestFuncs.create_manual_event_for_agent(agent_one, agent_one_wps[1], "Multi Agent Event", "Test Type")
	multi_event.waypoints.append([agent_two.agent_id, agent_two_wps[1].get_waypoint_index()])
	multi_event.waypoints.append([agent_three.agent_id, agent_three_wps[0].get_waypoint_index()])
	
	TestFuncs.add_event_to_emitter(event1, runner)
	TestFuncs.add_event_to_emitter(event2, runner)
	TestFuncs.add_event_to_emitter(multi_event, runner)
	
	await await_millis(50)
	
	# Verify initial state
	# Links: agent_one=1, agent_two=2, agent_three=1
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_one)).is_equal(1)
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_two)).is_equal(2)
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_three)).is_equal(1)
	
	# Events: 3 total, agent_one in 2, agent_two in 2, agent_three in 1
	assert_int(event_emitter._manual_events.size()).is_equal(3)
	var events_with_agent_one = TestFuncs.validate_agent_in_events(agent_one.agent_id, runner)
	var events_with_agent_two = TestFuncs.validate_agent_in_events(agent_two.agent_id, runner)
	var events_with_agent_three = TestFuncs.validate_agent_in_events(agent_three.agent_id, runner)
	assert_int(events_with_agent_one.size()).is_equal(2)
	assert_int(events_with_agent_two.size()).is_equal(2)
	assert_int(events_with_agent_three.size()).is_equal(1)
	
	# Delete agent_one (should remove 1 link and 1 event, modify 1 event)
	assert_bool(TestFuncs.simulate_agent_deletion(agent_one)).is_true()
	
	await await_millis(50)
	
	# Verify link cleanup: agent_two=1, agent_three=1 (agent_two<->agent_three remains)
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_two)).is_equal(1)
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_three)).is_equal(1)
	assert_bool(TestFuncs.validate_waypoints_linked(agent_two_wps[1], agent_three_wps[0])).is_true()
	
	# Verify event cleanup: 2 events remain (agent_two's event + modified multi_event)
	assert_int(event_emitter._manual_events.size()).is_equal(2)
	events_with_agent_one = TestFuncs.validate_agent_in_events(agent_one.agent_id, runner)
	events_with_agent_two = TestFuncs.validate_agent_in_events(agent_two.agent_id, runner)
	events_with_agent_three = TestFuncs.validate_agent_in_events(agent_three.agent_id, runner)
	assert_int(events_with_agent_one.size()).is_equal(0)
	assert_int(events_with_agent_two.size()).is_equal(2)
	assert_int(events_with_agent_three.size()).is_equal(1)
	
	# Undo deletion
	assert_bool(UndoSystem.undo()).is_true()
	
	await await_millis(50)
	
	# Verify everything is restored
	# Links should be back to original state
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_one)).is_equal(1)
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_two)).is_equal(2)
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_three)).is_equal(1)
	assert_bool(TestFuncs.validate_waypoints_linked(agent_one_wps[0], agent_two_wps[0])).is_true()
	assert_bool(TestFuncs.validate_waypoints_linked(agent_two_wps[1], agent_three_wps[0])).is_true()
	
	# Events should be back to original state
	assert_int(event_emitter._manual_events.size()).is_equal(3)
	events_with_agent_one = TestFuncs.validate_agent_in_events(agent_one.agent_id, runner)
	events_with_agent_two = TestFuncs.validate_agent_in_events(agent_two.agent_id, runner)
	events_with_agent_three = TestFuncs.validate_agent_in_events(agent_three.agent_id, runner)
	assert_int(events_with_agent_one.size()).is_equal(2)
	assert_int(events_with_agent_two.size()).is_equal(2)
	assert_int(events_with_agent_three.size()).is_equal(1)

## Test: Sequential deletions affecting both events and links
func test_sequential_deletions_combined():
	# Create a complex scenario with interconnected events and links
	TestFuncs.link_waypoints(agent_one_wps[0], agent_two_wps[0])
	TestFuncs.link_waypoints(agent_two_wps[1], agent_three_wps[0])
	TestFuncs.link_waypoints(agent_one_wps[1], agent_three_wps[1])
	
	# Create events involving multiple agents
	var event_all_three = TestFuncs.create_manual_event_for_agent(agent_one, agent_one_wps[0], "All Three Event", "Test Type")
	event_all_three.waypoints.append([agent_two.agent_id, agent_two_wps[0].get_waypoint_index()])
	event_all_three.waypoints.append([agent_three.agent_id, agent_three_wps[0].get_waypoint_index()])
	
	var event_one_two = TestFuncs.create_manual_event_for_agent(agent_one, agent_one_wps[1], "One Two Event", "Test Type")
	event_one_two.waypoints.append([agent_two.agent_id, agent_two_wps[1].get_waypoint_index()])
	
	TestFuncs.add_event_to_emitter(event_all_three, runner)
	TestFuncs.add_event_to_emitter(event_one_two, runner)
	
	await await_millis(50)
	
	# Initial state: 3 links total, 2 events, all agents involved
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_one)).is_equal(2)
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_two)).is_equal(2)
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_three)).is_equal(2)
	assert_int(event_emitter._manual_events.size()).is_equal(2)
	
	# Delete agent_one first
	assert_bool(TestFuncs.simulate_agent_deletion(agent_one)).is_true()
	await await_millis(50)
	
	# After agent_one deletion:
	# Links: agent_two=1, agent_three=1 (only agent_two<->agent_three remains)
	# Events: 1 event remains (modified event_all_three with only agent_two and agent_three)
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_two)).is_equal(1)
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_three)).is_equal(1)
	assert_int(event_emitter._manual_events.size()).is_equal(1)
	
	# Delete agent_two second
	assert_bool(TestFuncs.simulate_agent_deletion(agent_two)).is_true()
	await await_millis(50)
	
	# After agent_two deletion:
	# Links: agent_three=0 (no links remain)
	# Events: 0 events remain (the remaining event only had agent_two and agent_three)
	assert_bool(TestFuncs.validate_agent_has_no_linked_waypoints(agent_three)).is_true()
	assert_int(event_emitter._manual_events.size()).is_equal(0)
	
	# Undo agent_two deletion
	assert_bool(UndoSystem.undo()).is_true()
	await await_millis(50)
	
	# Should restore agent_two's state
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_two)).is_equal(1)
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_three)).is_equal(1)
	assert_int(event_emitter._manual_events.size()).is_equal(1)
	
	# Undo agent_one deletion
	assert_bool(UndoSystem.undo()).is_true()
	await await_millis(50)
	
	# Should restore everything to original state
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_one)).is_equal(2)
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_two)).is_equal(2)
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_three)).is_equal(2)
	assert_int(event_emitter._manual_events.size()).is_equal(2)

## Test: Edge case - agent with no events but has linked nodes
func test_agent_with_only_linked_nodes():
	# Create only linked nodes, no events
	TestFuncs.link_waypoints(agent_one_wps[0], agent_two_wps[0])
	TestFuncs.link_waypoints(agent_one_wps[1], agent_three_wps[0])
	
	await await_millis(50)
	
	# Verify links exist but no events
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_one)).is_equal(2)
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_two)).is_equal(1)
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_three)).is_equal(1)
	assert_int(event_emitter._manual_events.size()).is_equal(0)
	
	# Delete agent_one
	assert_bool(TestFuncs.simulate_agent_deletion(agent_one)).is_true()
	await await_millis(50)
	
	# Verify links are cleaned up but no event changes
	assert_bool(TestFuncs.validate_agent_has_no_linked_waypoints(agent_two)).is_true()
	assert_bool(TestFuncs.validate_agent_has_no_linked_waypoints(agent_three)).is_true()
	assert_int(event_emitter._manual_events.size()).is_equal(0)
	
	# Undo deletion
	assert_bool(UndoSystem.undo()).is_true()
	await await_millis(50)
	
	# Verify links are restored
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_one)).is_equal(2)
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_two)).is_equal(1)
	assert_int(TestFuncs.count_agent_linked_waypoints(agent_three)).is_equal(1)
	assert_int(event_emitter._manual_events.size()).is_equal(0)

## Test: Edge case - agent with events but no linked nodes
func test_agent_with_only_events():
	# Create only events, no linked nodes
	var event1 = TestFuncs.create_manual_event_for_agent(agent_one, agent_one_wps[0], "Agent One Event", "Test Type")
	var event2 = TestFuncs.create_manual_event_for_agent(agent_one, agent_one_wps[1], "Agent One Event 2", "Test Type")
	
	TestFuncs.add_event_to_emitter(event1, runner)
	TestFuncs.add_event_to_emitter(event2, runner)
	
	await await_millis(50)
	
	# Verify events exist but no links
	assert_bool(TestFuncs.validate_agent_has_no_linked_waypoints(agent_one)).is_true()
	assert_bool(TestFuncs.validate_agent_has_no_linked_waypoints(agent_two)).is_true()
	assert_bool(TestFuncs.validate_agent_has_no_linked_waypoints(agent_three)).is_true()
	assert_int(event_emitter._manual_events.size()).is_equal(2)
	
	var events_with_agent_one = TestFuncs.validate_agent_in_events(agent_one.agent_id, runner)
	assert_int(events_with_agent_one.size()).is_equal(2)
	
	# Delete agent_one
	assert_bool(TestFuncs.simulate_agent_deletion(agent_one)).is_true()
	await await_millis(50)
	
	# Verify events are cleaned up but no link changes
	assert_bool(TestFuncs.validate_agent_has_no_linked_waypoints(agent_two)).is_true()
	assert_bool(TestFuncs.validate_agent_has_no_linked_waypoints(agent_three)).is_true()
	assert_int(event_emitter._manual_events.size()).is_equal(0)
	
	# Undo deletion
	assert_bool(UndoSystem.undo()).is_true()
	await await_millis(50)
	
	# Verify events are restored
	assert_bool(TestFuncs.validate_agent_has_no_linked_waypoints(agent_one)).is_true()
	assert_bool(TestFuncs.validate_agent_has_no_linked_waypoints(agent_two)).is_true()
	assert_bool(TestFuncs.validate_agent_has_no_linked_waypoints(agent_three)).is_true()
	assert_int(event_emitter._manual_events.size()).is_equal(2)
	
	events_with_agent_one = TestFuncs.validate_agent_in_events(agent_one.agent_id, runner)
	assert_int(events_with_agent_one.size()).is_equal(2)