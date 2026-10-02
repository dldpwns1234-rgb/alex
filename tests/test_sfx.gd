extends "res://tests/test_case.gd"
## 소리(Prefs·Sfx): 소리 설정의 기본값·바꾸기·저장·옛 저장·초기화, 버스 음량과 끔, 같은 소리의 동시 재생 수와 최소 간격,
## 음높이 흔들기, 웹의 첫 입력 잠금, 마왕성 곡 고르기, 버튼을 누른 구매만 소리 내기


func run() -> void:
	_fresh_run()
	Sfx.unlocked = true
	_settings()
	_buses()
	_limits()
	_unlock()
	_music()
	await _purchases()
	_fresh_run()
	Sfx.unlocked = true
	Sfx.reset_limits()


func _settings() -> void:
	_equal([Prefs.sfx_on, Prefs.music_on], [true, true], "기본은 효과음·배경음 모두 켬")
	_close(Prefs.sfx_volume, Prefs.DEFAULT_SFX_VOLUME, "효과음 기본 음량")
	_close(Prefs.music_volume, Prefs.DEFAULT_MUSIC_VOLUME, "배경음 기본 음량")
	var seen: Array[int] = [0]
	var handler := func() -> void: seen[0] += 1
	Prefs.audio_changed.connect(handler)
	Prefs.set_sfx_volume(0.3)
	Prefs.set_sfx_volume(0.3)
	_equal(seen[0], 1, "바꿀 때만 시그널 (같은 값은 조용하다)")
	Prefs.set_music_volume(5.0)
	_close(Prefs.music_volume, 1.0, "음량은 1을 넘지 않는다")
	Prefs.set_music_volume(-1.0)
	_close(Prefs.music_volume, 0.0, "음량은 0 아래로 내려가지 않는다")
	Prefs.set_music_on(false)
	Prefs.set_sfx_on(false)
	Prefs.set_music_volume(0.25)
	Prefs.audio_changed.disconnect(handler)

	var data := Save.to_dict()
	_equal(data["prefs"]["sfx_on"], false, "효과음 끔 저장")
	_close(float(data["prefs"]["music_volume"]), 0.25, "배경음 음량 저장")
	Prefs.reset()
	_equal(Prefs.sfx_on, true, "초기화는 켬")
	Save.from_dict(data)
	_equal([Prefs.sfx_on, Prefs.music_on], [false, false], "켬/끔 복원")
	_close(Prefs.sfx_volume, 0.3, "효과음 음량 복원")
	_close(Prefs.music_volume, 0.25, "배경음 음량 복원")
	Save.from_dict({"save_version": 1, "prefs": {"sheet_height": 500.0}})
	_equal([Prefs.sfx_on, Prefs.music_on], [true, true], "소리 설정이 없던 옛 저장은 둘 다 켬")
	_close(Prefs.sfx_volume, Prefs.DEFAULT_SFX_VOLUME, "옛 저장은 기본 음량")
	_close(Prefs.sheet_height, 500.0, "옛 저장의 시트 높이는 그대로")

	Prefs.set_sfx_volume(0.1)
	Game.reset()
	_close(Prefs.sfx_volume, 0.1, "새 판(회귀)을 시작해도 남는다")
	Save.reset_data()
	_close(Prefs.sfx_volume, Prefs.DEFAULT_SFX_VOLUME, "데이터 초기화는 기본값으로")
	_fresh_run()


func _buses() -> void:
	var sfx_bus := AudioServer.get_bus_index(Sfx.BUS_SFX)
	var music_bus := AudioServer.get_bus_index(Sfx.BUS_MUSIC)
	_equal(sfx_bus > 0 and music_bus > 0, true, "SFX·Music 버스가 있다")
	_equal(AudioServer.get_bus_send(sfx_bus), &"Master", "SFX는 Master로 보낸다")
	Prefs.set_sfx_volume(0.5)
	_close(AudioServer.get_bus_volume_db(sfx_bus), linear_to_db(0.5), "효과음 음량이 버스 dB로")
	_equal(AudioServer.is_bus_mute(sfx_bus), false, "켜져 있으면 버스가 열린다")
	Prefs.set_sfx_volume(0.0)
	_equal(AudioServer.is_bus_mute(sfx_bus), true, "음량 0이면 버스를 막는다")
	_equal(Sfx.play("kill"), false, "음량 0이면 효과음을 내지 않는다")
	Prefs.set_sfx_volume(0.8)
	Prefs.set_music_on(false)
	_equal(AudioServer.is_bus_mute(music_bus), true, "배경음 끔이면 Music 버스를 막는다")
	_equal(Sfx.is_music_playing(Sfx.music_track), false, "배경음 끔이면 곡도 멈춘다")
	Prefs.set_music_on(true)
	_equal(Sfx.is_music_playing(Sfx.music_track), true, "다시 켜면 곡이 이어진다")


