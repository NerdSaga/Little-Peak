class_name PlayerController
extends CharacterBody3D

## First-pass player for the test room.
##
## Covers the design doc's starting moveset: camera-relative run, variable
## jump, stamina climbing (with a hop and an automatic mantle), and a glide
## that starts locked. Running and jumping are free. Stamina refills only on
## solid ground. Nothing here deals damage; falling off the pad sends the
## player back to where they spawned.
##
## Surfaces opt in. A body in group "climbable" can be climbed. Group
## "unclimbable" always wins, which is how the wet wall is blocked. Anything
## else is ordinary collision (ramps, crates, the gate).

const CLIMBABLE := &"climbable"
const UNCLIMBABLE := &"unclimbable"
const INTERACTABLE := &"interactable"

enum State { GROUND, AIR, CLIMB, GLIDE, MANTLE }

@export_group("Run")
@export var max_speed: float = 6.2
## The design doc wants full speed in about 0.15s, and a slightly slower stop
## so the run has a little weight.
@export var accel_time: float = 0.15
@export var decel_time: float = 0.28
@export var air_accel: float = 18.0
## Multiplier on acceleration when the new direction opposes the current one.
@export var turn_boost: float = 2.2
@export var max_walk_angle_degrees: float = 55.0
## Straight up a slope this steep (or steeper) uses uphill_min_scale.
@export var uphill_full_angle: float = 40.0
@export var uphill_min_scale: float = 0.68

@export_group("Slopes")
## Floors steeper than this start to carry the player downhill.
@export var slide_angle_degrees: float = 32.0
@export var slide_acceleration: float = 26.0

@export_group("Jump")
@export var jump_velocity: float = 8.0
@export var gravity: float = 24.0
## Falling uses more gravity than rising so arcs read as snappy, not floaty.
@export var fall_gravity_multiplier: float = 1.7
## Releasing jump early adds this much extra gravity on the way up.
@export var jump_cut_multiplier: float = 2.6
@export var coyote_time: float = 0.1
@export var jump_buffer_time: float = 0.1
@export var land_squash_speed: float = -8.0
@export var land_squash_scale: float = 0.8

@export_group("Climb")
@export var climb_speed: float = 2.0
@export var cling_speed: float = 1.4
@export var climb_hop_speed: float = 3.6
@export var climb_hop_decay: float = 9.0
@export var climb_hop_cost: float = 28.0
@export var climb_drain: float = 14.0
## A wall contact below this (relative to the feet) is a curb, not a climb.
@export var min_grab_height: float = 0.55
## Normals flatter than this are floors or walkable slopes, not walls.
@export var max_climb_normal_y: float = 0.35
@export var probe_distance: float = 0.8
@export var mantle_time: float = 0.26

@export_group("Stamina")
@export var max_stamina: float = 100.0
@export var stamina_regen: float = 45.0
@export var min_stamina_to_climb: float = 8.0
@export var low_stamina_ratio: float = 0.25

@export_group("Glide")
## Off until the trail guide grants it. Turn on in the inspector to test alone.
@export var glide_unlocked: bool = false
@export var glide_speed: float = 8.0
@export var glide_turn_accel: float = 5.0
@export var glide_fall_speed: float = 1.8
@export var glide_vertical_accel: float = 10.0
@export var glide_drain: float = 7.0
@export var glide_min_stamina: float = 5.0
## Can't open the glide until the jump has peaked, so it doesn't eat the hop.
@export var glide_entry_vertical_speed: float = 0.6

@export_group("Feel")
@export var visual_turn_speed: float = 12.0
@export var max_tilt_degrees: float = 8.0
@export var interact_range: float = 2.5
@export var fall_reset_y: float = -20.0

var stamina: float = 100.0

