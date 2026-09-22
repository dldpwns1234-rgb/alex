extends Node
## 한국식 숫자 표기 (GDD 10절). 화면에 숫자를 보일 때는 항상 format()을 쓴다.

## 10^4부터 네 자리마다 하나씩. 만(10^4) … 무량대수(10^68)
const UNITS: PackedStringArray = [
	"만", "억", "조", "경", "해", "자", "양", "구", "간",
	"정", "재", "극", "항하사", "아승기", "나유타", "불가사의", "무량대수",
]
const UNIT_BASE: float = 10000.0
const SCIENTIFIC_LIMIT: float = 1e72
## 부동소수 오차 허용치. 경계값(10, 100, 1만, 10^72)에 이만큼 못 미치면 경계값으로 본다.
## 없으면 1e8이 "9999.99만"처럼 잘리거나, 버림 뒤 "10.00만"처럼 자릿수가 어긋난다
const EPSILON: float = 1e-9


func format(value: float) -> String:
	if is_nan(value) or is_inf(value):
		return "∞"
	if value < 0.0:
		return "-" + format(-value)
	if value < UNIT_BASE:
		return "%.0f" % floor(value)
	if value >= SCIENTIFIC_LIMIT:
		return _scientific(value)

	var unit_index := floori(log(value) / log(UNIT_BASE))  # 1 = 만, 2 = 억 …
	var mantissa := value / pow(UNIT_BASE, unit_index)
	# log와 나눗셈의 부동소수 오차로 단위가 한 칸 어긋난 경우를 바로잡는다
	if mantissa >= UNIT_BASE - EPSILON:
		unit_index += 1
		mantissa = 1.0
	elif mantissa < 1.0:
		unit_index -= 1
		mantissa *= UNIT_BASE
	if unit_index > UNITS.size():
		return _scientific(value)
	return _truncated(mantissa) + UNITS[unit_index - 1]


## 단위 앞 숫자: 10 미만은 소수 둘째, 100 미만은 첫째, 그 이상은 정수. 반올림하지 않고 버린다
func _truncated(mantissa: float) -> String:
	if mantissa < 10.0 - EPSILON:
		return "%.2f" % (floor(mantissa * 100.0 + EPSILON) / 100.0)
	if mantissa < 100.0 - EPSILON:
		return "%.1f" % (floor(mantissa * 10.0 + EPSILON) / 10.0)
	return "%.0f" % floor(mantissa + EPSILON)


## 10^72 이상: 1.23e72
func _scientific(value: float) -> String:
	var exponent := floori(log(value) / log(10.0))
	var mantissa := value / pow(10.0, exponent)
	if mantissa >= 10.0 - EPSILON:
		exponent += 1
		mantissa = 1.0
	elif mantissa < 1.0:
		exponent -= 1
		mantissa *= 10.0
	return "%.2fe%d" % [floor(mantissa * 100.0 + EPSILON) / 100.0, exponent]


## 초를 "1시간 2분 5초"로. 0인 단위는 빼고, 1초 미만이면 "0초"
func format_duration(seconds: float) -> String:
	var total := floori(maxf(seconds, 0.0))
	var parts: PackedStringArray = []
	@warning_ignore("integer_division")
	var hours := total / 3600
	@warning_ignore("integer_division")
	var minutes := (total % 3600) / 60
	var secs := total % 60
	if hours > 0:
		parts.append("%d시간" % hours)
	if minutes > 0:
		parts.append("%d분" % minutes)
	if secs > 0 or parts.is_empty():
		parts.append("%d초" % secs)
	return " ".join(parts)
