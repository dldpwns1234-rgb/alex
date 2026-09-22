extends Node
## 게임 진행: 골드, 스테이지, 몬스터. 용사와 동료의 레벨은 Party가 맡는다.
## 상태 변경은 Game과 Party의 함수로만 하고, UI는 시그널을 받아 표시만 한다.

signal gold_changed(gold: float)
signal stage_changed(stage: int)
signal kills_changed(kills: int)
signal monster_spawned(max_hp: float)
signal monster_damaged(hp: float)   # 체력바 갱신용. 탭 피해와 동료 피해 모두
signal tap_hit(amount: float)       # 탭 피해 숫자 연출용
signal monster_killed(reward: float)

var gold: float = 0.0
var stage: int = 1
var highest_stage: int = 1          # 이번 판에서 도달한 최고 스테이지. 동료 합류와 회귀(M5)에 쓴다
var kills: int = 0                  # 이번 스테이지에서 처치한 수
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
	# 동료 피해: 매 프레임 DPS × delta (GDD 3절)
	var dps := Party.party_dps(false)
	if dps > 0.0 and is_monster_alive():
		_damage_monster(dps * dt)


## 새 판 시작 상태로 되돌린다. 회귀(M5)에서도 쓴다
func reset() -> void:
	gold = 0.0
	stage = 1
	highest_stage = 1
	kills = 0
	gold_changed.emit(gold)
	stage_changed.emit(stage)
	kills_changed.emit(kills)
	_spawn_monster()


func is_monster_alive() -> bool:
	return respawn_left <= 0.0 and monster_hp > 0.0


## 탭 공격. 재등장을 기다리는 동안에는 피해가 들어가지 않는다
func tap_attack() -> void:
	if not is_monster_alive():
		return
	var amount := Party.click_damage()
	tap_hit.emit(amount)
	_damage_monster(amount)


## 골드를 치른다. 모자라면 false
func spend(cost: float) -> bool:
	if gold < cost:
		return false
	gold -= cost
	gold_changed.emit(gold)
	return true


func _damage_monster(amount: float) -> void:
	monster_hp = maxf(monster_hp - amount, 0.0)  # 넘친 피해는 버린다
	monster_damaged.emit(monster_hp)
	if monster_hp <= 0.0:
		_kill_monster()


func _kill_monster() -> void:
	var reward := Balance.kill_gold(monster_max_hp)
	gold += reward
	kills += 1
	respawn_left = Balance.RESPAWN_DELAY
	gold_changed.emit(gold)
	monster_killed.emit(reward)
	if kills >= Balance.MONSTERS_PER_STAGE:
		kills = 0
		_advance_stage()
	kills_changed.emit(kills)


func _advance_stage() -> void:
	stage += 1
	highest_stage = maxi(highest_stage, stage)
	stage_changed.emit(stage)


func _spawn_monster() -> void:
	respawn_left = 0.0
	monster_max_hp = Balance.monster_hp(stage)
	monster_hp = monster_max_hp
	monster_spawned.emit(monster_max_hp)
