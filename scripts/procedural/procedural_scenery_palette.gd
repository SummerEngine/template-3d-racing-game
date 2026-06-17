class_name ProceduralSceneryPalette
extends RefCounted


static func flat_material(albedo: Color, roughness: float = 0.82, metallic: float = 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = albedo
	result.roughness = roughness
	result.metallic = metallic
	return result


static func material(key: String, variant: int = 0, roughness: float = -1.0, metallic: float = 0.0) -> StandardMaterial3D:
	var resolved_roughness: float = _default_roughness(key) if roughness < 0.0 else roughness
	var scenery_material := flat_material(color(key, variant), resolved_roughness, metallic)
	scenery_material.resource_name = "Scenery_%s_%02d" % [key, _positive_index(variant, 100)]
	return scenery_material


static func color(key: String, variant: int = 0) -> Color:
	match key:
		"house_wall":
			return _pick([
				Color(0.86, 0.74, 0.56, 1.0),
				Color(0.76, 0.84, 0.78, 1.0),
				Color(0.84, 0.82, 0.74, 1.0),
				Color(0.72, 0.78, 0.86, 1.0),
			], variant)
		"roof":
			return _pick([
				Color(0.42, 0.12, 0.08, 1.0),
				Color(0.18, 0.19, 0.22, 1.0),
				Color(0.48, 0.27, 0.16, 1.0),
				Color(0.14, 0.27, 0.31, 1.0),
			], variant)
		"door":
			return _pick([
				Color(0.28, 0.14, 0.08, 1.0),
				Color(0.12, 0.22, 0.32, 1.0),
				Color(0.34, 0.08, 0.07, 1.0),
			], variant)
		"glass":
			return _pick([
				Color(0.5, 0.74, 0.86, 1.0),
				Color(0.42, 0.64, 0.72, 1.0),
				Color(0.66, 0.8, 0.88, 1.0),
			], variant)
		"billboard_panel":
			return _pick([
				Color(0.95, 0.91, 0.62, 1.0),
				Color(0.76, 0.88, 0.96, 1.0),
				Color(0.93, 0.72, 0.56, 1.0),
				Color(0.79, 0.92, 0.72, 1.0),
			], variant)
		"billboard_trim":
			return Color(0.08, 0.09, 0.1, 1.0)
		"crop_soil":
			return Color(0.22, 0.13, 0.08, 1.0)
		"crop":
			return _pick([
				Color(0.22, 0.48, 0.14, 1.0),
				Color(0.36, 0.55, 0.16, 1.0),
				Color(0.52, 0.5, 0.18, 1.0),
			], variant)
		"factory_wall":
			return _pick([
				Color(0.46, 0.49, 0.49, 1.0),
				Color(0.58, 0.55, 0.5, 1.0),
				Color(0.36, 0.4, 0.43, 1.0),
			], variant)
		"factory_roof":
			return _pick([
				Color(0.16, 0.18, 0.2, 1.0),
				Color(0.27, 0.29, 0.3, 1.0),
				Color(0.22, 0.24, 0.25, 1.0),
			], variant)
		"container":
			return _pick([
				Color(0.72, 0.16, 0.08, 1.0),
				Color(0.08, 0.28, 0.48, 1.0),
				Color(0.84, 0.58, 0.12, 1.0),
				Color(0.18, 0.47, 0.24, 1.0),
			], variant)
		"metal":
			return Color(0.48, 0.5, 0.5, 1.0)
		"concrete":
			return Color(0.56, 0.56, 0.52, 1.0)
		_:
			return Color(0.8, 0.8, 0.78, 1.0)


static func darker(key: String, variant: int = 0, amount: float = 0.18) -> Color:
	var base_color: Color = color(key, variant)
	return base_color.darkened(clampf(amount, 0.0, 1.0))


static func lighter(key: String, variant: int = 0, amount: float = 0.18) -> Color:
	var base_color: Color = color(key, variant)
	return base_color.lightened(clampf(amount, 0.0, 1.0))


static func _pick(colors: Array[Color], variant: int) -> Color:
	if colors.is_empty():
		return Color.WHITE
	return colors[_positive_index(variant, colors.size())]


static func _positive_index(value: int, modulo: int) -> int:
	if modulo <= 0:
		return 0
	var index: int = value % modulo
	if index < 0:
		index += modulo
	return index


static func _default_roughness(key: String) -> float:
	match key:
		"glass":
			return 0.18
		"metal", "factory_roof", "container":
			return 0.58
		"crop", "crop_soil":
			return 0.95
		_:
			return 0.82
