extends "res://autoload/balance/training.gd"
## 모든 수치와 공식. 다른 파일에 게임 수치를 하드코딩하지 않는다.
## 이 파일은 몬스터, 보스, 시간, 오프라인 보상을 맡고, 용사·레벨업, 동료, 스킬, 회귀·상점, 단련은
## autoload/balance/ 아래 부분 스크립트에 있다 (상속으로 이어져 있어 Balance.로 모두 부른다).
## s = 스테이지

# 몬스터
const MONSTER_BASE_HP: float = 10.0
const MONSTER_HP_GROWTH: float = 1.16   # 단련(M5.5)을 넣으면서 1.15에서 올렸다. docs/BALANCE_SIM.md
const MONSTERS_PER_STAGE: int = 10
const GOLD_PER_HP: float = 1.0 / 15.0
const RESPAWN_DELAY: float = 0.3         # 처치 후 다음 몬스터가 나오기까지 (초)

# 보스: 5의 배수 스테이지에 1마리, 체력 ×10, 제한 시간 30초
const BOSS_STAGE_INTERVAL: int = 5
const BOSS_HP_MULTIPLIER: float = 10.0
const BOSS_TIME_LIMIT: float = 30.0     # 초. 시간의 모래(M5)가 더한다

# 시간
const MAX_DELTA: float = 0.25            # _process delta 상한 (초)

# 오프라인 보상 (GDD 8절)
const OFFLINE_MIN_GAP: float = 10.0               # 초. 이보다 짧은 공백은 그냥 넘어간다
const OFFLINE_MAX_SECONDS: float = 12.0 * 60.0 * 60.0  # 최대 12시간까지 인정
const OFFLINE_BASE_RATE: float = 0.5
# 단잠(OFFLINE_RATE_PER_NAP_LEVEL)은 memory.gd에 있다


## 일반 몬스터 체력: 10 × 1.16^(s − 1)
func monster_hp(stage: int) -> float:
	return MONSTER_BASE_HP * pow(MONSTER_HP_GROWTH, stage - 1)


func is_boss_stage(stage: int) -> bool:
	return stage % BOSS_STAGE_INTERVAL == 0


## 보스 체력: 몬스터 체력 × 10
func boss_hp(stage: int) -> float:
	return monster_hp(stage) * BOSS_HP_MULTIPLIER


## 이 스테이지에 나오는 적의 체력
func enemy_hp(stage: int) -> float:
	return boss_hp(stage) if is_boss_stage(stage) else monster_hp(stage)


## 보스 제한 시간: 30초 + 시간의 모래 3초/레벨
func boss_time_limit(sand_level: int) -> float:
	return BOSS_TIME_LIMIT + sand_bonus(sand_level)


## 기본 처치 골드: 체력 ÷ 15 (보스 포함). 황금의 기억(Prestige)과 황금 손길(Skills)은 Game이 곱한다
func kill_gold(max_hp: float) -> float:
	return max_hp * GOLD_PER_HP


## 오프라인 기준 스테이지: 현재 스테이지, 보스 스테이지면 직전 스테이지
func offline_stage(stage: int) -> int:
	return stage - 1 if is_boss_stage(stage) else stage


## 오프라인 초당 골드: 처치 골드 ÷ (체력 ÷ 동료 DPS 합계 + 0.3). 동료가 없으면 0
func offline_gold_per_second(stage: int, party_dps: float) -> float:
	if party_dps <= 0.0:
		return 0.0
	var hp := monster_hp(offline_stage(stage))
	return kill_gold(hp) / (hp / party_dps + RESPAWN_DELAY)


## 오프라인 보상: 초당 골드 × 경과 초(최대 12시간) × (0.5 + 단잠 레벨 × 0.1 + 안식 단련)
func offline_reward(gold_per_second: float, seconds: float, nap_level: int, extra_rate: float = 0.0) -> float:
	var counted := minf(seconds, OFFLINE_MAX_SECONDS)
	return gold_per_second * counted * (OFFLINE_BASE_RATE + OFFLINE_RATE_PER_NAP_LEVEL * nap_level + extra_rate)
