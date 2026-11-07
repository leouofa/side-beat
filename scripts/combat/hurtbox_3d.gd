class_name HurtBox3D
extends Area3D
## Receives strikes from opposing HitBox3D volumes and forwards them to owner_actor.receive_hit().

var owner_actor: Node = null
var team: StringName = &"enemy"
var _shape_node: CollisionShape3D
var _box_shape: BoxShape3D


func _init() -> void:
	monitoring = false
	monitorable = true


func setup(actor: Node, is_player_team: bool, box_size: Vector3 = Vector3(0.85, 1.85, 0.85), y_center: float = 0.92, is_prop: bool = false) -> void:
	owner_actor = actor
	team = &"player" if is_player_team else &"enemy"
	if is_prop:
		collision_layer = (1 << 5)
	else:
		collision_layer = (1 << 3) if is_player_team else (1 << 4)
	collision_mask = 0

	if _shape_node == null:
		_shape_node = CollisionShape3D.new()
		_box_shape = BoxShape3D.new()
		_shape_node.shape = _box_shape
		add_child(_shape_node)
	_box_shape.size = box_size
	_shape_node.position = Vector3(0.0, y_center, 0.0)


func receive_strike(payload: Dictionary) -> Dictionary:
	if owner_actor and owner_actor.has_method("receive_hit"):
		return owner_actor.receive_hit(payload)
	return {"connected": false}
