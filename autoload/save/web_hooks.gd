extends RefCounted
## Save 1부: 웹 저장 훅. 웹에서는 창 blur가 포커스 아웃 알림으로 오지 않는다 (M3 브라우저 검사).
## 탭이 숨겨지거나(visibilitychange) 닫힐 때(pagehide)의 브라우저 이벤트를 직접 받아 저장한다. 데스크톱에서는 아무것도 하지 않는다

var _callback: JavaScriptObject  # 참조를 잃으면 수거되므로 들고 있는다


func _init(on_event: Callable) -> void:
	if not OS.has_feature("web"):
		return
	_callback = JavaScriptBridge.create_callback(func(_args: Array) -> void: on_event.call())
	JavaScriptBridge.get_interface("document").addEventListener("visibilitychange", _callback)
	JavaScriptBridge.get_interface("window").addEventListener("pagehide", _callback)
