class_name GameplayCopy
extends RefCounted
## 玩家文案只解释现有对象；内部类型、资源账目和关卡规则继续使用原有标识。

const WORLD_GUIDE: String = "小画家：接收回收补给，为建设与战斗提供创作能量。生命耗尽时，本次挑战结束。\n花朵：连接花径，每朵可承载一座炮台或回收碎纸机。\n花径：运输补给与回收物；断裂会影响补给和回收。\n花海：与小画家保持连通的有效覆盖区域，可收集范围内的回收物。失联残影不提供有效覆盖。"
const FACILITY_GUIDE: String = "铅笔炮台：发射铅芯弹攻击单个目标，每轮消耗1创作能量。\n橡皮炮台：发射橡皮弹，本次伤害无视护甲，每轮消耗2创作能量。\n喷漆炮台：向前方散射，每轮最多攻击3个不同目标，整轮消耗1创作能量。\n回收碎纸机：加工回收物并送出补给；补给抵达小画家后才增加可用创作能量。"
const SHEEP_GUIDE: String = "涂鸦羊：向小画家逼近，也会攻击附近的前沿设施。\n小涂鸦羊：体型小、移动快，成群出现，适合用喷漆炮台拦截。\n重甲花羊：身披花饰，移动较慢，护甲抵挡部分伤害；可用橡皮炮台应对。\n啃食花羊：优先啃咬附近的花径与花朵，没有合适目标时继续逼近小画家。"
const AI_GUIDE: String = "监视者：带着红色镜头逼近防线的摄像头，在近距离发动攻击。\n拼贴面孔：图像与电路拼成的面孔，行动迅速，成群涌来。\n重装绘图机：装甲厚重、推进缓慢，适合用橡皮炮台集中应对。\n侵蚀大脑·断线型：只直接攻击花径，威胁运输路线。\n侵蚀大脑·摧花型：只直接攻击花朵，威胁节点及其设施。"
const TERMINAL_GUIDE: String = "AI 绘图终端：持续生成敌人的固定目标。摧毁后永久停止该终端的后续生成，已出现的敌人仍会行动。"
const RESOURCE_NAMES: Array[String] = ["破旧画架", "破损数位板", "公文包"]
const RESOURCE_GUIDES: Array[String] = [
	"破旧画架与画纸残片提供有限的回收材料；蜡笔补给沿花径运输。废纸团会阻挡通行。",
	"破损数位板、电子残片与损坏摄像头提供回收材料；能量补给沿花径运输。草稿堆会阻挡通行。",
	"公文包与电子回收物支持探索和防守；餐食补给沿花径运输。咖啡杯堆会阻挡通行。",
]
const TISSUE_NAMES: Dictionary = {
	&"菌结": "花朵", &"菌丝": "花径", &"胃囊": "回收碎纸机",
	&"攻击器官": "文具炮台", &"母核": "小画家", &"幼芽": "设施花苞", &"尖端": "延伸花苞",
}


static func resource_name(chapter: int) -> String:
	return RESOURCE_NAMES[clampi(chapter - 1, 0, RESOURCE_NAMES.size() - 1)]


static func resource_guide(chapter: int) -> String:
	return RESOURCE_GUIDES[clampi(chapter - 1, 0, RESOURCE_GUIDES.size() - 1)]


static func enemy_guide(chapter: int) -> String:
	return SHEEP_GUIDE if chapter == 1 else AI_GUIDE


static func tissue_name(kind: StringName) -> String:
	return String(TISSUE_NAMES.get(kind, String(kind)))
