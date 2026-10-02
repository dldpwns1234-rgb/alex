extends Node
## 자동화 (GDD 7.7절 운명의 상점): 자동 회귀, 결정 자동 구매, 스킬 자동 사용, 동료 자동 강화, 단련 자동 구매. 운명의 상점에서 해금했을 때만 동작한다.
## 켜고 끄는 설정은 저장되고 회귀·환생해도 남는다 (데이터 초기화에서만 기본값으로). 상태 변경은 Prestige·Skills·Party·Promotions의 함수로만 한다.

signal settings_changed()

var enabled: Array[bool] = []   # Balance.Auto 순서. 기본은 켬이라 운명을 사는 순간부터 동작한다
var _stall: float = 0.0         # 최고 스테이지가 오르지 않은 시간 (게임 시간, 초)
var _best_seen: int = 0


func _ready() -> void:
	reset()
	Game.stage_changed.connect(_on_stage_changed)
	Prestige.prestiged.connect(_on_new_run)
	Rebirth.reborn.connect(_on_new_run)
	Transcend.transcended.connect(_on_new_run)
	Game.tower_changed.connect(_restart_clock.unbind(1))  # 탑에 다녀온 시간은 정체가 아니다


## 정체 시계를 재고, 자동 회귀·자동 스킬·동료 자동 강화를 돌린다. 보스와 싸우는 중, 도전 판, 탑 안에서는 회귀하지 않는다 (판이 끊기는 느낌을 막는다)
func _process(delta: float) -> void:
	_stall += minf(delta, Balance.MAX_DELTA)
	var stalled := _stall >= Balance.AUTO_PRESTIGE_STALL and not _boss_alive() and not Challenges.any_active() and not Game.in_tower
	if stalled and is_active(Balance.Auto.REBIRTH) and Rebirth.can_rebirth():
		Rebirth.perform()  # 자동 환생이 자동 회귀보다 먼저 (별의 상점, GDD 7.12절)
	elif stalled and is_active(Balance.Auto.PRESTIGE) and Prestige.can_prestige():
		Prestige.perform()
	if is_active(Balance.Auto.SKILLS):
		use_skills()
	if is_active(Balance.Auto.TRAINING):
		buy_trainings()  # 동료 강화보다 먼저: 동료 강화는 살 수 있는 만큼 다 써서 뒤에 오면 단련 몫이 남지 않는다
	if is_active(Balance.Auto.UPGRADE):
		upgrade_companions()


## 데이터 초기화에서만 부른다 (회귀·환생은 설정을 남긴다)
func reset() -> void:
	enabled.clear()
	enabled.resize(Balance.AUTO_NAMES.size())
	enabled.fill(true)
	_restart_clock()
	settings_changed.emit()


func to_dict() -> Dictionary:
	return {"enabled": enabled.duplicate()}


## 없는 필드는 켬으로 (옛 저장 호환). Game을 불러온 뒤에 불러 정체 시계가 이번 판 최고에서 시작한다
func from_dict(data: Dictionary) -> void:
	reset()
	var saved: Variant = data.get("enabled", [])
	if saved is Array:
		for i in mini(saved.size(), enabled.size()):
			enabled[i] = bool(saved[i])
	settings_changed.emit()


func is_enabled(kind: int) -> bool:
	return enabled[kind]


## 운명의 상점에서 열었거나, 한 번 초월했으면 (초월은 운명을 지우지만 자동화 해금은 남긴다, GDD 7.12절)
## 자동 환생은 별의 상점에서만 열린다
func is_unlocked(kind: int) -> bool:
	if kind == Balance.Auto.REBIRTH:
		return Transcend.level(Balance.Star.AUTO_REBIRTH) > 0
	return Rebirth.has_fate(Balance.auto_fate(kind)) or Transcend.keeps_automation()


## 켜져 있고 운명의 상점에서 해금했으면 동작한다
func is_active(kind: int) -> bool:
	return enabled[kind] and is_unlocked(kind)


func set_enabled(kind: int, on: bool) -> void:
	if enabled[kind] == on:
		return
	enabled[kind] = on
	settings_changed.emit()


## 최고 스테이지가 오르지 않은 시간 (표시용)
func stall_seconds() -> float:
	return _stall


