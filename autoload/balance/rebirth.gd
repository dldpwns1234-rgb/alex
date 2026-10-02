extends "res://autoload/balance/equipment.gd"
## Balance 8부: 환생 (GDD 7.7절). 회귀를 거듭해 역대 최고 스테이지 500에 닿으면 기억까지 내려놓고 새 삶을 시작한다.
## 운명의 실을 받고 운명의 상점에서 회귀해도, 환생해도 남는 강화를 산다. 순서는 Fate 열거형과 같다.
## 자동 회귀·자동 스킬·자동 강화는 해금(1레벨)이고 켜고 끄는 것은 Automation이 맡는다. 새 운명은 저장 순서 때문에 뒤에 붙인다

const REBIRTH_MIN_STAGE: int = 500        # 환생 조건: 역대 최고 스테이지 (이번 판 포함)
const REBIRTH_BASE_STAGE: int = 450       # 운명의 실 = floor((역대 최고 스테이지 − 450) / 10) → 500에서 5, 600에서 15
const REBIRTH_STAGE_PER_THREAD: int = 10
enum Fate { DESTINY, BOND, FORESIGHT, AUTO_PRESTIGE, AUTO_SKILLS, COMPANION_MEMORY, AUTO_UPGRADE, LEAP }
const FATES: Array[Dictionary] = [
	{"name": "숙명", "max_level": 0},
	{"name": "인연", "max_level": 0},
	{"name": "예지", "max_level": 4},
	{"name": "자동 회귀", "max_level": 1},
	{"name": "자동 스킬", "max_level": 1},
	{"name": "동료 기억", "max_level": 5},
	{"name": "자동 강화", "max_level": 1},
	{"name": "도약", "max_level": 8},
]
const FATE_COST_STEP: int = 1             # 비용 = 현재 레벨 + 1 (1, 2, 3 …)
const DESTINY_MULTIPLIER: float = 3.0     # 숙명: 레벨당 모든 피해 ×3 (복리)
const BOND_MULTIPLIER: float = 2.0        # 인연: 레벨당 기억의 결정 ×2 (복리)
const FORESIGHT_STAGES: int = 25          # 예지: 레벨당 회귀 후 시작 스테이지 +25. 건너뛴 스테이지의 골드는 유산으로 받는다
# 도약: 회귀·환생 뒤 지난 판 최고 − (550 − 50 × 레벨)에서 시작 (1레벨 −500, 8레벨 −150). 예지보다 높을 때만 쓰고 유산도 받는다.
# 한 판의 95%가 한 방 구간(스테이지당 2초)이라 3000스테이지면 한 삶에 1시간 반을 기다렸다 (플레이테스트 2026-10-01). 벽 앞 150스테이지면 몇 분이다.
# 환생 직후 검술을 잃어도 50스테이지쯤이라 여유 150 안이다. 도전 판은 목표를 건너뛰지 않게 도약을 쉰다
const LEAP_BASE_GAP: int = 550
const LEAP_GAP_PER_LEVEL: int = 50
enum Auto { PRESTIGE, MEMORIES, SKILLS, UPGRADE, REBIRTH, TRAINING }  # Automation의 토글. 자동 회귀 운명이 앞 둘을, 자동 스킬이 하나, 자동 강화가 동료·단련 둘을, 자동 환생은 별의 상점이 연다. 저장 순서라 뒤에만 붙인다
const AUTO_NAMES: Array[String] = ["자동 회귀", "결정 자동 구매", "스킬 자동 사용", "동료 자동 강화", "자동 환생", "단련 자동 구매"]
const AUTO_UPGRADE_BUYS_PER_FRAME: int = 10  # 동료 자동 강화: 한 프레임에 사는 횟수 상한 (유산·오프라인 골드를 몇 프레임에 나눠 쓴다)
const AUTO_TRAINING_GOLD_SHARE: float = 0.1  # 단련 자동 구매: 다음 레벨 비용이 가진 골드의 이 몫 이하인 단련을 싼 것부터 (동료 강화에 쓸 골드를 남긴다)
const AUTO_PRESTIGE_STALL: float = 30.0   # 자동 회귀: 최고 스테이지가 이만큼(초) 오르지 않으면 회귀 (13절의 사람 정책)
const COMPANION_MEMORY_PER_LEVEL: float = 0.1  # 동료 기억: 레벨당 지난 판 동료 레벨의 10%를 기억 레벨로 얹고 시작 (비용에는 안 든다)


