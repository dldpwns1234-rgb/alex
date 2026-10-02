extends "res://tests/test_case.gd"
## 출시 전 버그 점검(2026-10-02)에서 고친 것: 최종 돌파 뒤 탑, 홀로 서기 중 동료 구매·승급, 가져오기의 보스 예약,
## 기기 시계 되돌림(스킬·축복·입장권), 데이터 초기화의 화면 설정


func run() -> void:
	_fresh_run()
	_test_tower_after_clear()
	_test_solo_blocks_companions()
	_test_import_clears_boss_queue()
	_test_clock_rollback()
	_test_reset_data_defaults()
	_fresh_run()


func _test_tower_after_clear() -> void:
	Game.cleared = true
	Game.enter_tower()
	_equal(Game.is_monster_alive(), true, "최종 돌파 뒤에도 탑에는 몬스터가 나온다")
	Game.exit_tower()
	_equal(Game.is_monster_alive(), false, "탑에서 나오면 본편은 돌파 상태 그대로")
	_fresh_run()


func _test_solo_blocks_companions() -> void:
	Game.add_gold(1e30)
	Game.highest_stage = 60
	Party.companion_levels[0] = 60
	var solo := -1
	for i in Balance.CHALLENGES.size():
		if Balance.challenge_restriction(i) == Balance.Restriction.NO_COMPANIONS:
			solo = i
	Challenges.active = solo
	_equal(Party.companion_purchase(0).affordable, false, "홀로 서기 중에는 동료를 살 수 없다고 보인다")
	_equal(Promotions.can_promote(0), false, "홀로 서기 중에는 승급할 수 없다")
	var gold := Game.gold
	_equal(Promotions.promote(0), false, "승급을 눌러도 거절")
	_close(Game.gold, gold, "골드가 나가지 않는다")
	Challenges.active = -1
	_equal(Party.companion_purchase(0).affordable, true, "도전이 끝나면 다시 산다")
	_equal(Promotions.can_promote(0), true, "도전이 끝나면 다시 승급한다")
	_fresh_run()


func _test_import_clears_boss_queue() -> void:
	var data := Save.to_dict()
	Game.boss_queued = true
	Save.from_dict(data)
	_equal(Game.boss_queued, false, "저장을 가져오면 보스 예약이 지워진다")


func _test_clock_rollback() -> void:
	Party.hero_level = 100
	Skills.clock_override = 10000.0
	_equal(Skills.activate(0), true, "스킬 발동")
	Skills.clock_override = 10000.0 - 3600.0  # 기기 시계를 한 시간 되돌림
	_equal(Skills.active_left(0) <= Skills.duration(), true, "되돌려도 지속 시간보다 길게 남지 않는다")
	Skills.clock_override = 10000.0 - 3600.0 + Skills.duration() + 1.0
	_equal(Skills.is_active(0), false, "지속 시간이 지나면 끝난다")
	_equal(Skills.cooldown_left(0) <= Skills.cooldown(), true, "쿨타임도 한 번 길이를 넘지 않는다")
	Skills.clock_override = -1.0
	Treasure.clock_override = 10000.0
	Treasure.blessing_until = 10000.0 + Balance.TREASURE_BLESSING_TIME
	Treasure.clock_override = 10000.0 - 3600.0
	_close(Treasure.blessing_left(), Balance.TREASURE_BLESSING_TIME, "축복도 30초보다 길게 남지 않는다")
	Treasure.blessing_until = 0.0
	Treasure.clock_override = -1.0
	Tower.tickets = 0
	Tower.ticket_date = "2999-01-01"  # 시계를 앞으로 돌려 채운 뒤 되돌린 상태
	Tower.refill_if_new_day()
	_equal(Tower.tickets, 0, "날짜를 되돌려도 입장권이 차지 않는다")
	Tower.ticket_date = "2000-01-01"
	Tower.refill_if_new_day()
	_equal(Tower.tickets, Balance.TOWER_TICKETS_PER_DAY, "날짜가 앞으로 가면 찬다")
	_fresh_run()


func _test_reset_data_defaults() -> void:
	Game.set_auto_retry(false)
	Party.set_buy_mode(Party.BuyMode.MAX)
	Save.reset_data()
	_equal(Game.auto_retry, true, "데이터 초기화로 자동 재도전이 켜진다")
	_equal(Party.buy_mode, Party.BuyMode.ONE, "데이터 초기화로 구매 배수가 ×1")
