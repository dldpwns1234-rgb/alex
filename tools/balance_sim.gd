extends "res://tools/sim_purchases.gd"
## 밸런스 시뮬레이션 (GDD 13절). 실제 Balance·Party·Game·Prestige·Rebirth 코드를 그대로 돌린다. 구매 정책은 sim_purchases.gd에 있다.
##
##   godot --headless --path . res://tools/balance_sim.tscn [-- --goal=500 --ratio=2 --skills=1 --plan=all --stall=180 --extra=0 --taps=4 --hours=10]
##
## 가정: 초당 4클릭(taps), 보스 재도전은 게임의 자동 재도전에 맡긴다, 장비 드롭은 고정 시드로 굴린다. 회귀 횟수는 환생을 넘어 센다.
## 정책 인자 (tools/route_search.py가 조합을 바꿔 가며 목표 도달 시간을 잰다). 인자가 없으면 스킬 없이 정체로만 회귀한다:
##   goal   목표 역대 최고 스테이지. 닿으면 시간을 찍고 끝낸다 (0이면 회귀 12번 또는 10시간까지)
##   ratio  회귀 보상이 지금 결정 재산(가진 것 + 상점에 쓴 것, 최소 10)의 이 배수 이상이면 회귀 (0이면 정체로만)
##   skills 1이면 스킬을 쿨타임마다 쓴다 (폭풍 베기의 자동 클릭 포함)
##   plan   결정 사용: sword_gold(검술·황금 중 싼 것), sword(검술만), all(일곱 개 중 싼 것)
##   stall  이만큼(초) 최고 스테이지가 안 오르면 회귀
##   extra  환생은 역대 최고가 500 + extra 이상일 때 (회귀 대신)
##   taps   초당 클릭 수
##   hours  시간 상한 (기본 10)

const FRAME: float = 0.25          # 프레임 상한. Game의 delta 상한과 같다
const MIN_FRAME: float = 1.0 / 60.0  # 프레임 하한. 60fps 브라우저처럼 처치·재등장 순간에 맞춰 진행한다
const BUY_INTERVAL: float = 2.0    # 이만큼(초)마다 구매를 따진다
const MAX_PRESTIGES: int = 12
const REPORT_STAGES: PackedStringArray = ["10", "20", "40", "60", "80", "100", "120", "150", "200"]
const RANDOM_SEED: int = 20260923  # 장비 드롭이 실행마다 같도록

var _t: float = 0.0                 # 시뮬레이션 시간 (초)
var _next_buy: float = 0.0
var _tap_budget: float = 0.0        # 초당 클릭 수 × 시간을 모아 1이 될 때마다 탭한다
var _prestiges: int = 0             # 환생을 넘어 센 회귀 횟수
var _run_start: float = 0.0
var _last_progress: float = 0.0     # 최고 스테이지가 마지막으로 오른 시각
var _best_this_run: int = 0         # 이번 판에서 본 최고 스테이지. 보스에 다시 도전하는 것은 진행이 아니다
var _reported: Dictionary = {}
var _previous_best: int = 0
var _beat_previous_at: float = -1.0


func _ready() -> void:
	Save.blocked = true  # 시뮬레이션은 저장하지 않는다. 시작할 때 읽힌 저장이 있어도 전부 새로 시작한다
	_parse_args()
	seed(RANDOM_SEED)
	Rebirth.reset()
	Prestige.reset()
	Achievements.reset()
	Equipment.reset()
	Party.reset()
	Party.set_buy_mode(Party.BuyMode.ONE)
	Skills.reset()
	Skills.clock_override = 0.0
	Training.reset()
	Promotions.reset()
	Game.reset()
	Automation.reset()
	Automation.enabled.fill(false)  # 회귀·결정·스킬은 시뮬레이션의 정책이 직접 돌린다
	Game.stage_changed.connect(_on_stage_changed)
	Party.companion_changed.connect(_on_companion_changed)
	print("")
	print("=== 밸런스 시뮬레이션: 초당 %d클릭, 목표 %d, 회귀 배수 %s, 스킬 %s, 결정 %s, 정체 %d초, 환생 +%d ===" % [
		roundi(clicks_per_second), _goal, _ratio, "사용" if _skills else "없음", _plan, roundi(_stall), _extra])
	# 목표가 있으면 시간 상한만 둔다 (일찍 회귀하는 정책은 회귀 12번을 금방 채운다)
	while _t < _hours * 3600.0 and (_goal > 0 or _prestiges < MAX_PRESTIGES) and not _goal_reached():
		_second()
	if _goal_reached():
		_report("목표 %d 도달: %s (회귀 %d회, 환생 %d회)  SCORE=%d" % [_goal, _clock(_t), _prestiges, Rebirth.rebirth_count, roundi(_t)])
	else:
		_report("종료: %s, 스테이지 %d, 회귀 %d회, 환생 %d회  SCORE=none" % [_clock(_t), Game.stage, _prestiges, Rebirth.rebirth_count])
	print("")
	get_tree().quit(0)


func _goal_reached() -> bool:
	return _goal > 0 and Rebirth.best_stage() >= _goal


## 1초 진행: 프레임을 처치·재등장 순간에 맞춰 잘게 나눠 돌린다 (0.25초 고정이면 재등장 대기 0.3초가 0.5초가 되고 처치 뒤 남은 시간이
## 버려져 회귀 직후 즉사 구간이 실제 게임보다 1.6배 느렸다). 그 뒤 스킬 발동, 구매, 회귀 판단
func _second() -> void:
	var end := _t + 1.0
	while end - _t > 0.0001:
		var dt := _frame_length(end - _t)
		Skills.clock_override = _t
		if _skills:
			Skills._process(dt)
		_tap_budget += clicks_per_second * dt
		while _tap_budget >= 1.0:
			_tap_budget -= 1.0
			Game.tap_attack()
		Game._process(dt)
		_t += dt
	Skills.clock_override = _t
	if _skills:
		_use_skills()
	if _t >= _next_buy:
		_next_buy = _t + BUY_INTERVAL
		_buy_everything()
	if Prestige.can_prestige() and (_t - _last_progress >= _stall or _worth_prestige()):
		if Rebirth.can_rebirth() and Rebirth.best_stage() >= Balance.REBIRTH_MIN_STAGE + _extra:
			_rebirth()
		else:
			_prestige()


## 다음 프레임 길이: 재등장 중이면 등장 순간까지, 동료가 이번 프레임 안에 잡을 몬스터면 처치 순간까지 (최소 1/60초)
func _frame_length(remaining: float) -> float:
	var dt := minf(FRAME, remaining)
	if Game.respawn_left > 0.0:
		return maxf(minf(dt, Game.respawn_left), MIN_FRAME)
	if Game.is_monster_alive():
		var dps := Party.party_dps(Game.is_boss_stage())
		if dps > 0.0:
			dt = minf(dt, maxf(Game.monster_hp / dps * 1.000001, MIN_FRAME))
	return dt


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
	_buy_memories(_plan)
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
			_clock(_t), stage, Party.hero_level, str(Party.companion_level_list()), trained, Num.format(Game.gold)])


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
