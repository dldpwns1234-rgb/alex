extends "res://tests/test_case.gd"
## 장비: 공식과 등급 뽑기, 드롭·장착·분해, 효과 배율, 강화, 저장, 회귀 유지와 초기화, 보스 드롭

var _drops: Array[Array] = []  # item_dropped로 받은 [slot, grade, stage, equipped]


func run() -> void:
	_test_balance()
	_test_drop()
	_test_effects()
	_test_enhance()
	_test_save()
	_test_boss_drops()
	_fresh_run()


func _test_balance() -> void:
	var G := Balance.Grade
	_equal(Balance.roll_grade(0.0), G.COMMON, "0은 일반")
	_equal(Balance.roll_grade(0.49), G.COMMON, "50% 미만은 일반")
	_equal(Balance.roll_grade(0.51), G.FINE, "50%부터 고급")
	_equal(Balance.roll_grade(0.81), G.RARE, "80%부터 희귀")
	_equal(Balance.roll_grade(0.94), G.EPIC, "93%부터 영웅")
	_equal(Balance.roll_grade(0.995), G.LEGENDARY, "99%부터 전설")
	_equal(Balance.roll_grade(1.0), G.LEGENDARY, "1도 전설")
	_equal(Balance.roll_slot(0.0), Balance.Slot.WEAPON, "칸은 균등: 처음은 무기")
	_equal(Balance.roll_slot(0.5), Balance.Slot.BANNER, "가운데는 깃발")
	_equal(Balance.roll_slot(0.99), Balance.Slot.CHARM, "끝은 장신구")
	_close(Balance.item_power(G.COMMON, 100), 0.1, "일반 100스테이지: 5% + 5% = 10%")
	_close(Balance.item_power(G.LEGENDARY, 100), 0.5, "전설은 ×5")
	_close(Balance.item_effect(G.COMMON, 100, 5), 0.15, "강화 +5는 ×1.5")
	_close(Balance.enhance_cost(0), 3.0, "첫 강화 3")
	_close(Balance.enhance_cost(1), 5.0, "2번째 강화: 4.5를 올려 5")
	_close(Balance.enhance_cost(2), 7.0, "3번째 강화: 6.75를 올려 7")
	_close(Balance.dismantle_stones(G.EPIC), 12.0, "영웅 분해 12")
	_equal(Balance.item_name(Balance.Slot.WEAPON, G.LEGENDARY), "성검", "이름 표")
	_equal(Balance.equipment_note(Balance.Slot.CHARM, 0.3), "처치 골드 +30%", "효과 설명")


func _test_drop() -> void:
	_fresh_run()
	Equipment.item_dropped.connect(_on_item_dropped)
	var W: int = Balance.Slot.WEAPON
	var G := Balance.Grade
	_equal(Equipment.has_item(W), false, "처음엔 빈 칸")
	_close(Equipment.click_multiplier(), 1.0, "무기가 없으면 ×1")
	_equal(Equipment.drop(W, G.COMMON, 10), true, "빈 칸이면 장착")
	_equal(Equipment.item_grade(W), G.COMMON, "장착한 등급")
	_equal(Equipment.item_stage(W), 10, "장착한 스테이지")
	_close(Equipment.stones, 0.0, "장착했으니 강화석 없음")
	_equal(_drops.back(), [W, G.COMMON, 10, true], "알림: 장착")
	_equal(Equipment.drop(W, G.COMMON, 5), false, "더 약한 장비는 분해")
	_close(Equipment.stones, 1.0, "일반 분해 강화석 1")
	_equal(Equipment.item_stage(W), 10, "장비는 그대로")
	_equal(_drops.back(), [W, G.COMMON, 5, false], "알림: 분해")
	_equal(Equipment.drop(W, G.RARE, 5), true, "희귀 5스테이지(×2 × 5.25%)가 일반 10스테이지(5.5%)보다 좋다")
	_close(Equipment.stones, 2.0, "옛 일반 장비를 분해해 +1")
	_equal(Equipment.drop(W, G.RARE, 5), true, "같은 것이 오면 새것으로 바꾼다")
	_close(Equipment.stones, 7.0, "옛 희귀 장비 분해 +5")
	Equipment.item_dropped.disconnect(_on_item_dropped)


func _test_effects() -> void:
	_fresh_run()
	var G := Balance.Grade
	Party.hero_level = 10
	Party.companion_levels[Balance.Companion.WARRIOR] = 1
	_close(Party.click_damage(), 20.0, "장비 전 클릭 피해 20")
	Equipment.drop(Balance.Slot.WEAPON, G.COMMON, 100)
	_close(Party.click_damage(), 22.0, "무기(일반 100스테이지): 클릭 피해 +10%")
	_close(Party.party_dps(false), 3.0, "무기는 동료에 영향 없음")
	Equipment.drop(Balance.Slot.BANNER, G.FINE, 100)
	_close(Party.party_dps(false), 3.45, "깃발(고급 100스테이지 15%): 동료 ×1.15")
	_close(Party.companion_dps(Balance.Companion.WARRIOR, false), 3.45, "연출용 DPS도")
	_close(Party.click_damage(), 22.0, "각성이 없으면 깃발은 클릭에 영향 없음")
	Equipment.drop(Balance.Slot.CHARM, G.COMMON, 50)
	_close(Equipment.gold_multiplier(), 1.075, "장신구(일반 50스테이지): 처치 골드 +7.5%")
	var before := Game.gold
	Game._damage_monster(Game.monster_max_hp)
	_close(Game.gold, before + Balance.kill_gold(10.0) * 1.075, "처치 골드에 장신구")
	before = Game.gold
	Save.grant_offline(100.0)
	var per_second := Balance.offline_gold_per_second(1, 3.45) * 1.075
	_close(Game.gold, before + per_second * 100.0 * 0.5, "오프라인 보상에 깃발과 장신구")


