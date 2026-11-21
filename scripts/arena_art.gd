extends RefCounted

const T = preload("res://scripts/tuning.gd")
const G = preload("res://scripts/wall_geometry.gd")
const MINT := Color("9cfdc2")
const RED := Color("ff886e")
const GOLD := Color("ffd17e")
const CORE_BODY := [
	Vector2(0, -T.TIP_LENGTH), Vector2(23, -64), Vector2(40, -63),
	Vector2(70, -3), Vector2(38, 50), Vector2(-33, 50),
	Vector2(-69, -1), Vector2(-36, -61), Vector2(-22, -64),
]

static func core(canvas: CanvasItem, center: Vector2, zoom: float, heading: float, aligned: bool) -> void:
	var points := PackedVector2Array()
	for point: Vector2 in CORE_BODY:
		points.append(center + point.rotated(heading - T.TIP_ANGLE) * zoom)
	canvas.draw_colored_polygon(points, Color("362327"))
	var tip := points[0]
	var shoulder_a := points[1]
	var shoulder_b := points[-1]
	var color := MINT if aligned else GOLD
	canvas.draw_colored_polygon(PackedVector2Array([tip, shoulder_a, shoulder_b]), Color(color, 0.24))
	points.append(tip)
	canvas.draw_polyline(points, RED, 2.5, true)
	canvas.draw_polyline(PackedVector2Array([shoulder_b, tip, shoulder_a]), color, 3.0, true)

static func ring(canvas: CanvasItem, center: Vector2, zoom: float, radius: float, angle: float, color: Color, width: float) -> void:
	for segment in G.segments(radius, angle):
		canvas.draw_line(center + segment[0] * zoom, center + segment[1] * zoom, color, width, true)