var _state: State = State.AIR
var _input_dir: Vector2 = Vector2.ZERO
var _wish: Vector3 = Vector3.ZERO
var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _wall_normal: Vector3 = Vector3.FORWARD
var _climb_time: float = 0.0
var _climb_start_y: float = 0.0
var _hop: float = 0.0
var _lost_wall: int = 0
var _regrab: float = 0.0
var _slide_influence: float = 0.0
var _low_warned: bool = false
var _squash: float = 1.0
var _spawn: Vector3 = Vector3.ZERO
var _default_mask: int = 1
var _mantle_from: Vector3 = Vector3.ZERO
var _mantle_to: Vector3 = Vector3.ZERO
var _mantle_t: float = 0.0
var _fill_mat: StandardMaterial3D
var _fill_half_width: float = 0.26

@onready var visual: Node3D = $Visual
@onready var cape: MeshInstance3D = $Visual/Cape
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var camera_rig: OrbitCamera = $CameraRig
@onready var camera: Camera3D = $CameraRig/SpringArm/Camera3D
@onready var blob: MeshInstance3D = $BlobShadow
@onready var stamina_bar: Node3D = $StaminaBar
@onready var stamina_fill: MeshInstance3D = $StaminaBar/Fill


func _ready() -> void:
	stamina = max_stamina
	_spawn = global_position
	_default_mask = collision_mask
	floor_max_angle = deg_to_rad(max_walk_angle_degrees)
	floor_snap_length = 0.25
	camera_rig.exclude_body(self)
	cape.visible = glide_unlocked
	_setup_stamina_fill()
	add_to_group(&"player")


func grant_ability(ability: StringName) -> void:
	# The test room wires the guide's signal to this. Glide stays a no-op
	# until then, matching the "early unlock from a person" note in the doc.
	if ability == &"glide":
		glide_unlocked = true


func get_status_text() -> String:
	var names: PackedStringArray = ["ground", "air", "climb", "glide", "mantle"]
	var glide_label := "ready" if glide_unlocked else "locked"
	return "state %s    stamina %d / %d    glide %s" % [
		names[_state],
		int(round(stamina)),
		int(round(max_stamina)),
		glide_label,
	]


func _physics_process(delta: float) -> void:
	_regrab = maxf(_regrab - delta, 0.0)
	_cache_input()
	if Input.is_action_just_pressed(&"interact"):
		_try_interact()
	if _state == State.AIR and _can_enter_glide():
		_state = State.GLIDE
	match _state:
		State.MANTLE:
			_physics_mantle(delta)
		State.CLIMB:
			_physics_climb(delta)
		State.GLIDE:
			_physics_glide(delta)
		_:
			_physics_locomotion(delta)
	_update_out_of_bounds()
	_update_visuals(delta)
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var allow_recenter := _state == State.GROUND and horizontal.length() > 2.0
	camera_rig.set_follow_context(_state == State.CLIMB, horizontal, allow_recenter)


func _physics_locomotion(delta: float) -> void:
	var on_floor := is_on_floor()
	# Computed before movement so a steep slope doesn't count as a rest this frame.
	_slide_influence = _compute_slide_influence() if on_floor else 0.0
	if on_floor:
		_coyote = coyote_time
		if _slide_influence < 0.2:
			_regen_stamina(delta)
	else:
		_coyote = maxf(_coyote - delta, 0.0)
		_apply_gravity(delta)

	if Input.is_action_just_pressed(&"jump"):
		_jump_buffer = jump_buffer_time
	else:
		_jump_buffer = maxf(_jump_buffer - delta, 0.0)

	var jumped := false
	if _jump_buffer > 0.0 and _coyote > 0.0:
		velocity.y = jump_velocity
		_jump_buffer = 0.0
		_coyote = 0.0
		jumped = true
	elif on_floor and velocity.y < 0.0:
		# A little downward bias keeps is_on_floor stable on the way down a ramp.
		velocity.y = -0.5

	_apply_horizontal(delta, on_floor and not jumped)
	# Idle slopes stay put. Steep ones have to be allowed to carry the body,
	# or floor_stop_on_slope cancels the slide velocity every frame.
	floor_stop_on_slope = _slide_influence < 0.12
	var vertical_before := velocity.y
	move_and_slide()
	_try_begin_climb()
	# Climb may have started this frame. Don't let the ground/air update
	# clobber it, or a grab would last exactly one physics step.
	if _state == State.GROUND or _state == State.AIR:
		_update_locomotion_state(vertical_before)


