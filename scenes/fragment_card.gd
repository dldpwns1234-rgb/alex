extends AcceptDialog
## 기억 조각 카드 (GDD 7.11절): 독백 하나를 창으로 보인다.
## auto가 켜져 있으면(메인 화면의 카드) 새로 열린 조각을 하나씩 띄우고 닫을 때 본 것으로 표시한다.
## 꺼져 있으면(기억의 서) show_fragment()로 부를 때만 다시 보여 준다. Fragments의 함수만 부르고 표시만 한다.

const CARD_SIZE := Vector2i(600, 300)

@export var auto: bool = true
var _showing: int = -1


func _ready() -> void:
	ok_button_text = "계속"
	dialog_autowrap = true  # 긴 독백이 창 밖으로 잘리지 않게
	confirmed.connect(_on_closed)
	canceled.connect(_on_closed)
	if auto:
		Fragments.changed.connect(_show_next, CONNECT_DEFERRED)  # 불러오기 중간이 아니라 끝난 뒤에 본다
		_show_next.call_deferred()


func show_fragment(index: int) -> void:
	_showing = index
	title = "기억 조각 %d · %s" % [index + 1, Balance.fragment_title(index)]
	dialog_text = Balance.fragment_text(index)
	popup_centered(CARD_SIZE)


func _show_next() -> void:
	if visible:
		return
	var index := Fragments.next_unseen()
	if index >= 0:
		show_fragment(index)


func _on_closed() -> void:
	if auto and _showing >= 0:
		Fragments.mark_seen(_showing)  # changed가 다음 조각을 띄운다
	_showing = -1
