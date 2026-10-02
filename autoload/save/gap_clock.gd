extends RefCounted
## Save 2부: 실행 중 공백 재기 (CLAUDE.md 시간 규칙). 매 프레임 직전 프레임과의 간격을 돌려준다.
## 유닉스 시각과 단조 시계(get_ticks_msec, 웹에서도 탭이 숨겨진 동안 흐른다) 중 작은 쪽만 인정한다.
## 유닉스 시각만 보면 게임을 켠 채 기기 시계를 앞으로 돌릴 때마다 오프라인 보상을 받는다 (버그 점검 2026-10-02)

var _last_unix: float = Time.get_unix_time_from_system()
var _last_ticks: int = Time.get_ticks_msec()


func reset() -> void:
	_last_unix = Time.get_unix_time_from_system()
	_last_ticks = Time.get_ticks_msec()


## 직전 호출 뒤 흐른 초
func gap() -> float:
	var now := Time.get_unix_time_from_system()
	var ticks := Time.get_ticks_msec()
	var seconds := minf(now - _last_unix, (ticks - _last_ticks) / 1000.0)
	_last_unix = now
	_last_ticks = ticks
	return seconds