## 결정을 싼 것부터 산다 (같으면 앞의 것). 루트 탐색에서 가장 빠른 결정 사용 계획이다 (docs/BALANCE_SIM.md)
func buy_memories() -> void:
	while true:
		var pick := -1
		for i in Balance.MEMORIES.size():
			if Prestige.can_buy(i) and (pick < 0 or Prestige.memory_cost(i) < Prestige.memory_cost(pick)):
				pick = i
		if pick < 0 or not Prestige.buy(pick):
			return


## 쿨타임이 끝난 스킬을 바로 쓴다
func use_skills() -> void:
	for i in Balance.SKILLS.size():
		if Skills.can_activate(i):
			Skills.activate(i)


## 동료 자동 강화: 골드 효율(지금 구매 배수로 샀을 때 파티 DPS 증가 ÷ 비용)이 가장 좋은 레벨업이나 승급을 산다.
## 살 수 있는 것 중에서 고른다 (시뮬레이션 봇의 구매 정책, tools/sim_purchases.gd). 한 프레임에 상한까지 되풀이한다
func upgrade_companions() -> void:
	for _i in Balance.AUTO_UPGRADE_BUYS_PER_FRAME:
		if not _buy_best_upgrade():
			return


## 살 수 있는 레벨업·승급 중 골드 효율이 가장 좋은 것 하나를 산다. 살 것이 없으면 false.
## 고용 전 동료가 합류했으면 먼저 최대로 고용한다: 용기사(600)의 1레벨은 수천 레벨 동료 곁에서 효율이 0으로 나와 영영 안 산다
func _buy_best_upgrade() -> bool:
	for i in Balance.COMPANIONS.size():
		if Party.is_companion_unlocked(i) and not Party.is_companion_hired(i) and Party.companion_purchase(i, Party.BuyMode.MAX).affordable:
			return Party.buy_companion(i, Party.BuyMode.MAX)
	var best := 0.0
	var pick := -1
	var promote := false
	for i in Balance.COMPANIONS.size():
		if Party.companion_purchase(i).affordable:
			var level_gain := Party.companion_gain_per_gold(i)
			if level_gain > best:
				best = level_gain
				pick = i
				promote = false
		if Promotions.can_promote(i):
			var rank_gain := Party.promotion_gain_per_gold(i)
			if rank_gain > best:
				best = rank_gain
				pick = i
				promote = true
	if pick < 0:
		return false
	return Promotions.promote(pick) if promote else Party.buy_companion(pick)


## 단련 자동 구매: 다음 레벨 비용이 가진 골드의 일정 몫 이하인 단련 중 가장 싼 것을 한 레벨씩 산다 (구매 배수와 상관없이).
## 단련은 최대 레벨이 있어 금방 다 차고, 몫을 두어 동료 강화에 쓸 골드를 남긴다. 한 프레임에 상한까지 되풀이한다
func buy_trainings() -> void:
	for _i in Balance.AUTO_UPGRADE_BUYS_PER_FRAME:
		var pick := -1
		var cheapest := 0.0
		for i in Training.levels.size():
			if not Training.is_unlocked(i) or Training.is_maxed(i):
				continue
			var cost := Training.purchase(i, Party.BuyMode.ONE).cost
			if cost <= Game.gold * Balance.AUTO_TRAINING_GOLD_SHARE and (pick < 0 or cost < cheapest):
				pick = i
				cheapest = cost
		if pick < 0 or not Training.buy(pick, Party.BuyMode.ONE):
			return


## 새 스테이지에 닿으면 정체 시계를 되돌린다. 보스 실패로 돌아갔다 다시 오른 것은 진행이 아니다
func _on_stage_changed(stage: int) -> void:
	if stage > _best_seen:
		_best_seen = stage
		_stall = 0.0


## 회귀·환생 직후: 시작 스테이지가 기준이 되고, 결정 자동 구매가 켜져 있으면 바로 산다
func _on_new_run(_reward: float) -> void:
	_restart_clock()
	if is_active(Balance.Auto.MEMORIES):
		buy_memories()


func _restart_clock() -> void:
	_best_seen = Game.highest_stage
	_stall = 0.0


func _boss_alive() -> bool:
	return Game.is_boss_stage() and Game.is_monster_alive()
