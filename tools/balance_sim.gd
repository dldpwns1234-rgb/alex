extends Node
## 밸런스 시뮬레이션 (GDD 13절). 실제 Balance·Party·Game·Prestige 코드를 그대로 돌린다.
##
##   godot --headless --path . res://tools/balance_sim.tscn
##
## 가정: 초당 4클릭, 스킬 없음, 골드 대비 진행 속도(DPS × 골드 배율) 상승이 가장 큰 것부터 산다
## (용사·동료 레벨과 단련 모두. 진행 속도에 안 잡히는 단련은 골드의 2% 이하일 때 산다), 보스 재도전은
## 게임의 자동 재도전(Game.auto_retry, Balance.AUTO_RETRY_*)에 맡긴다, 3분 동안 최고 스테이지가
## 오르지 않으면 회귀, 결정은 검술·황금 중 싼 것에 쓴다.

const CLICKS_PER_SECOND: float = 4.0
const FRAME: float = 0.25          # Game의 delta 상한과 같다
const STALL_SECONDS: float = 180.0  # 이만큼 최고 스테이지가 안 오르면 회귀
const MAX_PRESTIGES: int = 12
const MAX_HOURS: float = 10.0
const REPORT_STAGES: PackedStringArray = ["10", "20", "40", "60", "80", "100", "120", "150", "200"]

var _t: float = 0.0                 # 시뮬레이션 시간 (초)
var _run_start: float = 0.0
var _last_progress: float = 0.0     # 최고 스테이지가 마지막으로 오른 시각
var _best_this_run: int = 0         # 이번 판에서 본 최고 스테이지. 보스에 다시 도전하는 것은 진행이 아니다
var _reported: Dictionary = {}
var _previous_best: int = 0
var _beat_previous_at: float = -1.0
var _lines: PackedStringArray = []


func _ready() -> void:
	Save.blocked = true  # 시뮬레이션은 저장하지 않는다. 시작할 때 읽힌 저장이 있어도 전부 새로 시작한다
	Prestige.reset()
	Party.reset()
	Party.set_buy_mode(Party.BuyMode.ONE)
	Skills.reset()
	Training.reset()
	Game.reset()
	Game.stage_changed.connect(_on_stage_changed)
	Party.companion_changed.connect(_on_companion_changed)
	print("")
	print("=== 밸런스 시뮬레이션: 초당 %d클릭, 스킬 없음 ===" % roundi(CLICKS_PER_SECOND))
	_run_start = 0.0
	while _t < MAX_HOURS * 3600.0 and Prestige.prestige_count < MAX_PRESTIGES:
		_second()
	_report("종료: %s, 스테이지 %d, 회귀 %d회" % [_clock(_t), Game.stage, Prestige.prestige_count])
	print("")
	get_tree().quit(0)


## 1초 진행: 4프레임 동안 클릭과 동료 피해, 그 뒤 구매와 판단
func _second() -> void:
	var taps_per_frame := CLICKS_PER_SECOND * FRAME
	var tap_budget := 0.0
	for i in 4:
		tap_budget += taps_per_frame
		while tap_budget >= 1.0:
			tap_budget -= 1.0
			Game.tap_attack()
		Game._process(FRAME)
		_t += FRAME
	_buy_everything()
	if Prestige.can_prestige() and _t - _last_progress >= STALL_SECONDS:
		_prestige()


## 진행 속도: (동료 DPS + 클릭 DPS) × 처치 골드 배율. 골드 대비 이 값의 상승이 큰 것부터 산다
func _progress_rate() -> float:
	var boss := Game.is_boss_stage()
	var dps := Party.party_dps(boss) + Party.click_damage() * CLICKS_PER_SECOND
	return dps * (1.0 + Training.value(Balance.Effect.KILL_GOLD))


