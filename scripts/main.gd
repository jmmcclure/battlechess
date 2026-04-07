extends Node
## Entry point. Loads main menu on startup.


func _ready() -> void:
	call_deferred("_go_to_menu")


func _go_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
