extends SceneTree

## 헤드리스 테스트 러너.
##
##   godot --headless --script res://tests/run_tests.gd
##
## sim 계층이 순수하기 때문에(ARCHITECTURE §2) 엔진 없이, 창 없이, 초 단위로 돈다.
## 실패하면 종료 코드 1을 반환하므로 CI가 바로 잡아낸다.
##
## GUT을 쓰지 않는 이유:
##   M0의 소스 파일은 다섯 개다. 여기에 애드온 수백 개 파일을 커밋하는 것은
##   배보다 배꼽이 크다. 테스트가 실제로 늘어나는 M2에서 GUT으로 옮긴다.
##   그때까지 필요한 것은 "CI에서 빨간불이 켜지는 것"뿐이고, 그건 이걸로 충분하다.

var _passed := 0
var _failed := 0
var _current := ""


func _initialize() -> void:
	print("")
	print("=== Frostmarch 테스트 ===")

	_run_calendar_tests()
	_run_world_tests()
	_run_resource_tests()
	_run_catalog_tests()
	_run_village_tests()
	_run_build_command_tests()
	_run_labor_tests()
	_run_production_tests()
	_run_consumption_tests()
	_run_population_tests()
	_run_economy_tests()
	_run_data_integrity_tests()

	print("")
	print("통과 %d · 실패 %d" % [_passed, _failed])
	print("")
	quit(1 if _failed > 0 else 0)


# --- SimCalendar --------------------------------------------------------------

func _run_calendar_tests() -> void:
	var calendar := SimCalendar.new()

	_test("게임은 1년차 봄 1일에 시작한다")
	_equal(calendar.year(), 1, "연차")
	_equal(calendar.season(), SimCalendar.Season.SPRING, "계절")
	_equal(calendar.day_of_season(), 1, "계절 내 날짜")
	_equal(calendar.day_of_year(), 1, "연중 날짜")

	_test("계절은 30일마다 바뀐다")
	_advance(calendar, 29)
	_equal(calendar.season(), SimCalendar.Season.SPRING, "봄 30일차는 아직 봄")
	_equal(calendar.day_of_season(), 30, "봄 마지막 날")
	_advance(calendar, 1)
	_equal(calendar.season(), SimCalendar.Season.SUMMER, "31일차는 여름")
	_equal(calendar.day_of_season(), 1, "여름 첫날")

	_test("네 계절이 순서대로 돈다")
	calendar = SimCalendar.new()
	_advance(calendar, 60)
	_equal(calendar.season(), SimCalendar.Season.AUTUMN, "61일차는 가을")
	_advance(calendar, 30)
	_equal(calendar.season(), SimCalendar.Season.WINTER, "91일차는 겨울")
	_check(calendar.is_winter(), "is_winter()가 참")

	_test("1년은 120일이고 그 다음은 2년차 봄이다")
	calendar = SimCalendar.new()
	_advance(calendar, 119)
	_equal(calendar.year(), 1, "120일차는 아직 1년차")
	_equal(calendar.day_of_year(), 120, "연중 마지막 날")
	_advance(calendar, 1)
	_equal(calendar.year(), 2, "121일차는 2년차")
	_equal(calendar.season(), SimCalendar.Season.SPRING, "새해는 봄부터")
	_equal(calendar.day_of_season(), 1, "봄 첫날")

	_test("여러 해가 지나도 어긋나지 않는다")
	calendar = SimCalendar.new()
	_advance(calendar, SimCalendar.DAYS_PER_YEAR * 5)
	_equal(calendar.year(), 6, "5년 뒤는 6년차")
	_equal(calendar.season(), SimCalendar.Season.SPRING, "계절")
	_equal(calendar.day_of_season(), 1, "날짜")

	_test("겨울은 1년에 한 번, 30일 동안만이다")
	calendar = SimCalendar.new()
	var winter_days := 0
	for _i in SimCalendar.DAYS_PER_YEAR:
		if calendar.is_winter():
			winter_days += 1
		calendar.advance_day()
	_equal(winter_days, SimCalendar.DAYS_PER_SEASON, "1년 중 겨울 일수")


# --- SimWorld -----------------------------------------------------------------