func _test_enhance() -> void:
	_fresh_run()
	var W: int = Balance.Slot.WEAPON
	var G := Balance.Grade
	_equal(Equipment.can_enhance(W), false, "빈 칸은 강화 불가")
	Equipment.drop(W, G.COMMON, 100)
	_close(Equipment.enhance_cost(W), 3.0, "첫 강화 비용 3")
	_equal(Equipment.enhance(W), false, "강화석이 없으면 못 한다")
	Equipment.stones = 3.0
	_equal(Equipment.any_enhanceable(), true, "강화할 수 있는 칸이 있다")
	_equal(Equipment.enhance(W), true, "강화")
	_equal(Equipment.enhance_levels[W], 1, "강화 +1")
	_close(Equipment.stones, 0.0, "강화석을 냈다")
	_close(Equipment.effect(W), 0.11, "강화 +1: 10% × 1.1")
	Equipment.stones = 1e6
	for i in 9:
		_equal(Equipment.enhance(W), true, "강화 +%d" % (i + 2))
	_equal(Equipment.is_enhance_maxed(W), true, "강화 최대 10")
	_equal(Equipment.enhance(W), false, "최대면 못 한다")
	_close(Equipment.effect(W), 0.2, "강화 +10: ×2")
	_equal(Equipment.drop(W, G.LEGENDARY, 100), true, "전설 장착")
	_close(Equipment.effect(W), 1.0, "강화는 칸에 남아 새 장비에도 이어진다 (50% × 2)")


func _test_save() -> void:
	_fresh_run()
	var W: int = Balance.Slot.WEAPON
	var G := Balance.Grade
	Equipment.drop(W, G.EPIC, 120)
	Equipment.stones = 7.0
	Equipment.enhance_levels[W] = 2
	var data := Save.to_dict()
	_equal(data.has("equipment"), true, "저장 데이터에 장비가 들어간다")
	_fresh_run()
	_equal(Equipment.has_item(W), false, "초기화 확인")
	Save.from_dict(data)
	_equal(Equipment.item_grade(W), G.EPIC, "등급 복원")
	_equal(Equipment.item_stage(W), 120, "스테이지 복원")
	_equal(Equipment.enhance_levels[W], 2, "강화 복원")
	_close(Equipment.stones, 7.0, "강화석 복원")
	_equal(Equipment.has_item(Balance.Slot.CHARM), false, "빈 칸은 그대로 비어 있다")
	_equal(Save.apply_json(JSON.stringify(data)), true, "JSON 적용")
	_equal(Equipment.item_stage(W), 120, "JSON을 거친 스테이지")
	_equal(typeof(Equipment.enhance_levels[W]), TYPE_INT, "강화 레벨은 int로 돌아온다")
	Save.from_dict({"save_version": 1})
	_equal(Equipment.has_item(W), false, "필드가 없으면 빈 칸")
	_close(Equipment.stones, 0.0, "필드가 없으면 강화석 0")
	Save.from_dict({"save_version": 1, "equipment": {"slots": [{"grade": 99, "stage": -3}, {}], "enhance": [42], "stones": -5}})
	_equal(Equipment.item_grade(W), G.LEGENDARY, "등급은 상한으로 잘라낸다")
	_equal(Equipment.item_stage(W), 1, "스테이지는 1 이상")
	_equal(Equipment.has_item(Balance.Slot.BANNER), false, "빈 딕셔너리는 빈 칸")
	_equal(Equipment.enhance_levels[W], Balance.ENHANCE_MAX, "강화는 최대로 잘라낸다")
	_close(Equipment.stones, 0.0, "음수 강화석은 0")

	_fresh_run()
	Equipment.drop(W, G.RARE, 60)
	Game.highest_stage = 120
	_equal(Prestige.perform(), true, "회귀")
	_equal(Equipment.item_grade(W), G.RARE, "회귀해도 장비는 남는다")
	Save.reset_data()
	_equal(Equipment.has_item(W), false, "데이터 초기화는 지운다")


func _test_boss_drops() -> void:
	_fresh_run()
	Equipment.random_drops = true
	Equipment.item_dropped.connect(_on_item_dropped)
	_drops.clear()
	for i in 60:
		Game.stage = 5
		Game.highest_stage = 5
		Game._spawn_monster()
		Game._damage_monster(Game.monster_max_hp)
	_equal(_drops.size() > 0, true, "보스 60마리면 거의 확실히 떨어진다 (35%)")
	_equal(_drops.size() < 60, true, "매번 떨어지지는 않는다")
	for record in _drops:
		if int(record[2]) != 5:
			failed += 1
			push_error("떨어진 스테이지는 보스 스테이지여야 한다: %s" % [record])
	_drops.clear()
	for i in 60:
		Game.stage = 1  # 10마리마다 스테이지가 오르므로 보스 스테이지에 닿지 않게 되돌린다
		Game.kills = 0
		Game._spawn_monster()
		Game._damage_monster(Game.monster_max_hp)
	_equal(_drops.size(), 0, "일반 몬스터는 장비를 떨어뜨리지 않는다")
	Equipment.item_dropped.disconnect(_on_item_dropped)
	Equipment.random_drops = false


func _on_item_dropped(slot: int, grade: int, stage: int, equipped: bool) -> void:
	_drops.append([slot, grade, stage, equipped])