func _buy_everything() -> void:
	while true:
		var current := _progress_rate()
		var best_ratio := 0.0
		var best_kind := ""  # "hero", "companion", "training"
		var best_index := -1
		var hero := Party.hero_purchase()
		if hero.affordable:
			Party.hero_level += 1
			best_ratio = (_progress_rate() - current) / hero.cost
			best_kind = "hero"
			Party.hero_level -= 1
		for i in Party.companion_levels.size():
			if not Party.is_companion_unlocked(i):
				continue
			var purchase := Party.companion_purchase(i)
			if not purchase.affordable:
				continue
			Party.companion_levels[i] += 1
			var ratio := (_progress_rate() - current) / purchase.cost
			Party.companion_levels[i] -= 1
			if ratio > best_ratio:
				best_ratio = ratio
				best_kind = "companion"
				best_index = i
		for i in Training.levels.size():
			if not Training.can_buy(i):
				continue
			var purchase := Training.purchase(i)
			Training.levels[i] += 1
			var gain := _progress_rate() - current
			Training.levels[i] -= 1
			# 진행 속도에 안 잡히는 효과(보스 시간, 스킬, 재등장 등)는 싸면 산다
			var ratio := gain / purchase.cost if gain > 0.0 else (1e9 if purchase.cost <= Game.gold * 0.02 else 0.0)
			if ratio > best_ratio:
				best_ratio = ratio
				best_kind = "training"
				best_index = i
		match best_kind:
			"hero":
				Party.buy_hero()
			"companion":
				Party.buy_companion(best_index)
			"training":
				Training.buy(best_index)
			_:
				return


func _prestige() -> void:
	var reward := Prestige.crystal_reward()
	var reached := Game.highest_stage
	var run_seconds := _t - _run_start
	var beat := "이전 기록 %d 돌파 %s" % [_previous_best, _clock(_beat_previous_at - _run_start)] if _beat_previous_at >= 0.0 else "이전 기록 미돌파"
	_report("회귀 %d: %s에 스테이지 %d 도달, 판 길이 %s, 결정 +%s, %s" % [
		Prestige.prestige_count + 1, _clock(_t), reached, _clock(run_seconds), Num.format(reward), beat])
	_previous_best = maxi(_previous_best, reached)
	Prestige.perform()
	# 결정은 검술의 기억과 황금의 기억 중 싼 것부터
	while true:
		var sword: int = Balance.Memory.SWORD
		var gold: int = Balance.Memory.GOLD
		var pick := sword if Prestige.memory_cost(sword) <= Prestige.memory_cost(gold) else gold
		if not Prestige.buy(pick):
			break
	_report("    상점: 검술 Lv %d (×%s), 황금 Lv %d (×%s), 남은 결정 %s" % [
		Prestige.level(Balance.Memory.SWORD), Num.format(Prestige.sword_multiplier()),
		Prestige.level(Balance.Memory.GOLD), Num.format(Prestige.gold_multiplier()), Num.format(Prestige.crystals)])
	_run_start = _t
	_last_progress = _t
	_beat_previous_at = -1.0
	_best_this_run = 0
	_reported.clear()


func _on_stage_changed(stage: int) -> void:
	if stage <= _best_this_run:
		return  # 보스 실패로 돌아갔거나, 자동 재도전으로 같은 보스에 다시 들어간 것
	_best_this_run = stage
	_last_progress = _t
	if _beat_previous_at < 0.0 and _previous_best > 0 and stage > _previous_best:
		_beat_previous_at = _t
	var key := str(stage)
	if key in REPORT_STAGES and not _reported.has(key):
		_reported[key] = true
		var trained := 0
		for level in Training.levels:
			trained += level
		_report("%s  스테이지 %3d  용사 Lv %d  동료 %s  단련 %d  골드 %s" % [
			_clock(_t), stage, Party.hero_level, str(Party.companion_levels), trained, Num.format(Game.gold)])


func _on_companion_changed(index: int, level: int) -> void:
	if level == 1 and Prestige.prestige_count == 0:
		_report("%s  %s 합류 (스테이지 %d)" % [_clock(_t), Balance.companion_name(index), Game.stage])


func _report(line: String) -> void:
	_lines.append(line)
	print(line)


func _clock(seconds: float) -> String:
	var total := floori(seconds)
	@warning_ignore("integer_division")
	var hours := total / 3600
	@warning_ignore("integer_division")
	var minutes := (total % 3600) / 60
	if hours > 0:
		return "%d시간 %02d분 %02d초" % [hours, minutes, total % 60]
	return "%d분 %02d초" % [minutes, total % 60]
