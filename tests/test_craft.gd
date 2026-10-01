extends "res://tests/test_case.gd"
## 장비 제작 (GDD 7.6절): 강화석 10개로 고른 칸의 장비를 지금 스테이지로 만든다. 드롭과 같은 장착·분해 규칙, 알림, 부족하면 안 된다

var _crafted: Array[Array] = []  # item_crafted로 받은 [slot, grade, stage, equipped]


func run() -> void:
	_fresh_run()
	Equipment.item_crafted.connect(_on_item_crafted)
	var W: int = Balance.Slot.WEAPON
	var G := Balance.Grade
	Game.stage = 300
	_close(Balance.CRAFT_COST, 10.0, "제작 비용 10")
	Equipment.stones = 9.0
	_equal(Equipment.can_craft(), false, "9개로는 못 만든다")
	_equal(Equipment.craft(W, 0.0), false, "모자라면 false")
	_equal(Equipment.has_item(W), false, "칸은 비어 있다")
	_equal(_crafted.is_empty(), true, "알림도 없다")
	Equipment.stones = 25.0
	_equal(Equipment.craft(W, 0.0), true, "빈 칸에 일반 장비 제작 → 장착")
	_equal(Equipment.item_grade(W), G.COMMON, "굴린 등급 (0 → 일반)")
	_equal(Equipment.item_stage(W), 300, "지금 스테이지의 장비")
	_close(Equipment.stones, 15.0, "비용 10")
	_equal(_crafted.back(), [W, G.COMMON, 300, true], "알림: 제작·장착")
	_equal(Equipment.craft(W, 0.995), true, "전설이 나오면 갈아입는다")
	_equal(Equipment.item_grade(W), G.LEGENDARY, "전설 장착")
	_close(Equipment.stones, 6.0, "비용 10, 옛 일반 분해 +1")
	_equal(Equipment.craft(W, 0.0), false, "6개로는 못 만든다")
	Equipment.stones = 10.0
	_equal(Equipment.craft(W, 0.0), false, "일반이 나오면 분해")
	_equal(Equipment.item_grade(W), G.LEGENDARY, "전설은 그대로")
	_close(Equipment.stones, 1.0, "비용 10, 새 일반 분해 +1")
	_equal(_crafted.back(), [W, G.COMMON, 300, false], "알림: 제작·분해")
	Game.stage = 350
	Equipment.stones = 10.0
	_equal(Equipment.craft(W, 0.995), true, "스테이지가 오르면 같은 등급도 더 좋다")
	_equal(Equipment.item_stage(W), 350, "새 스테이지")
	_close(Equipment.stones, 30.0, "옛 전설 분해 +30")
	Equipment.stones = 10.0
	Equipment.craft(Balance.Slot.CHARM)
	var grade := _crafted.back()[1] as int
	_equal(grade >= G.COMMON and grade <= G.LEGENDARY, true, "굴림 값을 안 주면 무작위 등급")
	_equal(Equipment.item_stage(Balance.Slot.CHARM), 350, "빈 장신구 칸이 채워진다")
	_equal(Equipment.enhance_levels[W], 0, "제작은 강화 레벨을 건드리지 않는다")
	Equipment.item_crafted.disconnect(_on_item_crafted)
	_fresh_run()


func _on_item_crafted(slot: int, grade: int, stage: int, equipped: bool) -> void:
	_crafted.append([slot, grade, stage, equipped])
