extends "res://autoload/balance/equipment.gd"
## Balance 8부: 환생 (GDD 7.7절). 회귀를 거듭해 역대 최고 스테이지 500에 닿으면 기억까지 내려놓고 새 삶을 시작한다.
## 운명의 실을 받고 운명의 상점에서 회귀해도, 환생해도 남는 강화를 산다. 순서는 Fate 열거형과 같다.
## 자동 회귀·자동 스킬은 해금(1레벨)이고 켜고 끄는 것은 Automation이 맡는다

const REBIRTH_MIN_STAGE: int = 500        # 환생 조건: 역대 최고 스테이지 (이번 판 포함)
const REBIRTH_BASE_STAGE: int = 450       # 운명의 실 = floor((역대 최고 스테이지 − 450) / 10) → 500에서 5, 600에서 15
const REBIRTH_STAGE_PER_THREAD: int = 10
enum Fate { DESTINY, BOND, FORESIGHT, AUTO_PRESTIGE, AUTO_SKILLS, COMPANION_MEMORY }
const FATES: Array[Dictionary] = [
	{"name": "숙명", "max_level": 0},
	{"name": "인연", "max_level": 0},
	{"name": "예지", "max_level": 4},
	{"name": "자동 회귀", "max_level": 1},
	{"name": "자동 스킬", "max_level": 1},
	{"name": "동료 기억", "max_level": 5},
]
const FATE_COST_STEP: int = 1             # 비용 = 현재 레벨 + 1 (1, 2, 3 …)
const DESTINY_MULTIPLIER: float = 3.0     # 숙명: 레벨당 모든 피해 ×3 (복리)
const BOND_MULTIPLIER: float = 2.0        # 인연: 레벨당 기억의 결정 ×2 (복리)
const FORESIGHT_STAGES: int = 25          # 예지: 레벨당 회귀 후 시작 스테이지 +25. 건너뛴 스테이지의 골드는 유산으로 받는다
enum Auto { PRESTIGE, MEMORIES, SKILLS }  # Automation의 토글. 자동 회귀 운명이 앞 둘을, 자동 스킬 운명이 셋째를 연다
const AUTO_NAMES: Array[String] = ["자동 회귀", "결정 자동 구매", "스킬 자동 사용"]
const AUTO_PRESTIGE_STALL: float = 30.0   # 자동 회귀: 최고 스테이지가 이만큼(초) 오르지 않으면 회귀 (13절의 사람 정책)
const COMPANION_MEMORY_PER_LEVEL: float = 0.1  # 동료 기억: 레벨당 지난 판 동료 레벨의 10%를 가지고 시작


func can_rebirth(best_stage: int) -> bool:
	return best_stage >= REBIRTH_MIN_STAGE


## 환생으로 받는 운명의 실. 조건 미달이면 0
func thread_reward(best_stage: int) -> float:
	if not can_rebirth(best_stage):
		return 0.0
	return floor(float(best_stage - REBIRTH_BASE_STAGE) / REBIRTH_STAGE_PER_THREAD)


func fate_name(index: int) -> String:
	return FATES[index]["name"]


func fate_max_level(index: int) -> int:
	return FATES[index]["max_level"]


## 다음 레벨 비용: 현재 레벨 + 1 실
func fate_cost(level: int) -> float:
	return float(level + FATE_COST_STEP)


func destiny_multiplier(level: int) -> float:
	return pow(DESTINY_MULTIPLIER, level)


func bond_multiplier(level: int) -> float:
	return pow(BOND_MULTIPLIER, level)


## 회귀 뒤 시작 스테이지: 1 + 25 × 예지 레벨
func start_stage(level: int) -> int:
	return 1 + FORESIGHT_STAGES * level


## 동료 기억: 지난 판 레벨의 이 비율만큼 가지고 시작한다
func companion_memory_ratio(level: int) -> float:
	return COMPANION_MEMORY_PER_LEVEL * level


func remembered_level(previous: int, ratio: float) -> int:
	return floori(previous * ratio)


## 상점에 보여줄 레벨당 효과. 숫자는 위 상수에서 가져온다
func fate_note(index: int) -> String:
	match index:
		Fate.DESTINY:
			return "모든 피해 ×%d (복리)" % roundi(DESTINY_MULTIPLIER)
		Fate.BOND:
			return "기억의 결정 ×%d (복리)" % roundi(BOND_MULTIPLIER)
		Fate.FORESIGHT:
			return "회귀 후 시작 스테이지 +%d. 건너뛴 스테이지의 골드를 유산으로 받는다" % FORESIGHT_STAGES
		Fate.AUTO_PRESTIGE:
			return "최고 스테이지가 %d초 동안 오르지 않으면 스스로 회귀하고 결정을 싼 것부터 산다" % roundi(AUTO_PRESTIGE_STALL)
		Fate.AUTO_SKILLS:
			return "쿨타임이 끝나면 스킬을 바로 쓴다"
	return "회귀 뒤 동료가 지난 판 레벨의 %d%%로 시작" % roundi(COMPANION_MEMORY_PER_LEVEL * 100.0)


## 토글을 여는 운명
func auto_fate(kind: int) -> int:
	return Fate.AUTO_SKILLS if kind == Auto.SKILLS else Fate.AUTO_PRESTIGE


func auto_note(kind: int) -> String:
	match kind:
		Auto.PRESTIGE:
			return "최고 스테이지가 %d초 안 오르면 스스로 회귀" % roundi(AUTO_PRESTIGE_STALL)
		Auto.MEMORIES:
			return "회귀하면 결정을 싼 것부터 산다"
	return "쿨타임이 끝나면 스킬을 바로 쓴다"
