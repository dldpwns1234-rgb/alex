extends Node
## 헤드리스 테스트 러너.
##
##   godot --headless --path . res://tests/run_tests.tscn
##
## 메인 씬 대신 이 씬을 띄우면 오토로드(Balance, Num, Party, Game, Save)가 그대로 뜬다.
## --script 모드는 오토로드를 띄우지 않아 Game이 컴파일되지 않으므로 쓰지 않는다.
## 실패하면 종료 코드 1을 돌려준다. 테스트 안의 SCRIPT ERROR는 종료 코드에 잡히지 않으므로 CI가 로그를 grep한다.

const SUITES: Array[GDScript] = [
	preload("res://tests/test_formulas.gd"),
	preload("res://tests/test_game.gd"),
	preload("res://tests/test_boss.gd"),
	preload("res://tests/test_save.gd"),
	preload("res://tests/test_offline.gd"),
]


func _ready() -> void:
	print("")
	print("=== 회귀 용사 키우기 테스트 ===")
	var passed := 0
	var failed := 0
	for suite_script in SUITES:
		var suite: Node = suite_script.new()
		add_child(suite)
		await suite.run()  # 프레임을 기다리는 스위트가 있다
		passed += suite.passed
		failed += suite.failed
	print("")
	print("통과 %d · 실패 %d" % [passed, failed])
	print("")
	get_tree().quit(1 if failed > 0 else 0)
