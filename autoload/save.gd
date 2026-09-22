extends Node
## 저장, 불러오기, 오프라인 보상 (CLAUDE.md 저장 규칙과 시간 규칙, GDD 8절).
## user://save.json에 JSON으로 저장한다. 30초마다, 그리고 창이나 탭의 포커스를 잃을 때 저장한다.
## 매 프레임 유닉스 시각을 기록해서 10초 이상 비면 그 시간을 오프라인 보상으로 바꾼다.

signal saved()
signal offline_reward(seconds: float, gold: float)  # 인정된 시간과 받은 골드. 팝업용

const SAVE_VERSION: int = 1
const DEFAULT_SAVE_PATH: String = "user://save.json"
const AUTOSAVE_INTERVAL: float = 30.0  # 초. 게임 수치가 아니라 저장 주기
const BASE64_PATTERN: String = "^[A-Za-z0-9+/]+={0,2}$"

var save_path: String = DEFAULT_SAVE_PATH  # 테스트에서 다른 파일로 바꾼다
var _autosave_left: float = AUTOSAVE_INTERVAL
var _last_unix: float = Time.get_unix_time_from_system()
var _base64_regex := RegEx.create_from_string(BASE64_PATTERN)
var _web_callback: JavaScriptObject  # 브라우저 이벤트 콜백. 참조를 잃으면 수거된다


func _ready() -> void:
	_last_unix = Time.get_unix_time_from_system()
	_hook_browser_events()
	load_game()


## 웹에서는 창 blur가 포커스 아웃 알림으로 오지 않는 것을 브라우저 검사로 확인했다 (M3).
## 탭이 숨겨지거나 닫힐 때 오는 visibilitychange와 pagehide를 직접 받아 저장한다
func _hook_browser_events() -> void:
	if not OS.has_feature("web"):
		return
	_web_callback = JavaScriptBridge.create_callback(_on_browser_event)
	JavaScriptBridge.get_interface("document").addEventListener("visibilitychange", _web_callback)
	JavaScriptBridge.get_interface("window").addEventListener("pagehide", _web_callback)


func _on_browser_event(_args: Array) -> void:
	save_game()


func _process(delta: float) -> void:
	var now := Time.get_unix_time_from_system()
	var gap := now - _last_unix
	_last_unix = now
	if gap >= Balance.OFFLINE_MIN_GAP:
		grant_offline(gap)
	_autosave_left -= delta
	if _autosave_left <= 0.0:
		_autosave_left = AUTOSAVE_INTERVAL
		save_game()


## 공백 시간을 오프라인 보상으로 바꾼다. 스테이지는 진행하지 않는다.
## 동료 DPS와 처치 골드에 기억의 상점 효과는 넣고 스킬은 뺀다
func grant_offline(seconds: float) -> void:
	if seconds < Balance.OFFLINE_MIN_GAP:
		return
	var dps := Party.party_dps(false, false)
	var per_second := Balance.offline_gold_per_second(Game.stage, dps) * Prestige.gold_multiplier()
	per_second *= 1.0 + Training.value(Balance.Effect.KILL_GOLD)
	var gold := Balance.offline_reward(per_second, seconds, Prestige.level(Balance.Memory.NAP),
		Training.value(Balance.Effect.OFFLINE_RATE))
	if gold > 0.0:
		Game.add_gold(gold)
	# 시작할 때 불러오면서 부르면 아직 UI가 없으므로 프레임 끝에 알린다
	_emit_offline_reward.call_deferred(minf(seconds, Balance.OFFLINE_MAX_SECONDS), gold)
	save_game()


func _emit_offline_reward(seconds: float, gold: float) -> void:
	offline_reward.emit(seconds, gold)


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
		"skills": Skills.to_dict(),
		"training": Training.to_dict(),
		"prestige": Prestige.to_dict(),
	}


## 저장 데이터를 적용한다. 없는 부분은 각 오토로드가 기본값으로 채운다
func from_dict(data: Dictionary) -> void:
	var prestige_data: Variant = data.get("prestige", {})
	var party_data: Variant = data.get("party", {})
	var skills_data: Variant = data.get("skills", {})
	var training_data: Variant = data.get("training", {})
	var game_data: Variant = data.get("game", {})
	Prestige.from_dict(prestige_data if prestige_data is Dictionary else {})
	Party.from_dict(party_data if party_data is Dictionary else {})
	Skills.from_dict(skills_data if skills_data is Dictionary else {})
	Training.from_dict(training_data if training_data is Dictionary else {})
	Game.from_dict(game_data if game_data is Dictionary else {})


func save_game() -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("저장 실패: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(to_dict()))
	file.close()
	saved.emit()


## 저장 파일이 있으면 불러오고, 마지막 저장 이후 비운 시간을 오프라인 보상으로 준다.
## 없거나 깨졌으면 false를 주고 상태는 그대로 둔다
func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	file.close()
	var data := _parse(text)
	if data.is_empty():
		return false
	from_dict(data)
	var saved_at := float(data.get("saved_at", 0.0))
	if saved_at > 0.0:
		grant_offline(Time.get_unix_time_from_system() - saved_at)
	return true


## 내보내기 문자열: 저장 JSON을 base64로 인코딩한 것
func export_string() -> String:
	return Marshalls.utf8_to_base64(JSON.stringify(to_dict()))


## 내보내기 문자열을 적용하고 저장한다. 잘못된 문자열이면 false를 주고 상태는 그대로 둔다.
## 같은 문자열을 되풀이해 넣어 오프라인 보상을 여러 번 받지 못하도록, 가져오기는 보상을 주지 않는다
func import_string(text: String) -> bool:
	var compact := ""
	for part in text.split(" ", false):
		compact += part.strip_edges()
	# base64가 아닌 문자열을 풀려고 하면 엔진이 오류를 찍으므로 먼저 거른다 (글자 종류와 4의 배수 길이)
	if compact.is_empty() or compact.length() % 4 != 0 or _base64_regex.search(compact) == null:
		return false
	var json := Marshalls.base64_to_utf8(compact)
	if json.is_empty() or not apply_json(json):
		return false
	save_game()
	return true


## 모든 데이터를 지우고 새 판으로 시작한다. 설정 탭에서 두 번 확인한 뒤에만 부른다
func reset_data() -> void:
	Prestige.reset()
	Party.reset()
	Skills.reset()
	Training.reset()
	Game.reset()
	save_game()


## JSON 문자열을 검사해서 적용한다. 딕셔너리가 아니거나 save_version이 없으면 false
func apply_json(text: String) -> bool:
	var data := _parse(text)
	if data.is_empty():
		return false
	from_dict(data)
	return true


## 저장 JSON을 딕셔너리로. 딕셔너리가 아니거나 save_version이 없으면 빈 딕셔너리
## JSON.parse_string()은 실패할 때 엔진 오류를 찍으므로, 조용히 거부하려고 인스턴스의 parse()를 쓴다
func _parse(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return {}
	var data: Dictionary = json.data
	if not data.has("save_version"):
		return {}
	return data
