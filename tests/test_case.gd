extends Node
## 테스트 스위트의 공통 도우미. 스위트는 이 스크립트를 상속하고 run()을 채운다.

var passed: int = 0
var failed: int = 0


func run() -> void:
	pass


func _equal(actual: Variant, expected: Variant, what: String) -> void:
	if actual == expected:
		passed += 1
	else:
		failed += 1
		push_error("%s: 기대 %s, 실제 %s" % [what, expected, actual])


func _close(actual: float, expected: float, what: String) -> void:
	if is_equal_approx(actual, expected):
		passed += 1
	else:
		failed += 1
		push_error("%s: 기대 %s, 실제 %s" % [what, expected, actual])


## delta 상한을 지키면서 seconds만큼 Game의 프레임을 돌린다
func _advance(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		Game._process(minf(left, Balance.MAX_DELTA))
		left -= Balance.MAX_DELTA


## 아무것도 없는 상태에서 시작한다 (회귀 데이터, 업적 통계, 구매 배수까지 되돌린다)
func _fresh_run() -> void:
	Prestige.reset()
	Achievements.reset()
	Party.reset()
	Party.set_buy_mode(Party.BuyMode.ONE)
	Skills.reset()
	Training.reset()
	Game.reset()
