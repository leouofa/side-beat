class_name GodProfile
extends Resource
## Defines one of the 4 playable mythic gods in the Shared-Soul Morph roster.

@export var id: String = "endor"
@export var display_name: String = "Endor"
@export var pantheon: String = "Asgardian (Norse)"
@export var input_slot: int = 1
@export var archetype: String = "Heavy Armor-Breaker / Thunder Brawler"
@export var signature_weapon: String = "Runic War-Hammer & Thunder Gauntlets"
@export var glb_path: String = "res://assets/characters/endor.glb"
@export var primary_color: Color = Color("#00D4FF")
@export var secondary_color: Color = Color("#1E3A5F")
@export var accent_color: Color = Color("#C8D6E5")

@export var move_speed: float = 5.2
@export var attack_speed_mult: float = 0.85
@export var damage_mult: float = 1.35
@export var jump_velocity: float = 10.6
@export var max_air_jumps: int = 0
@export var has_air_hover: bool = false
@export var heavy_poise_armor: bool = true
@export var morph_sfx: String = "morph_endor"

var moves: Dictionary = {} # StringName -> AttackData
