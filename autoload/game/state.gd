extends Node
## Game 1부: 상태, 저장, 골드, 스테이지 진행과 몬스터 등장. 전투 흐름은 game.gd에 있다.
## Game이 200줄을 넘지 않도록 Balance처럼 상속으로 이어 붙였다. 바깥에서는 Game.만 쓴다.

const Dungeon := preload("res://autoload/dungeon.gd")

signal gold_changed(gold: float)
signal stage_changed(stage: int)
signal kills_changed(kills: int)
signal monster_spawned(max_hp: float, boss: bool)
signal monster_damaged(hp: float)         # 체력바 갱신용. 탭 피해와 동료 피해 모두
signal tap_hit(amount: float, crit: bool)  # 탭 피해 숫자 연출용. crit는 클릭 치명타
signal monster_killed(reward: float)
signal chain_killed(count: int, reward: float)  # 넘친 피해로 같은 스테이지의 다음 몬스터들을 연달아 잡았다 (첫 처치는 monster_killed)
signal demon_king_defeated()          # 마왕(1000의 배수 스테이지 보스)을 잡았다. 엔딩과 통계에 쓴다
signal tower_changed(in_tower: bool)  # 별도 모드(시련의 탑·심연)에 들어가거나 나왔다. 어느 쪽인지는 dungeon
signal cleared_changed(cleared: bool)       # 최종 스테이지의 마왕을 잡아 더 나아갈 곳이 없다 (회귀·환생으로만)
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
var in_tower: bool = false          # 별도 모드(시련의 탑·심연) 안. 저장하지 않는다 (불러오면 본편)
var dungeon: Dungeon = null         # 들어온 모드 (Tower 또는 Abyss). in_tower일 때만 뜻이 있다
var cleared: bool = false           # 최종 스테이지 돌파. 몬스터가 나오지 않는다. 저장하지 않는다 (불러오면 최후의 마왕이 다시 나온다)
var tap_rate: float = 0.0           # 최근 창의 초당 탭 수. 자동 재도전의 예상 DPS에 쓴다
var _taps_in_window: int = 0
var _tap_window_left: float = 0.0
var _farm_seconds: float = 0.0      # 파밍 시작(또는 취소) 뒤 흐른 시간. 음수면 자동 재도전을 그만큼 미룬다


## 새 판 시작 상태로 되돌린다. 회귀(M5)에서도 쓴다
func reset() -> void:
	_drop_tower()
	stage = Rebirth.start_stage(highest_stage)  # 예지·도약(운명의 상점)이 있으면 앞 스테이지를 건너뛰고 그만큼의 골드를 유산으로 받는다. 아직 지난 판의 최고다
	gold = minf(Rebirth.inheritance(stage), Balance.MAX_NUMBER)
	cleared = false
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
		"kills": 0 if in_tower else kills,  # 탑의 처치 수는 본편 것이 아니다
		"farming": farming,
		"auto_retry": auto_retry,
	}


## 저장 데이터를 적용한다. 없는 필드는 기본값으로 채운다 (옛 저장 호환)
func from_dict(data: Dictionary) -> void:
	_drop_tower()
	gold = clampf(float(data.get("gold", 0.0)), 0.0, Balance.MAX_NUMBER)  # 무한대가 든 옛 저장도 살린다
	stage = clampi(int(data.get("stage", 1)), 1, Balance.FINAL_STAGE)
	highest_stage = clampi(int(data.get("highest_stage", stage)), stage, Balance.FINAL_STAGE)
	cleared = false
	kills = clampi(int(data.get("kills", 0)), 0, Balance.MONSTERS_PER_STAGE - 1)
	farming = bool(data.get("farming", false))
	auto_retry = bool(data.get("auto_retry", true))
	_farm_seconds = 0.0
	boss_queued = false  # 가져오기 전 세션의 보스 예약이 남으면 보스 실패 뒤 첫 처치에 곧바로 재도전한다
	gold_changed.emit(gold)
	stage_changed.emit(stage)
	kills_changed.emit(kills)
	farming_changed.emit(farming)
	auto_retry_changed.emit(auto_retry)
	boss_queued_changed.emit(boss_queued)
	_spawn_monster()


func set_auto_retry(on: bool) -> void:
	auto_retry = on
	auto_retry_changed.emit(auto_retry)


