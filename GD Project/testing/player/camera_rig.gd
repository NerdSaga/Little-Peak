class_name OrbitCamera
extends Node3D

## Third-person orbit camera. Yaw lives on this rig; pitch tilts it so the
## spring arm (pointing back along +Z) swings the camera with it.
##
## The game design doc asks for a Mario / Short Hike style camera: follow from
## slightly above, let the player override, drift back behind them while they
## run, and pull out a little while climbing so the wall and the route above
## stay in frame. SpringArm3D does the "move in smoothly, don't snap" part.

@export_group("Look")
## Radians per pixel. Uses screen-space motion so the project's canvas stretch
## doesn't change how fast the mouse turns the camera.
@export var mouse_sensitivity: float = 0.0028
## Radians per second at full stick deflection.
@export var stick_sensitivity: float = 2.1
@export var invert_x: bool = false
@export var invert_y: bool = false
## Resting pitch. Negative looks down, which puts the player in the lower half
## of the frame the way the design doc describes ("slightly above").
@export var rest_pitch: float = -0.32
@export var min_pitch: float = -1.05
@export var max_pitch: float = 0.85

@export_group("Recenter")
@export var auto_recenter: bool = true
## How long the player has to leave the look controls alone before the camera
## drifts back behind them. Long enough that a small adjustment isn't fought.
@export var recenter_delay: float = 0.9
@export var recenter_speed: float = 1.35

@export_group("Climb framing")
@export var rest_arm_length: float = 4.6
@export var climb_arm_length: float = 6.3
## Added to pitch while climbing so the route above the player enters frame.
@export var climb_pitch_offset: float = 0.42
@export var arm_blend_speed: float = 3.5

var _yaw: float = 0.0
var _pitch: float = -0.32
var _look_idle: float = 0.0
var _climbing: bool = false
var _allow_recenter: bool = false
var _recenter_dir: Vector3 = Vector3.ZERO

@onready var spring_arm: SpringArm3D = $SpringArm


func _ready() -> void:
	_yaw = rotation.y
	_pitch = rest_pitch
	spring_arm.spring_length = rest_arm_length
	_apply_rotation()


func exclude_body(body: CollisionObject3D) -> void:
	# The arm would otherwise hit the player and collapse to zero length.
	spring_arm.add_excluded_object(body.get_rid())


func set_follow_context(climbing: bool, recenter_direction: Vector3, allow_recenter: bool) -> void:
	_climbing = climbing
	_recenter_dir = recenter_direction
	_allow_recenter = allow_recenter


func get_flat_forward() -> Vector3:
	var forward := -global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return Vector3.FORWARD
	return forward.normalized()


func get_flat_right() -> Vector3:
	var right := global_transform.basis.x
	right.y = 0.0
	if right.length_squared() < 0.0001:
		return Vector3.RIGHT
	return right.normalized()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		if motion.screen_relative.is_zero_approx():
			return
		_add_look(motion.screen_relative.x, motion.screen_relative.y, mouse_sensitivity)


func _physics_process(delta: float) -> void:
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if stick.length() > 0.08:
		_add_look(stick.x, stick.y, stick_sensitivity * delta)
	else:
		_look_idle += delta
	if auto_recenter and _allow_recenter and _look_idle > recenter_delay and _recenter_dir.length() > 0.5:
		# Yaw whose -Z matches the flattened run direction. See get_flat_forward.
		var dir := _recenter_dir.normalized()
		var desired := atan2(-dir.x, -dir.z)
		_yaw = lerp_angle(_yaw, desired, recenter_speed * delta)
	_apply_rotation()
	var target_length := climb_arm_length if _climbing else rest_arm_length
	spring_arm.spring_length = move_toward(spring_arm.spring_length, target_length, arm_blend_speed * delta)


func _add_look(amount_x: float, amount_y: float, scale: float) -> void:
	if invert_x:
		amount_x = -amount_x
	if invert_y:
		amount_y = -amount_y
	# Positive yaw turns this rig to the left, so a rightward look decreases it.
	# Positive pitch looks up; mouse-down should look down, so pitch decreases.
	_yaw -= amount_x * scale
	_pitch = clampf(_pitch - amount_y * scale, min_pitch, max_pitch)
	_look_idle = 0.0


func _apply_rotation() -> void:
	var extra := climb_pitch_offset if _climbing else 0.0
	rotation.y = _yaw
	rotation.x = clampf(_pitch + extra, min_pitch, max_pitch + climb_pitch_offset)
