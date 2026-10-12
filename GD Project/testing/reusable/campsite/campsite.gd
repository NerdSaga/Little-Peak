@tool
class_name Campsite
extends Node3D

## A rest fire. Press interact while close to roast a marshmallow, which
## unlocks the site. Unlocked sites can be teleported to; the spawn point is
## the SpawnPoint marker, so a level can scoot where the player appears.
##
## The test room listens to [signal unlocked] and does not get looked up from
## in here.

signal unlocked(campsite: Campsite)

@export var display_name: String = "Campsite":
	set(value):
		# Renames the wooden sign when the inspector renames the fire.
		display_name = value
		# The title is part of the scene, so renaming an instance in the
		# inspector updates the sign without a second property.
		if is_node_ready():
			title.text = value

var is_unlocked: bool = false
var _near: Node3D = null

@onready var sense: Area3D = $Sense
@onready var prompt: Label3D = $Prompt
@onready var speech: Label3D = $Speech
@onready var title: Label3D = $Title
@onready var marshmallow: Node3D = $Marshmallow
@onready var spawn_point: Marker3D = $SpawnPoint


func _ready() -> void:
	# Lights the prompt off and hides the marshmallow. Not yet.
	add_to_group(&"campsite")
	add_to_group(&"interactable")
	sense.body_entered.connect(_on_body_entered)
	sense.body_exited.connect(_on_body_exited)
	prompt.visible = false
	speech.visible = false
	marshmallow.visible = false
	title.text = display_name


func interact() -> void:
	# One roast, one unlock. The marshmallow stays as proof.
	if _near == null:
		return
	if is_unlocked:
		_say("Already toasted. Tab opens travel if you want to come back.")
		return
	# One roast is the unlock. The marshmallow stays so the fire reads as used.
	is_unlocked = true
	marshmallow.visible = true
	_say("Toasted. This fire will remember you.")
	unlocked.emit(self)


func get_spawn_position() -> Vector3:
	# Where a teleport should plant the feet. Not in the coals.
	return spawn_point.global_position


func _physics_process(_delta: float) -> void:
	# Shows the "press E" hint only while someone is actually here.
	if Engine.is_editor_hint():
		return
	prompt.visible = _near != null and not speech.visible


func _say(line: String) -> void:
	# The fire has a line. It is not shy about it.
	speech.text = line
	speech.visible = true


func _on_body_entered(body: Node3D) -> void:
	# A player wandered into smelling range.
	if body is PlayerController:
		_near = body


func _on_body_exited(body: Node3D) -> void:
	# They left. Hide the chatter unless the marshmallow already happened.
	if body == _near:
		_near = null
		if not is_unlocked:
			speech.visible = false