func _run_world_tests() -> void:
	_test("tick()은 하루를 진행시키고 day_advanced를 쏜다")
	var world := SimWorld.create_default()
	var days_seen: Array[int] = []
	world.day_advanced.connect(func(elapsed: int) -> void: days_seen.append(elapsed))
	world.tick()
	world.tick()
	_equal(world.calendar.elapsed_days, 2, "경과 일수")
	_equal(days_seen, [1, 2] as Array[int], "day_advanced 수신 내역")

	# 주의: GDScript 람다는 변수를 값으로 캡처한다.
	# 람다 안에서 지역 int를 증가시켜도 바깥에는 반영되지 않는다.
	# 그래서 카운터 대신 배열(참조 타입)에 수집한다.

	_test("season_changed는 계절 경계에서만, 올바른 순서로 발생한다")
	world = SimWorld.create_default()
	var seasons_seen: Array = []
	world.season_changed.connect(func(s: SimCalendar.Season) -> void: seasons_seen.append(s))
	for _i in SimCalendar.DAYS_PER_YEAR:
		world.tick()
	_equal(seasons_seen, [
		SimCalendar.Season.SUMMER,
		SimCalendar.Season.AUTUMN,
		SimCalendar.Season.WINTER,
		SimCalendar.Season.SPRING,
	], "1년간 계절 전환 내역")

	_test("year_changed는 해가 바뀔 때만 발생한다")
	world = SimWorld.create_default()
	var years_seen: Array = []
	world.year_changed.connect(func(y: int) -> void: years_seen.append(y))
	for _i in SimCalendar.DAYS_PER_YEAR * 3:
		world.tick()
	_equal(years_seen, [2, 3, 4], "3년간 연차 전환 내역")

	_test("시뮬레이션은 결정론적이다 — 같은 틱 수는 같은 상태를 만든다")
	var a := SimWorld.create_default()
	var b := SimWorld.create_default()
	for _i in 250:
		a.tick()
		b.tick()
	_equal(a.calendar.elapsed_days, b.calendar.elapsed_days, "경과 일수")
	_equal(a.calendar.season(), b.calendar.season(), "계절")


# --- SimResourcePool ----------------------------------------------------------

func _run_resource_tests() -> void:
	_test("자원은 데이터가 정하는 대로 담긴다")
	var pool := SimResourcePool.from_dict({"wood": 140, "stone": 60})
	_equal(pool.amount_of("wood"), 140, "목재")
	_equal(pool.amount_of("stone"), 60, "석재")
	_equal(pool.amount_of("iron"), 0, "한 번도 등장하지 않은 자원은 0")

	_test("지불은 전부 아니면 전무다")
	pool = SimResourcePool.from_dict({"wood": 20, "stone": 5})
	_check(not pool.can_afford({"wood": 10, "stone": 10}), "석재가 모자라면 지불 불가")
	_check(not pool.spend({"wood": 10, "stone": 10}), "spend()가 거절한다")
	_equal(pool.amount_of("wood"), 20, "실패한 지불은 목재를 건드리지 않는다")
	_equal(pool.amount_of("stone"), 5, "실패한 지불은 석재를 건드리지 않는다")

	_test("지불에 성공하면 정확히 그만큼만 빠진다")
	_check(pool.spend({"wood": 10, "stone": 5}), "지불 성공")
	_equal(pool.amount_of("wood"), 10, "남은 목재")
	_equal(pool.amount_of("stone"), 0, "남은 석재")

	_test("보유량은 음수가 되지 않는다")
	pool.add("wood", -999)
	_equal(pool.amount_of("wood"), 0, "0에서 멈춘다")

	_test("자원 목록은 항상 같은 순서다 — UI가 흔들리지 않게")
	pool = SimResourcePool.from_dict({"stone": 1, "wood": 2})
	_equal(pool.tracked_ids(), ["stone", "wood"], "정렬된 자원 id")


# --- SimBuildingCatalog -------------------------------------------------------

