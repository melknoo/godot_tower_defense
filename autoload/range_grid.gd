# Gemeinsame, rastergenaue Reichweitenlogik fuer Tower und Vorschauen.
extends RefCounted
class_name RangeGrid

const CELL_SIZE := 64.0


static func get_cell_radius(range_pixels: float) -> int:
	if range_pixels <= 0.0:
		return 0
	return maxi(1, roundi(range_pixels / CELL_SIZE))


static func get_half_extent(range_pixels: float) -> float:
	var cell_radius := get_cell_radius(range_pixels)
	if cell_radius <= 0:
		return 0.0
	# Die zusaetzlichen 0,5 Zellen legen die Kante exakt auf Rastergrenzen.
	return (float(cell_radius) + 0.5) * CELL_SIZE


static func contains_point(origin: Vector2, point: Vector2, range_pixels: float) -> bool:
	var half_extent := get_half_extent(range_pixels)
	if half_extent <= 0.0:
		return false
	var delta := point - origin
	return absf(delta.x) <= half_extent and absf(delta.y) <= half_extent


static func is_inside_minimum(origin: Vector2, point: Vector2, minimum_range: float) -> bool:
	if minimum_range <= 0.0:
		return false
	var half_extent := get_half_extent(minimum_range)
	var delta := point - origin
	return absf(delta.x) < half_extent and absf(delta.y) < half_extent


static func rebuild_visual(
		container: Node2D,
		range_pixels: float,
		color: Color,
		line_width: float = 1.0,
		show_cells: bool = true
	) -> Line2D:
	clear_visual(container)
	var half_extent := get_half_extent(range_pixels)
	if half_extent <= 0.0:
		return null

	var fill := Polygon2D.new()
	fill.name = "RangeFill"
	fill.polygon = PackedVector2Array([
		Vector2(-half_extent, -half_extent),
		Vector2(half_extent, -half_extent),
		Vector2(half_extent, half_extent),
		Vector2(-half_extent, half_extent),
	])
	fill.set_meta("range_color_role", "fill")
	container.add_child(fill)

	if show_cells:
		var cell_radius := get_cell_radius(range_pixels)
		var boundary_count := cell_radius * 2 + 2
		for index in range(1, boundary_count - 1):
			var offset := -half_extent + float(index) * CELL_SIZE
			var vertical := _make_line(
				PackedVector2Array([Vector2(offset, -half_extent), Vector2(offset, half_extent)]),
				line_width * 0.65,
				"grid"
			)
			container.add_child(vertical)
			var horizontal := _make_line(
				PackedVector2Array([Vector2(-half_extent, offset), Vector2(half_extent, offset)]),
				line_width * 0.65,
				"grid"
			)
			container.add_child(horizontal)

	var border := _make_line(PackedVector2Array([
		Vector2(-half_extent, -half_extent),
		Vector2(half_extent, -half_extent),
		Vector2(half_extent, half_extent),
		Vector2(-half_extent, half_extent),
		Vector2(-half_extent, -half_extent),
	]), line_width, "border")
	border.name = "RangeBorder"
	container.add_child(border)
	tint_visual(container, color)
	return border


static func clear_visual(container: Node2D) -> void:
	if not is_instance_valid(container):
		return
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


static func tint_visual(container: Node2D, color: Color) -> void:
	if not is_instance_valid(container):
		return
	for child in container.get_children():
		var role := String(child.get_meta("range_color_role", "border"))
		var role_color := color
		match role:
			"fill":
				role_color.a = color.a * 0.16
			"grid":
				role_color.a = color.a * 0.42
			_:
				role_color.a = color.a
		if child is Line2D:
			child.default_color = role_color
		elif child is Polygon2D:
			child.color = role_color


static func _make_line(points: PackedVector2Array, width: float, role: String) -> Line2D:
	var line := Line2D.new()
	line.points = points
	line.width = width
	line.antialiased = false
	line.set_meta("range_color_role", role)
	return line
