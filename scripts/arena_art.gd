extends RefCounted

const T = preload("res://scripts/tuning.gd")
const G = preload("res://scripts/wall_geometry.gd")
const Palette = preload("res://scripts/palette.gd")
const CORE_BODY := [
	Vector2(0, -T.TIP_LENGTH), Vector2(23, -64), Vector2(40, -63),
	Vector2(70, -3), Vector2(38, 50), Vector2(-33, 50),
	Vector2(-69, -1), Vector2(-36, -61), Vector2(-22, -64),
]

static func core(canvas: CanvasItem, center: Vector2, zoom: float, heading: float, aligned: bool) -> void:
	var points := PackedVector2Array()
	for point: Vector2 in CORE_BODY:
		points.append(center + point.rotated(heading - T.TIP_ANGLE) * zoom)
	canvas.draw_colored_polygon(points, Palette.RED_WASH)
	var tip := points[0]
	var shoulder_a := points[1]
	var shoulder_b := points[-1]
	var color := Palette.RED if aligned else Palette.MUTED
	canvas.draw_colored_polygon(PackedVector2Array([tip, shoulder_a, shoulder_b]), Color(color, 0.24))
	points.append(tip)
	canvas.draw_polyline(points, Palette.RED, 2.5, true)
	canvas.draw_polyline(PackedVector2Array([shoulder_b, tip, shoulder_a]), color, 3.0, true)

static func ring(canvas: CanvasItem, center: Vector2, zoom: float, radius: float, angle: float, color: Color, width: float) -> void:
	for segment in G.segments(radius, angle):
		canvas.draw_line(center + segment[0] * zoom, center + segment[1] * zoom, color, width, true)

static func spiky_circle(canvas: CanvasItem, center: Vector2, radius: float, angle: float, ink: Color) -> void:
	const POINTS := 20
	var outline := PackedVector2Array()
	for point in POINTS:
		var direction := angle + TAU * point / POINTS
		var tooth := radius * (1.35 if point % 2 == 0 else 0.72)
		outline.append(center + Vector2.from_angle(direction) * tooth)
	canvas.draw_colored_polygon(outline, ink)