## cut: 별의 상점 '지름길'이 내리는 스테이지 (조건과 실 공식의 기준을 함께 내린다)
func can_rebirth(best_stage: int, cut: int = 0) -> bool:
	return best_stage >= REBIRTH_MIN_STAGE - cut


## 환생으로 받는 운명의 실. 조건 미달이면 0
func thread_reward(best_stage: int, cut: int = 0) -> float:
	if not can_rebirth(best_stage, cut):
		return 0.0
	return floor(float(best_stage - (REBIRTH_BASE_STAGE - cut)) / REBIRTH_STAGE_PER_THREAD)


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


## 도약이 지난 판 최고에서 얼마나 뒤에서 시작하는지
func leap_gap(level: int) -> int:
	return LEAP_BASE_GAP - LEAP_GAP_PER_LEVEL * level


## 도약 시작 스테이지: 지난 판 최고 − 간격. 레벨이 없으면 1
func leap_start(level: int, previous_best: int) -> int:
	if level <= 0:
		return 1
	return maxi(previous_best - leap_gap(level), 1)


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
		Fate.AUTO_UPGRADE:
			return "살 수 있는 동료 레벨업·승급 중 골드 효율이 가장 좋은 것을 스스로 산다"
		Fate.LEAP:
			return "회귀 후 지난 판 최고 − %d에서 시작, 레벨마다 %d씩 가까이 (예지보다 높을 때, 유산도 받는다. 도전 판은 제외)" % [LEAP_BASE_GAP - LEAP_GAP_PER_LEVEL, LEAP_GAP_PER_LEVEL]
	return "회귀 뒤 동료 레벨의 %d%%를 기억으로 얹고 시작" % roundi(COMPANION_MEMORY_PER_LEVEL * 100.0)


## 지금 레벨의 누적 효과 (상점 줄의 "지금 ×9"). 0레벨이거나 토글을 여는 운명이면 빈 글
func fate_total(index: int, level: int) -> String:
	if level <= 0:
		return ""
	match index:
		Fate.DESTINY:
			return Num.multiplier(destiny_multiplier(level))
		Fate.BOND:
			return Num.multiplier(bond_multiplier(level))
		Fate.FORESIGHT:
			return "시작 %d" % start_stage(level)
		Fate.COMPANION_MEMORY:
			return "%d%%" % roundi(companion_memory_ratio(level) * 100.0)
		Fate.LEAP:
			return "최고 −%d" % leap_gap(level)
	return ""


## 토글을 여는 운명
func auto_fate(kind: int) -> int:
	match kind:
		Auto.SKILLS:
			return Fate.AUTO_SKILLS
		Auto.UPGRADE, Auto.TRAINING:
			return Fate.AUTO_UPGRADE
	return Fate.AUTO_PRESTIGE


func auto_note(kind: int) -> String:
	match kind:
		Auto.PRESTIGE:
			return "최고 스테이지가 %d초 안 오르면 스스로 회귀" % roundi(AUTO_PRESTIGE_STALL)
		Auto.MEMORIES:
			return "회귀하면 결정을 싼 것부터 산다"
		Auto.SKILLS:
			return "쿨타임이 끝나면 스킬을 바로 쓴다"
		Auto.REBIRTH:
			return "환생할 수 있고 %d초 안 오르면 회귀 대신 환생" % roundi(AUTO_PRESTIGE_STALL)
		Auto.TRAINING:
			return "골드의 %d%% 이하인 단련을 싼 것부터 산다" % roundi(AUTO_TRAINING_GOLD_SHARE * 100.0)
	return "살 수 있는 것 중 골드 효율 최고를 산다"
