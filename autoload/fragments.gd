extends Node
## 기억 조각 (GDD 7.11절): 회귀·환생·마왕에 붙는 독백 12개. 열림은 업적 통계(Achievements)에서 매번 다시 계산하고,
## 저장하는 것은 "본 조각 수"뿐이다. 앞 조각이 열려야 다음 조각이 열리므로 열린 조각은 늘 앞에서부터 이어진다.
## 새로 열렸는데 아직 안 본 조각이 있으면 카드(scenes/fragment_card.gd)가 하나씩 띄우고 mark_seen()을 부른다.
## 게임 수치에는 영향이 없다. 상태 변경은 이 오토로드의 함수로만 한다.

signal changed()  # 열린 수나 본 수가 바뀌었다. 카드와 기억의 서가 다시 그린다

var unlocked_count: int = 0  # 앞에서부터 열린 조각 수 (통계에서 다시 계산)
var seen_count: int = 0      # 카드로 본 조각 수. 이보다 많이 열렸으면 카드를 띄운다


func _ready() -> void:
	Achievements.stat_changed.connect(_on_stat_changed.unbind(2))
	reset()


## 데이터 초기화에서만 부른다
func reset() -> void:
	seen_count = 0
	_recount()


func to_dict() -> Dictionary:
	return {"seen_count": seen_count}


## 업적(통계) 다음에 부른다. 조각이 없던 옛 저장은 이미 열린 조각을 본 것으로 친다 (불러오자마자 카드가 쏟아지지 않게)
func from_dict(data: Dictionary) -> void:
	_recount()
	seen_count = clampi(int(data.get("seen_count", unlocked_count)), 0, unlocked_count)
	changed.emit()


func is_unlocked(index: int) -> bool:
	return index < unlocked_count


## 아직 카드로 안 본 다음 조각. 없으면 -1
func next_unseen() -> int:
	return seen_count if seen_count < unlocked_count else -1


func mark_seen(index: int) -> void:
	if index == seen_count and index < unlocked_count:
		seen_count += 1
		changed.emit()


## 앞에서부터, 통계가 목표에 닿은 조각까지 센다
func _recount() -> void:
	var count := 0
	while count < Balance.FRAGMENTS.size() \
			and Achievements.value(Balance.fragment_stat(count)) >= Balance.fragment_goal(count):
		count += 1
	unlocked_count = count


func _on_stat_changed() -> void:
	var before := unlocked_count
	_recount()
	if unlocked_count != before:
		seen_count = mini(seen_count, unlocked_count)  # 데이터 초기화로 통계가 내려간 경우
		changed.emit()
