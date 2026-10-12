@tool
class_name WingsBird
extends CharacterBody3D

## Foothills tutorial bird. It stays on its perch, faces the player, and on
## the first chat gifts the wings that unlock gliding.
##
## The test room connects [signal wings_gifted] to the player. This scene
## does not look the player up by path.

signal wings_gifted

const GREETING := "The way down is the easy part. These wings are yours."
const AFTER := "Hold glide once you're falling. They spend a little stamina."

@export var hop_interval: float = 2.8
@export var gravity: float = 24.0

var _gifted: bool = false
var _near: Node3D = null
var _hop_wait: float = 1.2
var _flap: float = 0.0

@onready var visual: Node3D = $Visual
@onready var sense: Area3D = $Sense
@onready var prompt: Label3D = $Prompt
@onready var speech: Label3D = $Speech
@onready var wing_l: Node3D = $Visual/WingL
@onready var wing_r: Node3D = $Visual/WingR


func _ready() -> void:
	# Perches, listens, and keeps the speech bubble in its pocket.
	add_to_group(&"interactable")
	sense.body_entered.connect(_on_body_entered)
	sense.body_exited.connect(_on_body_exited)
	prompt.visible = false
	speech.visible = false
	floor_snap_length = 0.2


func interact() -> void:
	# First chat hands over the wings. Later chats are just advice.
	if _near == null:
		return
	if _gifted:
		_say(AFTER)
		return
	_gifted = true
	_say(GREETING)
	wings_gifted.emit()


func _physics_process(delta: float) -> void:
	# Hops when nobody's looking, stares when they are, flaps either way.
	if Engine.is_editor_hint():
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.4
		_hop_wait -= delta
		if _hop_wait <= 0.0 and _near == null:
			velocity.y = 2.4
			_hop_wait = hop_interval + randf_range(-0.4, 0.6)
	if _near:
		_face(_near.global_position - global_position, delta)
		velocity.x = 0.0
		velocity.z = 0.0
	move_and_slide()
	prompt.visible = _near != null and not speech.visible
	# A slow flap so the gift reads as wings before the player has any.
	_flap += delta * (9.0 if _near != null else 4.0)
	var angle := sin(_flap) * deg_to_rad(28.0)
	wing_l.rotation.z = angle
	wing_r.rotation.z = -angle


func _face(direction: Vector3, delta: float) -> void:
	# Beak toward the visitor. Gravity stays out of the yaw.
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() < 0.0001:
		return
	var yaw := atan2(-flat.x, -flat.z)
	visual.rotation.y = lerp_angle(visual.rotation.y, yaw, 8.0 * delta)


func _say(line: String) -> void:
	# Puts words in the air above a very small bird.
	speech.text = line
	speech.visible = true


func _on_body_entered(body: Node3D) -> void:
	# Someone walkable showed up. Time to look important.
	if body is PlayerController:
		_near = body


func _on_body_exited(body: Node3D) -> void:
	# They left. The speech bubble goes back in the pocket.
	if body == _near:
		_near = null
		speech.visible = false
