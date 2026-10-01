extends "res://tests/test_case.gd"
## 보물 요정 (GDD 3.5절): 60~120초마다 8초 동안 날고, 잡으면 골드·스킬 쿨타임 초기화·보물의 축복 중 하나. 탑 안에서는 나오지 않는다

var _appeared: int = 0
var _escaped: int = 0
var _caught: Array[Array] = []  # caught로 받은 [reward, amount]


func run() -> void:
	_fresh_run()
	Treasure.appeared.connect(func(_d: float) -> void: _appeared += 1)
	Treasure.escaped.connect(func() -> void: _escaped += 1)
	Treasure.caught.connect(func(r: int, a: float) -> void: _caught.append([r, a]))
	Treasure.clock_override = 1000.0
	Skills.clock_override = 1000.0
	_test_schedule()
	_test_rewards()
	_test_tower()
	_test_save()
	Treasure.clock_override = -1.0
	Skills.clock_override = -1.0
	_fresh_run()


func _test_schedule() -> void:
	var first := Treasure.next_in
	_equal(first >= Balance.TREASURE_INTERVAL_MIN and first <= Balance.TREASURE_INTERVAL_MAX, true, "첫 등장은 60~120초 뒤")
	_equal(Treasure.catch(), false, "날지 않을 때는 못 잡는다")
	Treasure.tick(first - 0.1)
	_equal(Treasure.flying, false, "시간 전에는 안 나온다")
	Treasure.tick(0.2)
	_equal(Treasure.flying, true, "시간이 되면 나온다")
	_equal(_appeared, 1, "등장 알림")
	Treasure.tick(Balance.TREASURE_FLIGHT_TIME + 0.1)
	_equal(Treasure.flying, false, "8초 뒤 달아난다")
	_equal(_escaped, 1, "달아남 알림")
	_equal(Treasure.next_in >= Balance.TREASURE_INTERVAL_MIN, true, "다음 등장을 다시 잡는다")


func _test_rewards() -> void:
	Game.stage = 21
	var seen := {}
	for i in 60:
		_fly()
		var gold_before := Game.gold
		_equal(Treasure.catch(), true, "날 때는 잡힌다")
		var got: Array = _caught.back()
		seen[got[0]] = true
		if got[0] == Treasure.Reward.GOLD:
			_close(got[1], Balance.TREASURE_GOLD_KILLS * Balance.kill_gold(Balance.monster_hp(21)) * Game.gold_multiplier(), "골드 = 일반 몬스터 30마리 몫")
			_close(Game.gold - gold_before, got[1], "골드를 받는다")
	_equal(seen.has(Treasure.Reward.COOLDOWN), false, "쿨타임 중인 스킬이 없으면 초기화는 안 나온다")
	_equal(seen.has(Treasure.Reward.GOLD) and seen.has(Treasure.Reward.BLESSING), true, "골드와 축복은 나온다")

	# 축복: 30초 처치 골드 ×2
	Treasure.blessing_until = 0.0
	_equal(Treasure.gold_multiplier(), 1.0, "축복 없으면 ×1")
	while Treasure.blessing_left() <= 0.0:
		_fly()
		Treasure.catch()
	_close(Treasure.blessing_left(), Balance.TREASURE_BLESSING_TIME, "축복 30초")
	_equal(Treasure.gold_multiplier(), Balance.TREASURE_BLESSING_MULTIPLIER, "축복 중 ×2")
	Game.stage = 1
	Game.kills = 0
	Game._spawn_monster()
	var before := Game.gold
	Game._damage_monster(Game.monster_max_hp)
	_close(Game.gold - before, Balance.kill_gold(Game.monster_max_hp) * Game.gold_multiplier() * 2.0, "축복 중 처치 골드 ×2")
	Treasure.clock_override = 1000.0 + Balance.TREASURE_BLESSING_TIME + 1.0
	_equal(Treasure.gold_multiplier(), 1.0, "30초 뒤 끝난다")
	Treasure.clock_override = 1000.0

	# 초기화: 쿨타임 중인 스킬이 있으면 후보에 든다. 발동 중인 스킬은 그대로
	Party.hero_level = 50
	Skills.activate(Balance.Skill.STORM_SLASH)
	Skills.clock_override = 1000.0 + Skills.duration() + 1.0  # 지속은 끝나고 쿨타임 중
	Skills.activate(Balance.Skill.BATTLE_CRY)                  # 발동 중
	_equal(Skills.has_cooldown(), true, "쿨타임 중인 스킬이 있다")
	var tries := 0
	while Skills.has_cooldown() and tries < 200:
		_fly()
		Treasure.catch()
		tries += 1
	_equal(_caught.back()[0], Treasure.Reward.COOLDOWN, "초기화가 나온다")
	_equal(Skills.is_ready(Balance.Skill.STORM_SLASH), true, "쿨타임 중이던 스킬은 바로 쓸 수 있다")
	_equal(Skills.is_active(Balance.Skill.BATTLE_CRY), true, "발동 중인 스킬은 그대로")
	Skills.clock_override = 1000.0
	Skills.reset()


func _test_tower() -> void:
	_fly()
	Game.in_tower = true
	Treasure.tick(0.1)
	_equal(Treasure.flying, false, "탑에 들어가면 날던 요정이 사라진다")
	Treasure.tick(Balance.TREASURE_INTERVAL_MAX + 1.0)
	_equal(Treasure.flying, false, "탑 안에서는 안 나온다")
	Game.in_tower = false


func _test_save() -> void:
	Treasure.blessing_until = 1010.0
	var data := Save.to_dict()
	Treasure.reset()
	_equal(Treasure.blessing_until, 0.0, "초기화하면 축복도 지운다")
	Save.from_dict(data)
	_close(Treasure.blessing_left(), 10.0, "불러오면 남은 축복이 이어진다")
	Save.from_dict({})
	_equal(Treasure.blessing_until, 0.0, "옛 저장은 축복 없음")


func _fly() -> void:
	Treasure.tick(Treasure.next_in + 0.01)
