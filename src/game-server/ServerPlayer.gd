class_name ServerPlayer
extends SimulatedEntity

@onready var body: PhysicsBody = %Body
@onready var hostility: Node = %DetermineHostility
@onready var input_state: PlayerInputState = $PlayerInputState

func _get_face_angle() -> float:
	return body.face_angle


func _set_face_angle(value: float) -> void:
	body.face_angle = value