func _run_catalog_tests() -> void:
	var catalog := SimBuildingCatalog.load_default()

	_test("카탈로그는 데이터 파일을 읽는다")
	_equal(catalog.ids().size(), 6, "MVP 건물 6종 (GDD §4.5)")
	_check(not catalog.has("_comment"), "주석 키는 건물이 아니다")
	_check(catalog.has("bakery"), "화덕이 있다")

	_test("건물 정의가 숫자까지 읽힌다")
	var bakery := catalog.get_type("bakery")
	_equal(bakery.cost, {"wood": 20, "stone": 20}, "화덕 건설 비용")
	_equal(bakery.build_days, 6, "화덕 건설 일수")
	_equal(bakery.requires, ["mill"] as Array[String], "화덕 선행 건물")

	_test("해금 사슬 — 오두막 → 농장 → 방앗간 → 화덕 (GDD §4.5)")
	var nothing_built := {}
	_check(catalog.is_unlocked("hut", nothing_built), "오두막은 처음부터 열려 있다")
	_check(not catalog.is_unlocked("farm", nothing_built), "농장은 오두막이 필요하다")
	_check(not catalog.is_unlocked("bakery", nothing_built), "화덕은 잠겨 있다")

	var hut_built := {"hut": true}
	_check(catalog.is_unlocked("farm", hut_built), "오두막이 있으면 농장이 열린다")
	_check(catalog.is_unlocked("woodcutter", hut_built), "나무꾼 오두막도 열린다")
	_check(not catalog.is_unlocked("mill", hut_built), "방앗간은 아직 농장이 없다")

	_check(catalog.is_unlocked("mill", {"hut": true, "farm": true}), "농장이 생기면 방앗간")
	_check(catalog.is_unlocked("bakery", {"mill": true}), "방앗간이 생기면 화덕")

	_test("무엇이 부족한지 알려준다 — 메뉴가 이유를 보여줘야 한다")
	_equal(catalog.missing_requirements("bakery", {}), ["mill"] as Array[String], "화덕에 부족한 선행")
	_equal(catalog.missing_requirements("hut", {}), [] as Array[String], "오두막은 부족한 것이 없다")


# --- SimVillage ---------------------------------------------------------------

func _run_village_tests() -> void:
	_test("마을은 데이터 파일이 정한 자원과 슬롯으로 시작한다")
	var village := SimVillage.load_default()
	_equal(village.slot_count(), 8, "전체 슬롯 수")
	_equal(village.resources.amount_of("wood"), 140, "시작 목재")
	_check(village.is_slot_unlocked(0), "0번 슬롯은 열려 있다")
	_check(not village.is_slot_unlocked(village.slot_count() - 1), "마지막 슬롯은 잠겨 있다")

	_test("슬롯은 연차에 따라, 순서대로 열린다")
	village = _test_village()
	_equal(village.unlocked_slot_count, 2, "1년차 슬롯 수")
	_equal(village.refresh_slot_unlocks(2), 1, "2년차에 하나 더 열린다")
	_equal(village.unlocked_slot_count, 3, "2년차 슬롯 수")
	_equal(village.refresh_slot_unlocks(2), 0, "같은 해에 두 번 불러도 더 열리지 않는다")
	_equal(village.refresh_slot_unlocks(9), 1, "남은 슬롯이 전부 열린다")
	_equal(village.unlocked_slot_count, village.slot_count(), "모든 슬롯 해금")

	_test("건설 중인 건물은 해금 사슬을 진행시키지 않는다")
	village = _test_village()
	village.buildings[0] = SimBuilding.start_construction(village.catalog.get_type("hut"), 0)
	_equal(village.completed_type_ids(), {}, "착공만으로는 완공 목록에 오르지 않는다")
	_check(not village.is_type_unlocked("farm"), "오두막이 완공되기 전에는 농장이 잠겨 있다")

	for _i in 3:
		village.buildings[0].advance_construction()
	_check(village.buildings[0].is_complete(), "3일 뒤 오두막 완공")
	_check(village.is_type_unlocked("farm"), "완공되고 나서야 농장이 열린다")


# --- SimBuildCommand ----------------------------------------------------------

