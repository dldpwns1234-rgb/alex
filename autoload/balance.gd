extends "res://autoload/balance/challenges.gd"
## 모든 수치와 공식. 다른 파일에 게임 수치를 하드코딩하지 않는다.
## 이 파일은 몬스터, 보스, 시간, 오프라인 보상을 맡고, 용사·레벨업, 동료, 스킬, 회귀·상점, 단련, 업적, 장비, 환생, 도전은
## autoload/balance/ 아래 부분 스크립트에 있다 (상속으로 이어져 있어 Balance.로 모두 부른다).
## s = 스테이지

# 몬스터
const MONSTER_BASE_HP: float = 10.0
const MONSTER_HP_GROWTH: float = 1.17   # 단련에서 1.15→1.16, 업적·승급·장비(M8)에서 1.17로 올렸다. docs/BALANCE_SIM.md
const MONSTERS_PER_STAGE: int = 10
const GOLD_PER_HP: float = 1.0 / 15.0
const RESPAWN_DELAY: float = 0.3         # 처치 후 다음 몬스터가 나오기까지 (초). 도발 단련과 바람의 걸음이 줄인다
const MIN_RESPAWN_DELAY: float = 0.05    # 아무리 줄여도 이 아래로는 안 간다 (0이면 재등장이 걸리지 않는다)

# 보스: 5의 배수 스테이지에 1마리, 체력 ×10, 제한 시간 30초
const BOSS_STAGE_INTERVAL: int = 5
const BOSS_HP_MULTIPLIER: float = 10.0
const BOSS_TIME_LIMIT: float = 30.0     # 초. 시간의 모래(M5)가 더한다
# 보스 자동 재도전 (GDD 3절): 파밍 중 지금 DPS로 제한 시간의 이 비율 안에 잡을 것 같으면 스스로 도전한다
const AUTO_RETRY_MARGIN: float = 0.9
const AUTO_RETRY_REST: float = 10.0      # 초. 실패 직후 최소 파밍 시간 (예상이 빗나가도 연속 실패로 파밍을 잃지 않게)
const AUTO_RETRY_INTERVAL: float = 120.0 # 초. 탭하는 중이면 예상과 무관하게 이만큼마다 한 번 더 해 본다
const TAP_RATE_WINDOW: float = 5.0       # 초. 최근 탭 빈도를 재는 창. 예상 DPS에 클릭 피해 × 빈도를 더한다

# 마왕성 (GDD 7.8절): 600부터 마왕성 지역, 1000(과 그 배수)의 보스는 마왕
const CASTLE_STAGE: int = 600
const DEMON_KING_INTERVAL: int = 1000
const DEMON_KING_HP_MULTIPLIER: float = 3.0   # 마왕 체력 = 보스 체력 × 3
const DEMON_KING_EXTRA_TIME: float = 30.0     # 마왕전 제한 시간에 더하는 초

# 시련의 탑 (GDD 7.10절): 역대 최고 100부터, 입장권 하루 3장, 한 층은 60초 안에 10마리
const TOWER_UNLOCK_STAGE: int = 100
const TOWER_TICKETS_PER_DAY: int = 3
const TOWER_TIME_LIMIT: float = 60.0
const TOWER_STAGE_BASE: int = 100          # f층 몬스터 = 스테이지 (100 + 10f)의 일반 몬스터
const TOWER_STAGE_STEP: int = 10
const TOWER_STONES_PER_FLOOR: float = 1.0  # 첫 돌파 보상 강화석 = 층 × 1
const TOWER_THREAD_FLOOR_STEP: int = 10    # 10층마다 운명의 실 (층 ÷ 10)

# 시간
const MAX_DELTA: float = 0.25            # _process delta 상한 (초)

# 오프라인 보상 (GDD 8절)
const OFFLINE_MIN_GAP: float = 10.0               # 초. 이보다 짧은 공백은 그냥 넘어간다
const OFFLINE_MAX_SECONDS: float = 12.0 * 60.0 * 60.0  # 최대 12시간까지 인정
const OFFLINE_BASE_RATE: float = 0.5
# 단잠(OFFLINE_RATE_PER_NAP_LEVEL)은 memory.gd에 있다


## 일반 몬스터 체력: 10 × 1.17^(s − 1)
func monster_hp(stage: int) -> float:
	return MONSTER_BASE_HP * pow(MONSTER_HP_GROWTH, stage - 1)


