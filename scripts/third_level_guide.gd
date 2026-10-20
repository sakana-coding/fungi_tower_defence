class_name ThirdLevelGuide
extends SecondLevelGuide

const THIRD_TEXTS: Dictionary = {
	&"opening": "三个角落的记忆碎片从开局可见。让与小画家连通的花海覆盖目标，累计收集5秒；顺序不限，也可双线探索。",
	&"nutrition_returned": "餐食补给已送回小画家。四处公文包分别提供80、80、80和120可回收能量，可先接资源再探索。",
	&"fragment_collected": "碎片已永久保留，断路不会丢失；未完成目标失联时暂停计时，接通后继续。",
	&"armored": "重装绘图机的护甲会削减普通伤害。可先把前沿铅笔炮台改装为橡皮炮台，再继续建设；改装期间炮台停火。",
}


func record_event(event_id: StringName, facts: Dictionary = {}) -> void:
	if not THIRD_TEXTS.has(event_id):
		super.record_event(event_id, facts)
		return
	if _seen.has(event_id):
		return
	_seen[event_id] = true
	_seen_order.append(event_id)
	if is_enabled:
		_pending.append({"id": event_id, "text": String(THIRD_TEXTS[event_id])})
		_show_next()
	_publish()
