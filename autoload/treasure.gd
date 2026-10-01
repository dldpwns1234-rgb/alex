extends Node
## 보물 요정 (GDD 3.5절): 본편 전투 중 60~120초(게임 시간)마다 한 마리가 8초 동안 전투 화면을 가로지른다.
## 탭해서 잡으면 보상 셋 중 하나를 같은 확률로 준다: 골드, 스킬 쿨타임 초기화, 보물의 축복(30초 처치 골드 ×2).
## 초기화는 쿨타임 중인 스킬이 없거나 스킬이 봉인됐으면 후보에서 뺀다. 탑 안과 최종 스테이지 돌파 뒤에는 나오지 않는다.
## 자동화로는 잡지 않는다 (손맛). 상태 변경은 이 오토로드의 함수로만 하고, 날아가는 그림은 scenes/battle/treasure_view.gd가 맡는다.

signal appeared(duration: float)
signal escaped()
signal caught(reward: Reward, amount: float)  # amount: 골드면 받은 골드, 축복이면 지속 초, 초기화면 0

enum Reward { GOLD, COOLDOWN, BLESSING }

var flying: bool = false            # 지금 화면을 가로지르는 중
var flight_left: float = 0.0
var next_in: float = 0.0            # 다음 등장까지 남은 게임 시간 (초)
var blessing_until: float = 0.0     # 보물의 축복이 끝나는 유닉스 시각. 0이면 없음
var clock_override: float = -1.0    # 테스트가 켠다: 0 이상이면 유닉스 시각 대신 이 값을 지금 시각으로 쓴다
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	reset()


func _process(delta: float) -> void:
	tick(minf(delta, Balance.MAX_DELTA))


## dt만큼 시간을 흘린다. 탑 안이나 최종 돌파 뒤에는 멈춘다 (날던 요정은 사라진다)
func tick(dt: float) -> void:
	if Game.in_tower or Game.cleared:
		if flying:
			_escape()
		return
	if flying:
		flight_left -= dt
		if flight_left <= 0.0:
			_escape()
		return
	next_in -= dt
	if next_in <= 0.0:
		flying = true
		flight_left = Balance.TREASURE_FLIGHT_TIME
		appeared.emit(flight_left)


## 데이터 초기화에서만 부른다. 축복도 지운다
func reset() -> void:
	flying = false
	flight_left = 0.0
	blessing_until = 0.0
	_schedule()


func to_dict() -> Dictionary:
	return {"blessing_until": blessing_until}


## 축복은 실제 시간이라 불러온 뒤에도 남은 만큼 이어진다. 날던 요정은 저장하지 않는다
func from_dict(data: Dictionary) -> void:
	reset()
	blessing_until = maxf(float(data.get("blessing_until", 0.0)), 0.0)


## 탭으로 잡는다. 날고 있지 않으면 false
func catch() -> bool:
	if not flying:
		return false
	flying = false
	_schedule()
	var choices: Array[Reward] = [Reward.GOLD, Reward.BLESSING]
	if Skills.has_cooldown() and not Skills.is_sealed():
		choices.append(Reward.COOLDOWN)
	var reward: Reward = choices[rng.randi_range(0, choices.size() - 1)]
	var amount := 0.0
	match reward:
		Reward.GOLD:
			amount = Balance.treasure_gold(Game.stage, Game.gold_multiplier())
			Game.add_gold(amount)
		Reward.COOLDOWN:
			Skills.reset_cooldowns()
		Reward.BLESSING:
			amount = Balance.TREASURE_BLESSING_TIME
			blessing_until = _now() + amount  # 축복 중에 또 받으면 지금부터 다시 30초
	caught.emit(reward, amount)
	return true


func blessing_left() -> float:
	return maxf(blessing_until - _now(), 0.0)


## 처치 골드에 곱한다 (Game이 부른다)
func gold_multiplier() -> float:
	return Balance.TREASURE_BLESSING_MULTIPLIER if blessing_left() > 0.0 else 1.0


func _escape() -> void:
	flying = false
	flight_left = 0.0
	_schedule()
	escaped.emit()


func _schedule() -> void:
	next_in = rng.randf_range(Balance.TREASURE_INTERVAL_MIN, Balance.TREASURE_INTERVAL_MAX)


func _now() -> float:
	return clock_override if clock_override >= 0.0 else Time.get_unix_time_from_system()
