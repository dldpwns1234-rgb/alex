extends Node
## 게임 상태와 진행. 상태 변경은 여기서만 한다. UI는 시그널을 받아 표시만 한다.

signal gold_changed(gold: float)
signal stage_changed(stage: int)
signal kills_changed(kills: int)
signal hero_changed(level: int)
signal monster_spawned(max_hp: float)
signal monster_damaged(hp: float, amount: float)
signal monster_killed(reward: float)

var gold: float = 0.0
var stage: int = 1
var kills: int = 0                 # 이번 스테이지에서 처치한 수
var hero_level: int = Balance.HERO_START_LEVEL
var monster_hp: float = 0.0
var monster_max_hp: float = 0.0
var respawn_left: float = 0.0      # 0보다 크면 다음 몬스터를 기다리는 중 (초)


func _ready() -> void:
	_spawn_monster()


func _process(delta: float) -> void:
	var dt := minf(delta, Balance.MAX_DELTA)
	if respawn_left > 0.0:
		respawn_left -= dt
		if respawn_left <= 0.0:
			_spawn_monster()


func is_monster_alive() -> bool:
	return respawn_left <= 0.0 and monster_hp > 0.0


func click_damage() -> float:
	return Balance.hero_click_damage(hero_level)


func hero_cost() -> float:
	return Balance.hero_level_cost(hero_level)


func can_buy_hero_level() -> bool:
	return gold >= hero_cost()


## 탭 공격. 재등장을 기다리는 동안에는 피해가 들어가지 않는다
func tap_attack() -> void:
	if not is_monster_alive():
		return
	_damage_monster(click_damage())


## 용사 레벨 1 구매. 골드가 모자라면 false
func buy_hero_level() -> bool:
	if not can_buy_hero_level():
		return false
	gold -= hero_cost()
	hero_level += 1
	gold_changed.emit(gold)
	hero_changed.emit(hero_level)
	return true


func _damage_monster(amount: float) -> void:
	monster_hp = maxf(monster_hp - amount, 0.0)  # 넘친 피해는 버린다
	monster_damaged.emit(monster_hp, amount)
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
		stage += 1
		stage_changed.emit(stage)
	kills_changed.emit(kills)


func _spawn_monster() -> void:
	respawn_left = 0.0
	monster_max_hp = Balance.monster_hp(stage)
	monster_hp = monster_max_hp
	monster_spawned.emit(monster_max_hp)
