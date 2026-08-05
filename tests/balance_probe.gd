extends SceneTree

## 밸런스 탐침 — 100일을 자동으로 플레이해보고 마을이 어떻게 되는지 본다.
##
##   godot --headless --script res://tests/balance_probe.gd
##
## 단위 테스트가 "규칙이 맞게 동작하는가"를 묻는다면, 이쪽은
## **"그 규칙으로 만든 게임이 살 만한가"** 를 묻는다.
## 둘은 다른 질문이고, 후자는 단위 테스트로 잡히지 않는다.
##
## 이 탐침이 실제로 잡아낸 것:
##   M2 — 만성 식량 부족이 아무 결과도 낳지 않았다 (연속 일수 초기화 문제)
##   M2 — 농부 하나가 두 가구를 정확히 break-even으로 먹여, 마을이 성장할 수 없었다
##   M3 — 겨울에 식량은 남는데 장작이 0이었다. 장작을 패려면 목재가 필요한데
##        목재를 채취하면 장작이 안 나온다는 것을 전략이 다루지 않았다
## 전부 단위 테스트가 초록불인 상태에서 숨어 있었다.
##
## 여러 전략을 한 번에 쓸어보려면 tools/headless_balance.gd를 쓴다.
##
## ARCHITECTURE §8의 헤드리스 밸런싱 하네스의 초기 형태다.
## M6에서 여러 전략 × 여러 파라미터를 자동으로 쓸어보는 형태로 확장한다.

## 시험할 전략. "며칠에 무엇을 한다"의 목록이다.
##
## 사람이 실제로 할 법한 플레이여야 의미가 있다.
## 최적 플레이가 아니라 **평범한 플레이가 살아남는가**를 보는 것이 목적이다.
const STRATEGY := {
	0: [["build", 0, "hut"]],
	4: [["build", 1, "farm"]],
	10: [
		["assign", 1, 2], ["recipe", 1, "turnip"],
		["build", 2, "woodcutter"],
	],
	14: [
		# 농부 하나면 두 가구를 먹인다. 남는 하나를 장작으로 돌린다.
		["assign", 1, 1], ["assign", 2, 1], ["recipe", 2, "split_firewood"],
		["build", 3, "hut"],
	],
	20: [["build", 4, "hut"]],
	40: [["assign", 1, 2]],
	75: [["recipe", 2, "timber"]],
}

const REPORT_DAYS := [10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120]
const TOTAL_DAYS := 120


func _initialize() -> void:
	var world := SimWorld.create_default()
	var village := world.village

	print("")
	print("=== 밸런스 탐침 · %d일 ===" % TOTAL_DAYS)
	print("시작: %d가구 · 순무 %d · 장작 %d · 목재 %d" % [
		village.labor.total(),
		village.resources.amount_of("turnip"),
		village.resources.amount_of("firewood"),
		village.resources.amount_of("wood"),
	])
	print("")

	for day in range(0, TOTAL_DAYS + 1):
		_apply_strategy(world, day)
		if day > 0:
			world.tick()
		if REPORT_DAYS.has(day):
			_report(village, day)

	print("")
	print("결과: %s · %d가구 생존 (주거 %d)" % [
		{"victory": "승리", "defeat": "패배"}.get(world.outcome, "진행 중"),
		village.labor.total(), village.housing_capacity()])
	print("")
	quit(0)


func _apply_strategy(world: SimWorld, day: int) -> void:
	for action in STRATEGY.get(day, []):
		var error := ""
		match action[0]:
			"build":
				error = world.execute(SimBuildCommand.new(action[1], action[2]))
			"assign":
				error = world.execute(SimAssignWorkersCommand.new(action[1], action[2]))
			"recipe":
				error = world.execute(SimSetRecipeCommand.new(action[1], action[2]))

		# 거절당한 지시를 조용히 넘기면 "전략대로 했는데 죽었다"고 착각하게 된다.
		if error != "":
			print("  %3d일 · 지시 실패: %s %s → %s" % [day, action[0], action[1], error])


func _report(village: SimVillage, day: int) -> void:
	print("%3d일 %s | %d가구(유휴 %d) | 식량 %2d일 · 장작 %2d일 | 순무 %3d 장작 %3d" % [
		day,
		["봄", "여름", "가을", "겨울"][int(village.season)],
		village.labor.total(),
		village.labor.idle_count(),
		village.food_days_remaining(),
		village.firewood_days_remaining(),
		village.resources.amount_of("turnip"),
		village.resources.amount_of("firewood"),
	])
