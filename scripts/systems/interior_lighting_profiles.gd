extends RefCounted
class_name InteriorLightingProfiles

## Central art-direction table, uniform across all facilities.
## All lights emit warm yellow light, except NIDRA laboratories which emit sterile white light.

const YELLOW_LIGHT := Color(1.0, 0.86, 0.62)
const WHITE_LIGHT := Color(0.96, 0.98, 1.0)
const UNIFORM_AMBIENT := 0.22

const PROFILES := {
	"cellblock": {"color": YELLOW_LIGHT, "energy": 2.0, "attenuation": 1.8, "ambient": UNIFORM_AMBIENT, "always_on": false},
	"laboratory": {"color": WHITE_LIGHT, "energy": 2.2, "attenuation": 1.35, "ambient": UNIFORM_AMBIENT, "always_on": true},
	"medical": {"color": YELLOW_LIGHT, "energy": 1.8, "attenuation": 1.5, "ambient": UNIFORM_AMBIENT, "always_on": true},
	"office": {"color": YELLOW_LIGHT, "energy": 1.8, "attenuation": 1.6, "ambient": UNIFORM_AMBIENT, "always_on": true},
	"wellness": {"color": YELLOW_LIGHT, "energy": 1.8, "attenuation": 1.5, "ambient": UNIFORM_AMBIENT, "always_on": true},
	"food": {"color": YELLOW_LIGHT, "energy": 2.0, "attenuation": 1.6, "ambient": UNIFORM_AMBIENT, "always_on": true},
	"service": {"color": YELLOW_LIGHT, "energy": 1.8, "attenuation": 1.8, "ambient": UNIFORM_AMBIENT, "always_on": true},
}

const ALIASES := {
	"cell": "cellblock", "dorm": "cellblock", "dorms": "cellblock", "atrium": "cellblock",
	"lab": "laboratory", "laboratory": "laboratory", "nidra": "laboratory", "nidra-lab": "laboratory", "sterile": "laboratory", "research": "laboratory",
	"clinic": "medical", "ward": "medical", "infirmary": "medical", "exam": "medical", "treatment": "medical",
	"security": "office", "admin": "office", "administration": "office", "control": "office", "surveillance": "office", "staff": "office", "records": "office", "visitation": "office",
	"gym": "wellness", "shower": "wellness", "showers": "wellness", "changing": "wellness", "toilet": "wellness", "toilets": "wellness", "yard-support": "wellness", "recreation": "wellness",
	"kitchen": "food", "cafeteria": "food", "dining": "food", "prep": "food", "wash": "food", "serving": "food",
	"tunnel": "service", "basement": "service", "maintenance": "service", "utility": "service", "storage": "service", "workshop": "service", "laundry": "service", "interrogation": "service", "stair": "service", "lift": "service", "corridor": "service",
}

static func profile_id(room_type: String) -> String:
	var key := room_type.to_lower()
	if PROFILES.has(key): return key
	return String(ALIASES.get(key, "office"))

static func get_profile(room_type: String) -> Dictionary:
	return PROFILES[profile_id(room_type)]

static func apply_to_light(light: OmniLight3D, room_type: String) -> void:
	var profile := get_profile(room_type)
	light.light_color = profile.color
	light.light_energy = profile.energy
	light.omni_attenuation = profile.attenuation
	light.light_specular = 0.2
	light.set_meta("lighting_profile", profile_id(room_type))
	light.set_meta("always_on", profile.always_on)
