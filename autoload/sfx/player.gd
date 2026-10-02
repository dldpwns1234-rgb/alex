extends Node
## Sfx 1부: 오디오 버스(SFX·Music)와 음량, 효과음 재생, 배경음, 웹의 첫 입력 잠금. autoload/sfx.gd가 상속해 게임 시그널을 소리에 잇는다.
## - 효과음: 소리마다 플레이어 몇 개(동시 재생 수)를 두고, 최소 간격 안의 같은 소리는 버리며, 음높이를 조금씩 흔든다. 폭풍 베기(초당 10번)에도 소리가 쌓이지 않는다
## - 배경음: 들판·마왕성 두 곡을 교차 페이드로 바꾼다. 반복은 .wav.import의 loop_mode(2)가 맡는다
## - 웹: 브라우저는 사용자 입력 전에는 소리를 막는다. 첫 누름(unlock) 전에는 아무것도 틀지 않고, 그때 배경음을 시작한다
## - 울리는 중인지는 엔진이 아니라 여기 장부(끝나는 시각)로 센다. 소리 장치가 없는 헤드리스(테스트·도구)는 장부만 쓰고 엔진에 틀지 않는다
##   (헤드리스의 가짜 장치는 재생을 끝내지 않아 끝낼 때 소리 자원이 새고 동시 재생 수도 셀 수 없다)
## 소리 파일은 tools/make_sfx.gd·make_music.gd가 만들고 버스는 default_bus_layout.tres에 있다. 음량 설정은 Prefs가 저장하고 여기서 버스에 건다.

const SFX_DIR := "res://assets/sfx/"
const MUSIC_FILES := {"field": "res://assets/music/field.wav", "castle": "res://assets/music/castle.wav"}
const BUS_SFX := &"SFX"
const BUS_MUSIC := &"Music"
const PITCH_JITTER: float = 0.06  # 음높이를 ±6% 안에서 흔든다 (같은 소리가 기계처럼 되풀이되지 않게)
const MUSIC_DB: float = -4.0      # 곡 자체 음량. 설정 음량은 버스에 곱한다
const SILENT_DB: float = -60.0
const MUSIC_FADE: float = 1.5     # 곡을 바꿀 때 교차 페이드 (초)
## 소리 이름 → [동시 재생 수, 같은 소리의 최소 간격(ms), 음량(dB)]. 자주 나는 소리일수록 적게·작게
const CUES := {
	"tap": [3, 45, -9.0], "crit": [2, 60, -6.0], "kill": [2, 60, -7.0],
	"boss_appear": [1, 500, -2.0], "boss_kill": [1, 300, -2.0], "boss_fail": [1, 500, -3.0],
	"level_up": [2, 50, -6.0], "buy": [2, 50, -7.0], "promote": [1, 200, -3.0],
	"skill": [2, 100, -4.0], "achievement": [1, 300, -3.0], "item": [1, 200, -4.0],
	"prestige": [1, 1000, -1.0], "rebirth": [1, 1000, -1.0],
	"fairy_appear": [1, 500, -6.0], "fairy_catch": [1, 200, -3.0],
}