func _physics_climb(delta: float) -> void:
	_climb_time += delta
	if Input.is_action_just_pressed(&"jump") and _input_dir.y > 0.4:
		# Back plus jump is the deliberate "let go". A plain jump hops.
		_end_climb(_wall_normal * 3.2 + Vector3.UP * 2.2, 0.2)
		return
	if Input.is_action_just_pressed(&"jump") and _input_dir.y <= 0.4 and stamina >= climb_hop_cost:
		stamina -= climb_hop_cost
		_hop = climb_hop_speed

	# Project world up onto the wall so "up" stays up. Crossing in the other
	# order points down the wall and the climb never leaves the ground.
	var wall_up := Vector3.UP.slide(_wall_normal)
	if wall_up.length_squared() < 0.0001:
		wall_up = Vector3.UP
	else:
		wall_up = wall_up.normalized()
	var wall_right := wall_up.cross(_wall_normal)
	if wall_right.length_squared() < 0.0001:
		wall_right = Vector3.RIGHT
	else:
		wall_right = wall_right.normalized()
	if wall_right.dot(camera_rig.get_flat_right()) < 0.0:
		wall_right = -wall_right

	var climb_up := -_input_dir.y
	# The jump that started the grab is still held for a moment. Treat that as
	# "go up" so the player doesn't have to re-aim the stick at the first frame.
	if _climb_time < 0.4 and Input.is_action_pressed(&"jump") and _input_dir.y <= 0.2:
		climb_up = maxf(climb_up, 1.0)
	var along := wall_right * _input_dir.x + wall_up * climb_up
	if along.length() > 1.0:
		along = along.normalized()
	var motion := along * climb_speed
	if _hop > 0.0:
		motion += wall_up * _hop
		_hop = move_toward(_hop, 0.0, climb_hop_decay * delta)
	motion += -_wall_normal * cling_speed
	velocity = motion

	stamina = maxf(stamina - climb_drain * delta, 0.0)
	_check_low_stamina()
	if stamina <= 0.0:
		# Running out lets go. The push is away from the wall so we don't
		# instantly re-stick, and the cooldown blocks a grab while falling.
		_end_climb(_wall_normal * 1.6 + Vector3.UP * 0.4, 0.45)
		return

	move_and_slide()
	_probe_climb_contact()


