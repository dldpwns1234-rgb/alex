extends "res://tests/test_case.gd"
## 단련 효과가 각 공식에 실제로 붙는지. 인덱스는 Balance.TRAININGS 순서 (GDD 6.5절 표)

const W: int = 0  # Companion.WARRIOR
const A: int = 1
const M: int = 2
const C: int = 3
var _crits: int = 0
var _hits: int = 0
var _crit_amount: float = 0.0


func run() -> void:
	_test_damage()
	_test_gold_and_flow()
	_test_skills_and_offline()
	_test_click_crit()


func _test_damage() -> void:
	_fresh_run()
	Party.hero_level = 10
	Party.companion_levels[W] = 1
	_close(Party.click_damage(), 20.0, "기본 클릭 20")
	Training.levels[0] = 3  # 연격
	_close(Party.click_damage(), 26.0, "연격 3레벨: 클릭 ×1.3")
	Training.levels[5] = 2  # 굳건함
	_close(Party.party_dps(false), 4.2, "굳건함 2레벨: 전사 ×1.4")
	_close(Party.companion_dps(W, false), 4.2, "연출용 DPS도 ×1.4")
	Training.levels[3] = 2  # 지휘
	_close(Party.party_dps(false), 4.2 * 1.1, "지휘 2레벨: 동료 전체 ×1.1")
	Training.levels[7] = 3  # 방패 강타
	_close(Party.party_dps(false), 4.2 * 1.1, "일반 몬스터에는 방패 강타 없음")
	_close(Party.party_dps(true), 4.2 * 1.1 * 1.3, "보스에게 동료 ×1.3")
	Game.stage = 5
	Game.highest_stage = 5
	Game._spawn_monster()
	_close(Party.click_damage(), 26.0 * 1.3, "보스에게 클릭도 ×1.3")

	_fresh_run()
	Party.companion_levels[A] = 1
	Party.companion_levels[M] = 1
	Party.companion_levels[C] = 1
	Training.levels[10] = 5  # 정밀 사격: 치명타 20%
	Training.levels[13] = 2  # 관통: 배율 6
	Training.levels[17] = 1  # 대마법: 보스 배율 3.4
	Training.levels[20] = 5  # 축복: 버프 3%/레벨
	var archer := 16.0 * (1.0 + 0.2 * 5.0)
	_close(Party.party_dps(false), (archer + 110.0 + 200.0) * 1.03, "궁수 치명타·성직자 버프 반영")
	_close(Party.party_dps(true), (archer + 110.0 * 3.4 + 200.0) * 1.03, "마법사 보스 배율 반영")


func _test_gold_and_flow() -> void:
	_fresh_run()
	Training.levels[2] = 2   # 전리품 감각 +10%
	Training.levels[11] = 2  # 황금 화살 +10%
	var before := Game.gold
	Game._damage_monster(Game.monster_max_hp)
	_close(Game.gold, before + Balance.kill_gold(10.0) * 1.2, "처치 골드 +20% (두 단련의 합)")
	_close(Game.respawn_left, 0.3, "재등장 0.3초")
	Training.levels[6] = 5   # 도발
	_close(Game.respawn_delay(), 0.2, "도발 5레벨: 재등장 0.2초")
	_advance(0.5)
	Game._damage_monster(Game.monster_max_hp)
	_close(Game.respawn_left, 0.2, "처치 뒤 대기 0.2초")

	Training.levels[15] = 2  # 화염 폭발
	Training.levels[21] = 1  # 헌금 +20%
	Game.stage = 5
	Game.highest_stage = 5
	Game._spawn_monster()
	_close(Game.boss_time_left, 32.0, "화염 폭발 2레벨: 보스 32초")
	before = Game.gold
	Game._damage_monster(Game.monster_max_hp)
	_close(Game.gold, before + Balance.kill_gold(Balance.boss_hp(5)) * 1.2 * 1.2, "보스 골드에 헌금까지")


func _test_skills_and_offline() -> void:
	_fresh_run()
	Party.hero_level = 100
	Training.levels[4] = 1   # 각성의 잔향 +2초
	Training.levels[16] = 5  # 마나 순환 −20%
	Training.levels[19] = 2  # 시간 왜곡 +2회
	Training.levels[8] = 1   # 함성 공명 +0.2
	Training.levels[24] = 1  # 기적 +0.2
	_close(Skills.duration(), 32.0, "지속 32초")
	_close(Skills.cooldown(), 240.0, "쿨타임 4분")
	Skills.activate(Balance.Skill.BATTLE_CRY)
	_close(Skills.party_multiplier(), 2.2, "함성 ×2.2")
	Skills.activate(Balance.Skill.GOLDEN_TOUCH)
	_close(Skills.gold_multiplier(), 2.2, "황금 손길 ×2.2")
	Skills.activate(Balance.Skill.STORM_SLASH)
	Game.stage = 50
	Game.highest_stage = 50
	Game._spawn_monster()
	var start := Game.monster_hp
	for i in 4:
		Skills._process(0.25)
	_close(Game.monster_hp, start - 12.0 * Party.click_damage(), "1초에 12회 자동 클릭")

	_fresh_run()
	Party.companion_levels[W] = 1
	Training.levels[22] = 5  # 안식 +20%p
	Training.levels[2] = 2   # 전리품 감각 +10%
	var before := Game.gold
	Save.grant_offline(100.0)
	var per_second := Balance.offline_gold_per_second(1, 3.0) * 1.1
	_close(Game.gold, before + per_second * 100.0 * 0.7, "오프라인 0.7배, 전리품 반영")


func _on_tap_hit(amount: float, crit: bool) -> void:
	_hits += 1
	if crit:
		_crits += 1
		_crit_amount = amount


func _test_click_crit() -> void:
	_fresh_run()
	Game.tap_hit.connect(_on_tap_hit)
	Game.stage = 100
	Game.highest_stage = 100
	Game._spawn_monster()
	for i in 50:
		Game.tap_attack()
	_equal(_crits, 0, "치명타 단련이 없으면 치명타도 없다")
	Training.levels[1] = 10  # 급소 찌르기 20%
	Training.levels[14] = 10  # 매의 눈 10%
	_close(Training.value(Balance.Effect.CLICK_CRIT), 0.3, "클릭 치명타 확률 30%")
	_crits = 0
	_hits = 0
	for i in 300:
		Game.tap_attack()
	_equal(_hits, 300, "300번 탭")
	_equal(_crits > 20 and _crits < 160, true, "치명타가 확률만큼 나온다 (%d/300)" % _crits)
	_close(_crit_amount, Party.click_damage() * 3.0, "치명타 피해는 ×3")
	Game.tap_hit.disconnect(_on_tap_hit)
