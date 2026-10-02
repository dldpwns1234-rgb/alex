extends SceneTree
## 효과음을 코드로 합성해 assets/sfx/<이름>.wav로 저장한다. 게임의 Sfx 오토로드(autoload/sfx.gd)가 같은 이름으로 튼다.
##
##   godot --headless --path . --script tools/make_sfx.gd
##
## 소리는 여기 함수와 상수가 원본이다. .wav는 손으로 고치지 않는다: 고친 뒤 다시 돌려서 함께 커밋한다.
## 새 .wav를 넣었으면 `--headless --import`를 돌린다. 톤: 짧고 부드러운 판타지 (종·하프·바람). 높은 음은 진폭을 낮춘다
## 배경음은 tools/make_music.gd가 만든다.

const Synth := preload("res://tools/synth.gd")
const OUT_DIR := "res://assets/sfx/"

## 이름 → [길이(초), 정규화 최고 진폭]. 자주 나는 소리일수록 작다
const SOUNDS: Dictionary = {
	"tap": [0.14, 0.45],
	"crit": [0.32, 0.55],
	"kill": [0.3, 0.42],
	"boss_appear": [1.5, 0.7],
	"boss_kill": [1.3, 0.65],
	"boss_fail": [1.0, 0.5],
	"level_up": [0.3, 0.4],
	"buy": [0.18, 0.32],
	"promote": [1.0, 0.6],
	"skill": [0.7, 0.55],
	"achievement": [1.3, 0.55],
	"item": [0.6, 0.45],
	"prestige": [2.0, 0.7],
	"rebirth": [2.6, 0.75],
	"fairy_appear": [0.7, 0.35],
	"fairy_catch": [0.9, 0.55],
}

const C5: float = 72.0  # MIDI 음 번호 기준
const TAIL_FADE: float = 0.25  # 소리 길이의 마지막 이만큼을 서서히 줄인다 (잘린 종 꼬리가 딸깍하지 않게)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var failed := 0
	for sound_name: String in SOUNDS:
		var spec: Array = SOUNDS[sound_name]
		var s := Synth.new(spec[0], false, sound_name.hash())
		call("_" + sound_name, s)
		s.fade_tail(TAIL_FADE)
		s.normalize(spec[1])
		var err := s.save(OUT_DIR + sound_name + ".wav")
		if err != OK:
			failed += 1
			push_error("%s 저장 실패: %s" % [sound_name, error_string(err)])
	print("효과음 %d개 저장 (실패 %d)" % [SOUNDS.size() - failed, failed])
	quit(0 if failed == 0 else 1)


static func _n(offset: float) -> float:
	return Synth.midi(C5 + offset)


## 탭: 짧은 바람 소리(휙)와 낮은 둔탁함. 초당 10번 들어도 귀가 아프지 않게 고음을 걸렀다
func _tap(s: Synth) -> void:
	s.noise(0.0, 0.12, 0.55, 1600.0, 450.0, 0.006, 0.03)
	s.tone(0.0, 0.08, 200.0, 105.0, 0.6, 0.003, 0.04)


## 치명타: 탭 위에 맑은 쇳소리 종
func _crit(s: Synth) -> void:
	_tap(s)
	s.bell(0.01, _n(19.0), 0.35, 0.09)
	s.bell(0.03, _n(24.0), 0.2, 0.07)


## 처치: 부드러운 퍽과 위로 튀는 작은 음
func _kill(s: Synth) -> void:
	s.noise(0.0, 0.18, 0.4, 900.0, 250.0, 0.004, 0.06)
	s.tone(0.02, 0.1, _n(7.0), _n(12.0), 0.3, 0.004, 0.06, Synth.Wave.TRIANGLE)


## 보스 등장: 낮은 북과 어두운 5도 화음, 멀리 울리는 징
func _boss_appear(s: Synth) -> void:
	s.tone(0.0, 0.5, 110.0, 55.0, 1.0, 0.003, 0.3)
	s.tone(0.05, 0.9, Synth.midi(45.0), Synth.midi(45.0), 0.35, 0.15, 0.6, Synth.Wave.SOFT, 0.3)
	s.tone(0.05, 0.9, Synth.midi(52.0), Synth.midi(52.0), 0.25, 0.15, 0.6, Synth.Wave.SOFT, 0.3)
	s.bell(0.0, Synth.midi(45.0), 0.3, 0.5)


## 보스 처치: 도·미·솔·도 종 아르페지오
func _boss_kill(s: Synth) -> void:
	var notes: PackedFloat32Array = [0.0, 4.0, 7.0, 12.0]
	for i in notes.size():
		s.bell(0.09 * i, _n(notes[i]), 0.5 if i < 3 else 0.7, 0.18 if i < 3 else 0.35)
	s.tone(0.27, 0.6, _n(-12.0), _n(-12.0), 0.25, 0.05, 0.5, Synth.Wave.SOFT, 0.3)