func _physics_glide(delta: float) -> void:
	var wish := _wish
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var target := horizontal
	if wish.length() > 0.1:
		target = wish * glide_speed
	elif horizontal.length() > 0.1:
		target = horizontal.normalized() * glide_speed
	# Low acceleration is the "wide turns" note: the glide doesn't snap to a new heading.
	horizontal = horizontal.move_toward(target, glide_turn_accel * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = move_toward(velocity.y, -glide_fall_speed, glide_vertical_accel * delta)
	stamina = maxf(stamina - glide_drain * delta, 0.0)
	_check_low_stamina()
	move_and_slide()
	if is_on_floor() or stamina <= 0.0 or not Input.is_action_pressed(&"glide"):
		_state = State.GROUND if is_on_floor() else State.AIR
		return
	_try_begin_climb()


func _physics_mantle(delta: float) -> void:
	# Collision is off for this short correction. A mantle that snags on the
	# lip is the failure the design doc calls the most annoying one, so this
	# first pass favors landing on the ledge over a physics animation.
	_mantle_t += delta / maxf(mantle_time, 0.05)
	var t := clampf(_mantle_t, 0.0, 1.0)
	var eased := t * t * (3.0 - 2.0 * t)
	global_position = _mantle_from.lerp(_mantle_to, eased)
	if t >= 1.0:
		collision_mask = _default_mask
		velocity = Vector3.ZERO
		_state = State.GROUND


func _apply_gravity(delta: float) -> void:
	var scale := 1.0
	if velocity.y < 0.0:
		scale = fall_gravity_multiplier
	elif velocity.y > 0.0 and not Input.is_action_pressed(&"jump"):
		scale = jump_cut_multiplier
	velocity.y -= gravity * scale * delta


func _apply_horizontal(delta: float, on_floor: bool) -> void:
	_slide_influence = _compute_slide_influence() if on_floor else 0.0
	if _slide_influence > 0.12:
		_apply_slide_horizontal(delta)
		return
	var wish := _wish
	var speed := max_speed * (_uphill_scale(wish) if on_floor else 1.0)
	var target := wish * speed
	var rate := _horizontal_rate(wish, on_floor)
	velocity.x = move_toward(velocity.x, target.x, rate * delta)
	velocity.z = move_toward(velocity.z, target.z, rate * delta)


func _apply_slide_horizontal(delta: float) -> void:
	# Target a downhill speed instead of adding acceleration that the brake
	# then cancels. Input still nudges the slide, but it doesn't cancel it.
	var downhill := _downhill_direction()
	var slide_speed := lerpf(3.5, 8.0, _slide_influence)
	var wish := _wish * max_speed * (1.0 - _slide_influence) * 0.35
	var target := downhill * slide_speed + wish
	var rate := slide_acceleration
	velocity.x = move_toward(velocity.x, target.x, rate * delta)
	velocity.y = move_toward(velocity.y, target.y, rate * delta)
	velocity.z = move_toward(velocity.z, target.z, rate * delta)


func _horizontal_rate(wish: Vector3, on_floor: bool) -> float:
	if not on_floor:
		return air_accel
	if wish.length_squared() < 0.0001:
		return max_speed / maxf(decel_time, 0.05)
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var rate := max_speed / maxf(accel_time, 0.05)
	if horizontal.length_squared() > 0.25 and horizontal.normalized().dot(wish) < 0.0:
		return rate * turn_boost
	return rate


func _uphill_scale(wish: Vector3) -> float:
	if wish.length_squared() < 0.0001 or not is_on_floor():
		return 1.0
	var normal := get_floor_normal()
	var downhill := Vector3(normal.x, 0.0, normal.z)
	if downhill.length_squared() < 0.0001:
		return 1.0
	var into_uphill := -wish.normalized().dot(downhill.normalized())
	if into_uphill <= 0.0:
		return 1.0
	var steep := clampf(get_floor_angle() / deg_to_rad(uphill_full_angle), 0.0, 1.0)
	return lerpf(1.0, uphill_min_scale, into_uphill * steep)


func _compute_slide_influence() -> float:
	if not is_on_floor():
		return 0.0
	var angle := get_floor_angle()
	var start := deg_to_rad(slide_angle_degrees)
	if angle <= start:
		return 0.0
	return clampf((angle - start) / deg_to_rad(18.0), 0.0, 1.0)


func _downhill_direction() -> Vector3:
	var downhill := Vector3.DOWN.slide(get_floor_normal())
	if downhill.length_squared() < 0.0001:
		return Vector3.ZERO
	return downhill.normalized()


func _update_locomotion_state(vertical_before: float) -> void:
	var landed := is_on_floor()
	if landed and _state == State.AIR and vertical_before < land_squash_speed:
		_squash = land_squash_scale
	_state = State.GROUND if landed else State.AIR
	if landed and stamina / maxf(max_stamina, 1.0) > low_stamina_ratio:
		_low_warned = false


func _try_begin_climb() -> void:
	if _regrab > 0.0 or stamina < min_stamina_to_climb:
		return
	if _state == State.MANTLE or _state == State.CLIMB:
		return
	var normal := _find_climb_normal()
	if normal == Vector3.ZERO:
		return
	var into := -normal
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var moving_in := horizontal.length() > 0.45 and horizontal.normalized().dot(into) > 0.18
	var pushing_in := _wish.length() > 0.2 and _wish.dot(into) > 0.3
	var looking_in := camera_rig.get_flat_forward().dot(into) > 0.4
	if is_on_floor():
		# On the ground, climbing is a choice: jump while aimed at the wall.
		if Input.is_action_pressed(&"jump") and (pushing_in or looking_in):
			_begin_climb(normal)
	elif moving_in or pushing_in or (Input.is_action_pressed(&"jump") and looking_in):
		_begin_climb(normal)


func _find_climb_normal() -> Vector3:
	var chest := global_position + Vector3.UP * _chest_height()
	var dirs: Array[Vector3] = []
	if _wish.length() > 0.2:
		dirs.append(_wish.normalized())
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if horizontal.length() > 0.4:
		dirs.append(horizontal.normalized())
	dirs.append(camera_rig.get_flat_forward())
	for dir in dirs:
		var hit := _raycast(chest, chest + dir * probe_distance)
		if _is_climbable_hit(hit):
			return (hit.normal as Vector3).normalized()
	return _slide_climb_normal()


func _slide_climb_normal() -> Vector3:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var node := collision.get_collider() as Node
		if not _node_is_climbable(node):
			continue
		var normal := collision.get_normal()
		if normal.y >= max_climb_normal_y:
			continue
		if collision.get_position().y < global_position.y + min_grab_height:
			continue
		return normal.normalized()
	return Vector3.ZERO


func _probe_climb_contact() -> void:
	var from := global_position + Vector3.UP * _chest_height() + _wall_normal * 0.06
	var hit := _raycast(from, from - _wall_normal * (probe_distance + 0.15))
	if _is_climbable_hit(hit):
		var fresh := (hit.normal as Vector3).normalized()
		_wall_normal = _wall_normal.lerp(fresh, 0.45).normalized()
		_lost_wall = 0
		if (
			_climb_time > 0.35
			and is_on_floor()
			and get_floor_angle() < deg_to_rad(22.0)
			and global_position.y > _climb_start_y + 0.75
		):
			# Reached a walkable top without needing the mantle correction.
			_state = State.GROUND
			velocity = Vector3.ZERO
			return
		if _climb_time > 0.35 and is_on_floor() and global_position.y <= _climb_start_y + 0.12 and _hop <= 0.0:
			# Still standing at the base. Drop the grab so walking still works.
			_end_climb(Vector3.ZERO, 0.15)
		return
	if _try_mantle():
		return
	# A couple of missed probes, so a single frame of ray jitter doesn't drop us.
	_lost_wall += 1
	if _lost_wall > 4:
		_end_climb(Vector3.ZERO, 0.12)
		return
	if _climb_time > 0.25 and is_on_floor() and global_position.y <= _climb_start_y + 0.12:
		_end_climb(Vector3.ZERO, 0.15)


func _try_mantle() -> bool:
	var into := -_wall_normal
	var origin := global_position + Vector3.UP * (_body_height() + 0.25) + into * 0.55
	var hit := _raycast(origin, origin + Vector3.DOWN * 1.8)
	if hit.is_empty():
		return false
	var normal := hit.normal as Vector3
	if normal.y < 0.65:
		return false
	var point := hit.position as Vector3
	var rise := point.y - global_position.y
	if rise < 0.2 or rise > _body_height() + 0.4:
		return false
	_mantle_from = global_position
	_mantle_to = point + into * 0.4
	_mantle_to.y = point.y + 0.04
	if _mantle_from.distance_to(_mantle_to) > 2.6:
		return false
	_mantle_t = 0.0
	_state = State.MANTLE
	velocity = Vector3.ZERO
	collision_mask = 0
	return true


func _begin_climb(normal: Vector3) -> void:
	_state = State.CLIMB
	_wall_normal = normal.normalized()
	_climb_time = 0.0
	_climb_start_y = global_position.y
	_lost_wall = 0
	_hop = 0.0
	velocity = Vector3.ZERO


func _end_climb(push: Vector3, cooldown: float) -> void:
	_state = State.AIR
	_hop = 0.0
	_regrab = cooldown
	velocity = push
	collision_mask = _default_mask


func _can_enter_glide() -> bool:
	if not glide_unlocked or stamina <= glide_min_stamina:
		return false
	if not Input.is_action_pressed(&"glide"):
		return false
	return velocity.y <= glide_entry_vertical_speed


func _regen_stamina(delta: float) -> void:
	if stamina < max_stamina:
		stamina = minf(max_stamina, stamina + stamina_regen * delta)


func _check_low_stamina() -> void:
	var low := stamina / maxf(max_stamina, 1.0) < low_stamina_ratio
	if low and not _low_warned:
		_low_warned = true
		# Stand-in for the "breathing and a rumble" warning. There is no
		# animation yet; the bar flashes and the body pulses in _update_visuals.
		if not Input.get_connected_joypads().is_empty():
			Input.start_joy_vibration(0, 0.22, 0.4, 0.16)
	elif not low:
		_low_warned = false


func _try_interact() -> void:
	var best: Node = null
	var best_distance := interact_range
	for node in get_tree().get_nodes_in_group(INTERACTABLE):
		if not node.has_method(&"interact"):
			continue
		var distance := global_position.distance_to(node.global_position)
		if distance < best_distance:
			best = node
			best_distance = distance
	if best:
		best.interact()


func _update_out_of_bounds() -> void:
	if global_position.y >= fall_reset_y:
		return
	# The test pad has edges. Dropping off it is confusing, not a challenge,
	# so the player is put back. This is not a game over and costs no stamina.
	collision_mask = _default_mask
	global_position = _spawn
	velocity = Vector3.ZERO
	_state = State.AIR
	_hop = 0.0


func _update_visuals(delta: float) -> void:
	_face_visual(delta)
	_squash = move_toward(_squash, 1.0, delta * 3.5)
	var breathe := 1.0
	if _state == State.CLIMB and stamina / maxf(max_stamina, 1.0) < low_stamina_ratio:
		breathe = 1.0 + sin(Time.get_ticks_msec() * 0.014) * 0.045
	var width := lerpf(1.14, 1.0, _squash) * breathe
	visual.scale = Vector3(width, _squash, width)
	cape.visible = glide_unlocked
	var cape_pitch := deg_to_rad(-55.0) if _state == State.GLIDE else deg_to_rad(14.0)
	cape.rotation.x = lerp_angle(cape.rotation.x, cape_pitch, 6.0 * delta)
	_update_blob()
	_update_stamina_bar()


func _face_visual(delta: float) -> void:
	var face := Vector3.ZERO
	if _state == State.CLIMB or _state == State.MANTLE:
		face = -_wall_normal
	else:
		var horizontal := Vector3(velocity.x, 0.0, velocity.z)
		if horizontal.length() > 0.3:
			face = horizontal
		elif _wish.length() > 0.1 and _state != State.GLIDE:
			face = _wish
	if face.length_squared() < 0.0001:
		return
	# The mesh nose is local -Z. This yaw makes -Z match `face`.
	var target := atan2(-face.x, -face.z)
	visual.rotation.y = lerp_angle(visual.rotation.y, target, visual_turn_speed * delta)
	var local_right := visual.global_transform.basis.x
	var horizontal_vel := Vector3(velocity.x, 0.0, velocity.z)
	var strafe := horizontal_vel.dot(local_right)
	var tilt := clampf(-strafe / max_speed, -1.0, 1.0) * deg_to_rad(max_tilt_degrees)
	visual.rotation.z = lerp_angle(visual.rotation.z, tilt, 8.0 * delta)


func _update_blob() -> void:
	# A dark disc under the player. Decals aren't available on the compatibility
	# renderer this project ships with, so the landing aid is a flat mesh.
	var from := global_position + Vector3.UP * 0.3
	var hit := _raycast(from, from + Vector3.DOWN * 40.0)
	if hit.is_empty():
		blob.visible = false
		return
	var normal := hit.normal as Vector3
	if normal.y < 0.35:
		blob.visible = false
		return
	blob.visible = true
	var point := hit.position as Vector3
	blob.global_position = point + normal * 0.035
	blob.global_basis = _basis_from_up(normal)


func _update_stamina_bar() -> void:
	var ratio := clampf(stamina / maxf(max_stamina, 1.0), 0.0, 1.0)
	var using := _state == State.CLIMB or _state == State.GLIDE or _state == State.MANTLE
	# The doc wants the meter gone while it isn't part of a decision.
	stamina_bar.visible = using or ratio < 0.995
	if not stamina_bar.visible:
		return
	stamina_bar.global_position = global_position + Vector3.UP * 1.65
	stamina_bar.global_basis = camera.global_transform.basis
	stamina_fill.scale.x = maxf(ratio, 0.001)
	stamina_fill.position.x = (ratio - 1.0) * _fill_half_width
	if _fill_mat:
		if ratio < low_stamina_ratio:
			_fill_mat.albedo_color = Color(0.86, 0.28, 0.22)
		elif ratio < 0.55:
			_fill_mat.albedo_color = Color(0.9, 0.74, 0.28)
		else:
			_fill_mat.albedo_color = Color(0.46, 0.78, 0.42)
		var flashing := using and ratio < low_stamina_ratio
		_fill_mat.albedo_color.a = 0.45 + 0.55 * absf(sin(Time.get_ticks_msec() * 0.012)) if flashing else 1.0


func _setup_stamina_fill() -> void:
	var mesh := stamina_fill.mesh as QuadMesh
	if mesh:
		_fill_half_width = mesh.size.x * 0.5
	var source := stamina_fill.get_active_material(0)
	if source:
		_fill_mat = source.duplicate() as StandardMaterial3D
		stamina_fill.material_override = _fill_mat


func _cache_input() -> void:
	_input_dir = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	# get_vector's Y is positive for "back", and the camera's forward is -Z,
	# so forward input (negative Y) maps onto the camera forward.
	_wish = camera_rig.get_flat_right() * _input_dir.x + camera_rig.get_flat_forward() * (-_input_dir.y)
	if _wish.length() > 1.0:
		_wish = _wish.normalized()


func _raycast(from: Vector3, to: Vector3) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [get_rid()]
	return space.intersect_ray(query)


func _is_climbable_hit(hit: Dictionary) -> bool:
	if hit.is_empty():
		return false
	if not _node_is_climbable(hit.get("collider") as Node):
		return false
	var normal := hit.normal as Vector3
	return normal.y < max_climb_normal_y


func _node_is_climbable(node: Node) -> bool:
	if node == null:
		return false
	if node.is_in_group(UNCLIMBABLE):
		return false
	return node.is_in_group(CLIMBABLE)


func _body_height() -> float:
	var capsule := collision_shape.shape as CapsuleShape3D
	return capsule.height if capsule else 1.15


func _chest_height() -> float:
	return _body_height() * 0.62


func _basis_from_up(up: Vector3) -> Basis:
	var y := up.normalized()
	var helper := Vector3.FORWARD if absf(y.dot(Vector3.UP)) > 0.95 else Vector3.UP
	var x := helper.cross(y).normalized()
	var z := y.cross(x).normalized()
	return Basis(x, y, z)


func _exit_tree() -> void:
	Input.stop_joy_vibration(0)
