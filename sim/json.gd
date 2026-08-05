class_name SimJson
extends RefCounted

## 데이터 파일 읽기 (ARCHITECTURE §5).
##
## JSON을 고른 대가로 타입 검증을 직접 해야 한다. 그 대가를 여기 한 곳에 모은다.
## 데이터 파일이 깨졌을 때 조용히 빈 값으로 넘어가면 나중에 원인을 찾기 어려우므로,
## 여기서 시끄럽게 실패한다.


static func read_dict(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("데이터 파일을 읽을 수 없습니다: %s" % path)
		return {}

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("데이터 파일이 JSON 객체가 아닙니다: %s" % path)
		return {}

	return parsed
