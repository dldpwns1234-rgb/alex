extends Node
## 헤드리스 테스트 러너.
##
##   godot --headless --path . res://tests/run_tests.tscn
##
## 메인 씬 대신 이 씬을 띄우면 오토로드(Balance, Num, Prestige, Rebirth, Party, Skills, Training, Promotions, Game, Achievements, Equipment, Automation, Challenges, Save)가 그대로 뜬다.
## --script 모드는 오토로드를 띄우지 않아 Game이 컴파일되지 않으므로 쓰지 않는다.
## 실패하면 종료 코드 1을 돌려준다. 테스트 안의 SCRIPT ERROR는 종료 코드에 잡히지 않으므로 CI가 로그를 grep한다.

## 테스트 중 저장은 전부 이 파일로 간다. 실제 저장 파일을 건드리면 다음 실행의 시작 상태가 오염된다
const TEST_SAVE_PATH: String = "user://test_run.json"

const SUITES: Array[GDScript] = [
	preload("res://tests/test_formulas.gd"),
	preload("res://tests/test_game.gd"),
	preload("res://tests/test_boss.gd"),
	preload("res://tests/test_save.gd"),
	preload("res://tests/test_offline.gd"),
	preload("res://tests/test_skills.gd"),
	preload("res://tests/test_prestige.gd"),
	preload("res://tests/test_training.gd"),
	preload("res://tests/test_training_effects.gd"),
	preload("res://tests/test_promotions.gd"),
	preload("res://tests/test_equipment.gd"),
	preload("res://tests/test_rebirth.gd"),
	preload("res://tests/test_automation.gd"),
	preload("res://tests/test_achievements.gd"),
	preload("res://tests/test_tap_scroll.gd"),
	preload("res://tests/test_zones.gd"),
	preload("res://tests/test_castle.gd"),
	preload("res://tests/test_challenges.gd"),
]


func _ready() -> void:
	print("")
	print("=== 회귀 용사 키우기 테스트 ===")
	Save.save_path = TEST_SAVE_PATH
	await get_tree().process_frame  # 시작할 때 불러온 저장이 남긴 지연 시그널을 흘려보낸다
	var passed := 0
	var failed := 0
	for suite_script in SUITES:
		var suite: Node = suite_script.new()
		add_child(suite)
		await suite.run()  # 프레임을 기다리는 스위트가 있다
		passed += suite.passed
		failed += suite.failed
	Save.blocked = true  # 종료 직전의 자동 저장이나 오프라인 보상 저장이 파일을 다시 만들지 않도록
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
	print("")
	print("통과 %d · 실패 %d" % [passed, failed])
	print("")
	get_tree().quit(1 if failed > 0 else 0)
