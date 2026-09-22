extends Node
## 밸런스 시뮬레이션 (GDD 13절). 실제 Balance·Party·Game·Prestige 코드를 그대로 돌린다.
##
##   godot --headless --path . res://tools/balance_sim.tscn
##
## 가정: 초당 4클릭, 스킬 없음, 골드 대비 DPS 상승이 가장 큰 것부터 산다, 보스에 실패하면
## 예상 처치 시간이 제한 시간의 90% 안에 들 때(늦어도 5분마다) 재도전, 3분 동안 최고 스테이지가
## 오르지 않으면 회귀, 결정은 검술·황금 중 싼 것에 쓴다.

const CLICKS_PER_SECOND: float = 4.0
const FRAME: float = 0.25          # Game의 delta 상한과 같다
const BOSS_RETRY_SECONDS: float = 300.0   # 예상이 안 맞아도 이만큼 지나면 한 번 더 해 본다
const BOSS_RETRY_MARGIN: float = 0.9      # 예상 처치 시간이 제한 시간의 이 비율 안이면 도전
const STALL_SECONDS: float = 180.0  # 이만큼 최고 스테이지가 안 오르면 회귀
const MAX_PRESTIGES: int = 12
const MAX_HOURS: float = 10.0
const REPORT_STAGES: PackedStringArray = ["10", "20", "40", "60", "80", "100", "120", "150", "200"]
const SIM_SAVE_PATH: String = "user://balance_sim.json"

var _t: float = 0.0                 # 시뮬레이션 시간 (초)
var _run_start: float = 0.0
var _last_progress: float = 0.0     # 최고 스테이지가 마지막으로 오른 시각
var _last_retry: float = 0.0
var _reported: Dictionary = {}
var _previous_best: int = 0
var _beat_previous_at: float = -1.0
var _lines: PackedStringArray = []


func _ready() -> void:
	Save.save_path = SIM_SAVE_PATH
	Prestige.reset()
	Party.reset()
	Skills.reset()
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SIM_SAVE_PATH))
	Save.save_path = Save.DEFAULT_SAVE_PATH
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
	if Game.farming and not Game.boss_queued and (_boss_looks_beatable() or _t - _last_retry >= BOSS_RETRY_SECONDS):
		_last_retry = _t
		Game.challenge_boss()
	if Prestige.can_prestige() and _t - _last_progress >= STALL_SECONDS:
		_prestige()


## 파밍 중인 스테이지 다음의 보스를 지금 DPS로 제한 시간 안에 잡을 수 있을지 어림한다
func _boss_looks_beatable() -> bool:
	var boss_stage := Game.stage + 1
	var dps := Party.party_dps(true) + Party.click_damage() * CLICKS_PER_SECOND
	var limit := Balance.boss_time_limit(Prestige.level(Balance.Memory.SAND))
	return Balance.boss_hp(boss_stage) / dps <= limit * BOSS_RETRY_MARGIN


## 골드 대비 DPS 상승이 가장 큰 것부터 살 수 있는 만큼 산다
func _buy_everything() -> void:
	while true:
		var best_ratio := 0.0
		var best_index := -2  # -1 = 용사, 0~ = 동료
		var boss := Game.is_boss_stage()
		var hero := Party.hero_purchase()
		if hero.affordable:
			var gain := (Balance.hero_click_damage(Party.hero_level + 1) - Balance.hero_click_damage(Party.hero_level))
			gain *= Prestige.sword_multiplier() * CLICKS_PER_SECOND
			best_ratio = gain / hero.cost
			best_index = -1
		var current := Balance.party_dps(Party.companion_levels, boss)
		for i in Party.companion_levels.size():
			if not Party.is_companion_unlocked(i):
				continue
			var purchase := Party.companion_purchase(i)
			if not purchase.affordable:
				continue
			var levels: Array[int] = Party.companion_levels.duplicate()
			levels[i] += 1
			var gain := (Balance.party_dps(levels, boss) - current) * Prestige.sword_multiplier()
			var ratio := gain / purchase.cost
			if ratio > best_ratio:
				best_ratio = ratio
				best_index = i
		if best_index == -2:
			return
		if best_index == -1:
			Party.buy_hero()
		else:
			Party.buy_companion(best_index)


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
	_reported.clear()


func _on_stage_changed(stage: int) -> void:
	if stage < Game.highest_stage:
		return  # 보스 실패로 돌아간 것
	_last_progress = _t
	if _beat_previous_at < 0.0 and _previous_best > 0 and stage > _previous_best:
		_beat_previous_at = _t
	var key := str(stage)
	if key in REPORT_STAGES and not _reported.has(key):
		_reported[key] = true
		_report("%s  스테이지 %3d  용사 Lv %d  동료 %s  골드 %s" % [
			_clock(_t), stage, Party.hero_level, str(Party.companion_levels), Num.format(Game.gold)])


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
