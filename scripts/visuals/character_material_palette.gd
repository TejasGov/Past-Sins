extends RefCounted
class_name CharacterMaterialPalette

## Color-cached material provider for modular characters (guards, inmates, NPCs).
## Follows the greybox_factory.gd caching pattern to ensure zero texture duplication
## and single-material batching across character variants.

static var _skin_materials: Dictionary = {}
static var _uniform_materials: Dictionary = {}
static var _hair_materials: Dictionary = {}
static var _accessory_materials: Dictionary = {}
static var _character_surface_materials: Dictionary = {}
const FACTION_SHADER: Shader = preload("res://shaders/character_faction.gdshader")

# Standard Skin Tone Palettes
const SKIN_FAIR := Color("f2cbaf")
const SKIN_MEDIUM := Color("d7a581")
const SKIN_TAN := Color("a56e48")
const SKIN_DARK := Color("5c3822")
const SKIN_DEEP := Color("3d2314")
const SKIN_TONES: Array[Color] = [SKIN_FAIR, SKIN_MEDIUM, SKIN_TAN, SKIN_DARK, SKIN_DEEP]

# Standard Guard Uniform Palettes
const GUARD_PRIMARY := Color("1b252c")
const GUARD_SECONDARY := Color("141b20")
const GUARD_VEST := Color("1e292d")
const GUARD_LEATHER := Color("111315")
const GUARD_BADGE := Color("d4af37")

# Standard Inmate Uniform Palettes
const INMATE_ORANGE := Color("d9541e")
const INMATE_KHAKI := Color("8c7b64")
const INMATE_CYAN := Color("2e7a82")
const INMATE_SHOES := Color("2a2622")

# Standard Hair Palettes
const HAIR_BLACK := Color("141414")
const HAIR_DARK_BROWN := Color("2b1d14")
const HAIR_BROWN := Color("4a3321")
const HAIR_BLONDE := Color("c29e62")
const HAIR_GREY := Color("858585")


static func get_skin_material(color: Color) -> StandardMaterial3D:
	var key := color.to_html(true)
	if _skin_materials.has(key):
		return _skin_materials[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	material.metallic_specular = 0.35
	_skin_materials[key] = material
	return material


static func get_uniform_material(color: Color, roughness := 0.85) -> StandardMaterial3D:
	var key := "%s:%0.2f" % [color.to_html(true), roughness]
	if _uniform_materials.has(key):
		return _uniform_materials[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	_uniform_materials[key] = material
	return material


static func get_hair_material(color: Color) -> StandardMaterial3D:
	var key := color.to_html(true)
	if _hair_materials.has(key):
		return _hair_materials[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	_hair_materials[key] = material
	return material


static func get_accessory_material(color: Color, metallic := 0.0, roughness := 0.6) -> StandardMaterial3D:
	var key := "%s:%0.2f:%0.2f" % [color.to_html(true), metallic, roughness]
	if _accessory_materials.has(key):
		return _accessory_materials[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	_accessory_materials[key] = material
	return material


static func get_character_surface_material(
	texture: Texture2D,
	is_inmate: bool,
	skin: Color,
	primary: Color,
	secondary: Color
) -> ShaderMaterial:
	var key := "%s:%s:%s:%s:%s" % [
		texture.resource_path,
		is_inmate,
		skin.to_html(true),
		primary.to_html(true),
		secondary.to_html(true),
	]
	if _character_surface_materials.has(key):
		return _character_surface_materials[key] as ShaderMaterial
	var material := ShaderMaterial.new()
	material.shader = FACTION_SHADER
	material.set_shader_parameter(&"source_texture", texture)
	material.set_shader_parameter(&"inmate_mix", 1.0 if is_inmate else 0.0)
	material.set_shader_parameter(&"skin_color", skin)
	material.set_shader_parameter(&"inmate_primary", primary)
	material.set_shader_parameter(&"inmate_secondary", secondary)
	_character_surface_materials[key] = material
	return material


static func clear_cache() -> void:
	_skin_materials.clear()
	_uniform_materials.clear()
	_hair_materials.clear()
	_accessory_materials.clear()
	_character_surface_materials.clear()
