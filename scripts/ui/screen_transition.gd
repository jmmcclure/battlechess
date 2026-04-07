extends CanvasLayer
## Autoload-friendly screen transition with fade-to-black effects.
## Add as autoload — creates its own full-screen ColorRect at runtime.

var color_rect: ColorRect
var _tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100

	color_rect = ColorRect.new()
	color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	color_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	add_child(color_rect)


func fade_out(duration: float = 0.5) -> void:
	_kill_tween()
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(color_rect, "color:a", 1.0, duration)
	await _tween.finished


func fade_in(duration: float = 0.5) -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(color_rect, "color:a", 0.0, duration)
	await _tween.finished
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func transition_to(scene_path: String, duration: float = 0.5) -> void:
	await fade_out(duration)
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await fade_in(duration)


func _kill_tween() -> void:
	if _tween and _tween.is_running():
		_tween.kill()
