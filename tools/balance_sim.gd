extends "res://tools/sim_purchases.gd"
## 밸런스 시뮬레이션 (GDD 13절). 실제 Balance·Party·Game·Prestige·Rebirth 코드를 그대로 돌린다. 구매 정책은 sim_purchases.gd에 있다.
##
##   godot --headless --path . res://tools/balance_sim.tscn
##
## 가정: 초당 4클릭, 스킬 없음, 보스 재도전은 게임의 자동 재도전에 맡긴다, 3분 동안 최고 스테이지가 오르지 않으면 회귀하고
## 환생할 수 있으면 회귀 대신 환생한다. 장비 드롭은 고정 시드로 굴린다. 회귀 횟수는 환생을 넘어 센다.

const FRAME: float = 0.25          # Game의 delta 상한과 같다
const STALL_SECONDS: float = 180.0  # 이만큼 최고 스테이지가 안 오르면 회귀
const MAX_PRESTIGES: int = 12
const MAX_HOURS: float = 10.0
const REPORT_STAGES: PackedStringArray = ["10", "20", "40", "60", "80", "100", "120", "150", "200"]
const RANDOM_SEED: int = 20260923  # 장비 드롭이 실행마다 같도록

var _t: float = 0.0                 # 시뮬레이션 시간 (초)
var _prestiges: int = 0             # 환생을 넘어 센 회귀 횟수
var _run_start: float = 0.0
var _last_progress: float = 0.0     # 최고 스테이지가 마지막으로 오른 시각
var _best_this_run: int = 0         # 이번 판에서 본 최고 스테이지. 보스에 다시 도전하는 것은 진행이 아니다
var _reported: Dictionary = {}
var _previous_best: int = 0
var _beat_previous_at: float = -1.0


func _ready() -> void:
	Save.blocked = true  # 시뮬레이션은 저장하지 않는다. 시작할 때 읽힌 저장이 있어도 전부 새로 시작한다
	seed(RANDOM_SEED)
	Rebirth.reset()
	Prestige.reset()
	Achievements.reset()
	Equipment.reset()
	Party.reset()
	Party.set_buy_mode(Party.BuyMode.ONE)
	Skills.reset()
	Training.reset()
	Promotions.reset()
	Game.reset()
	Game.stage_changed.connect(_on_stage_changed)
	Party.companion_changed.connect(_on_companion_changed)
	print("")
	print("=== 밸런스 시뮬레이션: 초당 %d클릭, 스킬 없음 ===" % roundi(CLICKS_PER_SECOND))
	_run_start = 0.0
	while _t < MAX_HOURS * 3600.0 and _prestiges < MAX_PRESTIGES:
		_second()
	_report("종료: %s, 스테이지 %d, 회귀 %d회, 환생 %d회" % [_clock(_t), Game.stage, _prestiges, Rebirth.rebirth_count])
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
		if Rebirth.can_rebirth():
			_rebirth()
		else:
			_prestige()


func _prestige() -> void:
	var reward := Prestige.crystal_reward()
	var reached := Game.highest_stage
	var run_seconds := _t - _run_start
	var beat := "이전 기록 %d 돌파 %s" % [_previous_best, _clock(_beat_previous_at - _run_start)] if _beat_previous_at >= 0.0 else "이전 기록 미돌파"
	_report("회귀 %d: %s에 스테이지 %d 도달, 판 길이 %s, 결정 +%s, %s" % [
		_prestiges + 1, _clock(_t), reached, _clock(run_seconds), Num.format(reward), beat])
	_previous_best = maxi(_previous_best, reached)
	Prestige.perform()
	_prestiges += 1
	_buy_memories()
	_report("    상점: 검술 Lv %d (×%s), 황금 Lv %d (×%s), 남은 결정 %s" % [
		Prestige.level(Balance.Memory.SWORD), Num.format(Prestige.sword_multiplier()),
		Prestige.level(Balance.Memory.GOLD), Num.format(Prestige.gold_multiplier()), Num.format(Prestige.crystals)])
	_new_run()


## 환생: 기억을 내려놓고 운명의 실로 운명의 상점을 산다. 이전 기록도 새 삶에서 다시 센다
func _rebirth() -> void:
	var reward := Rebirth.thread_reward()
	_report("환생 %d: %s에 역대 최고 %d, 판 길이 %s, 운명의 실 +%s" % [
		Rebirth.rebirth_count + 1, _clock(_t), Rebirth.best_stage(), _clock(_t - _run_start), Num.format(reward)])
	Rebirth.perform()
	_buy_fates()
	_report("    운명: 숙명 Lv %d (×%s), 인연 Lv %d (×%s), 예지 Lv %d (시작 %d), 남은 실 %s" % [
		Rebirth.level(Balance.Fate.DESTINY), Num.format(Rebirth.damage_multiplier()),
		Rebirth.level(Balance.Fate.BOND), Num.format(Rebirth.crystal_multiplier()),
		Rebirth.level(Balance.Fate.FORESIGHT), Rebirth.start_stage(), Num.format(Rebirth.threads)])
	_previous_best = 0
	_new_run()


func _new_run() -> void:
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
	if level == 1 and _prestiges == 0:
		_report("%s  %s 합류 (스테이지 %d)" % [_clock(_t), Balance.companion_name(index), Game.stage])


func _report(line: String) -> void:
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
