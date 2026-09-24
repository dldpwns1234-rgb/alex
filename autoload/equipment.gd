extends Node
## 장비 (GDD 7.6절). 보스를 잡으면 확률로 장비가 떨어진다. 지금 것보다 좋으면 바로 장착하고 나머지는 분해해 강화석이 된다.
## 칸(무기·깃발·장신구)마다 효과 종류가 정해져 있고, 강화는 칸에 붙어 새 장비에도 이어진다. 장비와 강화석은 회귀해도 남는다.
## 효과는 click_multiplier()·party_multiplier()·gold_multiplier()로 Party·Game·Save가 곱한다.
## 상태 변경은 이 오토로드의 함수로만 하고 UI는 표시만 한다.

signal equipment_changed(slot: int)
signal stones_changed(stones: float)
signal item_dropped(slot: int, grade: int, stage: int, equipped: bool)  # 알림용. equipped가 false면 분해했다

var slots: Array[Dictionary] = []    # 칸마다 {"grade": int, "stage": int}. 비어 있으면 빈 딕셔너리
var enhance_levels: Array[int] = []  # 칸의 강화 레벨. 장비를 바꿔도 남는다
var stones: float = 0.0              # 강화석
var random_drops: bool = true        # 테스트가 끈다 (무작위 드롭이 수치 검사를 흔들지 않게)


func _ready() -> void:
	reset()
	Game.monster_killed.connect(_on_monster_killed)


## 데이터 초기화에서만 부른다. 회귀는 지우지 않는다
func reset() -> void:
	slots.clear()
	enhance_levels.clear()
	for i in Balance.SLOT_LABELS.size():
		slots.append({})
		enhance_levels.append(0)
	stones = 0.0
	for i in slots.size():
		equipment_changed.emit(i)
	stones_changed.emit(stones)


func to_dict() -> Dictionary:
	return {"slots": slots.duplicate(true), "enhance": enhance_levels.duplicate(), "stones": stones}


## 없는 필드는 빈 칸·0으로, 이상한 값은 잘라낸다. 칸이 늘어나면 새 칸은 비어 있다
func from_dict(data: Dictionary) -> void:
	reset()
	var saved: Variant = data.get("slots", [])
	if saved is Array:
		for i in mini(saved.size(), slots.size()):
			if saved[i] is Dictionary and not saved[i].is_empty():
				slots[i] = {
					"grade": clampi(int(saved[i].get("grade", 0)), 0, Balance.GRADE_LABELS.size() - 1),
					"stage": maxi(int(saved[i].get("stage", 1)), 1),
				}
	var levels: Variant = data.get("enhance", [])
	if levels is Array:
		for i in mini(levels.size(), enhance_levels.size()):
			enhance_levels[i] = clampi(int(levels[i]), 0, Balance.ENHANCE_MAX)
	stones = maxf(float(data.get("stones", 0.0)), 0.0)
	for i in slots.size():
		equipment_changed.emit(i)
	stones_changed.emit(stones)


func has_item(slot: int) -> bool:
	return not slots[slot].is_empty()


func item_grade(slot: int) -> int:
	return int(slots[slot].get("grade", 0))


func item_stage(slot: int) -> int:
	return int(slots[slot].get("stage", 0))


## 칸의 효과 (더해지는 비율). 비어 있으면 0
func effect(slot: int) -> float:
	if not has_item(slot):
		return 0.0
	return Balance.item_effect(item_grade(slot), item_stage(slot), enhance_levels[slot])


## 빈손 도전 중에는 세 칸 모두 효과가 없다
func click_multiplier() -> float:
	return 1.0 if Challenges.blocks_equipment() else 1.0 + effect(Balance.Slot.WEAPON)


func party_multiplier() -> float:
	return 1.0 if Challenges.blocks_equipment() else 1.0 + effect(Balance.Slot.BANNER)


func gold_multiplier() -> float:
	return 1.0 if Challenges.blocks_equipment() else 1.0 + effect(Balance.Slot.CHARM)


## 장비가 떨어졌다. 지금 것보다 좋으면(같아도) 장착하고 옛것을 분해하며, 아니면 새것을 분해한다. 장착했으면 true
func drop(slot: int, grade: int, stage: int) -> bool:
	var better := not has_item(slot) \
		or Balance.item_power(grade, stage) >= Balance.item_power(item_grade(slot), item_stage(slot))
	if better:
		if has_item(slot):
			stones += Balance.dismantle_stones(item_grade(slot)) * Challenges.stone_multiplier()
		slots[slot] = {"grade": grade, "stage": stage}
		equipment_changed.emit(slot)
	else:
		stones += Balance.dismantle_stones(grade) * Challenges.stone_multiplier()
	stones_changed.emit(stones)
	item_dropped.emit(slot, grade, stage, better)
	return better


## 보스를 잡을 때: 확률로 칸과 등급을 굴린다
func roll_drop(stage: int) -> void:
	if not random_drops or randf() >= Balance.BOSS_DROP_CHANCE:
		return
	drop(Balance.roll_slot(randf()), Balance.roll_grade(randf()), stage)


func enhance_cost(slot: int) -> float:
	return Balance.enhance_cost(enhance_levels[slot])


func is_enhance_maxed(slot: int) -> bool:
	return enhance_levels[slot] >= Balance.ENHANCE_MAX


func can_enhance(slot: int) -> bool:
	return has_item(slot) and not is_enhance_maxed(slot) and stones >= enhance_cost(slot)


## 강화: 강화석을 내고 칸의 강화 레벨을 올린다. 빈 칸, 최대 레벨, 강화석 부족이면 false
func enhance(slot: int) -> bool:
	if not can_enhance(slot):
		return false
	stones -= enhance_cost(slot)
	enhance_levels[slot] += 1
	stones_changed.emit(stones)
	equipment_changed.emit(slot)
	return true


## 강화할 수 있는 칸이 하나라도 있는지 (용사 탭 점)
func any_enhanceable() -> bool:
	for slot in slots.size():
		if can_enhance(slot):
			return true
	return false


## 처치 직후라 아직 그 스테이지다: 보스 스테이지면 보스를 잡은 것
func _on_monster_killed(_reward: float) -> void:
	if Game.is_boss_stage():
		roll_drop(Game.stage)
