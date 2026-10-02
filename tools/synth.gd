extends RefCounted
## 소리 합성 도구: 버퍼 하나에 음(사인·삼각·부드러운 배음), 종소리, 걸러 낸 잡음을 더하고 16비트 WAV로 저장한다.
## tools/make_sfx.gd(효과음)와 tools/make_music.gd(배경음)가 쓴다. 게임에는 들어가지 않는다 (익스포트에서 tools/ 제외).
## wrap이 켜진 버퍼는 끝을 넘친 꼬리를 앞으로 감는다: 반복 곡이 이음매 없이 돈다.

enum Wave { SINE, TRIANGLE, SOFT }  # SOFT = 사인 + 약한 2·3배음 (하프·피리 사이)

const RATE: int = 22050          # 표본률. 웹 용량과 판타지 톤(고음 적음) 사이
const CLICK_GUARD: float = 0.004 # 음 끝을 이만큼 페이드해 딸깍 소리를 막는다
const BELL_PARTIALS: PackedFloat32Array = [1.0, 2.0, 2.76, 4.07]   # 종의 비화성 배음 (주파수 배)
const BELL_LEVELS: PackedFloat32Array = [1.0, 0.45, 0.25, 0.1]
const BELL_DECAYS: PackedFloat32Array = [1.0, 0.6, 0.4, 0.25]      # 높은 배음일수록 빨리 사라진다

var data: PackedFloat32Array
var wrap: bool
var _rng := RandomNumberGenerator.new()


func _init(seconds: float, wrap_around: bool = false, seed_value: int = 7) -> void:
	data.resize(int(round(seconds * RATE)))
	data.fill(0.0)
	wrap = wrap_around
	_rng.seed = seed_value  # 같은 상수면 같은 파일이 나온다


static func midi(note: float) -> float:
	return 440.0 * pow(2.0, (note - 69.0) / 12.0)


## 음 하나. freq_from에서 freq_to로 지수로 미끄러진다. 엔벨로프 = 선형 attack × exp(-t/tau), length 뒤 release 동안 0으로
func tone(start: float, length: float, freq_from: float, freq_to: float, amp: float,
		attack: float, tau: float, wave: Wave = Wave.SINE, release: float = 0.05) -> void:
	var total := length + release
	var count := int(total * RATE)
	var offset := int(start * RATE)
	var phase := 0.0
	var ratio := freq_to / freq_from
	for i in count:
		var t := float(i) / RATE
		var freq := freq_from * pow(ratio, minf(t / maxf(length, 0.001), 1.0))
		phase = fmod(phase + freq / RATE, 1.0)
		var env := amp * minf(t / maxf(attack, 0.0005), 1.0) * exp(-t / tau)
		if t > length:
			env *= 1.0 - (t - length) / release
		env *= minf((total - t) / CLICK_GUARD, 1.0)
		_add(offset + i, env * _wave(phase, wave))


## 종소리: 비화성 배음 넷. 높은 배음부터 사라진다
func bell(start: float, freq: float, amp: float, tau: float) -> void:
	for k in BELL_PARTIALS.size():
		var length := tau * BELL_DECAYS[k] * 5.0
		tone(start, length, freq * BELL_PARTIALS[k], freq * BELL_PARTIALS[k], amp * BELL_LEVELS[k], 0.002, tau * BELL_DECAYS[k], Wave.SINE, 0.02)


## 퉁기는 현 (하프): SOFT 파형에 빠른 attack, 긴 꼬리
func pluck(start: float, freq: float, amp: float, tau: float) -> void:
	tone(start, tau * 4.0, freq, freq, amp, 0.004, tau, Wave.SOFT, 0.05)


## 걸러 낸 잡음 (휙, 퍽). 2단 저역 필터의 차단 주파수가 cut_from에서 cut_to로 움직인다
func noise(start: float, length: float, amp: float, cut_from: float, cut_to: float, attack: float, tau: float) -> void:
	var count := int(length * RATE)
	var offset := int(start * RATE)
	var low := 0.0
	var lower := 0.0  # 1차 필터를 두 번 걸어 고음을 더 깎는다 (쉭 소리가 귀를 찌르지 않게)
	for i in count:
		var t := float(i) / RATE
		var cut := lerpf(cut_from, cut_to, t / length)
		var alpha := 1.0 - exp(-TAU * cut / RATE)
		low += alpha * (_rng.randf_range(-1.0, 1.0) - low)
		lower += alpha * (low - lower)
		var env := amp * minf(t / maxf(attack, 0.0005), 1.0) * exp(-t / tau) * minf((length - t) / CLICK_GUARD, 1.0)
		_add(offset + i, env * lower * 3.0)


## 메아리: 지연 delay초, 되먹임 feedback. wrap 버퍼는 두 바퀴 돌려 이음매에도 꼬리가 이어진다
func echo(delay: float, feedback: float) -> void:
	var d := int(delay * RATE)
	var n := data.size()
	var dry := data.duplicate()
	for pass_index in (2 if wrap else 1):
		for i in n:
			var j := i - d
			if j < 0 and not wrap:
				continue
			data[i] = dry[i] + feedback * data[posmod(j, n)]


## 가장 큰 진폭을 peak로 맞춘다
func normalize(peak: float) -> void:
	var top := 0.0
	for v in data:
		top = maxf(top, absf(v))
	if top <= 0.0:
		return
	var gain := peak / top
	for i in data.size():
		data[i] *= gain


## 버퍼 끝에서 잘린 꼬리가 딸깍하지 않게 마지막 fraction만큼 서서히 줄인다 (반복 곡에는 쓰지 않는다)
func fade_tail(fraction: float) -> void:
	var n := data.size()
	var count := int(n * fraction)
	for i in count:
		data[n - count + i] *= 1.0 - float(i) / count


## 16비트 모노 WAV로 저장한다
func save(path: String) -> Error:
	var bytes := PackedByteArray()
	bytes.resize(data.size() * 2)
	for i in data.size():
		bytes.encode_s16(i * 2, int(clampf(data[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = bytes
	return stream.save_to_wav(path)


func _add(index: int, value: float) -> void:
	var n := data.size()
	if index >= n:
		if not wrap:
			return
		index %= n
	data[index] += value


func _wave(phase: float, wave: Wave) -> float:
	match wave:
		Wave.TRIANGLE:
			return 4.0 * absf(phase - 0.5) - 1.0
		Wave.SOFT:
			return sin(TAU * phase) + 0.3 * sin(2.0 * TAU * phase) + 0.12 * sin(3.0 * TAU * phase)
	return sin(TAU * phase)
