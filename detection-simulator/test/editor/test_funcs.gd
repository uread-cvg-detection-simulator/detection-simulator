extends GdUnitTestSuite

func spawn_waypoint_from(selected_object, position: Vector2, runner: GdUnitSceneRunner) -> Waypoint:
	var selection = null
	var agent = null

	if selected_object is Agent:
		selection = selected_object._current_agent._selection_area
		agent = selected_object
	if selected_object is Waypoint:
		selection = selected_object._selection_area
		agent = selected_object.parent_object

	assert_object(selection).is_not_null()
	selection.selected = true

	var position_mod: Vector2 = metres_to_pixels(position)

	runner.set_property("_right_click_position", position_mod)
	runner.invoke("_on_empty_menu_press", ScenarioEditor.empty_menu_enum.CREATE_WAYPOINT)

	# Get waypoints object
	var waypoints = agent.waypoints

	# Get index of selected object to get the new waypoint

	var new_waypoint: Waypoint = null

	if selected_object is Agent:
		new_waypoint = waypoints.get_waypoint(0)

	if selected_object is Waypoint:
		var selected_index = waypoints.get_waypoint_index(selected_object)
		new_waypoint = waypoints.get_waypoint(selected_index + 1)

	assert_object(new_waypoint).is_not_null()

	return new_waypoint

func spawn_and_get_agent(position: Vector2, runner: GdUnitSceneRunner) -> Agent:
	var position_mod: Vector2 = metres_to_pixels(position)

	runner.invoke("spawn_agent", position_mod)

	var id: int = runner.get_property("_last_id")
	var agent: Agent = TreeFuncs.get_agent_with_id(id)

	return agent

func metres_to_pixels(metre_vector: Vector2) -> Vector2:
	return Vector2(metre_vector.x * 64.0, metre_vector.y * -64.0)

func find_string_in_context_menu(context_menu: PopupMenu, string: String):
	var string_found: bool = false

	for i in range(context_menu.item_count):
		var item = context_menu.get_item_text(i)
		if item == string:
			string_found = true
			break

	return string_found

func enter_vehicle(wp_individual: Waypoint, wp_enter: Waypoint, runner: GdUnitSceneRunner):
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

## Creates a manual event for testing
static func create_manual_event_for_agent(agent: Agent, waypoint: Waypoint, description: String = "Test Event", type: String = "Test Type") -> SimulationEventExporterManual:
	var event = SimulationEventExporterManual.new()
	event.description = description
	event.type = type
	event.trigger_type = SimulationEventExporterManual.TriggerType.ON_STOP
	event.mode = SimulationEventExporterManual.Mode.ON_EACH_AGENT
	event.waypoints = [[agent.agent_id, waypoint.get_waypoint_index()]]
	return event

## Adds event to the event emitter
static func add_event_to_emitter(event: SimulationEventExporterManual, runner: GdUnitSceneRunner):
	var event_emitter = runner.get_property("event_emittor")
	event_emitter.manual_event_add(event)

## Returns array of events that contain this agent
static func validate_agent_in_events(agent_id: int, runner: GdUnitSceneRunner) -> Array:
	var event_emitter = runner.get_property("event_emittor")
	var events_with_agent = []
	
	for event in event_emitter._manual_events:
		for waypoint_data in event.waypoints:
			if waypoint_data[0] == agent_id:
				events_with_agent.append(event)
				break
	
	return events_with_agent

## Validates that event is properly connected to its waypoints
static func validate_event_waypoint_connections(event: SimulationEventExporterManual) -> bool:
	for waypoint_data in event.waypoints:
		var agent_id = waypoint_data[0]
		var waypoint_id = waypoint_data[1]
		
		var agent = TreeFuncs.get_agent_with_id(agent_id)
		if agent == null:
			return false
			
		var waypoint = agent.waypoints.get_waypoint(waypoint_id)
		if waypoint == null:
			return false
			
		if not waypoint._events.has(event):
			return false
	
	return true

## Simulates agent deletion via context menu
static func simulate_agent_deletion(agent: Agent) -> bool:
	if agent._current_agent == null:
		return false
	
	# Simulate the context menu deletion
	agent._context_menu(Agent.ContextMenuIDs.DELETE)
	return true

## Links two waypoints together for testing
static func link_waypoints(wp1: Waypoint, wp2: Waypoint):
	wp1.link_waypoint(wp2)

## Returns array of all waypoints that are linked to this waypoint
static func get_linked_waypoints(waypoint: Waypoint) -> Array:
	return waypoint.linked_nodes.duplicate()

## Validates that two waypoints are bidirectionally linked
static func validate_waypoints_linked(wp1: Waypoint, wp2: Waypoint) -> bool:
	return wp2 in wp1.linked_nodes and wp1 in wp2.linked_nodes

## Validates that two waypoints are NOT linked
static func validate_waypoints_not_linked(wp1: Waypoint, wp2: Waypoint) -> bool:
	return wp2 not in wp1.linked_nodes and wp1 not in wp2.linked_nodes

## Returns the total count of linked waypoints for an agent
static func count_agent_linked_waypoints(agent: Agent) -> int:
	var count = 0
	var current_wp = agent.waypoints.starting_node
	while current_wp != null:
		count += current_wp.linked_nodes.size()
		current_wp = current_wp.pt_next
	return count

## Validates that an agent has no linked waypoints
static func validate_agent_has_no_linked_waypoints(agent: Agent) -> bool:
	return count_agent_linked_waypoints(agent) == 0