## 보스 실패: 내려가는 두 음 (미 → 도), 낮게
func _boss_fail(s: Synth) -> void:
	s.tone(0.0, 0.25, _n(-8.0), _n(-8.0), 0.45, 0.01, 0.25, Synth.Wave.SOFT, 0.1)
	s.tone(0.22, 0.55, _n(-12.0), _n(-13.0), 0.45, 0.01, 0.35, Synth.Wave.SOFT, 0.2)
	s.tone(0.0, 0.8, 82.0, 70.0, 0.25, 0.05, 0.5)


## 용사 레벨업: 위로 짧게 두 번
func _level_up(s: Synth) -> void:
	s.tone(0.0, 0.07, _n(7.0), _n(7.0), 0.5, 0.003, 0.05, Synth.Wave.TRIANGLE, 0.02)
	s.tone(0.06, 0.12, _n(14.0), _n(14.0), 0.45, 0.003, 0.06, Synth.Wave.TRIANGLE, 0.03)


## 구매 (동료·단련·상점·강화): 작은 동전 딸깍
func _buy(s: Synth) -> void:
	s.bell(0.0, _n(16.0), 0.5, 0.04)
	s.bell(0.03, _n(21.0), 0.3, 0.035)


## 승급: 솔·시·레·솔 위로, 반짝이 둘
func _promote(s: Synth) -> void:
	var notes: PackedFloat32Array = [-5.0, -1.0, 2.0, 7.0]
	for i in notes.size():
		s.pluck(0.07 * i, _n(notes[i]), 0.45, 0.2)
	s.bell(0.3, _n(19.0), 0.25, 0.2)
	s.bell(0.38, _n(26.0), 0.15, 0.15)


## 스킬 발동: 올라가는 바람(휙)과 맑은 화음
func _skill(s: Synth) -> void:
	s.noise(0.0, 0.45, 0.4, 350.0, 2200.0, 0.2, 0.25)
	s.tone(0.15, 0.3, _n(4.0), _n(4.0), 0.3, 0.03, 0.2, Synth.Wave.SOFT, 0.2)
	s.tone(0.15, 0.3, _n(11.0), _n(11.0), 0.2, 0.03, 0.2, Synth.Wave.SOFT, 0.2)


## 업적: 솔 → 도 종 두 번
func _achievement(s: Synth) -> void:
	s.bell(0.0, _n(7.0), 0.5, 0.3)
	s.bell(0.13, _n(12.0), 0.6, 0.4)


## 장비 획득: 동전 두 번과 낮은 받침음
func _item(s: Synth) -> void:
	s.bell(0.0, _n(14.0), 0.45, 0.1)
	s.bell(0.07, _n(19.0), 0.45, 0.14)
	s.tone(0.0, 0.2, _n(-5.0), _n(-5.0), 0.3, 0.005, 0.12, Synth.Wave.SOFT)


## 회귀: 부풀어 오르는 화음 위로 올라가는 반짝이 (5음계)
func _prestige(s: Synth) -> void:
	for offset: float in [-12.0, -5.0, 0.0]:
		s.tone(0.0, 1.2, _n(offset), _n(offset), 0.25, 0.6, 1.5, Synth.Wave.SOFT, 0.6)
	var scale: PackedFloat32Array = [0.0, 2.0, 4.0, 7.0, 9.0, 12.0, 14.0, 16.0, 19.0, 21.0, 24.0]
	for i in scale.size():
		s.bell(0.08 * i, _n(scale[i]), 0.22, 0.18)
	s.noise(0.0, 1.0, 0.15, 800.0, 5000.0, 0.7, 0.6)


## 환생: 더 낮고 큰 화음, 징, 내려왔다 올라가는 반짝이
func _rebirth(s: Synth) -> void:
	s.tone(0.0, 0.8, 98.0, 49.0, 0.6, 0.003, 0.5)
	for offset: float in [-24.0, -17.0, -12.0, -8.0]:
		s.tone(0.0, 1.6, _n(offset), _n(offset), 0.22, 0.8, 2.0, Synth.Wave.SOFT, 0.8)
	var scale: PackedFloat32Array = [12.0, 7.0, 4.0, 0.0, 4.0, 7.0, 12.0, 16.0, 19.0, 24.0]
	for i in scale.size():
		s.bell(0.3 + 0.1 * i, _n(scale[i]), 0.2, 0.22)
	s.bell(0.0, Synth.midi(43.0), 0.3, 0.7)


## 보물 요정 등장: 높고 작은 반짝임 넷
func _fairy_appear(s: Synth) -> void:
	var notes: PackedFloat32Array = [16.0, 19.0, 23.0, 28.0]
	for i in notes.size():
		s.bell(0.06 * i, _n(notes[i]), 0.3, 0.09)
	s.echo(0.11, 0.3)


## 보물 요정 잡기: 반짝이 아르페지오와 동전
func _fairy_catch(s: Synth) -> void:
	var notes: PackedFloat32Array = [12.0, 16.0, 19.0, 24.0, 28.0]
	for i in notes.size():
		s.bell(0.05 * i, _n(notes[i]), 0.3, 0.15)
	s.bell(0.25, _n(19.0), 0.4, 0.2)
	s.tone(0.0, 0.3, _n(0.0), _n(0.0), 0.25, 0.01, 0.2, Synth.Wave.SOFT, 0.1)
	s.echo(0.13, 0.25)
