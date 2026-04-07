extends Node
## Entry point. Loads main menu on startup.


func _ready() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
