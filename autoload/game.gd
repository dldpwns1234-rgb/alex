extends Node
## 게임 진행: 골드, 스테이지, 몬스터, 보스. 용사와 동료의 레벨은 Party가 맡는다.
## 상태 변경은 Game과 Party의 함수로만 하고, UI는 시그널을 받아 표시만 한다.

signal gold_changed(gold: float)
signal stage_changed(stage: int)
signal kills_changed(kills: int)
signal monster_spawned(max_hp: float, boss: bool)
signal monster_damaged(hp: float)         # 체력바 갱신용. 탭 피해와 동료 피해 모두
signal tap_hit(amount: float)             # 탭 피해 숫자 연출용
signal monster_killed(reward: float)
signal boss_timer_changed(seconds_left: float)
signal boss_failed()                      # 시간 초과. 보스가 사라지고 파밍 모드로
signal farming_changed(farming: bool)

var gold: float = 0.0
var stage: int = 1
var highest_stage: int = 1          # 이번 판에서 도달한 최고 스테이지. 동료 합류와 회귀(M5)에 쓴다
var kills: int = 0                  # 이번 스테이지에서 처치한 수
var farming: bool = false           # 보스에 실패해 직전 스테이지를 무한 파밍하는 중
var boss_time_left: float = 0.0     # 보스전 남은 시간 (초). 보스전이 아니면 0
var monster_hp: float = 0.0
var monster_max_hp: float = 0.0
var respawn_left: float = 0.0       # 0보다 크면 다음 몬스터를 기다리는 중 (초)


func _ready() -> void:
	reset()


func _process(delta: float) -> void:
	var dt := minf(delta, Balance.MAX_DELTA)
	if respawn_left > 0.0:
		respawn_left -= dt
		if respawn_left <= 0.0:
			_spawn_monster()
		return
	if not is_monster_alive():
		return
	if is_boss_stage():
		boss_time_left -= dt
		boss_timer_changed.emit(maxf(boss_time_left, 0.0))
		if boss_time_left <= 0.0:
			_fail_boss()
			return
	# 동료 피해: 매 프레임 DPS × delta (GDD 3절). 마법사는 보스에게 ×3
	var dps := Party.party_dps(is_boss_stage())
	if dps > 0.0:
		_damage_monster(dps * dt)


## 새 판 시작 상태로 되돌린다. 회귀(M5)에서도 쓴다
func reset() -> void:
	gold = 0.0
	stage = 1
	highest_stage = 1
	kills = 0
	farming = false
	gold_changed.emit(gold)
	stage_changed.emit(stage)
	kills_changed.emit(kills)
	farming_changed.emit(farming)
	_spawn_monster()


## 저장할 상태 (Save가 부른다). 몬스터는 저장하지 않고 불러올 때 새로 낸다
func to_dict() -> Dictionary:
	return {
		"gold": gold,
		"stage": stage,
		"highest_stage": highest_stage,
		"kills": kills,
		"farming": farming,
	}


## 저장 데이터를 적용한다. 없는 필드는 기본값으로 채운다 (옛 저장 호환)
func from_dict(data: Dictionary) -> void:
	gold = maxf(float(data.get("gold", 0.0)), 0.0)
	stage = maxi(int(data.get("stage", 1)), 1)
	highest_stage = maxi(int(data.get("highest_stage", stage)), stage)
	kills = clampi(int(data.get("kills", 0)), 0, Balance.MONSTERS_PER_STAGE - 1)
	farming = bool(data.get("farming", false))
	gold_changed.emit(gold)
	stage_changed.emit(stage)
	kills_changed.emit(kills)
	farming_changed.emit(farming)
	_spawn_monster()


func is_monster_alive() -> bool:
	return respawn_left <= 0.0 and monster_hp > 0.0


func is_boss_stage() -> bool:
	return Balance.is_boss_stage(stage)


## 탭 공격. 재등장을 기다리는 동안에는 피해가 들어가지 않는다
func tap_attack() -> void:
	if not is_monster_alive():
		return
	var amount := Party.click_damage()
	tap_hit.emit(amount)
	_damage_monster(amount)


## 골드를 받는다 (오프라인 보상 등)
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


## 파밍 중에 보스 스테이지로 다시 올라간다. 지금 몬스터는 버리고 보스가 바로 나온다
func challenge_boss() -> void:
	if not farming:
		return
	farming = false
	kills = 0
	farming_changed.emit(farming)
	_advance_stage()
	kills_changed.emit(kills)
	_spawn_monster()


func _damage_monster(amount: float) -> void:
	monster_hp = maxf(monster_hp - amount, 0.0)  # 넘친 피해는 버린다
	monster_damaged.emit(monster_hp)
	if monster_hp <= 0.0:
		_kill_monster()


func _kill_monster() -> void:
	var reward := Balance.kill_gold(monster_max_hp)
	gold += reward
	kills += 1
	boss_time_left = 0.0
	respawn_left = Balance.RESPAWN_DELAY
	gold_changed.emit(gold)
	monster_killed.emit(reward)
	# 보스는 1마리, 일반 스테이지는 10마리. 파밍 중에는 처치 수만 돌고 진행하지 않는다
	if is_boss_stage() or kills >= Balance.MONSTERS_PER_STAGE:
		kills = 0
		if not farming:
			_advance_stage()
	kills_changed.emit(kills)


## 보스 시간 초과: 직전 스테이지로 돌아가 파밍 모드가 된다 (GDD 3절)
func _fail_boss() -> void:
	farming = true
	kills = 0
	boss_time_left = 0.0
	monster_hp = 0.0
	respawn_left = Balance.RESPAWN_DELAY
	stage -= 1
	boss_failed.emit()
	stage_changed.emit(stage)
	kills_changed.emit(kills)
	farming_changed.emit(farming)


func _advance_stage() -> void:
	stage += 1
	highest_stage = maxi(highest_stage, stage)
	stage_changed.emit(stage)


func _spawn_monster() -> void:
	respawn_left = 0.0
	var boss := is_boss_stage()
	monster_max_hp = Balance.enemy_hp(stage)
	monster_hp = monster_max_hp
	boss_time_left = Balance.boss_time_limit() if boss else 0.0
	monster_spawned.emit(monster_max_hp, boss)
	if boss:
		boss_timer_changed.emit(boss_time_left)
