extends SceneTree

## 헤드리스 밸런싱 하네스 (ARCHITECTURE §8, ROADMAP M3).
##
##   godot --headless --script res://tools/headless_balance.gd
##
## 묻는 것: **"평범한 플레이가 첫 겨울을 넘기는가, 몇 %나?"**
##
## `tests/balance_probe.gd`와 역할이 다르다:
##   probe   — 전략 하나를 하루씩 추적한다. "무슨 일이 일어났나"
##   balance — 수십 개 전략을 쓸어본다. "몇 %가 살아남나"
##
## 로드맵은 "시드 100개"라고 적었지만 이 시뮬레이션에는 아직 무작위 요소가 없다
## (전투가 들어오는 M4부터 생긴다). 그래서 시드 대신 **전략**을 흩뿌린다.
## 어차피 알고 싶은 것은 "운이 나쁘면 죽는가"가 아니라
## **"어떻게 플레이하면 죽는가"** 이므로, 지금은 이쪽이 더 맞는 질문이다.
##
## 판정 기준 (ROADMAP M3): **첫 겨울을 넘기는 것이 실제로 어려워야 한다.**
## 전부 살아남으면 압박이 없는 것이고, 전부 죽으면 배울 수 없는 게임이다.

## 이 범위 안이면 "어렵지만 가능하다"로 본다.
const TARGET_SURVIVAL_MIN := 0.25
const TARGET_SURVIVAL_MAX := 0.75

const DAYS := SimCalendar.DAYS_PER_YEAR


func _initialize() -> void:
	print("")
	print("=== 밸런싱 스윕 · 1년(%d일) ===" % DAYS)
	print("")

	var results: Array[Dictionary] = []
	for strategy in _strategies():
		results.append(_run(strategy))

	_report(results)
	quit(0)


## 전략 공간.
##
## 사람이 실제로 고민할 법한 축만 흩뿌린다. 최적해를 찾는 것이 목적이 아니라
## **평범한 판단들이 어떤 결말을 맞는지** 보는 것이 목적이다.
func _strategies() -> Array[Dictionary]:
	var strategies: Array[Dictionary] = []
	for crop in ["turnip", "barley"]:
		# 언제 농장에서 사람을 빼 나무꾼으로 돌릴 것인가.
		# 너무 이르면 굶고, 너무 늦으면 언다.
		for woodcutter_day in [14, 24, 34, 44]:
			# 남는 슬롯을 무엇에 쓸 것인가.
			# 오두막은 일손을 늘리고, 사냥꾼은 겨울에도 도는 식량원이며,
			# 창고는 겨울 비축의 한도를 늘린다.
			for hunter in [false, true]:
				for storehouse in [false, true]:
					strategies.append({
						"crop": crop,
						"woodcutter_day": woodcutter_day,
						"hunter": hunter,
						"storehouse": storehouse,
					})
	return strategies


func _run(strategy: Dictionary) -> Dictionary:
	var world := SimWorld.create_default()
	var village := world.village
	var lowest_food := 999
	var lowest_firewood := 999

	for day in range(0, DAYS + 1):
		_act(world, strategy, day)
		if world.is_over():
			break
		world.tick()

		if village.labor.total() > 0:
			lowest_food = mini(lowest_food, village.food_days_remaining())
			lowest_firewood = mini(lowest_firewood, village.firewood_days_remaining())

	return {
		"strategy": strategy,
		"survived": village.labor.total() > 0,
		"day": world.calendar.elapsed_days,
		"families": village.labor.total(),
		"lowest_food": lowest_food,
		"lowest_firewood": lowest_firewood,
	}


func _act(world: SimWorld, strategy: Dictionary, day: int) -> void:
	match day:
		0:
			world.execute(SimBuildCommand.new(0, "hut"))
		4:
			world.execute(SimBuildCommand.new(1, "farm"))
		10:
			world.execute(SimAssignWorkersCommand.new(1, 2))
			world.execute(SimSetRecipeCommand.new(1, strategy["crop"]))
			world.execute(SimBuildCommand.new(2, "woodcutter"))
		20:
			world.execute(SimBuildCommand.new(3, "hut"))
		30:
			world.execute(SimBuildCommand.new(4, "hunter" if strategy["hunter"] else "hut"))
		45:
			world.execute(SimBuildCommand.new(5, "storehouse" if strategy["storehouse"] else "hut"))
		60:
			world.execute(SimBuildCommand.new(6, "hut"))

	if day == strategy["woodcutter_day"]:
		# 농장에서 한 명 빼서 나무꾼으로 돌린다.
		world.execute(SimAssignWorkersCommand.new(1, 1))
		world.execute(SimAssignWorkersCommand.new(2, 1))

	_tend_woodcutter(world)
	_employ_idle(world)


