extends Node3D

## Gym for the reusable scenes. Run this scene (F6). The main scene is untouched.
##
## Click to capture the mouse. Esc releases it. Tab opens travel and frees the
## mouse so the camp buttons can be clicked. F1 hides the help text.

@onready var player: PlayerController = $Player
@onready var bird: WingsBird = $WingsBird
@onready var help: Label = $HUD/Panel/Column/Help
@onready var status: Label = $HUD/Panel/Column/Status

var _travel_open: bool = false
var _travel_panel: PanelContainer
var _travel_hint: Label
var _buttons: Dictionary = {}


func _ready() -> void:
	# Wires the bird and the fires, then builds a travel menu nobody can see yet.
	bird.wings_gifted.connect(_on_wings_gifted)
	_build_travel_menu()
	for node in get_tree().get_nodes_in_group(&"campsite"):
		var camp := node as Campsite
		if camp == null:
			continue
		camp.unlocked.connect(_on_camp_unlocked)
		_add_camp_button(camp)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(_delta: float) -> void:
	# Keeps the status line honest about stamina and wings.
	status.text = player.get_status_text()


func _unhandled_input(event: InputEvent) -> void:
	# Tab frees the mouse. Clicks only recapture when the menu is shut.
	if event.is_action_pressed(&"toggle_menu"):
		_set_travel_menu(not _travel_open)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_cancel"):
		if _travel_open:
			_set_travel_menu(false)
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	# While the menu is open, clicks belong to the buttons. Don't recapture.
	if _travel_open:
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_F1:
			help.visible = not help.visible


func _on_wings_gifted() -> void:
	# The bird did the talking. The player gets the feathers.
	player.grant_ability(&"wings")


func _on_camp_unlocked(camp: Campsite) -> void:
	# A roasted marshmallow turns that fire's button on.
	var button := _buttons.get(camp) as Button
	if button == null:
		return
	button.visible = true
	button.disabled = false
	_travel_hint.text = "Click a fire to travel there."


func _add_camp_button(camp: Campsite) -> void:
	# One hidden button per fire. Locked means invisible.
	var button := Button.new()
	button.name = camp.display_name.replace(" ", "")
	button.text = camp.display_name
	button.visible = false
	button.disabled = true
	button.pressed.connect(_on_camp_button.bind(camp))
	_travel_panel.get_node("List").add_child(button)
	_buttons[camp] = button


func _on_camp_button(camp: Campsite) -> void:
	# Click a fire, appear at its spawn, try not to land in the coals.
	if not camp.is_unlocked:
		return
	player.teleport_to(camp.get_spawn_position())


func _set_travel_menu(open: bool) -> void:
	# Open the menu and the cursor is free. Close it and you're a hiker again.
	_travel_open = open
	_travel_panel.visible = open
	# Opening the menu is what frees the cursor. Closing it puts you back in play.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED


func _build_travel_menu() -> void:
	# A small panel in the corner. Not a world map. Not yet.
	var layer := $HUD as CanvasLayer
	var panel := PanelContainer.new()
	panel.name = "TravelMenu"
	panel.visible = false
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -280.0
	panel.offset_top = 12.0
	panel.offset_right = -12.0
	panel.offset_bottom = 280.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.09, 0.82)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)

	var list := VBoxContainer.new()
	list.name = "List"
	list.add_theme_constant_override("separation", 6)
	panel.add_child(list)

	var title := Label.new()
	title.text = "Travel"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.96, 0.93, 0.84))
	list.add_child(title)

	var hint := Label.new()
	hint.name = "Hint"
	hint.text = "Roast a marshmallow at a fire (E) to unlock it."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(240, 0)
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.82, 0.8, 0.74))
	list.add_child(hint)
	_travel_hint = hint
	_travel_panel = panel
