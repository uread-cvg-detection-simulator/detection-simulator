extends Node

signal node_grouped(group: String, node: Node)
signal node_ungrouped(group: String, node: Node)

## Called when a node is added to a group
func add_node_to_group(node: Node, group: String):
	node.add_to_group(group)
	emit_signal("node_grouped", group, node)

## Called when a node is removed from a group
func remove_node_from_group(node: Node, group: String):
	node.remove_from_group(group)
	emit_signal("node_ungrouped", group, node)

var debug_print_groups = true : set = _on_debug_print_groups_changed

func _ready():
	if debug_print_groups:
		connect("node_grouped", self._debug_on_grouped)
		connect("node_ungrouped", self._debug_on_ungrouped)

func _on_debug_print_groups_changed(value):
	debug_print_groups = value

	if debug_print_groups:
		connect("node_grouped", self._debug_on_grouped)
		connect("node_ungrouped", self._debug_on_ungrouped)
	else:
		disconnect("node_grouped", self._debug_on_grouped)
		disconnect("node_ungrouped", self._debug_on_ungrouped)

func _debug_on_grouped(group, node):
	print_debug("Node Grouped: [%s] -> %s" % [group, node])

func _debug_on_ungrouped(group, node):
	print_debug("Node Ungrouped: [%s] -> %s" % [group, node])
