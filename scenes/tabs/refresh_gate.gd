extends Node
## 화면 갱신 문: 시그널이 오면 "다시 그려야 함"만 표시하고, 주인이 보일 때 프레임당 한 번만 갱신한다.
## 연쇄 처치 한 번에 골드·처치 수·스테이지 시그널이 함께 나가는데, 탭마다 바로 다시 계산하면 안 보이는 탭까지
## 12~16ms가 들어 프레임이 떨어졌다 (2026-10-02 측정, 동료 탭 골드 효율 2.5ms·단련 탭 2.3ms).
## 쓰는 법: _ready 첫머리에서 _gate = RefreshGate.new(_refresh, self) 와 add_child(_gate), 시그널은 _gate.queue에 잇는다.

var _refresh: Callable
var _host: CanvasItem
var _self_hiding: bool  # 해금 전에는 스스로 숨는 절(초월·시련 …): 자기 대신 부모가 보일 때 갱신해야 열린다
var _dirty: bool = false


func _init(refresh: Callable, host: CanvasItem, self_hiding: bool = false) -> void:
	_refresh = refresh
	_host = host
	_self_hiding = self_hiding


## 시그널 인자는 버린다 (bind 없이 어느 시그널에나 잇는다)
func queue(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	_dirty = true


func _process(_delta: float) -> void:
	var watched := _host.get_parent() as CanvasItem if _self_hiding else _host
	if _dirty and watched != null and watched.is_visible_in_tree():
		_dirty = false
		_refresh.call()
