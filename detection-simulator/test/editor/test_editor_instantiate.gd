class_name TestEditorInstantiate
extends GdUnitTestSuite

var editor_scene = "res://simulation_scenes/editor.tscn"

func test_instantiate_menu() -> void:
	var runner = scene_runner(editor_scene)

	var menu: PopupMenu = runner.get_property("_rightclick_empty")
	assert_that(menu).is_not_null()

	assert_int(menu.item_count).is_not_zero()


