extends Node
## 저장과 불러오기 (CLAUDE.md 저장 규칙). 오프라인 보상은 M3 세 번째 기능에서 붙는다.
## user://save.json에 JSON으로 저장한다. 30초마다, 그리고 창이나 탭의 포커스를 잃을 때 저장한다.

signal saved()

const SAVE_VERSION: int = 1
const DEFAULT_SAVE_PATH: String = "user://save.json"
const AUTOSAVE_INTERVAL: float = 30.0  # 초. 게임 수치가 아니라 저장 주기

var save_path: String = DEFAULT_SAVE_PATH  # 테스트에서 다른 파일로 바꾼다
var _autosave_left: float = AUTOSAVE_INTERVAL


func _ready() -> void:
	load_game()


func _process(delta: float) -> void:
	_autosave_left -= delta
	if _autosave_left <= 0.0:
		_autosave_left = AUTOSAVE_INTERVAL
		save_game()


## 창이나 탭의 포커스를 잃을 때, 창을 닫을 때, 모바일에서 앱이 뒤로 갈 때 저장한다
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED:
			save_game()


## 저장 데이터 전체. 새 필드를 넣으면 from_dict에서 기본값도 넣는다
func to_dict() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"game": Game.to_dict(),
		"party": Party.to_dict(),
	}


## 저장 데이터를 적용한다. 없는 부분은 각 오토로드가 기본값으로 채운다
func from_dict(data: Dictionary) -> void:
	var party_data: Variant = data.get("party", {})
	var game_data: Variant = data.get("game", {})
	Party.from_dict(party_data if party_data is Dictionary else {})
	Game.from_dict(game_data if game_data is Dictionary else {})


func save_game() -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("저장 실패: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(to_dict()))
	file.close()
	saved.emit()


## 저장 파일이 있으면 불러온다. 없거나 깨졌으면 false를 주고 상태는 그대로 둔다
func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	file.close()
	return apply_json(text)


## 내보내기 문자열: 저장 JSON을 base64로 인코딩한 것
func export_string() -> String:
	return Marshalls.utf8_to_base64(JSON.stringify(to_dict()))


## 내보내기 문자열을 적용하고 저장한다. 잘못된 문자열이면 false를 주고 상태는 그대로 둔다
func import_string(text: String) -> bool:
	var json := Marshalls.base64_to_utf8(text.strip_edges())
	if json.is_empty() or not apply_json(json):
		return false
	save_game()
	return true


## 모든 데이터를 지우고 새 판으로 시작한다. 설정 탭에서 두 번 확인한 뒤에만 부른다
func reset_data() -> void:
	Party.reset()
	Game.reset()
	save_game()


## JSON 문자열을 검사해서 적용한다. 딕셔너리가 아니거나 save_version이 없으면 false
## JSON.parse_string()은 실패할 때 엔진 오류를 찍으므로, 조용히 거부하려고 인스턴스의 parse()를 쓴다
func apply_json(text: String) -> bool:
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return false
	var data: Dictionary = json.data
	if not data.has("save_version"):
		return false
	from_dict(data)
	return true
