extends RefCounted

const G = preload("res://scripts/wall_geometry.gd")
const SPIKE_TIP_SCALE := 1.35

static func ring(canvas: CanvasItem, center: Vector2, zoom: float, radius: float, angle: float, color: Color, width: float) -> void:
	for segment in G.segments(radius, angle):
		canvas.draw_line(center + segment[0] * zoom, center + segment[1] * zoom, color, width, true)

static func spiky_circle(canvas: CanvasItem, center: Vector2, radius: float, angle: float, ink: Color) -> void:
	const POINTS := 20
	var outline := PackedVector2Array()
	for point in POINTS:
		var direction := angle + TAU * point / POINTS
		var tooth := radius * (SPIKE_TIP_SCALE if point % 2 == 0 else 0.72)
		outline.append(center + Vector2.from_angle(direction) * tooth)
	canvas.draw_colored_polygon(outline, ink)

static func slider_marker(canvas: CanvasItem, center: Vector2, radius: float, axis: Vector2, ink: Color, width: float) -> void:
	canvas.draw_arc(center, radius, 0.0, TAU, 24, ink, width, true)
	direction_arrow(canvas, center, axis, radius * 0.62, ink, width)

static func direction_arrow(canvas: CanvasItem, center: Vector2, axis: Vector2, length: float, ink: Color, width: float) -> void:
	var tip := center + axis * length
	var wing := axis.orthogonal() * length * 0.53
	canvas.draw_line(center - axis * length, tip, ink, width, true)
	canvas.draw_polyline(PackedVector2Array([center + wing, tip, center - wing]), ink, width, true)
