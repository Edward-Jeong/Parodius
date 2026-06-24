extends Node

const SAVE_PATH := "user://save.json"
var data := {
	"high_score": 0,
	"stage_complete": false,
	"music_enabled": true,
	"sfx_enabled": true
}

func _ready() -> void:
	load_data()

func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		for key in data.keys():
			if parsed.has(key):
				data[key] = parsed[key]

func save_data() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))

func record_result(score: int, completed: bool) -> void:
	data.high_score = maxi(int(data.high_score), score)
	data.stage_complete = bool(data.stage_complete) or completed
	save_data()

