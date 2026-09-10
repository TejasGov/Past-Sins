extends RefCounted
class_name ArmorTypes

## Shared armor identifiers and temporary effective-health bonuses. Resistance,
## penetration, durability, and damage reduction deliberately do not live here.
enum Type {
	NONE,
	STANDARD_VEST,
	ADVANCED_VEST,
}

const BONUS_BY_TYPE := {
	Type.NONE: 0.0,
	Type.STANDARD_VEST: 25.0,
	Type.ADVANCED_VEST: 50.0,
}

const LABEL_BY_TYPE := {
	Type.NONE: "NONE",
	Type.STANDARD_VEST: "STANDARD VEST",
	Type.ADVANCED_VEST: "ADVANCED VEST",
}


static func bonus_for(armor_type: Type) -> float:
	return float(BONUS_BY_TYPE.get(armor_type, 0.0))


static func label_for(armor_type: Type) -> String:
	return String(LABEL_BY_TYPE.get(armor_type, "NONE"))
