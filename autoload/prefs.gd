extends Node
## 화면·소리 설정 (GDD 9절): 하단 메뉴 시트의 높이, 효과음과 배경음의 켬/끔과 음량.
## 게임 수치가 아니라 보고 듣는 방식이라 회귀·환생해도 남고 데이터 초기화에서만 기본값으로 돌아간다.
## 저장은 Save가 "prefs" 절로 한다. UI는 set_…()으로 바꾸고 시그널을 받아 움직인다 (scenes/sheet.gd, 소리는 Sfx가 버스에 건다).

signal sheet_height_changed(height: float)
signal audio_changed()  # 효과음·배경음의 켬/끔이나 음량이 바뀌었다

const DEFAULT_SFX_VOLUME: float = 0.8    # 0~1. 버스 음량은 Sfx가 dB로 바꾼다
const DEFAULT_MUSIC_VOLUME: float = 0.5  # 배경음은 효과음보다 낮게 시작한다

var sheet_height: float = 0.0  # 하단 메뉴 시트 높이(px). 0이면 접힌 기본 높이 (화면이 정한다)
var sfx_on: bool = true
var music_on: bool = true
var sfx_volume: float = DEFAULT_SFX_VOLUME
var music_volume: float = DEFAULT_MUSIC_VOLUME


## 바꾸면 알린다. 같은 값이면 조용하다
func set_sheet_height(height: float) -> void:
	var clamped := maxf(height, 0.0)
	if is_equal_approx(clamped, sheet_height):
		return
	sheet_height = clamped
	sheet_height_changed.emit(sheet_height)


func set_sfx_on(on: bool) -> void:
	if on != sfx_on:
		sfx_on = on
		audio_changed.emit()


func set_music_on(on: bool) -> void:
	if on != music_on:
		music_on = on
		audio_changed.emit()


## 음량은 0~1로 자른다. 같은 값이면 조용하다
func set_sfx_volume(volume: float) -> void:
	var clamped := clampf(volume, 0.0, 1.0)
	if not is_equal_approx(clamped, sfx_volume):
		sfx_volume = clamped
		audio_changed.emit()


func set_music_volume(volume: float) -> void:
	var clamped := clampf(volume, 0.0, 1.0)
	if not is_equal_approx(clamped, music_volume):
		music_volume = clamped
		audio_changed.emit()


func reset() -> void:
	set_sheet_height(0.0)
	_set_audio(true, true, DEFAULT_SFX_VOLUME, DEFAULT_MUSIC_VOLUME)


func to_dict() -> Dictionary:
	return {
		"sheet_height": sheet_height,
		"sfx_on": sfx_on,
		"music_on": music_on,
		"sfx_volume": sfx_volume,
		"music_volume": music_volume,
	}


## 없는 필드는 기본값으로 (소리 설정이 없던 옛 저장은 둘 다 켬, 기본 음량)
func from_dict(data: Dictionary) -> void:
	set_sheet_height(float(data.get("sheet_height", 0.0)))
	_set_audio(bool(data.get("sfx_on", true)), bool(data.get("music_on", true)),
		float(data.get("sfx_volume", DEFAULT_SFX_VOLUME)), float(data.get("music_volume", DEFAULT_MUSIC_VOLUME)))


## 소리 설정 넷을 한꺼번에 바꾸고 바뀌었으면 한 번만 알린다
func _set_audio(new_sfx_on: bool, new_music_on: bool, new_sfx_volume: float, new_music_volume: float) -> void:
	var before := [sfx_on, music_on, sfx_volume, music_volume]
	sfx_on = new_sfx_on
	music_on = new_music_on
	sfx_volume = clampf(new_sfx_volume, 0.0, 1.0)
	music_volume = clampf(new_music_volume, 0.0, 1.0)
	if before != [sfx_on, music_on, sfx_volume, music_volume]:
		audio_changed.emit()
