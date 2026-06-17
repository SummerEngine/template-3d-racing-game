class_name TrackPath
extends RefCounted

var centerline: PackedVector3Array = PackedVector3Array()
var distance_table: PackedFloat32Array = PackedFloat32Array()
var closed_loop: bool = true
var track_y: float = 0.0
var length_m: float = 0.0


static func from_points(points: PackedVector3Array, is_closed_loop: bool = true) -> RefCounted:
	var script: Script = load("res://scripts/track/track_path.gd")
	var result: RefCounted = script.new()
	result.configure(points, is_closed_loop)
	return result


static func build_arcade_loop_points(target_length_m: float = 1800.0, samples: int = 192, y: float = 0.0) -> PackedVector3Array:
	var safe_samples: int = maxi(samples, 96)
	var raw_points := PackedVector3Array()

	for i: int in range(safe_samples):
		var theta: float = TAU * float(i) / float(safe_samples)
		var radius: float = (
			1.0
			+ 0.16 * sin(theta * 3.0 + 0.35)
			+ 0.08 * sin(theta * 5.0 - 1.1)
			+ 0.05 * cos(theta * 2.0 + 0.9)
		)
		raw_points.append(Vector3(cos(theta) * radius, y, sin(theta) * radius))

	var raw_length: float = closed_path_length(raw_points)
	var track_scale: float = target_length_m / maxf(raw_length, 0.001)
	var scaled_points := PackedVector3Array()
	for point: Vector3 in raw_points:
		scaled_points.append(Vector3(point.x * track_scale, y, point.z * track_scale))

	return align_first_segment_to_spawn_axis(scaled_points, y)


static func align_first_segment_to_spawn_axis(points: PackedVector3Array, y: float = 0.0) -> PackedVector3Array:
	if points.size() < 2:
		return points

	var tangent: Vector3 = tangent_at(points, 0)
	var yaw_to_positive_z: float = atan2(-tangent.x, tangent.z)
	var rotated_points := PackedVector3Array()

	for point: Vector3 in points:
		rotated_points.append(point.rotated(Vector3.UP, yaw_to_positive_z))

	var start: Vector3 = rotated_points[0]
	var aligned_points := PackedVector3Array()
	for point: Vector3 in rotated_points:
		aligned_points.append(Vector3(point.x - start.x, y, point.z - start.z))

	return aligned_points


static func closed_path_length(points: PackedVector3Array) -> float:
	var length: float = 0.0
	if points.size() < 2:
		return length
	for i: int in range(points.size()):
		length += points[i].distance_to(points[(i + 1) % points.size()])
	return length


static func tangent_at(points: PackedVector3Array, index: int) -> Vector3:
	if points.size() < 2:
		return Vector3(0.0, 0.0, 1.0)

	var safe_index: int = clampi(index, 0, points.size() - 1)
	var prev: Vector3 = points[(safe_index - 1 + points.size()) % points.size()]
	var next: Vector3 = points[(safe_index + 1) % points.size()]
	var tangent: Vector3 = next - prev
	tangent.y = 0.0
	if tangent.length_squared() <= 0.0001:
		return Vector3(0.0, 0.0, 1.0)
	return tangent.normalized()


static func normal_from_tangent(tangent: Vector3) -> Vector3:
	var flat_tangent := Vector3(tangent.x, 0.0, tangent.z)
	if flat_tangent.length_squared() <= 0.0001:
		return Vector3.RIGHT
	return Vector3(flat_tangent.z, 0.0, -flat_tangent.x).normalized()


static func basis_from_forward(forward: Vector3) -> Basis:
	var flat_forward := Vector3(forward.x, 0.0, forward.z).normalized()
	if flat_forward.length_squared() <= 0.0001:
		flat_forward = Vector3(0.0, 0.0, 1.0)

	var back: Vector3 = -flat_forward
	var right: Vector3 = Vector3.UP.cross(back).normalized()
	return Basis(right, Vector3.UP, back).orthonormalized()


func configure(points: PackedVector3Array, is_closed_loop: bool = true) -> void:
	centerline = points.duplicate()
	closed_loop = is_closed_loop
	track_y = centerline[0].y if not centerline.is_empty() else 0.0
	distance_table = _build_distance_table(centerline, closed_loop)
	length_m = distance_table[distance_table.size() - 1] if not distance_table.is_empty() else 0.0