## 나무꾼을 목재와 장작 사이에서 오간다.
##
## 이것을 하지 않으면 나무꾼은 반드시 굶는다:
## 장작을 패려면 목재가 필요한데, 목재를 채취하면 장작이 안 나온다.
## "둘 다는 못 한다"가 이 건물의 설계이므로(GDD), 번갈아 하는 것이 정답이고
## 사람이라면 목재가 바닥나는 것을 보고 알아서 전환한다.
func _tend_woodcutter(world: SimWorld) -> void:
	var village := world.village
	var building := village.building_at(2)
	if building == null or not building.is_complete():
		return

	# 장작 한 번 패는 데 목재 2가 든다. 여유를 두고 20을 기준선으로 잡는다.
	var wanted := "timber" if village.resources.amount_of("wood") < 20 else "split_firewood"
	if building.recipe_id != wanted:
		world.execute(SimSetRecipeCommand.new(2, wanted))


## 놀고 있는 가구를 일터로 보낸다.
##
## 이걸 넣지 않으면 이주민이 와도 입만 늘고 생산은 그대로다.
## 사람이라면 당연히 하는 일이므로, 넣지 않으면 밸런스가 아니라
## **하네스의 플레이 실력**을 측정하게 된다.
##
## 식량을 먼저 채우는 이유: 굶는 것이 어는 것보다 빨리 온다.
func _employ_idle(world: SimWorld) -> void:
	var village := world.village
	if village.labor.idle_count() <= 0:
		return

	# 앞 슬롯부터 채운다. 농장(1) → 나무꾼(2) → 그 뒤에 지은 생산 건물들.
	for slot in range(village.slot_count()):
		var capacity := village.worker_capacity(slot)
		if capacity <= 0:
			continue
		var assigned := village.labor.assigned_to(slot)
		if assigned < capacity:
			world.execute(SimAssignWorkersCommand.new(
				slot, assigned + village.labor.idle_count()))
		if village.labor.idle_count() <= 0:
			return


func _report(results: Array[Dictionary]) -> void:
	var survivors := results.filter(func(r: Dictionary) -> bool: return r["survived"])
	var rate := float(survivors.size()) / float(results.size())

	print("전략 %d개 · 생존 %d개 (%.0f%%)" % [results.size(), survivors.size(), rate * 100.0])
	print("")

	_report_by("작물", results, func(r: Dictionary) -> String: return r["strategy"]["crop"])
	_report_by("사냥꾼", results,
		func(r: Dictionary) -> String: return "지음" if r["strategy"]["hunter"] else "안 지음")
	_report_by("나무꾼 투입일", results,
		func(r: Dictionary) -> String: return "%d일" % r["strategy"]["woodcutter_day"])
	_report_by("창고", results,
		func(r: Dictionary) -> String: return "지음" if r["strategy"]["storehouse"] else "안 지음")

	var deaths := results.filter(func(r: Dictionary) -> bool: return not r["survived"])
	if not deaths.is_empty():
		var total_day := 0
		var in_winter := 0
		for death in deaths:
			total_day += death["day"]
			if death["day"] > SimCalendar.DAYS_PER_SEASON * 3:
				in_winter += 1

		@warning_ignore("integer_division")
		print("")
		print("죽은 마을 %d개 · 평균 %d일까지 버팀" % [deaths.size(), total_day / deaths.size()])
		# 겨울이 이 게임의 보스전이라면(GDD §3.2) 죽음도 거기 몰려야 한다.
		# 겨울 전에 다 죽는다면 압박이 잘못된 곳에 걸려 있는 것이다.
		print("  겨울에 죽음 %d개 · 겨울 전에 죽음 %d개" % [in_winter, deaths.size() - in_winter])

	print("")
	if rate < TARGET_SURVIVAL_MIN:
		print("⚠ 너무 어렵다. 대부분의 평범한 플레이가 죽는다.")
	elif rate > TARGET_SURVIVAL_MAX:
		print("⚠ 너무 쉽다. 아무렇게나 해도 겨울을 넘긴다 — 압박이 없다.")
	else:
		print("목표 범위 안이다 (%.0f~%.0f%%). 첫 겨울이 어렵지만 넘길 수 있다."
			% [TARGET_SURVIVAL_MIN * 100.0, TARGET_SURVIVAL_MAX * 100.0])
	print("")


## 한 축을 기준으로 생존율을 쪼갠다. 무엇이 결과를 가르는지 보이게 하는 것이 목적이다.
func _report_by(label: String, results: Array[Dictionary], key: Callable) -> void:
	var totals := {}
	var lived := {}
	for result in results:
		var group: String = key.call(result)
		totals[group] = int(totals.get(group, 0)) + 1
		if result["survived"]:
			lived[group] = int(lived.get(group, 0)) + 1

	var groups := totals.keys()
	groups.sort()

	var parts: Array[String] = []
	for group in groups:
		parts.append("%s %d/%d" % [group, int(lived.get(group, 0)), int(totals[group])])
	print("  %-12s %s" % [label, "  ".join(parts)])