func _run_build_command_tests() -> void:
	_test("건설 커맨드는 자원을 쓰고 건물을 세운다")
	var world := SimWorld.create_default()
	var error := world.execute(SimBuildCommand.new(0, "hut"))
	_equal(error, SimCommand.OK, "커맨드 성공")
	_equal(world.village.resources.amount_of("wood"), 125, "목재 15 소모")
	_check(world.village.building_at(0) != null, "0번 슬롯에 건물이 생겼다")
	_check(not world.village.building_at(0).is_complete(), "아직 건설 중")

	_test("거절 사유가 구체적으로 나온다")
	world = SimWorld.create_default()
	_equal(world.execute(SimBuildCommand.new(99, "hut")),
		SimBuildCommand.ERR_SLOT_OUT_OF_RANGE, "없는 슬롯")
	_equal(world.execute(SimBuildCommand.new(7, "hut")),
		SimBuildCommand.ERR_SLOT_LOCKED, "잠긴 슬롯 (7번은 3년차 해금)")
	_equal(world.execute(SimBuildCommand.new(0, "castle")),
		SimBuildCommand.ERR_UNKNOWN_TYPE, "없는 건물")
	_equal(world.execute(SimBuildCommand.new(0, "bakery")),
		SimBuildCommand.ERR_TYPE_LOCKED, "선행 건물 미충족")

	world.execute(SimBuildCommand.new(0, "hut"))
	_equal(world.execute(SimBuildCommand.new(0, "hut")),
		SimBuildCommand.ERR_SLOT_OCCUPIED, "이미 찬 슬롯")

	_test("자원이 모자라면 거절하고, 아무것도 쓰지 않는다")
	world = SimWorld.create_default()
	world.village.resources = SimResourcePool.from_dict({"wood": 5})
	_equal(world.execute(SimBuildCommand.new(0, "hut")),
		SimBuildCommand.ERR_CANNOT_AFFORD, "자원 부족")
	_equal(world.village.resources.amount_of("wood"), 5, "목재가 그대로다")
	_check(world.village.is_slot_empty(0), "슬롯도 그대로다")

	_test("잠긴 슬롯이 자원 부족보다 먼저 걸린다 — 안내가 헷갈리지 않게")
	world = SimWorld.create_default()
	world.village.resources = SimResourcePool.from_dict({"wood": 0})
	_equal(world.execute(SimBuildCommand.new(7, "hut")),
		SimBuildCommand.ERR_SLOT_LOCKED, "슬롯 잠김이 먼저")

	_test("건물은 정해진 일수를 채워야 완공된다")
	world = SimWorld.create_default()
	world.execute(SimBuildCommand.new(0, "hut"))
	var completed_names: Array = []
	world.building_completed.connect(func(b: SimBuilding) -> void: completed_names.append(b.type_id))

	world.tick()
	world.tick()
	_check(not world.village.building_at(0).is_complete(), "2일차에는 아직 건설 중")
	_equal(world.village.building_at(0).days_remaining, 1, "하루 남음")
	world.tick()
	_check(world.village.building_at(0).is_complete(), "3일차에 완공")
	_equal(completed_names, ["hut"], "building_completed는 완공 순간 한 번만")

	world.tick()
	_equal(completed_names, ["hut"], "완공 이후로는 다시 쏘지 않는다")

	_test("해금 사슬이 실제 플레이 흐름에서 이어진다")
	world = SimWorld.create_default()
	world.execute(SimBuildCommand.new(0, "hut"))
	for _i in 3:
		world.tick()
	_equal(world.execute(SimBuildCommand.new(1, "farm")), SimCommand.OK, "오두막 완공 후 농장 착공")


# --- SimLabor -----------------------------------------------------------------

func _run_labor_tests() -> void:
	_test("가구는 한 곳에만 있을 수 있다 — 제로섬이 구조로 보장된다")
	var labor := SimLabor.new()
	for _i in 3:
		labor.add_family()
	_equal(labor.total(), 3, "전체 가구")
	_equal(labor.idle_count(), 3, "처음엔 전부 유휴")

	labor.set_assignment(0, 2, 3)
	_equal(labor.assigned_to(0), 2, "0번에 2가구")
	_equal(labor.idle_count(), 1, "유휴 1가구")

	_test("다른 건물에서 자동으로 빼오지 않는다 — 무엇을 포기할지는 플레이어가 정한다")
	_equal(labor.set_assignment(1, 3, 3), 1, "유휴가 1가구뿐이므로 1가구만 배정된다")
	_equal(labor.assigned_to(0), 2, "0번 인력은 그대로다")
	_equal(labor.idle_count(), 0, "유휴 없음")

	_test("건물 정원을 넘겨 배정할 수 없다")
	labor = SimLabor.new()
	for _i in 5:
		labor.add_family()
	_equal(labor.set_assignment(0, 99, 2), 2, "정원 2에서 멈춘다")

	_test("인력을 빼면 유휴로 돌아온다")
	_equal(labor.set_assignment(0, 0, 2), 0, "0명으로")
	_equal(labor.idle_count(), 5, "전부 유휴")

	_test("건물이 사라지면 그곳 인력이 풀린다")
	labor.set_assignment(3, 2, 2)
	labor.release_all(3)
	_equal(labor.assigned_to(3), 0, "배정 해제")
	_equal(labor.idle_count(), 5, "유휴로 복귀")

	_test("떠나는 가구는 유휴부터 나간다 — 생산 라인이 먼저 무너지면 회복할 수 없다")
	labor = SimLabor.new()
	for _i in 3:
		labor.add_family()
	labor.set_assignment(0, 2, 2)
	_check(labor.remove_family(), "한 가구가 떠난다")
	_equal(labor.assigned_to(0), 2, "일하던 가구는 남는다")
	_equal(labor.idle_count(), 0, "유휴 가구가 나갔다")


# --- 생산 ---------------------------------------------------------------------

