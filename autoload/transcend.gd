extends Node
## 초월 (GDD 7.12절). 이번 삶(지난 초월 뒤)에 최후의 마왕(4000)을 잡았으면 운명까지 내려놓고 별의 파편을 받는다.
## 별의 파편·별의 상점·초월 횟수는 남고, 장비·업적·기억 조각·도전 달성·설정·자동화 해금도 남는다.
## 효과는 damage_multiplier()·shortcut()·level()로 Rebirth·Promotions·Automation이 묻고, 시작 보너스는 grant_start_bonus()가 준다.
## 상태 변경은 이 오토로드의 함수로만 하고 UI는 표시만 한다.

signal stars_changed(stars: float)
signal star_changed(index: int, level: int)
signal transcended(reward: float)
signal ready_changed(ready: bool)  # 이번 삶에서 최후의 마왕을 잡아 초월할 수 있게 됐다 (또는 초월로 지워졌다)

var stars: float = 0.0           # 별의 파편
var star_levels: Array[int] = []  # 별의 상점 레벨. Balance.Star 순서
var count: int = 0                # 초월 횟수
var cycle_seconds: float = 0.0    # 이번 삶(지난 초월 뒤)에 흐른 게임 시간. 파편 수를 정한다
var final_cleared: bool = false   # 이번 삶에서 최후의 마왕을 잡았다


func _ready() -> void:
	reset()
	Game.demon_king_defeated.connect(_on_demon_king_defeated)


func _process(delta: float) -> void:
	cycle_seconds += minf(delta, Balance.MAX_DELTA)


## 데이터 초기화에서만 부른다. 초월은 perform()이다
func reset() -> void:
	stars = 0.0
	star_levels.clear()
	star_levels.resize(Balance.STARS.size())
	star_levels.fill(0)
	count = 0
	cycle_seconds = 0.0
	final_cleared = false
	stars_changed.emit(stars)
	for i in star_levels.size():
		star_changed.emit(i, 0)
	ready_changed.emit(false)


func to_dict() -> Dictionary:
	return {"stars": stars, "star_levels": star_levels.duplicate(), "count": count,
		"cycle_seconds": cycle_seconds, "final_cleared": final_cleared}


## 없는 필드는 기본값으로, 상한을 넘는 값은 잘라낸다. 초월이 없던 옛 저장은 첫 삶의 시간이 0부터 흐른다
func from_dict(data: Dictionary) -> void:
	reset()
	stars = clampf(float(data.get("stars", 0.0)), 0.0, Balance.MAX_NUMBER)
	var saved: Variant = data.get("star_levels", [])
	if saved is Array:
		for i in mini(saved.size(), star_levels.size()):
			star_levels[i] = clampi(int(saved[i]), 0, _cap(i))
	count = maxi(int(data.get("count", 0)), 0)
	cycle_seconds = maxf(float(data.get("cycle_seconds", 0.0)), 0.0)
	final_cleared = bool(data.get("final_cleared", false))
	stars_changed.emit(stars)
	for i in star_levels.size():
		star_changed.emit(i, star_levels[i])
	ready_changed.emit(final_cleared)


func can_transcend() -> bool:
	return final_cleared


## 지금 초월하면 받을 파편 (별자리 시련 '홀로 잊힌 자'의 단계 보상을 더한다)
func star_reward() -> float:
	return Balance.star_reward(cycle_seconds) + Trials.star_bonus()


## 초월: 파편을 받고 운명·기억·판·탑 층을 내려놓는다
func perform() -> bool:
	if not can_transcend():
		return false
	var reward := star_reward()
	stars = minf(stars + reward, Balance.MAX_NUMBER)
	count += 1
	cycle_seconds = 0.0
	final_cleared = false
	Rebirth.reset()   # 운명의 실, 운명의 상점, 환생 횟수
	Rebirth.keep_automation_fates()  # 자동화 운명은 1레벨로 남긴다 (상점에 1/1)
	Prestige.reset()  # 결정, 기억의 상점, 회귀 기록
	Tower.forget_floors()
	Party.reset()
	Skills.reset()
	Training.reset()
	Promotions.reset()
	Game.reset()
	grant_start_bonus()
	stars_changed.emit(stars)
	ready_changed.emit(false)
	transcended.emit(reward)
	Save.save_game()
	return true


## 초월·환생 직후의 시작 보너스: 별빛 날개(운명의 실), 기억의 잔향(검술·황금의 기억 레벨)
func grant_start_bonus() -> void:
	Rebirth.add_threads(Balance.wings_threads(level(Balance.Star.WINGS)))
	var echo := Balance.echo_levels(level(Balance.Star.ECHO))
	Prestige.grant_levels(Balance.Memory.SWORD, echo)
	Prestige.grant_levels(Balance.Memory.GOLD, echo)


## 심연 보상 등 초월 밖에서 주는 파편
func add_stars(amount: float) -> void:
	if amount <= 0.0:
		return
	stars = minf(stars + amount, Balance.MAX_NUMBER)
	stars_changed.emit(stars)


## 다른 오토로드가 _ready에서 물을 수 있어(오토로드 순서상 초월이 뒤) 준비 전에는 0
func level(index: int) -> int:
	return star_levels[index] if index < star_levels.size() else 0


func is_maxed(index: int) -> bool:
	var cap := Balance.star_max_level(index)
	return cap > 0 and star_levels[index] >= cap


func star_cost(index: int) -> float:
	return Balance.star_cost(star_levels[index])


func can_buy(index: int) -> bool:
	return not is_maxed(index) and stars >= star_cost(index)


func buy(index: int) -> bool:
	if not can_buy(index):
		return false
	stars -= star_cost(index)
	star_levels[index] += 1
	stars_changed.emit(stars)
	star_changed.emit(index, star_levels[index])
	return true


# 효과

## 별의 축복: 모든 피해 (Rebirth.damage_multiplier에 곱해진다)
func damage_multiplier() -> float:
	return Balance.blessing_multiplier(level(Balance.Star.BLESSING))


## 지름길: 환생 조건과 실 공식의 기준을 내리는 스테이지
func shortcut() -> int:
	return Balance.shortcut_stages(level(Balance.Star.SHORTCUT))


## 초월 1회부터 자동화 해금이 남는다 (Automation이 묻는다)
func keeps_automation() -> bool:
	return count > 0


func _on_demon_king_defeated() -> void:
	if Game.stage >= Balance.FINAL_STAGE and not Game.in_tower and not final_cleared:
		final_cleared = true
		ready_changed.emit(true)


func _cap(index: int) -> int:
	var cap := Balance.star_max_level(index)
	return cap if cap > 0 else 1000000
