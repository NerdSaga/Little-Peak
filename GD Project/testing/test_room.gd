extends Node3D

## Gym scene for the first-pass moveset. Run this scene (F6 in the editor).
## The project's main scene is intentionally left alone.
##
## Click to capture the mouse. Esc releases it. F1 hides the help text.

@onready var player: PlayerController = $Player
@onready var guide: TrailGuide = $TrailGuide
@onready var help: Label = $HUD/Panel/Column/Help
@onready var status: Label = $HUD/Panel/Column/Status


func _ready() -> void:
	guide.ability_granted.connect(_on_ability_granted)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(_delta: float) -> void:
	status.text = player.get_status_text()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_F1:
			help.visible = not help.visible


func _on_ability_granted(ability: StringName) -> void:
	player.grant_ability(ability)