var unlocked: bool = false   # 소리를 낼 수 있는지. 웹은 첫 입력 전 false, 데스크톱은 처음부터 true
var music_track: String = "" # 지금 들려야 할 곡 ("field" 또는 "castle")
var last_pitch: float = 1.0  # 마지막 효과음의 음높이 배율 (테스트용)
var played: Dictionary = {}  # 소리 이름 → 실제로 낸 횟수 (테스트용)
var _silent: bool = false            # 소리 장치가 없다 (헤드리스). 장부만 쓴다
var _pools: Dictionary = {}          # 소리 이름 → Array[AudioStreamPlayer]
var _next: Dictionary = {}           # 소리 이름 → 다 차 있을 때 끊고 다시 쓸 플레이어 번호
var _last_msec: Dictionary = {}      # 소리 이름 → 마지막으로 낸 시각
var _busy_until: Dictionary = {}     # 플레이어 → 소리가 끝나는 시각(ms)
var _music: Dictionary = {}          # 곡 이름 → AudioStreamPlayer
var _music_on: Dictionary = {}       # 곡 이름 → 울리는 중인지 (페이드 아웃 중 포함)
var _fades: Dictionary = {}          # 곡 이름 → Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_silent = DisplayServer.get_name() == "headless"
	for cue: String in CUES:
		var stream: AudioStream = load(SFX_DIR + cue + ".wav")
		var pool: Array[AudioStreamPlayer] = []
		for i in int(CUES[cue][0]):
			pool.append(_make_player(stream, BUS_SFX, float(CUES[cue][2])))
		_pools[cue] = pool
		_next[cue] = 0
	for track: String in MUSIC_FILES:
		var music: AudioStream = load(MUSIC_FILES[track])
		if music is AudioStreamWAV and (music as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED:
			push_warning("배경음 %s의 반복이 꺼져 있다 (.wav.import의 edit/loop_mode=2)" % track)
		_music[track] = _make_player(music, BUS_MUSIC, SILENT_DB)
		_music_on[track] = false
	Prefs.audio_changed.connect(apply_volumes)
	unlocked = not OS.has_feature("web")
	apply_volumes()


## 끝낼 때 울리는 소리를 모두 멈추고 스트림을 뗀다. 재생 중인 채로 끝나면 엔진이 소리 자원을 놓지 못한다 (종료 때 누수 경고)
func _exit_tree() -> void:
	for node: Node in get_children():
		var player := node as AudioStreamPlayer
		if player != null:
			player.stop()
			player.stream = null


## 효과음 하나. 잠겨 있거나 꺼져 있거나 최소 간격 안이면 내지 않고 false. 플레이어가 다 차 있으면 돌아가며 하나를 끊는다
func play(cue: String) -> bool:
	if not unlocked or not Prefs.sfx_on or Prefs.sfx_volume <= 0.0 or not _pools.has(cue):
		return false
	var now := Time.get_ticks_msec()
	if _last_msec.has(cue) and now - int(_last_msec[cue]) < int(CUES[cue][1]):
		return false
	_last_msec[cue] = now
	var player := _pick(cue, now)
	last_pitch = 1.0 + randf_range(-PITCH_JITTER, PITCH_JITTER)
	player.pitch_scale = last_pitch
	_busy_until[player] = now + int(player.stream.get_length() / last_pitch * 1000.0)
	if not _silent:
		player.play()
	played[cue] = int(played.get(cue, 0)) + 1
	return true


## 지금 울리는 같은 소리 수 (동시 재생 수 이하)
func active_voices(cue: String) -> int:
	var now := Time.get_ticks_msec()
	var count := 0
	for player: AudioStreamPlayer in _pools.get(cue, []):
		if int(_busy_until.get(player, 0)) > now:
			count += 1
	return count


func voice_limit(cue: String) -> int:
	return int(CUES[cue][0]) if CUES.has(cue) else 0


## 최소 간격 기록과 낸 횟수를 지운다 (테스트용)
func reset_limits() -> void:
	_last_msec.clear()
	played.clear()


## 웹의 첫 입력. 이때부터 소리를 내고 배경음을 시작한다. 두 번째부터는 아무 일도 없다
func unlock() -> void:
	if unlocked:
		return
	unlocked = true
	_refresh_music()


func is_music_playing(track: String) -> bool:
	return bool(_music_on.get(track, false))


## 들려야 할 곡을 정한다. 다르면 교차 페이드로 바꾼다
func set_music_track(track: String) -> void:
	if track == music_track or not _music.has(track):
		return
	music_track = track
	_refresh_music()


## Prefs의 켬/끔과 음량을 버스에 건다. 음량 0이나 끔이면 버스를 막는다. 배경음을 끄면 곡도 멈춘다
func apply_volumes() -> void:
	_set_bus(BUS_SFX, Prefs.sfx_on, Prefs.sfx_volume)
	_set_bus(BUS_MUSIC, Prefs.music_on, Prefs.music_volume)
	_refresh_music()


func _set_bus(bus: StringName, on: bool, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_mute(index, not on or volume <= 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.001)))


## 고른 곡은 틀고(페이드 인) 나머지는 페이드 아웃해 멈춘다. 잠겨 있거나 배경음이 꺼져 있으면 모두 바로 멈춘다
func _refresh_music() -> void:
	var allowed := unlocked and Prefs.music_on and Prefs.music_volume > 0.0
	for track: String in _music:
		var player: AudioStreamPlayer = _music[track]
		var wanted := allowed and track == music_track
		if wanted == is_music_playing(track) and (not wanted or not _fades.has(track)):
			continue
		if _fades.has(track):
			(_fades[track] as Tween).kill()
			_fades.erase(track)
		if not allowed:
			_stop_music(track)
			continue
		if wanted and not is_music_playing(track):
			player.volume_db = SILENT_DB
			_music_on[track] = true
			if not _silent:
				player.play()
		var tween := create_tween()
		tween.tween_property(player, "volume_db", MUSIC_DB if wanted else SILENT_DB, MUSIC_FADE)
		if not wanted:
			tween.tween_callback(_stop_music.bind(track))
		tween.tween_callback(_on_fade_done.bind(track))
		_fades[track] = tween


func _stop_music(track: String) -> void:
	_music_on[track] = false
	(_music[track] as AudioStreamPlayer).stop()


func _on_fade_done(track: String) -> void:
	_fades.erase(track)


## 쉬는 플레이어가 있으면 그것, 다 울리는 중이면 돌아가며 하나를 끊고 쓴다
func _pick(cue: String, now: int) -> AudioStreamPlayer:
	var pool: Array = _pools[cue]
	for player: AudioStreamPlayer in pool:
		if int(_busy_until.get(player, 0)) <= now:
			return player
	var index: int = _next[cue]
	_next[cue] = (index + 1) % pool.size()
	return pool[index]


func _make_player(stream: AudioStream, bus: StringName, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = bus
	player.volume_db = volume_db
	add_child(player)
	return player
