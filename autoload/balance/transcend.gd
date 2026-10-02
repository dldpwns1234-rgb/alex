extends "res://autoload/balance/story.gd"
## Balance 11부: 초월과 별의 상점 (GDD 7.12절). 최후의 마왕(4000)을 잡은 삶에서 운명까지 내려놓고 별의 파편을 받는다.
## 순서는 Star 열거형과 같다

const STAR_BASE: float = 3.0                   # 6시간 30분 걸린 삶이면 파편 3개
const STAR_REFERENCE_SECONDS: float = 23400.0  # 6시간 30분: 사람 정책 봇의 첫 초월이 6시간 2분이라, 첫 초월에 3개가 나오게 (docs/BALANCE_SIM.md)
const STAR_MIN_SECONDS: float = 60.0           # 0에 가까운 시간으로 나누지 않게

enum Star { WINGS, ECHO, SHORTCUT, AUTO_REBIRTH, AWAKEN, BLESSING }
const STARS: Array[Dictionary] = [
	{"name": "별빛 날개", "max_level": 10},
	{"name": "기억의 잔향", "max_level": 5},
	{"name": "지름길", "max_level": 4},
	{"name": "자동 환생", "max_level": 1},
	{"name": "동료 각성", "max_level": 5},
	{"name": "별의 축복", "max_level": 0},
]
const WINGS_THREADS_PER_LEVEL: float = 5.0   # 초월·환생 직후 운명의 실
const ECHO_LEVELS_PER_LEVEL: int = 2          # 초월·환생 직후 검술·황금의 기억 레벨
const SHORTCUT_STAGES_PER_LEVEL: int = 50     # 환생 조건과 실 공식 기준을 내린다
const BLESSING_MULTIPLIER: float = 10.0       # 모든 피해 ×10 (복리)


## 초월로 받는 별의 파편: max(1, 내림(3 × √(6시간 ÷ 걸린 시간)))
func star_reward(cycle_seconds: float) -> float:
	var ratio := STAR_REFERENCE_SECONDS / maxf(cycle_seconds, STAR_MIN_SECONDS)
	return maxf(1.0, floor(STAR_BASE * sqrt(ratio)))


func star_name(index: int) -> String:
	return STARS[index]["name"]


func star_max_level(index: int) -> int:
	return STARS[index]["max_level"]


## 다음 레벨 비용: 현재 레벨 + 1 (운명의 상점과 같다)
func star_cost(level: int) -> float:
	return float(level + 1)


func wings_threads(level: int) -> float:
	return WINGS_THREADS_PER_LEVEL * level


func echo_levels(level: int) -> int:
	return ECHO_LEVELS_PER_LEVEL * level


func shortcut_stages(level: int) -> int:
	return SHORTCUT_STAGES_PER_LEVEL * level


func blessing_multiplier(level: int) -> float:
	return pow(BLESSING_MULTIPLIER, level)


## 상점에 보여줄 레벨당 효과
func star_note(index: int) -> String:
	match index:
		Star.WINGS:
			return "초월·환생 직후 운명의 실 +%d" % roundi(WINGS_THREADS_PER_LEVEL)
		Star.ECHO:
			return "초월·환생 직후 검술·황금의 기억을 %d레벨씩 들고 시작" % ECHO_LEVELS_PER_LEVEL
		Star.SHORTCUT:
			return "환생 조건 −%d 스테이지" % SHORTCUT_STAGES_PER_LEVEL
		Star.AUTO_REBIRTH:
			return "자동 환생 토글을 연다 (역대 최고가 %d초 안 오르면 스스로 환생)" % roundi(AUTO_PRESTIGE_STALL)
		Star.AWAKEN:
			return "동료 승급 상한 +1단계"
	return "모든 피해 ×%d (복리)" % roundi(BLESSING_MULTIPLIER)


## 지금 레벨의 누적 효과 ("지금 ×100"). 0레벨이거나 토글을 여는 것이면 빈 글
func star_total(index: int, level: int) -> String:
	if level <= 0:
		return ""
	match index:
		Star.WINGS:
			return "실 +%d" % roundi(wings_threads(level))
		Star.ECHO:
			return "+%d레벨" % echo_levels(level)
		Star.SHORTCUT:
			return "환생 %d" % (REBIRTH_MIN_STAGE - shortcut_stages(level))
		Star.AWAKEN:
			return "%d단계" % (PROMOTION_MAX_RANK + level)
		Star.BLESSING:
			return Num.multiplier(blessing_multiplier(level))
	return ""