func sample_at_distance(distance_m: float) -> Dictionary:
	if centerline.is_empty():
		return {
			"position": Vector3.ZERO,
			"tangent": Vector3(0.0, 0.0, 1.0),
			"normal": Vector3.RIGHT,
			"distance": 0.0,
			"ratio": 0.0,
			"segment_index": 0,
		}

	if centerline.size() == 1 or length_m <= 0.0:
		return {
			"position": centerline[0],
			"tangent": Vector3(0.0, 0.0, 1.0),
			"normal": Vector3.RIGHT,
			"distance": 0.0,
			"ratio": 0.0,
			"segment_index": 0,
		}

	var resolved_distance: float = _resolve_distance(distance_m)
	var segment_count: int = centerline.size() if closed_loop else centerline.size() - 1
	for i: int in range(segment_count):
		var start_distance: float = distance_table[i]
		var end_distance: float = distance_table[i + 1]
		if resolved_distance <= end_distance:
			var segment_length: float = maxf(end_distance - start_distance, 0.001)
			var t: float = (resolved_distance - start_distance) / segment_length
			var next_index: int = (i + 1) % centerline.size()
			var sampled_position: Vector3 = centerline[i].lerp(centerline[next_index], t)
			var tangent: Vector3 = centerline[next_index] - centerline[i]
			tangent.y = 0.0
			if tangent.length_squared() <= 0.0001:
				tangent = tangent_at(centerline, i)
			else:
				tangent = tangent.normalized()
			return {
				"position": sampled_position,
				"tangent": tangent,
				"normal": normal_from_tangent(tangent),
				"distance": resolved_distance,
				"ratio": resolved_distance / length_m,
				"segment_index": i,
			}

	return sample_at_distance(0.0)


func transform_at_distance(distance_m: float, lateral_offset_m: float = 0.0, vertical_offset_m: float = 0.0) -> Transform3D:
	var sample: Dictionary = sample_at_distance(distance_m)
	var origin: Vector3 = sample["position"] + sample["normal"] * lateral_offset_m
	origin.y += vertical_offset_m
	return Transform3D(basis_from_forward(sample["tangent"]), origin)


func road_edge_position(distance_m: float, road_width_m: float, side: float, edge_offset_m: float = 0.0) -> Vector3:
	var sample: Dictionary = sample_at_distance(distance_m)
	var side_sign: float = -1.0 if side < 0.0 else 1.0
	return sample["position"] + sample["normal"] * side_sign * (road_width_m * 0.5 + edge_offset_m)


func closest_distance_for_position(position: Vector3) -> float:
	if centerline.size() < 2 or length_m <= 0.0:
		return 0.0

	var target := Vector2(position.x, position.z)
	var best_distance_sq: float = INF
	var best_distance_m: float = 0.0
	var segment_count: int = centerline.size() if closed_loop else centerline.size() - 1

	for i: int in range(segment_count):
		var next_index: int = (i + 1) % centerline.size()
		var a := Vector2(centerline[i].x, centerline[i].z)
		var b := Vector2(centerline[next_index].x, centerline[next_index].z)
		var segment: Vector2 = b - a
		var segment_length_sq: float = segment.length_squared()
		var t: float = 0.0
		if segment_length_sq > 0.0001:
			t = clampf((target - a).dot(segment) / segment_length_sq, 0.0, 1.0)

		var projected: Vector2 = a + segment * t
		var distance_sq: float = target.distance_squared_to(projected)
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			best_distance_m = distance_table[i] + (distance_table[i + 1] - distance_table[i]) * t

	return _resolve_distance(best_distance_m)


func get_length_m() -> float:
	return length_m


func _build_distance_table(points: PackedVector3Array, is_closed_loop: bool) -> PackedFloat32Array:
	var distances := PackedFloat32Array()
	var distance: float = 0.0
	distances.append(distance)

	if points.size() < 2:
		return distances

	var segment_count: int = points.size() if is_closed_loop else points.size() - 1
	for i: int in range(segment_count):
		distance += points[i].distance_to(points[(i + 1) % points.size()])
		distances.append(distance)

	return distances


func _resolve_distance(distance_m: float) -> float:
	if length_m <= 0.0:
		return 0.0
	if closed_loop:
		return fposmod(distance_m, length_m)
	return clampf(distance_m, 0.0, length_m)