func _run_production_tests() -> void:
	_test("인력이 붙어야 생산한다")
	var village := _production_village(3)
	_place(village, 0, "woodcutter")
	village.produce()
	_equal(village.buildings[0].halt_reason, SimBuilding.HALT_NO_WORKERS, "인력 없음으로 멈춤")
	_equal(village.resources.amount_of("wood"), 0, "아무것도 나오지 않았다")

	_test("가구일을 채우면 산출한다 — 나무꾼 1가구, 1가구일당 목재 4")
	village.labor.set_assignment(0, 1, 2)
	village.produce()
	_equal(village.resources.amount_of("wood"), 4, "하루에 목재 4")
	_equal(village.buildings[0].halt_reason, SimBuilding.HALT_NONE, "가동 중")

	# 기대값을 데이터에서 읽는다. 밸런싱으로 수치가 바뀌어도 규칙 자체는 그대로여야 한다.
	_test("인력이 두 배면 두 배 빨리 만든다")
	village = _production_village(3)
	_place(village, 0, "farm")
	var turnip := village.catalog.get_type("farm").get_recipe("turnip")
	var yield_per_cycle := int(turnip.outputs["turnip"])

	village.labor.set_assignment(0, 1, 3)
	for _i in turnip.worker_days - 1:
		village.produce()
	_equal(village.resources.amount_of("turnip"), 0, "1가구로는 %d일이 걸린다" % turnip.worker_days)
	village.produce()
	_equal(village.resources.amount_of("turnip"), yield_per_cycle, "마지막 날에 산출")

	village = _production_village(3)
	_place(village, 0, "farm")
	village.labor.set_assignment(0, turnip.worker_days, 3)
	village.produce()
	_equal(village.resources.amount_of("turnip"), yield_per_cycle, "%d가구면 하루 만에 나온다"
		% turnip.worker_days)

	_test("재료가 없으면 멈추고, 쌓아둔 진행은 잃지 않는다")
	village = _production_village(3)
	_place(village, 0, "mill")
	var grind := village.catalog.get_type("mill").get_recipe("grind")
	village.labor.set_assignment(0, 2, 2)
	village.produce()
	_equal(village.buildings[0].halt_reason, SimBuilding.HALT_NO_INPUT, "재료 없음")
	_equal(village.buildings[0].production_progress, 2, "진행은 남아 있다")

	village.resources.add("wheat", int(grind.inputs["wheat"]))
	village.produce()
	_equal(village.resources.amount_of("flour"), int(grind.outputs["flour"]),
		"재료가 들어오자마자 산출")

	_test("창고가 가득 차면 재료를 버리지 않고 멈춘다")
	village = _production_village(3)
	_place(village, 0, "mill")
	village.resources.add("wheat", 30)
	village.resources.add("flour", village.storage_capacity("flour"))
	village.labor.set_assignment(0, 2, 2)
	var wheat_before := village.resources.amount_of("wheat")
	village.produce()
	_equal(village.buildings[0].halt_reason, SimBuilding.HALT_STORAGE_FULL, "창고 가득")
	_equal(village.resources.amount_of("wheat"), wheat_before, "밀을 헛되이 쓰지 않았다")

	_test("저장 한도를 넘겨 쌓이지 않는다")
	village = _production_village(3)
	_place(village, 0, "woodcutter")
	village.labor.set_assignment(0, 2, 2)
	for _i in 200:
		village.produce()
	_equal(village.resources.amount_of("wood"), village.storage_capacity("wood"), "한도에서 멈춘다")

	_test("창고를 지으면 저장 한도가 늘어난다")
	village = _production_village(3)
	var base_capacity := village.storage_capacity("wood")
	_place(village, 1, "storehouse")
	_equal(village.storage_capacity("wood"), base_capacity + 200, "창고 하나당 +200")

	_test("레시피를 바꾸면 진행 중이던 작업은 버려진다")
	village = _production_village(3)
	_place(village, 0, "farm")
	village.labor.set_assignment(0, 1, 3)
	village.produce()
	_check(village.buildings[0].production_progress > 0, "진행이 쌓였다")
	village.buildings[0].set_recipe("wheat")
	_equal(village.buildings[0].production_progress, 0, "작물을 바꾸면 처음부터")


# --- 소비 ---------------------------------------------------------------------

