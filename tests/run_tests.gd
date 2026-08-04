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
	var world := SimWorld.new()
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
	world = SimWorld.new()
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
	world = SimWorld.new()
	var years_seen: Array = []
	world.year_changed.connect(func(y: int) -> void: years_seen.append(y))
	for _i in SimCalendar.DAYS_PER_YEAR * 3:
		world.tick()
	_equal(years_seen, [2, 3, 4], "3년간 연차 전환 내역")

	_test("시뮬레이션은 결정론적이다 — 같은 틱 수는 같은 상태를 만든다")
	var a := SimWorld.new()
	var b := SimWorld.new()
	for _i in 250:
		a.tick()
		b.tick()
	_equal(a.calendar.elapsed_days, b.calendar.elapsed_days, "경과 일수")
	_equal(a.calendar.season(), b.calendar.season(), "계절")


# --- 러너 ---------------------------------------------------------------------

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