func is_boss_stage(stage: int) -> bool:
	return stage % BOSS_STAGE_INTERVAL == 0


## 보스 체력: 몬스터 체력 × 10
func boss_hp(stage: int) -> float:
	return monster_hp(stage) * BOSS_HP_MULTIPLIER


func is_castle_stage(stage: int) -> bool:
	return stage >= CASTLE_STAGE


func is_demon_king_stage(stage: int) -> bool:
	return stage > 0 and stage % DEMON_KING_INTERVAL == 0


## 이 스테이지에 나오는 적의 체력. 마왕은 보스 체력의 3배
func enemy_hp(stage: int) -> float:
	if is_demon_king_stage(stage):
		return boss_hp(stage) * DEMON_KING_HP_MULTIPLIER
	return boss_hp(stage) if is_boss_stage(stage) else monster_hp(stage)


## 보스 제한 시간: 30초 + 시간의 모래 3초/레벨 (+ 마왕전 30초)
func boss_time_limit(sand_level: int, stage: int = 1) -> float:
	var limit := BOSS_TIME_LIMIT + sand_bonus(sand_level)
	return limit + DEMON_KING_EXTRA_TIME if is_demon_king_stage(stage) else limit


## 자동 재도전 판단: 체력 hp의 보스를 초당 dps로 제한 시간 limit의 여유 안에 잡을 수 있는지
func boss_beatable(hp: float, dps: float, limit: float) -> bool:
	return dps > 0.0 and hp / dps <= limit * AUTO_RETRY_MARGIN


## 기본 처치 골드: 체력 ÷ 15 (보스 포함). 황금의 기억(Prestige)과 황금 손길(Skills)은 Game이 곱한다
func kill_gold(max_hp: float) -> float:
	return max_hp * GOLD_PER_HP


## 오프라인 기준 스테이지: 현재 스테이지, 보스 스테이지면 직전 스테이지
func offline_stage(stage: int) -> int:
	return stage - 1 if is_boss_stage(stage) else stage


## 오프라인 초당 골드: 처치 골드 ÷ (체력 ÷ 동료 DPS 합계 + 재등장 대기). 동료가 없으면 0. respawn은 실제 대기(Game.respawn_delay())
func offline_gold_per_second(stage: int, party_dps: float, respawn: float = RESPAWN_DELAY) -> float:
	if party_dps <= 0.0:
		return 0.0
	var hp := monster_hp(offline_stage(stage))
	return kill_gold(hp) / (hp / party_dps + respawn)


## 오프라인 보상: 초당 골드 × 경과 초(최대 12시간) × (0.5 + 단잠 레벨 × 0.1 + 안식 단련)
func offline_reward(gold_per_second: float, seconds: float, nap_level: int, extra_rate: float = 0.0) -> float:
	var counted := minf(seconds, OFFLINE_MAX_SECONDS)
	return gold_per_second * counted * (OFFLINE_BASE_RATE + OFFLINE_RATE_PER_NAP_LEVEL * nap_level + extra_rate)


## 유산: 예지가 건너뛴 스테이지(1 ~ 시작 − 1)에서 얻었을 골드. 스테이지마다 일반 몬스터 10마리 처치 골드 × 골드 배율.
## 환생 직후 기억 없이 101스테이지에 서면 첫 몬스터에 한 시간이 걸리던 함정을 막는다 (docs/BALANCE_SIM.md 2026-09-24)
func inheritance_gold(start: int, gold_multiplier: float) -> float:
	var total := 0.0
	for stage in range(1, start):
		total += MONSTERS_PER_STAGE * kill_gold(monster_hp(stage))
	return total * gold_multiplier


## 시련의 탑 f층에 해당하는 스테이지 (몬스터 체력과 그림에 쓴다)
func tower_stage(floor: int) -> int:
	return TOWER_STAGE_BASE + TOWER_STAGE_STEP * floor


func tower_monster_hp(floor: int) -> float:
	return monster_hp(tower_stage(floor))


## 첫 돌파 보상: 강화석은 층마다, 운명의 실은 10층마다 (층 ÷ 10)
func tower_stones(floor: int) -> float:
	return TOWER_STONES_PER_FLOOR * floor


func tower_threads(floor: int) -> float:
	@warning_ignore("integer_division")
	return float(floor / TOWER_THREAD_FLOOR_STEP) if floor % TOWER_THREAD_FLOOR_STEP == 0 else 0.0