func _run_consumption_tests() -> void:
	_test("장작이 없으면 식량이 넉넉해도 견디지 못한다 — 나무꾼의 선택이 진짜가 되는 지점")
	var cold := _production_village()
	cold.labor.add_family()
	cold.resources.add("turnip", 100)
	_check(not cold.consume(), "먹었지만 얼었다")
	_equal(cold.last_shortage, "firewood", "모자란 것은 장작")

	cold.resources.add("firewood", 10)
	_check(cold.consume(), "장작이 들어오자 견딘다")
	_equal(cold.last_shortage, "", "부족 없음")

	_test("무엇이 모자랐는지 구분해 알려준다")
	var empty := _production_village()
	empty.labor.add_family()
	_check(not empty.consume(), "둘 다 없다")
	_equal(empty.last_shortage, "both", "식량도 장작도")

	_test("가구는 매일 먹고 땐다")
	var village := _production_village()
	village.labor.add_family()
	village.labor.add_family()
	village.resources.add("turnip", 20)
	village.resources.add("firewood", 20)

	_check(village.consume(), "먹였다")
	_equal(village.resources.amount_of("turnip"), 16, "2가구 × 2끼니 = 순무 4")
	_equal(village.resources.amount_of("firewood"), 18, "2가구 × 장작 1")

	_test("식량이 모자라면 false를 반환한다")
	village = _production_village()
	village.labor.add_family()
	_check(not village.consume(), "먹일 것이 없다")

	_test("배급 정책이 먹는 순서를 바꾼다")
	village = _production_village()
	village.labor.add_family()
	village.resources.add("bread", 10)
	village.resources.add("turnip", 10)

	village.ration_policy = SimVillage.RATION_RICH_FIRST
	village.consume()
	_equal(village.resources.amount_of("bread"), 9, "빵부터 먹는다")
	_equal(village.resources.amount_of("turnip"), 10, "순무는 그대로")

	village = _production_village()
	village.labor.add_family()
	village.resources.add("bread", 10)
	village.resources.add("turnip", 10)
	village.ration_policy = SimVillage.RATION_CHEAP_FIRST
	village.consume()
	_equal(village.resources.amount_of("bread"), 10, "빵을 아낀다")
	_equal(village.resources.amount_of("turnip"), 8, "순무 2개로 2끼니")

	_test("며칠 버틸 수 있는지 계산한다 — 화면에 띄우는 가장 중요한 숫자")
	village = _production_village()
	village.labor.add_family()
	village.labor.add_family()
	village.resources.add("bread", 4)
	_equal(village.food_stock_units(), 20, "빵 4개 = 20끼니")
	_equal(village.food_days_remaining(), 5, "2가구가 하루 4끼니 → 5일")


# --- 인구 ---------------------------------------------------------------------

func _run_population_tests() -> void:
	_test("빈 집과 식량이 있으면 이주해 온다")
	var village := _production_village()
	village.labor.add_family()
	_place(village, 0, "hut")
	_place(village, 1, "hut")
	village.resources.add("bread", 60)

	var arrived := ""
	for _i in village.rules.immigration_interval_days:
		arrived = village.update_population(true)
	_equal(arrived, "family_arrived", "간격을 채우면 한 가구가 온다")
	_equal(village.labor.total(), 2, "가구 수 증가")

	_test("빈 집이 없으면 오지 않는다")
	village = _production_village()
	village.labor.add_family()
	_place(village, 0, "hut")
	village.resources.add("bread", 60)
	for _i in village.rules.immigration_interval_days * 3:
		village.update_population(true)
	_equal(village.labor.total(), 1, "주거 한도에서 멈춘다")

	_test("식량이 모자라면 오지 않는다 — 먹여 살릴 수 없는 인구를 부르지 않는다")
	village = _production_village()
	village.labor.add_family()
	_place(village, 0, "hut")
	_place(village, 1, "hut")
	village.resources.add("turnip", 2)
	for _i in village.rules.immigration_interval_days * 3:
		village.update_population(true)
	_equal(village.labor.total(), 1, "식량 여유가 없으면 이주 없음")

	_test("굶은 끼니가 쌓여야 떠난다 — 하루 굶었다고 바로는 아니다")
	village = _production_village()
	for _i in 2:
		village.labor.add_family()

	# 2가구가 완전히 굶고 언다: 하루에 끼니 4 + 장작 2 = 고난 6씩.
	# 한계는 가구당 10 × 2가구 = 20.
	var event := ""
	for _i in 3:
		village.consume()
		event = village.update_population(false)
	_equal(village.hardship, 18, "사흘이면 18")
	_equal(event, "", "아직 한계에 닿지 않았다")

	village.consume()
	event = village.update_population(false)
	_equal(event, "family_left", "한계를 넘으면 한 가구가 떠난다")
	_equal(village.labor.total(), 1, "한 가구가 줄었다")

	# 이 검증이 M2에서 실제로 잡아낸 구멍이다.
	# '연속으로 며칠 굶었는가'로 세면, 하루 굶고 하루 먹기를 반복하는 마을은
	# 매번 0으로 초기화되어 필요량의 60%만 먹으면서도 영원히 버틴다.
	_test("만성 부족도 결국 사람을 떠나게 한다 — 하루 걸러 굶어도")
	village = _production_village()
	village.labor.add_family()

	var left := false
	for day in 40:
		village.resources.add("firewood", 1)          # 장작은 늘 충분하게
		if day % 2 == 1:
			village.resources.add("turnip", 2)        # 이틀에 한 번만 배불리
		village.consume()
		if village.update_population(village.last_shortage.is_empty()) == "family_left":
			left = true
			break
	_check(left, "절반만 먹여서는 버틸 수 없다")

	_test("배불리 먹은 날은 고난을 갚지만, 쌓인 것이 없던 일이 되지는 않는다")
	village = _production_village()
	village.labor.add_family()
	village.consume()
	village.update_population(false)
	var accumulated := village.hardship
	_check(accumulated > 0, "굶어서 고난이 쌓였다")

	village.resources.add("turnip", 10)
	village.resources.add("firewood", 10)
	village.consume()
	village.update_population(true)
	_equal(village.hardship, accumulated - village.rules.hardship_recovery_per_day,
		"하루치만 갚는다 — 한 번에 0이 되지 않는다")


