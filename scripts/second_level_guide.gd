class_name SecondLevelGuide
extends FirstEventGuide

const SECOND_TEXTS: Dictionary = {
	&"remains_returned": "回收物已送到碎纸机。向前建设时，请保护回收和补给路线。",
	&"nutrition_returned": "创作能量已入账。两侧数位板各有80可回收能量，可支持向AI绘图终端推进。",
	&"facility_destroyed": "这台AI绘图终端已停止生成，已出现的敌人仍会行动。其余终端至少留出20秒整备。",
	&"silk_gnawer": "侵蚀大脑·断线型只直接攻击花径。保护运输路线，及时修复，或连接另一条道路。",
	&"junction_gnawer": "侵蚀大脑·摧花型只直接攻击花朵。保护节点，避免节点受损影响其上的设施。",
	&"swarm": "拼贴面孔正在成群靠近。进入成形阶段后，可把铅笔炮台改装为喷漆炮台，一轮拦截多个目标。",
	&"armored": "重装绘图机的护甲会削减普通和散射伤害。进入成形阶段后，可用橡皮炮台无视护甲的攻击应对。",
}


func record_event(event_id: StringName, _facts: Dictionary = {}) -> void:
	if not SECOND_TEXTS.has(event_id) or _seen.has(event_id):
		return
	_seen[event_id] = true
	_seen_order.append(event_id)
	if is_enabled:
		_pending.append({"id": event_id, "text": String(SECOND_TEXTS[event_id])})
		_show_next()
	_publish()
