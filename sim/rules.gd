class_name SimRules
extends RefCounted

## data/rules.json — 밸런싱 상수 (ARCHITECTURE §5, §8).
##
## 코드에 숫자를 박지 않는 이유는 헤드리스 밸런싱 때문이다.
## "3년차에 항상 굶어 죽는다"를 고치려고 소스를 고치게 되면,
## 그 순간부터 밸런싱을 안 하게 된다.

const DATA_PATH := "res://data/rules.json"

var food_per_family: int = 2
var firewood_per_family: int = 1
## 어떤 자원이 난방 연료인가. sim에 문자열을 박지 않기 위해 데이터로 둔다.
var firewood_resource: String = "firewood"

var starting_families: int = 2
var immigration_interval_days: int = 8
## 이주민은 '며칠치 식량이 남아 있는가'를 보고 온다.
## 절대량으로 재면 인구가 늘수록 기준이 헐거워져 먹여 살릴 수 없는 인구까지 불러들인다.
var immigration_food_days_required: int = 10
## 굶은 끼니와 못 땐 장작이 '고난'으로 쌓인다. 가구당 이만큼 쌓이면 한 가구가 떠난다.
##
## 연속 일수로 세지 않는 이유: 하루 굶고 하루 먹기를 반복하는 마을은
## 연속 일수가 매번 초기화되어 만성 부족이 아무 결과도 낳지 않는다.
var hardship_per_family_before_leaving: int = 10
## 부족함 없이 지낸 하루에 갚는 양. 쌓이는 속도보다 느리게 둔다.
var hardship_recovery_per_day: int = 1

## 계절 배율. 인덱스는 SimCalendar.Season 순서 (봄 · 여름 · 가을 · 겨울).
##
## 겨울이 이 게임의 보스전인 이유가 여기 있다 (GDD §3.2):
## 생산은 5분의 1로 떨어지고 장작 소비는 두 배가 된다.
var season_production: Array[float] = [1.0, 1.0, 1.0, 0.2]
var season_food: Array[float] = [1.0, 1.0, 1.0, 1.0]
var season_firewood: Array[float] = [1.0, 0.5, 1.0, 2.0]

## 이만큼의 해를 넘기면 이긴다 (ROADMAP M3).
var years_to_survive: int = 1

const _SEASON_KEYS := ["spring", "summer", "autumn", "winter"]


static func load_default() -> SimRules:
	return from_json(SimJson.read_dict(DATA_PATH))


static func from_json(raw: Dictionary) -> SimRules:
	var rules := SimRules.new()

	var consumption: Dictionary = raw.get("consumption", {})
	rules.food_per_family = int(consumption.get("food_per_family", rules.food_per_family))
	rules.firewood_per_family = int(
		consumption.get("firewood_per_family", rules.firewood_per_family))
	rules.firewood_resource = String(
		consumption.get("firewood_resource", rules.firewood_resource))

	var population: Dictionary = raw.get("population", {})
	rules.starting_families = int(population.get("starting_families", rules.starting_families))
	rules.immigration_interval_days = maxi(1, int(
		population.get("immigration_interval_days", rules.immigration_interval_days)))
	rules.immigration_food_days_required = int(
		population.get("immigration_food_days_required", rules.immigration_food_days_required))
	rules.hardship_per_family_before_leaving = maxi(1, int(population.get(
		"hardship_per_family_before_leaving", rules.hardship_per_family_before_leaving)))
	rules.hardship_recovery_per_day = int(population.get(
		"hardship_recovery_per_day", rules.hardship_recovery_per_day))

	var seasons: Dictionary = raw.get("seasons", {})
	for index in _SEASON_KEYS.size():
		var season: Dictionary = seasons.get(_SEASON_KEYS[index], {})
		rules.season_production[index] = float(
			season.get("production", rules.season_production[index]))
		rules.season_food[index] = float(season.get("food", rules.season_food[index]))
		rules.season_firewood[index] = float(
			season.get("firewood", rules.season_firewood[index]))

	var victory: Dictionary = raw.get("victory", {})
	rules.years_to_survive = maxi(1, int(
		victory.get("years_to_survive", rules.years_to_survive)))

	return rules


func production_multiplier(season: SimCalendar.Season) -> float:
	return season_production[int(season)]


func food_multiplier(season: SimCalendar.Season) -> float:
	return season_food[int(season)]


func firewood_multiplier(season: SimCalendar.Season) -> float:
	return season_firewood[int(season)]