# --- SimEconomy ---------------------------------------------------------------

func _run_economy_tests() -> void:
	var catalog := SimBuildingCatalog.load_default()
	var resources := SimResourceCatalog.load_default()
	var economy := SimEconomy.new(catalog, resources)

	_test("먹을 수 있는 자원은 그 자체가 값어치다")
	_equal(economy.unit_value("bread").food, 5.0, "빵 한 개 = 5끼니")
	_equal(economy.unit_value("bread").worker_days, 0.0, "더 가공할 필요 없음")

	_test("밀은 가공 사슬을 따라가 값어치가 매겨진다")
	var wheat := economy.unit_value("wheat")
	_check(wheat.food > 0.0, "밀도 결국 값어치가 있다")
	_check(wheat.worker_days > 0.0, "다만 가공 인력이 든다")

	_test("돌도 아닌 것은 값어치 0이다")
	_equal(economy.unit_value("stone").food, 0.0, "석재는 먹을 수 없고 가공해도 식량이 아니다")

	# 이 검증이 실패하면 표시 버그가 아니라 밸런스 버그다.
	# 밀 사슬이 순무보다 못하면 방앗간과 화덕을 지을 이유가 사라진다 (GDD §4.4).
	_test("밀 사슬이 순무보다 효율이 높다 — 아니면 아무도 방앗간을 짓지 않는다")
	var farm := catalog.get_type("farm")
	var turnip_rate := economy.food_per_worker_day(farm.get_recipe("turnip"))
	var barley_rate := economy.food_per_worker_day(farm.get_recipe("barley"))
	var wheat_rate := economy.food_per_worker_day(farm.get_recipe("wheat"))

	_check(turnip_rate > 0.0, "순무 효율 %.2f" % turnip_rate)
	_check(barley_rate > turnip_rate, "보리 %.2f > 순무 %.2f" % [barley_rate, turnip_rate])
	_check(wheat_rate > barley_rate, "밀 %.2f > 보리 %.2f" % [wheat_rate, barley_rate])

	_test("순환 레시피가 있어도 무한 재귀에 빠지지 않는다")
	var looped := SimBuildingCatalog.from_json({
		"a": {"recipes": [{"id": "x", "in": {"foo": 1}, "out": {"bar": 1}, "worker_days": 1}]},
		"b": {"recipes": [{"id": "y", "in": {"bar": 1}, "out": {"foo": 1}, "worker_days": 1}]},
	})
	var loop_economy := SimEconomy.new(looped, SimResourceCatalog.from_json({
		"foo": {"capacity": 10}, "bar": {"capacity": 10},
	}))
	_equal(loop_economy.unit_value("foo").food, 0.0, "순환은 값어치 0으로 끊는다")


# --- 데이터 정합성 -------------------------------------------------------------

