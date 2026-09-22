extends "res://tests/test_case.gd"
## 저장과 불러오기: 직렬화 왕복, 옛 저장 호환, 파일 저장

const TEST_SAVE_PATH: String = "user://test_save.json"


func run() -> void:
	Save.save_path = TEST_SAVE_PATH
	_test_roundtrip()
	_test_defaults()
	_test_file()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
	Save.save_path = Save.DEFAULT_SAVE_PATH


func _play_a_bit() -> void:
	_fresh_run()
	Game.gold = 12345.5
	Game.stage = 7
	Game.highest_stage = 10
	Game.kills = 3
	Game.farming = true
	Party.hero_level = 12
	Party.companion_levels[Balance.Companion.WARRIOR] = 5
	Party.companion_levels[Balance.Companion.ARCHER] = 2
	Party.set_buy_mode(Party.BuyMode.TEN)


func _test_roundtrip() -> void:
	_play_a_bit()
	var data := Save.to_dict()
	_equal(data["save_version"], Save.SAVE_VERSION, "save_version이 들어간다")
	_equal(data.has("saved_at"), true, "저장 시각이 들어간다")

	_fresh_run()
	_equal(Game.stage, 1, "초기화 확인")
	Save.from_dict(data)
	_close(Game.gold, 12345.5, "골드 복원")
	_equal(Game.stage, 7, "스테이지 복원")
	_equal(Game.highest_stage, 10, "최고 스테이지 복원")
	_equal(Game.kills, 3, "처치 수 복원")
	_equal(Game.farming, true, "파밍 모드 복원")
	_equal(Party.hero_level, 12, "용사 레벨 복원")
	_equal(Party.companion_levels, [5, 2, 0, 0], "동료 레벨 복원")
	_equal(Party.buy_mode, Party.BuyMode.TEN, "구매 배수 복원")
	_close(Game.monster_max_hp, Balance.monster_hp(7), "불러온 스테이지의 몬스터가 새로 나온다")
	_equal(Game.is_monster_alive(), true, "몬스터가 살아 있다")

	# JSON을 거쳐도 같다 (JSON은 정수를 float으로 돌려준다)
	_fresh_run()
	_equal(Save.apply_json(JSON.stringify(data)), true, "JSON 적용")
	_equal(Game.stage, 7, "JSON을 거친 스테이지")
	_equal(Party.companion_levels, [5, 2, 0, 0], "JSON을 거친 동료 레벨")
	_equal(typeof(Party.companion_levels[0]), TYPE_INT, "레벨은 int로 돌아온다")


func _test_defaults() -> void:
	_play_a_bit()
	Save.from_dict({"save_version": 1})
	_close(Game.gold, 0.0, "필드가 없으면 골드 0")
	_equal(Game.stage, 1, "필드가 없으면 1스테이지")
	_equal(Party.hero_level, 1, "필드가 없으면 용사 1레벨")
	_equal(Party.companion_levels, [0, 0, 0, 0], "필드가 없으면 동료 미고용")
	_equal(Party.buy_mode, Party.BuyMode.ONE, "필드가 없으면 ×1")

	# 동료가 3명이던 옛 저장: 네 번째는 미고용. 이상한 값은 기본값
	Save.from_dict({"save_version": 1, "party": {"companion_levels": [1, 2, 3], "buy_mode": 99},
		"game": {"stage": 0, "highest_stage": -5, "kills": 42}})
	_equal(Party.companion_levels, [1, 2, 3, 0], "모자란 동료는 0으로")
	_equal(Party.buy_mode, Party.BuyMode.MAX, "범위를 벗어난 배수는 잘라낸다")
	_equal(Game.stage, 1, "0스테이지는 1로")
	_equal(Game.highest_stage, 1, "최고 스테이지는 현재 스테이지 이상")
	_equal(Game.kills, 9, "처치 수는 9 이하")

	_equal(Save.apply_json("이건 JSON이 아니다"), false, "깨진 문자열은 거부")
	_equal(Save.apply_json("[1, 2, 3]"), false, "딕셔너리가 아니면 거부")
	_equal(Save.apply_json("{\"gold\": 5}"), false, "save_version이 없으면 거부")
	_equal(Game.stage, 1, "거부하면 상태는 그대로")


func _test_file() -> void:
	_play_a_bit()
	Save.save_game()
	_equal(FileAccess.file_exists(TEST_SAVE_PATH), true, "파일이 생긴다")
	_fresh_run()
	_equal(Save.load_game(), true, "불러오기 성공")
	_equal(Game.stage, 7, "파일에서 스테이지 복원")
	_equal(Party.hero_level, 12, "파일에서 용사 레벨 복원")

	Save.save_path = "user://없는_폴더/없는_파일.json"
	_equal(Save.load_game(), false, "파일이 없으면 false")
	Save.save_path = TEST_SAVE_PATH
