extends Node

func get_agent_with_id(id):
	for member in get_tree().get_nodes_in_group("agent"):
		if member.agent_id == id:
			return member
	return null


func get_sensor_with_id(id):
	for member in get_tree().get_nodes_in_group("sensor"):
		if member.sensor_id == id:
			return member
	return null
