class_name TestEditorAgent
extends GdUnitTestSuite

var editor_scene = "res://simulation_scenes/editor.tscn"
var runner = null
var agent = null

func before():
	runner = auto_free(scene_runner(editor_scene))
	agent = _spawn_and_get_agent(Vector2.ZERO)

func test_last_id_first():
	# Assert the last id was set
	assert_int(runner.get_property("_last_id")).is_equal(1)

func test_num_children():
	var agent_root: Node2D = runner.get_property("_agent_root")

	var children = agent_root.get_children()

	# Check number of children
	assert_int(children.size()).is_equal(1)

func test_spawn_agent_tree_same_as_id():

	# Get the agent
	var agent_root: Node2D = runner.get_property("_agent_root")

	var children = agent_root.get_children()

	# Check the spawned agent is the same as in the tree
	var child_agent: Agent = children[0]

	assert_object(child_agent).is_same(agent)

func test_agent_id():
	# Check the id is correct (1)
	assert_int(agent.agent_id).is_equal(1)

func test_agent_position():
	# Check position is 0,0
	assert_vector2(agent.position).is_equal(Vector2.ZERO)

func _spawn_and_get_agent(position: Vector2) -> Agent:
	runner.invoke("spawn_agent", Vector2(0, 0))

	var id: int = runner.get_property("_last_id")
	var agent: Agent = TreeFuncs.get_agent_with_id(id)

	return agent
