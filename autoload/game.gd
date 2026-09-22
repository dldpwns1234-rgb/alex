extends "res://autoload/game/state.gd"
## 게임 진행: 골드, 스테이지, 몬스터, 보스. 상태 변경은 오토로드의 함수로만 하고 UI는 표시만 한다.
## 이 파일은 매 프레임 전투 흐름(피해, 처치, 보스 타이머, 파밍과 도전)을 맡는다. 상태와 저장은 game/state.gd에 있다.


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


## 탭 공격. 재등장을 기다리는 동안에는 피해가 들어가지 않는다
func tap_attack() -> void:
	if not is_monster_alive():
		return
	var amount := Party.click_damage()
	tap_hit.emit(amount)
	_damage_monster(amount)


## 파밍 중 보스 도전: 지금 몬스터를 잡은 뒤 보스가 나온다 (다시 누르면 취소). 재등장 대기 중이면 바로 간다
func challenge_boss() -> void:
	if not farming:
		return
	if is_monster_alive():
		boss_queued = not boss_queued
		boss_queued_changed.emit(boss_queued)
		return
	_start_boss_challenge()
	kills_changed.emit(kills)


func _start_boss_challenge() -> void:
	farming = false
	boss_queued = false
	kills = 0
	farming_changed.emit(farming)
	boss_queued_changed.emit(boss_queued)
	_advance_stage()  # 재등장 대기가 끝나면 이 스테이지의 보스가 나온다


func _damage_monster(amount: float) -> void:
	monster_hp = maxf(monster_hp - amount, 0.0)  # 넘친 피해는 버린다
	monster_damaged.emit(monster_hp)
	if monster_hp <= 0.0:
		_kill_monster()


func _kill_monster() -> void:
	var reward := Balance.kill_gold(monster_max_hp) * Prestige.gold_multiplier() * Skills.gold_multiplier()
	gold += reward
	kills += 1
	boss_time_left = 0.0
	respawn_left = Balance.RESPAWN_DELAY
	gold_changed.emit(gold)
	monster_killed.emit(reward)
	# 보스는 1마리, 일반 스테이지는 10마리. 파밍 중에는 처치 수만 돌고, 도전을 예약했으면 보스로 간다
	if farming and boss_queued:
		_start_boss_challenge()
	elif is_boss_stage() or kills >= Balance.MONSTERS_PER_STAGE:
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
