extends GdUnitTestSuite

const TestFuncs = preload("res://test/editor/test_funcs.gd")

var editor_scene = "res://simulation_scenes/editor.tscn"
var runner = null

var agent: Agent = null

func before():
	runner = auto_free(scene_runner(editor_scene))

func before_test():
	agent = TestFuncs.spawn_and_get_agent(Vector2.ZERO, runner)

func after_test():
	agent.free()
	agent = null
	runner.set_property("_last_id", 0)

func test_agent_select_waypoint_in_menu():
	assert_object(agent).is_not_null()

	# Check the first item is "Create Waypoint" when selected
	agent._current_agent._selection_area.selected = true
	runner.invoke("_prepare_menu")

	var menu: PopupMenu = runner.get_property("_rightclick_empty")

	var text = menu.get_item_text(0)

	assert_str(text).is_equal("Create Waypoint")

func test_agent_deselect_waypoint_not_in_menu():
	assert_object(agent).is_not_null()

	# Check the first item is "Create Waypoint" when selected
	agent._current_agent._selection_area.selected = true
	agent._current_agent._selection_area.selected = false
	runner.invoke("_prepare_menu")

	var menu: PopupMenu = runner.get_property("_rightclick_empty")

	var text = auto_free(menu.get_item_text(0))

	assert_str(text).is_not_equal("Create Waypoint")

	await await_idle_frame()
	pass

func test_waypoint_place():
	assert_object(agent).is_not_null()

	agent._current_agent._selection_area.selected = true

	# Place waypoint at 10,0
	var place_position = Vector2(5, 0)
	var place_act_position = Vector2(place_position.x * 64, place_position.y * -64)
	TestFuncs.spawn_waypoint_from(agent, place_position, runner)

	# Get waypoints object
	var waypoints = agent.waypoints

	# Test waypoint exists
	assert_array(waypoints.waypoints).has_size(1)

	# Test placed at correct position
	var new_waypoint: Waypoint = waypoints.get_waypoint(0)

	assert_vector(new_waypoint.position).is_equal(place_act_position)

	await await_idle_frame()
	pass

