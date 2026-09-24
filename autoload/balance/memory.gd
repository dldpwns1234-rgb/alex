extends "res://autoload/balance/skills.gd"
## Balance 4부: 회귀와 기억의 상점 (GDD 7절). 순서는 Memory 열거형과 같다

# 회귀: 이번 판 최고 스테이지 120 이상, 결정 floor(10 × 1.1^(최고 스테이지 − 120)). 단련을 넣으면서 100에서 올렸다
const PRESTIGE_MIN_STAGE: int = 120
const PRESTIGE_BASE_CRYSTALS: float = 10.0
const PRESTIGE_GROWTH: float = 1.1

# 기억의 상점. 비용은 2^현재 레벨. max_level 0은 상한 없음
enum Memory { SWORD, GOLD, SAND, MEDITATION, NAP, AWAKENING, WIND }
const MEMORIES: Array[Dictionary] = [
	{"name": "검술의 기억", "max_level": 0},
	{"name": "황금의 기억", "max_level": 0},
	{"name": "시간의 모래", "max_level": 10},
	{"name": "명상", "max_level": 5},
	{"name": "단잠", "max_level": 5},
	{"name": "용사의 각성", "max_level": 10},
	{"name": "바람의 걸음", "max_level": 5},
]
const MEMORY_COST_BASE: float = 2.0
const SWORD_MULTIPLIER: float = 1.5          # 레벨당 모든 피해 ×1.5 (복리)
const GOLD_MEMORY_MULTIPLIER: float = 1.25   # 레벨당 처치 골드 ×1.25 (복리)
const SAND_SECONDS_PER_LEVEL: float = 3.0    # 레벨당 보스 제한 시간 +3초
const AWAKENING_SHARE_PER_LEVEL: float = 0.01  # 레벨당 클릭 피해에 동료 DPS 합계의 1% 추가
const OFFLINE_RATE_PER_NAP_LEVEL: float = 0.1  # 단잠: 레벨당 오프라인 보상 +10%p
const WIND_RESPAWN_CUT_PER_LEVEL: float = 0.03  # 바람의 걸음: 레벨당 재등장 대기 −0.03초 (5레벨이면 0.3초 → 0.15초)
# 명상(MEDITATION_COOLDOWN_CUT)은 skills.gd에 있다


func can_prestige(highest_stage: int) -> bool:
	return highest_stage >= PRESTIGE_MIN_STAGE


## 회귀로 받는 기억의 결정. 조건 미달이면 0
func crystal_reward(highest_stage: int) -> float:
	if not can_prestige(highest_stage):
		return 0.0
	return floor(PRESTIGE_BASE_CRYSTALS * pow(PRESTIGE_GROWTH, highest_stage - PRESTIGE_MIN_STAGE))


func memory_name(index: int) -> String:
	return MEMORIES[index]["name"]


func memory_max_level(index: int) -> int:
	return MEMORIES[index]["max_level"]


## 다음 레벨 비용: 2^현재 레벨 (1, 2, 4, 8…)
func memory_cost(level: int) -> float:
	return pow(MEMORY_COST_BASE, level)


func sword_multiplier(level: int) -> float:
	return pow(SWORD_MULTIPLIER, level)


func gold_memory_multiplier(level: int) -> float:
	return pow(GOLD_MEMORY_MULTIPLIER, level)


func sand_bonus(level: int) -> float:
	return SAND_SECONDS_PER_LEVEL * level


func awakening_share(level: int) -> float:
	return AWAKENING_SHARE_PER_LEVEL * level


func wind_respawn_cut(level: int) -> float:
	return WIND_RESPAWN_CUT_PER_LEVEL * level


## 상점에 보여줄 레벨당 효과. 숫자는 위 상수에서 가져온다
func memory_note(index: int) -> String:
	match index:
		Memory.SWORD:
			return "모든 피해 ×%s (복리)" % SWORD_MULTIPLIER
		Memory.GOLD:
			return "처치 골드 ×%s (복리)" % GOLD_MEMORY_MULTIPLIER
		Memory.SAND:
			return "보스 제한 시간 +%d초" % roundi(SAND_SECONDS_PER_LEVEL)
		Memory.MEDITATION:
			return "스킬 쿨타임 −%d%%" % roundi(MEDITATION_COOLDOWN_CUT * 100.0)
		Memory.NAP:
			return "오프라인 보상 +%d%%p" % roundi(OFFLINE_RATE_PER_NAP_LEVEL * 100.0)
		Memory.AWAKENING:
			return "클릭 피해에 동료 DPS 합계의 %d%% 추가" % roundi(AWAKENING_SHARE_PER_LEVEL * 100.0)
	return "재등장 대기 −%.2f초" % WIND_RESPAWN_CUT_PER_LEVEL
