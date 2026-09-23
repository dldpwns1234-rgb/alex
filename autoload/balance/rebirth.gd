extends "res://autoload/balance/equipment.gd"
## Balance 8부: 환생 (GDD 7.7절). 회귀를 거듭해 역대 최고 스테이지 500에 닿으면 기억까지 내려놓고 새 삶을 시작한다.
## 운명의 실을 받고 운명의 상점에서 회귀해도, 환생해도 남는 강화를 산다. 순서는 Fate 열거형과 같다

const REBIRTH_MIN_STAGE: int = 500        # 환생 조건: 역대 최고 스테이지 (이번 판 포함)
const REBIRTH_BASE_STAGE: int = 450       # 운명의 실 = floor((역대 최고 스테이지 − 450) / 10) → 500에서 5, 600에서 15
const REBIRTH_STAGE_PER_THREAD: int = 10
enum Fate { DESTINY, BOND, FORESIGHT }
const FATES: Array[Dictionary] = [
	{"name": "숙명", "max_level": 0},
	{"name": "인연", "max_level": 0},
	{"name": "예지", "max_level": 4},
]
const FATE_COST_STEP: int = 1             # 비용 = 현재 레벨 + 1 (1, 2, 3 …)
const DESTINY_MULTIPLIER: float = 3.0     # 숙명: 레벨당 모든 피해 ×3 (복리)
const BOND_MULTIPLIER: float = 2.0        # 인연: 레벨당 기억의 결정 ×2 (복리)
const FORESIGHT_STAGES: int = 25          # 예지: 레벨당 회귀 후 시작 스테이지 +25


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


## 상점에 보여줄 레벨당 효과. 숫자는 위 상수에서 가져온다
func fate_note(index: int) -> String:
	match index:
		Fate.DESTINY:
			return "모든 피해 ×%d (복리)" % roundi(DESTINY_MULTIPLIER)
		Fate.BOND:
			return "기억의 결정 ×%d (복리)" % roundi(BOND_MULTIPLIER)
	return "회귀 후 시작 스테이지 +%d" % FORESIGHT_STAGES
