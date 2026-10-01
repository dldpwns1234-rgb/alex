extends "res://tests/test_case.gd"
## 기억 조각 (GDD 7.11절): 표, 통계로 열림, 앞 조각을 건너뛰지 않음, 본 수, 저장과 옛 저장 호환, 데이터 초기화


func run() -> void:
	_fresh_run()
	Fragments.reset()
	_test_table()
	_test_unlock_in_order()
	_test_seen()
	_test_save()
	_test_reset()
	_fresh_run()
	Fragments.reset()


func _test_table() -> void:
	var titles := {}
	for i in Balance.FRAGMENTS.size():
		titles[Balance.fragment_title(i)] = true
		_equal(Balance.fragment_text(i).is_empty(), false, "%d번 조각에 독백이 있다" % i)
		_equal(Balance.fragment_goal(i) > 0.0, true, "%d번 조각의 목표는 양수" % i)
	_equal(titles.size(), Balance.FRAGMENTS.size(), "조각 제목은 겹치지 않는다")
	_equal(Balance.FRAGMENTS.size(), 12, "조각은 12개 (docs/STORY.md)")
	_equal(Balance.fragment_hint(1), "스테이지 200 도달", "잠긴 조각의 힌트")


func _test_unlock_in_order() -> void:
	_equal(Fragments.unlocked_count, 0, "처음에는 열린 조각이 없다")
	_equal(Fragments.next_unseen(), -1, "볼 조각이 없다")
	Achievements.raise(Balance.Stat.STAGE, 350.0)
	_equal(Fragments.unlocked_count, 0, "첫 회귀 전에는 스테이지가 높아도 열리지 않는다 (앞 조각을 건너뛰지 않는다)")
	Achievements.raise(Balance.Stat.PRESTIGES, 1.0)
	_equal(Fragments.unlocked_count, 2, "첫 회귀로 1번이 열리고, 이미 넘은 스테이지 200의 2번도 이어서 열린다")
	_equal(Fragments.is_unlocked(1), true, "2번 열림")
	_equal(Fragments.is_unlocked(2), false, "3번(회귀 3회)은 아직")
	Achievements.raise(Balance.Stat.PRESTIGES, 3.0)
	_equal(Fragments.unlocked_count, 4, "회귀 3회로 3번, 이미 넘은 300의 4번까지")


func _test_seen() -> void:
	_equal(Fragments.next_unseen(), 0, "안 본 첫 조각부터")
	Fragments.mark_seen(2)
	_equal(Fragments.seen_count, 0, "순서를 건너뛴 표시는 무시한다")
	Fragments.mark_seen(0)
	_equal(Fragments.next_unseen(), 1, "다음 조각")
	for i in range(1, 4):
		Fragments.mark_seen(i)
	_equal(Fragments.next_unseen(), -1, "열린 것을 다 보면 없다")
	Fragments.mark_seen(4)
	_equal(Fragments.seen_count, 4, "안 열린 조각은 본 것으로 못 친다")


func _test_save() -> void:
	var data := Save.to_dict()
	_equal(data.has("fragments"), true, "저장 데이터에 조각이 들어간다")
	Fragments.seen_count = 1
	Save.from_dict(data)
	_equal(Fragments.unlocked_count, 4, "열림은 통계에서 다시 계산한다")
	_equal(Fragments.seen_count, 4, "본 수 복원")
	var old := data.duplicate(true)
	old.erase("fragments")
	Save.from_dict(old)
	_equal(Fragments.seen_count, 4, "조각이 없던 옛 저장은 열린 조각을 본 것으로 친다")
	_equal(Fragments.next_unseen(), -1, "옛 저장을 불러와도 카드가 쏟아지지 않는다")
	var json := JSON.parse_string(JSON.stringify(data)) as Dictionary
	Fragments.seen_count = 0
	Save.from_dict(json)
	_equal(Fragments.seen_count, 4, "JSON을 거친 본 수")


func _test_reset() -> void:
	Save.reset_data()
	_equal(Fragments.unlocked_count, 0, "데이터 초기화로 모두 잠긴다")
	_equal(Fragments.seen_count, 0, "본 수도 0")