func _limits() -> void:
	Sfx.reset_limits()
	_equal(Sfx.play("tap"), true, "탭 소리")
	_equal(Sfx.play("tap"), false, "최소 간격 안의 같은 소리는 버린다")
	_equal(Sfx.play("kill"), true, "다른 소리는 따로 센다")
	_equal(Sfx.play("없는 소리"), false, "없는 소리는 조용히 false")
	var jitter_ok := true
	for i in 30:  # 폭풍 베기 3초 몫. 간격 기록을 지워 가며 몰아친다
		Sfx.reset_limits()
		Sfx.play("tap")
		jitter_ok = jitter_ok and absf(Sfx.last_pitch - 1.0) <= Sfx.PITCH_JITTER + 0.0001
	_equal(Sfx.active_voices("tap") <= Sfx.voice_limit("tap"), true, "같은 소리는 동시 재생 수까지만 울린다")
	_equal(Sfx.voice_limit("tap"), 3, "탭은 셋까지")
	_equal(jitter_ok, true, "음높이는 ±%d%% 안에서 흔든다" % roundi(Sfx.PITCH_JITTER * 100.0))
	Prefs.set_sfx_on(false)
	Sfx.reset_limits()
	_equal(Sfx.play("tap"), false, "효과음 끔이면 내지 않는다")
	Prefs.set_sfx_on(true)


## 웹은 첫 입력 전에 소리를 막는다: 그 전에는 아무것도 틀지 않고(오류 없이 false), 첫 누름에 열고 곡을 시작한다
func _unlock() -> void:
	Sfx.unlocked = false
	Sfx.apply_volumes()
	Sfx.reset_limits()
	_equal(Sfx.play("crit"), false, "잠겨 있으면 효과음을 내지 않는다")
	_equal(Sfx.is_music_playing(Sfx.music_track), false, "잠겨 있으면 곡도 멈춰 있다")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	Sfx._input(press)
	_equal(Sfx.unlocked, true, "첫 누름에 열린다")
	_equal(Sfx.is_music_playing(Sfx.music_track), true, "열리면 곡이 시작된다")
	_equal(Sfx.play("crit"), true, "열린 뒤 효과음")
	Sfx.unlock()
	_equal(Sfx.unlocked, true, "두 번 열어도 그대로")


func _music() -> void:
	Game.reset()
	_equal(Sfx.music_track, "field", "들판 곡으로 시작")
	Game.stage = Balance.CASTLE_STAGE
	Game.stage_changed.emit(Game.stage)
	_equal(Sfx.music_track, "castle", "마왕성(600부터)은 어두운 곡")
	_equal(Sfx.is_music_playing("castle"), true, "마왕성 곡이 울린다")
	Game.reset()
	_equal(Sfx.music_track, "field", "새 판이면 들판 곡으로")


## 버튼을 누른 그 프레임에 오른 레벨만 소리를 낸다 (자동 강화·불러오기는 조용하다). 버튼 시그널이 먼저든 나중이든 같다
func _purchases() -> void:
	_fresh_run()
	Sfx.reset_limits()
	Game.gold = 1.0e6
	Party.buy_hero()
	_equal(Sfx.played.get("level_up", 0), 0, "버튼 없이 오른 레벨은 조용하다")
	await get_tree().process_frame
	Sfx.note_button_press()
	_equal(Sfx.played.get("level_up", 0), 0, "앞 프레임의 레벨 변화는 다음 버튼에 끌려오지 않는다")
	Sfx.note_button_press()
	Party.buy_hero()
	_equal(Sfx.played.get("level_up", 0), 1, "버튼을 누르고 산 용사 레벨업")
	await get_tree().process_frame
	Sfx.reset_limits()
	Party.buy_companion(0)
	Sfx.note_button_press()
	_equal(Sfx.played.get("buy", 0), 1, "사고 나서 버튼 시그널이 와도 구매 소리")
	Party.reset()
	_equal(Sfx.played.get("buy", 0), 1, "레벨이 내려가면(새 판) 조용하다")
