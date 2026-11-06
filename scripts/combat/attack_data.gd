class_name AttackData
extends Resource
## Frame-accurate fighting-game move specification (60 Hz frame windows).

@export var move_id: StringName = &"light_1"
@export var display_name: String = "Jab"
@export var anim_name: StringName = &"light_1"
@export var startup_frames: int = 4
@export var active_frames: int = 5
@export var recovery_frames: int = 9
@export var cancel_window_start: int = 6
@export var damage: float = 38.0
@export var armor_damage: float = 22.0
@export var meter_gain: float = 5.5
@export var meter_cost: float = 0.0
@export var hitstop_frames: int = 4
@export var forward_lunge_speed: float = 2.6
@export var knockback_vel: Vector3 = Vector3(3.4, 0.0, 0.0)
@export var launches_airborne: bool = false
@export var ground_bounces: bool = false
@export var wall_bounces: bool = false
@export var crumples_block: bool = false
@export var unblockable: bool = false
@export var hyper_armor: bool = false
@export var counter_stance: bool = false
@export var pulls_z_corridor: bool = false
@export var leeches_hp_ratio: float = 0.0
@export var teleport_cross_through: bool = false
@export var dive_velocity: Vector3 = Vector3.ZERO
@export var active_sockets: PackedStringArray = ["weapon_socket.R"]
@export var hitbox_extents: Vector3 = Vector3(1.15, 0.85, 0.95)
@export var aoe_corridor_box: Vector3 = Vector3.ZERO # Non-zero spawns corridor/arena AOE hitbox
@export var sfx_hit: String = "hit_light"
@export var spark_scale: float = 1.0


func total_frames() -> int:
	return startup_frames + active_frames + recovery_frames
