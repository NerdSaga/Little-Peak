class_name TrailGuide
extends CharacterBody3D

## Placeholder for the foothills trail guide.
##
## Wanders a few steps from home, turns to face the player, and on the second
## chat hands over the glide. The test room connects [signal ability_granted]
## to the player, so this scene doesn't reach into the player by path.

signal ability_granted(ability: StringName)

const INTRO: PackedStringArray = [
	"Gray rock will hold you. The blue wall is wet, so it won't.",
	"Take this cloak. Once you're falling, hold glide. It spends stamina.",
]
const AFTER: PackedStringArray = [
	"If your arms get heavy, stand somewhere solid. Stamina comes back there.",
	"The white cone is the peak. It's just there to look at for now.",
]

@export var wander_radius: float = 1.6
@export var wander_speed: float = 1.15
@export var gravity: float = 24.0

var _home: Vector3 = Vector3.ZERO
var _target: Vector3 = Vector3.ZERO
var _wait: float = 1.0
var _target_time: float = 0.0
var _near: Node3D = null
var _line: int = 0
var _granted: bool = false

@onready var visual: Node3D = $Visual
@onready var sense: Area3D = $Sense
@onready var prompt: Label3D = $Prompt
@onready var speech: Label3D = $Speech


func _ready() -> void:
	add_to_group(&"interactable")
	_home = global_position
	_pick_target()
	sense.body_entered.connect(_on_body_entered)
	sense.body_exited.connect(_on_body_exited)
	prompt.visible = false
	speech.visible = false
	floor_snap_length = 0.2


func interact() -> void:
	# Distance is checked by the player. The area is what makes the prompt
	# honest: no greeting unless they actually walked up.
	if _near == null:
		return
	if _granted:
		_show(AFTER[_line % AFTER.size()])
		_line += 1
		return
	_show(INTRO[_line])
	if _line >= INTRO.size() - 1:
		_granted = true
		_line = 0
		ability_granted.emit(&"glide")
	else:
		_line += 1


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.4
	if _near:
		_face(_near.global_position - global_position, delta)
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
	else:
		_wander(delta)
	move_and_slide()
	prompt.visible = _near != null and not speech.visible


func _wander(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
		return
	var to := _target - global_position
	to.y = 0.0
	_target_time += delta
	if to.length() < 0.35 or _target_time > 4.0:
		_wait = randf_range(0.7, 1.8)
		_pick_target()
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var dir := to.normalized()
	velocity.x = dir.x * wander_speed
	velocity.z = dir.z * wander_speed
	_face(dir, delta)


func _pick_target() -> void:
	var angle := randf() * TAU
	var dist := randf_range(0.4, wander_radius)
	_target = _home + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
	_target_time = 0.0


func _face(direction: Vector3, delta: float) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() < 0.0001:
		return
	# Same yaw convention as the player: local -Z is the nose.
	var yaw := atan2(-flat.x, -flat.z)
	visual.rotation.y = lerp_angle(visual.rotation.y, yaw, 8.0 * delta)


func _show(line: String) -> void:
	speech.text = line
	speech.visible = true


func _on_body_entered(body: Node3D) -> void:
	if body is PlayerController:
		_near = body


func _on_body_exited(body: Node3D) -> void:
	if body == _near:
		_near = null
		speech.visible = false
