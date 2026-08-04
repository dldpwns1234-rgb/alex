class_name SeasonDisplay
extends RefCounted

## 계절의 표시 방식 — 이름과 색.
##
## sim 계층은 계절을 enum으로만 알고 있다 (ARCHITECTURE §2 규칙 2).
## 한글 이름과 색은 표현의 영역이므로 game 계층인 여기에 둔다.

const NAMES := {
	SimCalendar.Season.SPRING: "봄",
	SimCalendar.Season.SUMMER: "여름",
	SimCalendar.Season.AUTUMN: "가을",
	SimCalendar.Season.WINTER: "겨울",
}

## M5에서 셰이더 오버레이로 대체된다 (ARCHITECTURE §6.3).
## 지금은 계절이 바뀌는 것을 눈으로 확인하기 위한 배경색이다.
const COLORS := {
	SimCalendar.Season.SPRING: Color(0.22, 0.30, 0.24),
	SimCalendar.Season.SUMMER: Color(0.20, 0.31, 0.20),
	SimCalendar.Season.AUTUMN: Color(0.33, 0.26, 0.17),
	SimCalendar.Season.WINTER: Color(0.20, 0.25, 0.33),
}


static func name_of(season: SimCalendar.Season) -> String:
	return NAMES.get(season, "?")


static func color_of(season: SimCalendar.Season) -> Color:
	return COLORS.get(season, Color.BLACK)


## "1년차 · 봄 15일"
static func format_date(calendar: SimCalendar) -> String:
	return "%d년차 · %s %d일" % [
		calendar.year(),
		name_of(calendar.season()),
		calendar.day_of_season(),
	]
