extends Node
## 헤드리스 테스트. 공식과 숫자 표기, 전투 진행을 엔진 창 없이 확인한다.
##
##   godot --headless --path . res://tests/run_tests.tscn
##
## 메인 씬 대신 이 씬을 띄우면 오토로드(Balance, Num, Game)가 그대로 뜬다.
## --script 모드는 오토로드를 띄우지 않아 Game이 컴파일되지 않으므로 쓰지 않는다.
## 실패하면 종료 코드 1을 돌려주므로 CI가 바로 잡아낸다.

const GameScript := preload("res://autoload/game.gd")

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	print("")
	print("=== 회귀 용사 키우기 테스트 ===")
	_test_balance(Balance)
	_test_num(Num)
	_test_game()
	print("")
	print("통과 %d · 실패 %d" % [_passed, _failed])
	print("")
	get_tree().quit(1 if _failed > 0 else 0)


## delta 상한을 지키면서 seconds만큼 프레임을 돌린다
func _advance(game: Node, seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		game._process(minf(left, Balance.MAX_DELTA))
		left -= Balance.MAX_DELTA


func _equal(actual: Variant, expected: Variant, what: String) -> void:
	if actual == expected:
		_passed += 1
	else:
		_failed += 1
		push_error("%s: 기대 %s, 실제 %s" % [what, expected, actual])


func _close(actual: float, expected: float, what: String) -> void:
	if is_equal_approx(actual, expected):
		_passed += 1
	else:
		_failed += 1
		push_error("%s: 기대 %s, 실제 %s" % [what, expected, actual])


func _test_balance(balance: Node) -> void:
	_equal(balance.milestones(1), 0, "1레벨 마일스톤")
	_equal(balance.milestones(9), 0, "9레벨 마일스톤")
	_equal(balance.milestones(10), 1, "10레벨 마일스톤")
	_equal(balance.milestones(24), 1, "24레벨 마일스톤")
	_equal(balance.milestones(25), 2, "25레벨 마일스톤")
	_equal(balance.milestones(50), 3, "50레벨 마일스톤")
	_equal(balance.milestones(100), 5, "100레벨 마일스톤")

	_close(balance.attack(1.0, 1), 1.0, "1레벨 공격력")
	_close(balance.attack(1.0, 10), 20.0, "10레벨 공격력 (×2)")
	_close(balance.attack(1.0, 25), 100.0, "25레벨 공격력 (×4)")
	_close(balance.attack(3.0, 0), 0.0, "0레벨(미고용) 공격력")

	_close(balance.level_cost(5.0, 0), 5.0, "0레벨 비용")
	_close(balance.level_cost(5.0, 1), 5.35, "1레벨 비용")
	_close(balance.hero_level_cost(1), 5.35, "용사 1레벨 비용")
	_close(balance.hero_click_damage(10), 20.0, "용사 10레벨 클릭 피해")

	_close(balance.monster_hp(1), 10.0, "1스테이지 체력")
	_close(balance.monster_hp(2), 11.5, "2스테이지 체력")
	_close(balance.monster_hp(100), 10.0 * pow(1.15, 99), "100스테이지 체력")
	_close(balance.kill_gold(15.0), 1.0, "처치 골드")


func _test_num(num: Node) -> void:
	_equal(num.format(0.0), "0", "0")
	_equal(num.format(0.67), "0", "1 미만은 0")
	_equal(num.format(9999.0), "9999", "1만 미만 정수")
	_equal(num.format(9999.9), "9999", "1만 미만은 버림")
	_equal(num.format(10000.0), "1.00만", "1만")
	_equal(num.format(12345.0), "1.23만", "1.23만")
	_equal(num.format(12399.0), "1.23만", "소수 둘째 자리 버림")
	_equal(num.format(456000.0), "45.6만", "45.6만")
	_equal(num.format(4560000000.0), "45.6억", "45.6억")
	_equal(num.format(99999999.0), "9999만", "9999만")
	_equal(num.format(100000000.0), "1.00억", "1억")
	_equal(num.format(7.89e14), "789조", "789조")
	_equal(num.format(1.234e19), "1234경", "1234경")
	_equal(num.format(1e20), "1.00해", "1해")
	_equal(num.format(1e68), "1.00무량대수", "1무량대수")
	_equal(num.format(9.99e71), "9990무량대수", "9990무량대수")
	_equal(num.format(99999.0), "9.99만", "9.99만 (10만 바로 아래)")
	_equal(num.format(999999.0), "99.9만", "99.9만 (100만 바로 아래)")
	_equal(num.format(9999999.0), "999만", "999만")
	_equal(num.format(1e72), "1.00e72", "10^72는 과학적 표기")
	_equal(num.format(1.23456e80), "1.23e80", "과학적 표기 버림")
	_equal(num.format(-12345.0), "-1.23만", "음수")


func _test_game() -> void:
	var game: Node = GameScript.new()  # 오토로드 Game 말고 새 인스턴스로 시작 상태를 본다
	add_child(game)  # _ready에서 첫 몬스터가 나온다

	_equal(game.stage, 1, "시작 스테이지")
	_close(game.gold, 0.0, "시작 골드")
	_close(game.monster_hp, 10.0, "첫 몬스터 체력")
	_equal(game.is_monster_alive(), true, "몬스터 살아 있음")

	game.tap_attack()
	_close(game.monster_hp, 9.0, "탭 1회에 클릭 피해 1")

	for i in 9:
		game.tap_attack()
	_close(game.monster_hp, 0.0, "10회 탭에 처치")
	_close(game.gold, 10.0 / 15.0, "처치 골드 = 체력 ÷ 15")
	_equal(game.kills, 1, "처치 수")
	_equal(game.is_monster_alive(), false, "재등장 대기 중")

	game.tap_attack()
	_close(game.gold, 10.0 / 15.0, "대기 중에는 피해도 골드도 없음")

	game._process(0.1)
	_equal(game.is_monster_alive(), false, "0.1초 뒤에도 아직 대기")
	game._process(0.25)
	_equal(game.is_monster_alive(), true, "0.3초가 지나면 재등장")
	_close(game.monster_hp, 10.0, "재등장 몬스터 체력")

	_equal(game.buy_hero_level(), false, "골드가 모자라면 못 산다")
	game.gold = 6.0
	_equal(game.buy_hero_level(), true, "비용(5.35)보다 많으면 산다")
	_equal(game.hero_level, 2, "용사 2레벨")
	_close(game.gold, 6.0 - 5.0 * 1.07, "비용을 뺀다")
	_close(game.click_damage(), 2.0, "2레벨 클릭 피해")

	# 9마리를 더 잡으면 2스테이지. 재등장은 delta 상한(0.25초) 때문에 여러 프레임이 걸린다
	for i in 9:
		game._damage_monster(game.monster_max_hp)
		_advance(game, 1.0)
	_equal(game.stage, 2, "10마리 처치 후 2스테이지")
	_equal(game.kills, 0, "처치 수 초기화")
	_close(game.monster_max_hp, 11.5, "2스테이지 몬스터 체력")

	game.queue_free()
