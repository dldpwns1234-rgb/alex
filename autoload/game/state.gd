extends Node
## Game 1부: 상태, 저장, 골드, 스테이지 진행과 몬스터 등장. 전투 흐름은 game.gd에 있다.
## Game이 200줄을 넘지 않도록 Balance처럼 상속으로 이어 붙였다. 바깥에서는 Game.만 쓴다.

signal gold_changed(gold: float)
signal stage_changed(stage: int)
signal kills_changed(kills: int)
signal monster_spawned(max_hp: float, boss: bool)
signal monster_damaged(hp: float)         # 체력바 갱신용. 탭 피해와 동료 피해 모두
signal tap_hit(amount: float, crit: bool)  # 탭 피해 숫자 연출용. crit는 클릭 치명타
signal monster_killed(reward: float)
signal boss_timer_changed(seconds_left: float)
signal boss_failed()                      # 시간 초과. 보스가 사라지고 파밍 모드로
signal farming_changed(farming: bool)
signal boss_queued_changed(queued: bool)  # 지금 몬스터를 잡으면 보스가 나오도록 예약됨
signal auto_retry_changed(on: bool)

var gold: float = 0.0
var stage: int = 1
var highest_stage: int = 1          # 이번 판에서 도달한 최고 스테이지. 동료 합류와 회귀(M5)에 쓴다
var kills: int = 0                  # 이번 스테이지에서 처치한 수
var farming: bool = false           # 보스에 실패해 직전 스테이지를 무한 파밍하는 중
var boss_queued: bool = false       # 파밍 중 보스 도전을 눌러 둔 상태. 지금 몬스터를 잡으면 보스가 나온다
var boss_time_left: float = 0.0     # 보스전 남은 시간 (초). 보스전이 아니면 0
var monster_hp: float = 0.0
var monster_max_hp: float = 0.0
var respawn_left: float = 0.0       # 0보다 크면 다음 몬스터를 기다리는 중 (초)
var auto_retry: bool = true         # 파밍 중 잡을 수 있을 것 같으면 스스로 보스에 도전 (저장됨)
var tap_rate: float = 0.0           # 최근 창의 초당 탭 수. 자동 재도전의 예상 DPS에 쓴다
var _taps_in_window: int = 0
var _tap_window_left: float = 0.0
var _farm_seconds: float = 0.0      # 파밍 시작(또는 취소) 뒤 흐른 시간. 음수면 자동 재도전을 그만큼 미룬다


## 새 판 시작 상태로 되돌린다. 회귀(M5)에서도 쓴다
func reset() -> void:
	stage = Rebirth.start_stage()  # 예지(운명의 상점)가 있으면 앞 스테이지를 건너뛰고 그만큼의 골드를 유산으로 받는다
	gold = Rebirth.inheritance()
	highest_stage = stage
	kills = 0
	farming = false
	boss_queued = false
	_farm_seconds = 0.0
	tap_rate = 0.0
	_taps_in_window = 0
	gold_changed.emit(gold)
	stage_changed.emit(stage)
	kills_changed.emit(kills)
	farming_changed.emit(farming)
	boss_queued_changed.emit(boss_queued)
	_spawn_monster()


## 저장할 상태 (Save가 부른다). 몬스터는 저장하지 않고 불러올 때 새로 낸다
func to_dict() -> Dictionary:
	return {
		"gold": gold,
		"stage": stage,
		"highest_stage": highest_stage,
		"kills": kills,
		"farming": farming,
		"auto_retry": auto_retry,
	}


## 저장 데이터를 적용한다. 없는 필드는 기본값으로 채운다 (옛 저장 호환)
func from_dict(data: Dictionary) -> void:
	gold = maxf(float(data.get("gold", 0.0)), 0.0)
	stage = maxi(int(data.get("stage", 1)), 1)
	highest_stage = maxi(int(data.get("highest_stage", stage)), stage)
	kills = clampi(int(data.get("kills", 0)), 0, Balance.MONSTERS_PER_STAGE - 1)
	farming = bool(data.get("farming", false))
	auto_retry = bool(data.get("auto_retry", true))
	_farm_seconds = 0.0
	gold_changed.emit(gold)
	stage_changed.emit(stage)
	kills_changed.emit(kills)
	farming_changed.emit(farming)
	auto_retry_changed.emit(auto_retry)
	_spawn_monster()


func set_auto_retry(on: bool) -> void:
	auto_retry = on
	auto_retry_changed.emit(auto_retry)


## 이번 보스전의 제한 시간: 기본 + 시간의 모래 + 화염 폭발 단련
func boss_limit() -> float:
	return Balance.boss_time_limit(Prestige.level(Balance.Memory.SAND)) + Training.value(Balance.Effect.BOSS_TIME)


## 파밍 중인 스테이지 다음의 보스를 지금 DPS(동료 + 클릭 × 최근 탭 빈도)로 제한 시간 안에 잡을 것 같은지
func boss_looks_beatable() -> bool:
	var dps := Party.party_dps(true) + Party.click_damage() * tap_rate
	return Balance.boss_beatable(Balance.boss_hp(stage + 1), dps, boss_limit())


func is_monster_alive() -> bool:
	return respawn_left <= 0.0 and monster_hp > 0.0


func is_boss_stage() -> bool:
	return Balance.is_boss_stage(stage)


## 다음 몬스터가 나오기까지: 0.3초에서 도발 단련과 바람의 걸음(기억의 상점)을 뺀 값. 최소 0.05초
func respawn_delay() -> float:
	var delay := Balance.RESPAWN_DELAY + Training.value(Balance.Effect.RESPAWN_DELAY) - Prestige.wind_respawn_cut()
	return maxf(delay, Balance.MIN_RESPAWN_DELAY)


## 처치 골드와 오프라인 보상, 유산에 공통으로 곱하는 배율: 황금의 기억 × 업적 × 장신구 (스킬·단련은 각자 얹는다)
func gold_multiplier() -> float:
	return Prestige.gold_multiplier() * Achievements.gold_multiplier() * Equipment.gold_multiplier()


func add_gold(amount: float) -> void:
	gold += amount
	gold_changed.emit(gold)


## 골드를 치른다. 모자라면 false
func spend(cost: float) -> bool:
	if gold < cost:
		return false
	gold -= cost
	gold_changed.emit(gold)
	return true


func _advance_stage() -> void:
	stage += 1
	highest_stage = maxi(highest_stage, stage)
	stage_changed.emit(stage)


func _spawn_monster() -> void:
	respawn_left = 0.0
	var boss := is_boss_stage()
	monster_max_hp = Balance.enemy_hp(stage)
	monster_hp = monster_max_hp
	boss_time_left = boss_limit() if boss else 0.0
	monster_spawned.emit(monster_max_hp, boss)
	if boss:
		boss_timer_changed.emit(boss_time_left)
