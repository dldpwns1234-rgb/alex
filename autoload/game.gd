extends "res://autoload/game/state.gd"
## 게임 진행: 골드, 스테이지, 몬스터, 보스. 상태 변경은 오토로드의 함수로만 하고 UI는 표시만 한다.
## 이 파일은 매 프레임 전투 흐름(피해, 처치와 연쇄 처치, 보스 타이머, 파밍과 도전)을 맡는다. 상태와 저장은 game/state.gd에 있다.


func _ready() -> void:
	reset()


func _process(delta: float) -> void:
	var dt := minf(delta, Balance.MAX_DELTA)
	_tick_tap_rate(dt)
	if in_tower:
		Tower.tick(dt)  # 층 제한 시간. 끝나면 Tower가 본편으로 돌려보낸다
		if not in_tower:
			return
	elif farming:
		_farm_seconds += dt
		_auto_retry()
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


## 최근 창의 탭 빈도. 창이 끝날 때마다 초당 탭 수로 굳힌다
func _tick_tap_rate(dt: float) -> void:
	_tap_window_left -= dt
	if _tap_window_left <= 0.0:
		tap_rate = _taps_in_window / Balance.TAP_RATE_WINDOW
		_taps_in_window = 0
		_tap_window_left = Balance.TAP_RATE_WINDOW


## 자동 재도전 (GDD 3절): 실패 뒤 잠깐 파밍한 다음 잡을 수 있을 것 같으면, 또는 탭하는 중이면 한참마다, 스스로 도전한다.
## 예약을 손으로 취소하면 한동안 미룬다
func _auto_retry() -> void:
	if not auto_retry or boss_queued or _farm_seconds < Balance.AUTO_RETRY_REST:
		return
	if boss_looks_beatable() or (tap_rate > 0.0 and _farm_seconds >= Balance.AUTO_RETRY_INTERVAL):
		challenge_boss()


## 탭 공격. 재등장을 기다리는 동안에는 피해가 들어가지 않는다. 클릭 치명타는 실제로 굴린다 (GDD 6.5절).
## auto는 폭풍 베기의 자동 클릭: 탭 빈도에는 들어가지만 업적의 탭 수에는 세지 않는다
func tap_attack(auto: bool = false) -> void:
	_taps_in_window += 1
	if not auto:
		Achievements.add(Balance.Stat.TAPS, 1.0)
	if not is_monster_alive():
		return
	var amount := Party.click_damage()
	var chance := Training.value(Balance.Effect.CLICK_CRIT)
	var crit := chance > 0.0 and randf() < chance
	if crit:
		amount *= Balance.CLICK_CRIT_MULTIPLIER
	tap_hit.emit(amount, crit)
	_damage_monster(amount)


## 파밍 중 보스 도전: 지금 몬스터를 잡은 뒤 보스가 나온다 (다시 누르면 취소). 재등장 대기 중이면 바로 간다
func challenge_boss() -> void:
	if not farming or in_tower:
		return
	if is_monster_alive():
		boss_queued = not boss_queued
		if not boss_queued:
			_farm_seconds = -Balance.AUTO_RETRY_INTERVAL  # 취소했으니 자동 재도전은 한동안 미룬다
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


## 피해를 준다. 넘친 피해는 같은 스테이지의 다음 몬스터들을 연달아 잡는 데 쓴다 (연쇄 처치, GDD 3절)
func _damage_monster(amount: float) -> void:
	var excess := amount - monster_hp
	monster_hp = maxf(monster_hp - amount, 0.0)
	monster_damaged.emit(monster_hp)
	if monster_hp <= 0.0:
		_kill_monster()
		_chain_kills(excess)


## 처치: 골드와 처치 수, 재등장 대기, 연출 알림, 진행
func _kill_monster() -> void:
	var reward := _award_kill()
	boss_time_left = 0.0
	respawn_left = respawn_delay()
	monster_killed.emit(reward)
	if Balance.is_demon_king_stage(stage) and not in_tower:
		demon_king_defeated.emit()
	_after_kill()


## 연쇄 처치: 넘친 피해가 몬스터 하나를 통째로 잡을 만큼이면 같은 스테이지(탑이면 같은 층)의 다음 몬스터를 재등장 대기 없이 잡는다.
## 스테이지가 넘어가면(처치 수 0) 멈추고 나머지는 버린다. 보스는 혼자라 연쇄가 없다. 한 방 구간을 몬스터 수만큼 빠르게 지난다
func _chain_kills(excess: float) -> void:
	var count := 0
	var reward := 0.0
	while kills > 0 and not is_boss_stage() and excess >= monster_max_hp:
		excess -= monster_max_hp
		reward += _award_kill()
		count += 1
		_after_kill()
	if count > 0:
		chain_killed.emit(count, reward)


## 처치 하나의 처치 수와 골드. 처치 골드 = 기본 × 황금의 기억 × 업적 × 장신구 × 황금 손길 × 전리품·황금 화살 단련 (보스면 × 헌금).
## 탑에서는 골드 없이 처치 수만 센다 (GDD 7.10절). 받은 골드를 돌려준다
func _award_kill() -> float:
	kills += 1
	if in_tower:
		return 0.0
	var reward := Balance.kill_gold(monster_max_hp) * gold_multiplier() * Skills.gold_multiplier()
	reward *= 1.0 + Training.value(Balance.Effect.KILL_GOLD)
	if is_boss_stage():
		reward *= 1.0 + Training.value(Balance.Effect.BOSS_GOLD)
	gold += reward
	gold_changed.emit(gold)
	return reward


## 처치 뒤 진행. 탑은 10마리면 다음 층. 본편은 보스 1마리, 일반 10마리면 다음 스테이지 (파밍 중에는 처치 수만 돌고, 도전을 예약했으면 보스로)
func _after_kill() -> void:
	if in_tower:
		if kills >= Balance.MONSTERS_PER_STAGE:
			kills = 0
			Tower.clear_floor()
	elif farming and boss_queued:
		_start_boss_challenge()
	elif is_boss_stage() or kills >= Balance.MONSTERS_PER_STAGE:
		kills = 0
		if not farming:
			_advance_stage()
	kills_changed.emit(kills)


## 보스 시간 초과: 직전 스테이지로 돌아가 파밍 모드가 된다 (GDD 3절)
func _fail_boss() -> void:
	farming = true
	_farm_seconds = 0.0
	kills = 0
	boss_time_left = 0.0
	monster_hp = 0.0
	respawn_left = respawn_delay()
	stage -= 1
	boss_failed.emit()
	stage_changed.emit(stage)
	kills_changed.emit(kills)
	farming_changed.emit(farming)
