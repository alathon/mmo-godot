class_name RemoteEntityBody
extends Node3D



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_physics_process(false)
	set_process(false)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
