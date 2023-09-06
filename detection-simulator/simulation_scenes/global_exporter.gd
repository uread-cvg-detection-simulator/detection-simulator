extends Node

@export_group("Parameters")
@export_range(0, 60) var export_framerate: int = 30: set = _set_framerate
var export_timestep: float = INF
var export_last_time: float = INF

@export_group("Scene")
@export var editor_base: ScenarioEditor = null

var global_all_fileaccess: FileAccess = null
var global_sensor_fileaccess: FileAccess = null
var global_all_separate_fileaccess: Dictionary = {}
var global_sensor_separate_fileaccess: Dictionary = {}

var save_base: String = ""
var exporting: bool = false

func _ready():
	# Set Parameters
	export_framerate = export_framerate

	# Create file accessors
	PlayTimer.connect("start_playing", self._start_playing)
	PlayTimer.connect("stop_playing", self._stop_playing)

func _physics_process(_delta):
	if exporting:
		var current_time = PlayTimer.current_time

		if current_time > export_last_time + export_timestep:
			export_last_time = float(int(current_time / export_timestep)) * export_timestep

			# We have two types of output: export all agents in separate files, and export agents within sensor range in separate files
			# There is also a global file for each of the above

			global_agent_export(export_last_time)
			global_sensor_export(export_last_time)

## Export all agents into a global file, and into separate files
func global_agent_export(timestamp: float):
	# Get all the exported data from the agent
	var all_agents = get_tree().get_nodes_in_group("agent")
	var all_agent_data: Array[Dictionary] = []

	for agent in all_agents:
		all_agent_data.append(agent.play_export())

	if not all_agent_data.is_empty():
		# Export to all file
		var export_data = {
			"sensor_id": -1,
			"timestamp_ms": int(timestamp * 1000),
			"detections": all_agent_data
		}

		if not global_all_fileaccess:
			global_all_fileaccess = FileAccess.open(save_base + "_global_all.json", FileAccess.WRITE)
			global_all_fileaccess.store_string("[")
		else:
			global_all_fileaccess.store_string(",")

		global_all_fileaccess.store_string(JSON.stringify(export_data))

		# Export to separate files
		for ad in all_agent_data:
			ad["timestamp_ms"] = int(timestamp * 1000)

			var agent_id = ad["id"]

			if not global_all_separate_fileaccess.has(agent_id):
				global_all_separate_fileaccess[agent_id] = FileAccess.open(save_base + "_global_all_%03d.json" % agent_id, FileAccess.WRITE)
				global_all_separate_fileaccess[agent_id].store_string("[")
			else:
				global_all_separate_fileaccess[agent_id].store_string(",")

			global_all_separate_fileaccess[agent_id].store_string(JSON.stringify(ad))

func global_sensor_export(timestamp: float):
	var all_sensors: Array = get_tree().get_nodes_in_group("sensor")

	var all_agent_data: Dictionary = {}

	for sensor in all_sensors:
		for agent in sensor.current_detections:
			if not all_agent_data.has(agent.agent_id):
				all_agent_data[agent.agent_id] = agent.play_export()

	if not all_agent_data.is_empty():
		# Export to all file
		var export_data = {
			"sensor_id": -1,
			"timestamp_ms": int(timestamp * 1000),
			"detections": all_agent_data
		}

		if not global_sensor_fileaccess:
			global_sensor_fileaccess = FileAccess.open(save_base + "_global_sensor.json", FileAccess.WRITE)
			global_sensor_fileaccess.store_string("[")
		else:
			global_sensor_fileaccess.store_string(",")

		global_sensor_fileaccess.store_string(JSON.stringify(export_data))

		# Export to separate files
		for ad in all_agent_data.values():
			ad["timestamp_ms"] = int(timestamp * 1000)

			var agent_id = ad["id"]

			if not global_sensor_separate_fileaccess.has(agent_id):
				global_sensor_separate_fileaccess[agent_id] = FileAccess.open(save_base + "_global_sensor_%03d.json" % agent_id, FileAccess.WRITE)
				global_sensor_separate_fileaccess[agent_id].store_string("[")
			else:
				global_sensor_separate_fileaccess[agent_id].store_string(",")

			global_sensor_separate_fileaccess[agent_id].store_string(JSON.stringify(ad))

func _start_playing():
	if PlayTimer.exporting:
		save_base = editor_base.save_path_export_base
		exporting = true
		export_last_time = -1

func _stop_playing():
	save_base = ""
	exporting = false
	export_last_time = INF

	if global_all_fileaccess != null:
		global_all_fileaccess.store_string("]")
		global_all_fileaccess.close()
		global_all_fileaccess = null

	for fa in global_all_separate_fileaccess.values():
		fa.store_string("]")
		fa.close()

	global_all_separate_fileaccess.clear()

	if global_sensor_fileaccess != null:
		global_sensor_fileaccess.store_string("]")
		global_sensor_fileaccess.close()
		global_sensor_fileaccess = null

	for fa in global_sensor_separate_fileaccess.values():
		fa.store_string("]")
		fa.close()

	global_sensor_separate_fileaccess.clear()

func _set_framerate(value):
	export_framerate = value
	export_timestep = 1.0 / value
