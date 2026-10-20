class_name MapBoundary
extends Node2D
## 只标出已有的可生长范围；不改变寻路、放置判定或地图尺寸。

@export var buildable_bounds: Rect2

@onready var caption: Label = $Caption

var _placing: bool = false


func configure(bounds: Rect2) -> void:
	buildable_bounds = bounds.abs()
	# 左下留白不与顶部目标、入口标签或居中的建造卡片争位置。
	caption.position = Vector2(buildable_bounds.position.x + 12, buildable_bounds.end.y + 8)
	visible = buildable_bounds.has_area()
	queue_redraw()


func set_placement_active(active: bool) -> void:
	if _placing == active:
		return
	_placing = active
	caption.visible = active
	queue_redraw()


func _draw() -> void:
	if not buildable_bounds.has_area():
		return
	var ink := Color(0.40, 0.40, 0.32, 0.48 if _placing else 0.24)
	var corners := PackedVector2Array([
		buildable_bounds.position,
		Vector2(buildable_bounds.end.x, buildable_bounds.position.y),
		buildable_bounds.end,
		Vector2(buildable_bounds.position.x, buildable_bounds.end.y),
	])
	for side: int in range(4):
		_draw_pencil_dashes(corners[side], corners[(side + 1) % 4], ink)


func _draw_pencil_dashes(start: Vector2, end: Vector2, ink: Color) -> void:
	var direction := (end - start).normalized()
	var normal := Vector2(-direction.y, direction.x)
	var length: float = start.distance_to(end)
	var offset: float = 0.0
	while offset < length:
		# 轻微的固定笔触偏差，让边界融入纸面；不随时间抖动。
		var points := PackedVector2Array()
		for fraction: float in [0.0, 0.5, 1.0]:
			var along: float = minf(offset + 11.0 * fraction, length)
			points.append(start + direction * along + normal * sin(along * 0.037) * 0.65)
		draw_polyline(points, ink, 1.25, true)
		offset += 20.0
