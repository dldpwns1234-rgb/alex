extends "res://tests/test_case.gd"
## 오프라인 보상: 공식, 공백 감지, 불러올 때의 보상, 시간 표기

const TEST_SAVE_PATH: String = "user://test_offline.json"

var _received: Array = []


func run() -> void:
	var previous_path := Save.save_path
	Save.save_path = TEST_SAVE_PATH
	Save.offline_reward.connect(_on_offline_reward)
	_test_formulas()
	await _test_grant()
	await _test_load_grants()
	_test_duration()
	Save.offline_reward.disconnect(_on_offline_reward)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
	Save.save_path = previous_path


func _on_offline_reward(seconds: float, gold: float) -> void:
	_received.append([seconds, gold])


func _test_formulas() -> void:
	_equal(Balance.offline_stage(6), 6, "일반 스테이지는 그대로")
	_equal(Balance.offline_stage(5), 4, "보스 스테이지면 직전 스테이지")
	_close(Balance.offline_gold_per_second(3, 0.0), 0.0, "동료가 없으면 0")
	var hp := Balance.monster_hp(3)
	_close(Balance.offline_gold_per_second(3, 10.0), Balance.kill_gold(hp) / (hp / 10.0 + 0.3), "초당 골드")
	_close(Balance.offline_reward(2.0, 100.0, 0), 100.0, "초당 2 × 100초 × 0.5")
	_close(Balance.offline_reward(2.0, 100.0, 3), 160.0, "단잠 3레벨은 0.8배")
	_close(Balance.offline_reward(1.0, 13.0 * 3600.0, 0), 12.0 * 3600.0 * 0.5, "12시간까지만 인정")


func _test_grant() -> void:
	_fresh_run()
	Party.companion_levels[Balance.Companion.WARRIOR] = 1  # DPS 3
	_received.clear()
	Save.grant_offline(5.0)
	_close(Game.gold, 0.0, "10초 미만 공백은 보상이 없다")

	var expected := Balance.offline_reward(Balance.offline_gold_per_second(1, 3.0), 100.0, 0)
	Save.grant_offline(100.0)
	_close(Game.gold, expected, "100초 공백의 보상")
	_equal(Game.stage, 1, "스테이지는 진행하지 않는다")

	Party.companion_levels[Balance.Companion.WARRIOR] = 0
	Save.grant_offline(100.0)
	_close(Game.gold, expected, "동료가 없으면 골드가 늘지 않는다")

	# 시그널은 프레임 끝에 온다. 5초 공백은 빼고 100초 두 번
	await get_tree().process_frame
	_equal(_received.size(), 2, "보상 시그널 두 번")
	if _received.size() == 2:
		_close(_received[0][0], 100.0, "인정된 시간 100초")
		_close(_received[0][1], expected, "받은 골드")
		_close(_received[1][1], 0.0, "동료가 없으면 골드 0으로 알린다")


## 마지막 저장 시각이 오래전이면 불러올 때 보상을 준다. 시그널은 프레임 끝에 오므로 한 프레임 기다린다
func _test_load_grants() -> void:
	_fresh_run()
	Party.companion_levels[Balance.Companion.WARRIOR] = 1
	Game.gold = 50.0
	var data := Save.to_dict()
	data["saved_at"] = Time.get_unix_time_from_system() - 1000.0
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

	_fresh_run()
	_received.clear()
	_equal(Save.load_game(), true, "불러오기")
	await get_tree().process_frame
	_equal(_received.size(), 1, "보상 시그널이 한 번 온다")
	if _received.size() == 1:
		# 저장 시각을 적고 불러올 때까지 흐른 실제 시간(느린 러너에서는 1초 넘게)이 그대로 인정되므로,
		# 기대값은 1000초가 아니라 인정된 시간으로 계산한다
		var seconds: float = _received[0][0]
		_equal(seconds >= 1000.0 and seconds < 1010.0, true, "인정된 시간 약 1000초")
		var expected := 50.0 + Balance.offline_reward(Balance.offline_gold_per_second(1, 3.0), seconds, 0)
		_close(Game.gold, expected, "저장 골드 + 인정된 시간의 보상")

	# 가져오기는 보상을 주지 않는다
	_fresh_run()
	_received.clear()
	var exported := Marshalls.utf8_to_base64(JSON.stringify(data))
	_equal(Save.import_string(exported), true, "가져오기")
	_close(Game.gold, 50.0, "가져온 골드 그대로")


func _test_duration() -> void:
	_equal(Num.format_duration(0.0), "0초", "0초")
	_equal(Num.format_duration(59.9), "59초", "59초")
	_equal(Num.format_duration(61.0), "1분 1초", "1분 1초")
	_equal(Num.format_duration(3600.0), "1시간", "1시간")
	_equal(Num.format_duration(3725.0), "1시간 2분 5초", "1시간 2분 5초")
	_equal(Num.format_duration(43200.0), "12시간", "12시간")