## sim과 game이 data/buildings.json을 따로 파싱한다 (ARCHITECTURE §2 규칙 2).
## 그 대가로 생길 수 있는 어긋남을 여기서 막는다.
func _run_data_integrity_tests() -> void:
	var catalog := SimBuildingCatalog.load_default()

	_test("모든 건물에 한글 이름과 설명이 있다")
	for type_id in catalog.ids():
		_check(BuildingDisplay.name_of(type_id) != type_id, "%s → 한글 이름" % type_id)
		_check(not BuildingDisplay.description_of(type_id).is_empty(), "%s → 설명" % type_id)

	_test("건설 비용에 쓰인 자원이 전부 한글 이름을 갖는다")
	for type_id in catalog.ids():
		for resource_id in catalog.get_type(type_id).cost:
			_check(ResourceDisplay.has(String(resource_id)),
				"%s의 비용 자원 '%s'" % [type_id, resource_id])

	_test("모든 거절 사유에 안내 문구가 있다")
	for code in [
		SimBuildCommand.ERR_SLOT_OUT_OF_RANGE, SimBuildCommand.ERR_SLOT_LOCKED,
		SimBuildCommand.ERR_SLOT_OCCUPIED, SimBuildCommand.ERR_UNKNOWN_TYPE,
		SimBuildCommand.ERR_TYPE_LOCKED, SimBuildCommand.ERR_CANNOT_AFFORD,
	]:
		_check(BuildingDisplay.COMMAND_ERRORS.has(code), "'%s' 문구" % code)

	_test("선행 건물로 지목된 id가 전부 실제로 존재한다")
	for type_id in catalog.ids():
		for required_id in catalog.get_type(type_id).requires:
			_check(catalog.has(required_id), "%s가 요구하는 '%s'" % [type_id, required_id])

	_test("자원은 GDD §4.3 분류 순서로 표시된다 — 영문 id 알파벳순이 아니라")
	_equal(ResourceDisplay.ordered(["stone", "wood"]), ["wood", "stone"] as Array[String],
		"목재가 석재보다 먼저")
	_equal(ResourceDisplay.ordered(["silver", "grain", "wood"]),
		["wood", "grain", "silver"] as Array[String], "1차 → 화폐 순")
	_equal(ResourceDisplay.ordered(["mystery", "wood"]), ["wood", "mystery"] as Array[String],
		"표에 없는 자원은 뒤로 밀되 사라지지는 않는다")
	_equal(BuildingDisplay.format_cost({"stone": 20, "wood": 20}), "목재 20 · 석재 20",
		"건설 비용 표기")

	_test("시작 자원으로 첫 건물을 지을 수 있다 — 시작하자마자 막히면 안 된다")
	var village := SimVillage.load_default()
	_check(village.resources.can_afford(catalog.get_type("hut").cost), "오두막 건설 가능")
	_check(village.unlocked_slot_count > 0, "열린 슬롯이 있다")


# --- 러너 ---------------------------------------------------------------------

## 데이터 파일과 무관하게 슬롯 해금 규칙만 시험하기 위한 작은 마을.
func _test_village() -> SimVillage:
	return SimVillage.from_json({
		"starting_resources": {"wood": 140, "stone": 60},
		"slots": [
			{"unlock_year": 1}, {"unlock_year": 1},
			{"unlock_year": 2}, {"unlock_year": 5},
		],
	}, SimBuildingCatalog.load_default(), SimResourceCatalog.load_default(), SimRules.load_default())


## 자원도 가구도 없는 빈 마을. 생산·소비 시험은 여기서 시작해야
## 시작 자원이 결과를 흐리지 않는다.
func _production_village(families: int = 0) -> SimVillage:
	return SimVillage.from_json({
		"starting_resources": {},
		"slots": [{"unlock_year": 1}, {"unlock_year": 1}, {"unlock_year": 1}],
	}, SimBuildingCatalog.load_default(), SimResourceCatalog.load_default(),
	SimRules.from_json({"population": {"starting_families": families}}))


## 완공된 건물을 슬롯에 바로 꽂는다. 건설 일수를 기다리지 않고
## 생산·소비만 시험하기 위한 도구다.
func _place(village: SimVillage, slot_index: int, type_id: String) -> SimBuilding:
	var building := SimBuilding.start_construction(village.catalog.get_type(type_id), slot_index)
	building.state = SimBuilding.State.ACTIVE
	building.days_remaining = 0
	village.buildings[slot_index] = building
	return building


func _advance(calendar: SimCalendar, days: int) -> void:
	for _i in days:
		calendar.advance_day()


func _test(name: String) -> void:
	_current = name
	print("")
	print("  " + name)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("    OK   " + label)
	else:
		_failed += 1
		print("    FAIL " + label)


func _equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		_passed += 1
		print("    OK   %s" % label)
	else:
		_failed += 1
		print("    FAIL %s — 기대값 %s, 실제값 %s" % [label, expected, actual])