## 보스전의 제한 시간: (기본 + 시간의 모래 + 화염 폭발 단련 + 도전 보너스, 마왕이면 +30초) × 시간의 채찍. at_stage는 기본이 지금 스테이지
func boss_limit(at_stage: int = stage) -> float:
	var limit := Balance.boss_time_limit(Prestige.effect_level(Balance.Memory.SAND), at_stage)
	limit += Training.value(Balance.Effect.BOSS_TIME) + Challenges.boss_time_bonus()
	return limit * Challenges.boss_time_scale()


func is_monster_alive() -> bool:
	return respawn_left <= 0.0 and monster_hp > 0.0


## 탑 안에서는 보스가 없다 (마법사 보스 배율, 보스 타이머, 파밍 조작이 본편 스테이지를 따르지 않게)
func is_boss_stage() -> bool:
	return Balance.is_boss_stage(stage) and not in_tower


## 그림과 배경에 쓰는 스테이지. 탑·심연 안이면 그 층의 그림
func visual_stage() -> int:
	return dungeon.visual_stage() if in_tower else stage


## 별도 모드에 들어간다·나온다 (Tower·Abyss가 부른다). 본편의 몬스터는 다시 나온다
func enter_tower(source: Dungeon = null) -> void:
	dungeon = source if source != null else Tower
	_switch_tower(true)


func exit_tower() -> void:
	_switch_tower(false)


## 판을 새로 시작하거나 불러오면 탑 밖이다 (Tower는 회귀·환생 시그널로 층을 지운다)
func _drop_tower() -> void:
	if in_tower:
		in_tower = false
		tower_changed.emit(false)


## 몬스터를 먼저 바꾸고 알린다: 나올 때 알림이 먼저 가면 상단 바가 아직 남은 탑 몬스터를 본편 보스로 읽어 '보스 0초'를 띄웠다
func _switch_tower(inside: bool) -> void:
	in_tower = inside
	kills = 0
	boss_queued = false
	_spawn_monster()
	tower_changed.emit(inside)
	boss_queued_changed.emit(boss_queued)
	kills_changed.emit(kills)


## 다음 몬스터가 나오기까지: 0.3초에서 도발 단련과 바람의 걸음(기억의 상점)을 뺀 값. 최소 0.05초
func respawn_delay() -> float:
	var delay := Balance.RESPAWN_DELAY + Training.value(Balance.Effect.RESPAWN_DELAY) - Prestige.wind_respawn_cut()
	return maxf(delay, Balance.MIN_RESPAWN_DELAY) * Abyss.respawn_multiplier()  # 심연의 느린 숨


## 처치 골드와 오프라인 보상, 유산에 공통으로 곱하는 배율: 황금의 기억 × 업적 × 장신구 (스킬·단련은 각자 얹는다)
func gold_multiplier() -> float:
	return Prestige.gold_multiplier() * Achievements.gold_multiplier() * Equipment.gold_multiplier()


func add_gold(amount: float) -> void:
	gold = minf(gold + amount, Balance.MAX_NUMBER)
	gold_changed.emit(gold)


## 골드를 치른다. 모자라면 false
func spend(cost: float) -> bool:
	if gold < cost:
		return false
	gold -= cost
	gold_changed.emit(gold)
	return true


## 다음 스테이지. 최종 스테이지의 보스를 잡았으면 더 나아가지 않고 돌파 상태가 된다 (몬스터가 나오지 않는다)
func _advance_stage() -> void:
	if stage >= Balance.FINAL_STAGE:
		cleared = true
		cleared_changed.emit(true)
		return
	stage += 1
	highest_stage = maxi(highest_stage, stage)
	stage_changed.emit(stage)


func _spawn_monster() -> void:
	respawn_left = 0.0
	if cleared and not in_tower:  # 돌파 뒤에도 탑은 그대로 오른다 (탑 몬스터는 본편 스테이지와 무관)
		monster_hp = 0.0
		return
	var boss := is_boss_stage()
	monster_max_hp = dungeon.monster_hp() if in_tower else Balance.enemy_hp(stage)
	monster_hp = monster_max_hp
	boss_time_left = boss_limit(stage) if boss else 0.0
	monster_spawned.emit(monster_max_hp, boss or (in_tower and dungeon.is_boss_floor()))  # 심연의 두목도 두목 그림
	if boss:
		boss_timer_changed.emit(boss_time_left)
