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
			_check(ResourceDisplay.NAMES.has(resource_id),
				"%s의 비용 자원 '%s'" % [type_id, resource_id])

	_test("모든 거절 사유에 안내 문구가 있다")
	for code in [
		SimBuildCommand.ERR_SLOT_OUT_OF_RANGE, SimBuildCommand.ERR_SLOT_LOCKED,
		SimBuildCommand.ERR_SLOT_OCCUPIED, SimBuildCommand.ERR_UNKNOWN_TYPE,
		SimBuildCommand.ERR_TYPE_LOCKED, SimBuildCommand.ERR_CANNOT_AFFORD,
	]:
		_check(BuildingDisplay.BUILD_ERRORS.has(code), "'%s' 문구" % code)

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
	}, SimBuildingCatalog.load_default())


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
