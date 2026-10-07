extends SceneTree
# 程序化合成全部游戏音效，输出 16-bit 单声道 WAV。
# 运行：godot --headless --script res://_gen_audio.gd

const SR := 22050

var written: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var d = DirAccess.open("res://")
	if not d.dir_exists("assets/audio"):
		d.make_dir_recursive("assets/audio")

	_write("sword_cast", _whoosh(0.11, 0.30, true, 0.5))
	_write("sword_hit", _hit_click(0.07, 1400.0, 520.0, 0.55))
	_write("enemy_die", _thud(0.20, 210.0, 52.0, 0.6, 0.35))
	_write("gem_pickup", _blip(0.09, 880.0, 1760.0, 0.30))
	_write("level_up", _arpeggio([523.25, 659.25, 783.99, 1046.5], 0.13, 0.40))
	_write("thunder", _thunder(0.50, 0.85))
	_write("player_hurt", _thud(0.22, 320.0, 70.0, 0.75, 0.5))
	_write("dash", _whoosh(0.18, 0.26, false, 0.42))

	print("WAV_WRITTEN=", written.size(), " ", written)
	quit(0)

# ---------- 基础构件 ----------

func _frames(sec: float) -> int:
	return int(sec * float(SR))

func _noise(n: int) -> PackedFloat32Array:
	var a = PackedFloat32Array()
	a.resize(n)
	for i in range(n):
		a[i] = randf_range(-1.0, 1.0)
	return a

# 一极点低通，系数随样本变化可实现扫频
func _lowpass_sweep(buf: PackedFloat32Array, a_from: float, a_to: float) -> void:
	var n = buf.size()
	var y = 0.0
	for i in range(n):
		var t = float(i) / float(max(1, n - 1))
		var a = lerpf(a_from, a_to, t)
		y += a * (buf[i] - y)
		buf[i] = y

# 指数衰减包络，可带起音
func _apply_env(buf: PackedFloat32Array, attack_sec: float, gain: float) -> void:
	var n = buf.size()
	var atk = _frames(attack_sec)
	for i in range(n):
		var t = float(i) / float(n)
		var e = exp(-4.5 * t)
		if atk > 0 and i < atk:
			e *= float(i) / float(atk)
		buf[i] = buf[i] * e * gain

func _sine_sweep(n: int, f_from: float, f_to: float) -> PackedFloat32Array:
	var a = PackedFloat32Array()
	a.resize(n)
	var phase = 0.0
	for i in range(n):
		var t = float(i) / float(n)
		var f = lerpf(f_from, f_to, t)
		phase += TAU * f / float(SR)
		a[i] = sin(phase)
	return a

func _mix_into(dst: PackedFloat32Array, src: PackedFloat32Array, offset: int, gain: float) -> void:
	for i in range(src.size()):
		var j = offset + i
		if j >= 0 and j < dst.size():
			dst[j] += src[i] * gain

func _normalize(buf: PackedFloat32Array, peak: float) -> void:
	var m = 0.0
	for i in range(buf.size()):
		m = maxf(m, absf(buf[i]))
	if m > 0.0001:
		var k = peak / m
		for i in range(buf.size()):
			buf[i] *= k

# ---------- 具体音色 ----------

func _whoosh(sec: float, bright: float, rising: bool, gain: float) -> PackedFloat32Array:
	var buf = _noise(_frames(sec))
	if rising:
		_lowpass_sweep(buf, 0.03, bright)
	else:
		_lowpass_sweep(buf, bright, 0.03)
	_apply_env(buf, 0.012, gain)
	_normalize(buf, 0.85)
	return buf

func _hit_click(sec: float, f_from: float, f_to: float, gain: float) -> PackedFloat32Array:
	var n = _frames(sec)
	var buf = _sine_sweep(n, f_from, f_to)
	# 叠加极短噪声瞬态，制造"叮"的敲击感
	var click = _noise(_frames(0.012))
	_mix_into(buf, click, 0, 0.5)
	_apply_env(buf, 0.001, gain)
	_normalize(buf, 0.9)
	return buf

func _thud(sec: float, f_from: float, f_to: float, gain: float, noise_mix: float) -> PackedFloat32Array:
	var n = _frames(sec)
	var buf = _sine_sweep(n, f_from, f_to)
	var nz = _noise(n)
	_lowpass_sweep(nz, 0.25, 0.05)
	_mix_into(buf, nz, 0, noise_mix)
	_apply_env(buf, 0.003, gain)
	_normalize(buf, 0.95)
	return buf

func _blip(sec: float, f_from: float, f_to: float, gain: float) -> PackedFloat32Array:
	var n = _frames(sec)
	var buf = _sine_sweep(n, f_from, f_to)
	# 二次谐波增加亮度
	for i in range(n):
		buf[i] += 0.3 * sin(buf[i] * TAU)
	_apply_env(buf, 0.004, gain)
	_normalize(buf, 0.8)
	return buf

func _arpeggio(freqs: Array, note_sec: float, gain: float) -> PackedFloat32Array:
	var per = _frames(note_sec)
	var total = per * freqs.size() + _frames(0.12)
	var buf = PackedFloat32Array()
	buf.resize(total)
	for k in range(freqs.size()):
		var f = freqs[k]
		var note = PackedFloat32Array()
		note.resize(per + _frames(0.12))
		var phase = 0.0
		for i in range(note.size()):
			phase += TAU * f / float(SR)
			# 基频 + 半幅二次谐波 = 类铃音
			note[i] = sin(phase) + 0.4 * sin(phase * 2.0)
		_apply_env(note, 0.006, gain)
		_mix_into(buf, note, k * per, 1.0)
	_normalize(buf, 0.9)
	return buf

func _thunder(sec: float, gain: float) -> PackedFloat32Array:
	var n = _frames(sec)
	# 低频隆隆声
	var buf = _sine_sweep(n, 70.0, 28.0)
	for i in range(n):
		buf[i] *= 0.7
	# 撕裂噪声：先亮后暗，模拟雷声由炸裂到消散
	var crack = _noise(n)
	_lowpass_sweep(crack, 0.55, 0.04)
	_mix_into(buf, crack, 0, 1.0)
	# 前段额外爆裂瞬态
	var burst = _noise(_frames(0.05))
	_mix_into(buf, burst, 0, 1.3)
	_apply_env(buf, 0.002, gain)
	_normalize(buf, 0.98)
	return buf

# ---------- WAV 写出 ----------

func _write(name: String, samples: PackedFloat32Array) -> void:
	var path = "res://assets/audio/%s.wav" % name
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("cannot open %s" % path)
		return
	var data_size = samples.size() * 2
	f.store_buffer("RIFF".to_utf8_buffer())
	f.store_32(36 + data_size)
	f.store_buffer("WAVE".to_utf8_buffer())
	f.store_buffer("fmt ".to_utf8_buffer())
	f.store_32(16)
	f.store_16(1)          # PCM
	f.store_16(1)          # 单声道
	f.store_32(SR)         # 采样率
	f.store_32(SR * 2)     # 字节率 = SR * 声道 * 位深/8
	f.store_16(2)          # 块对齐
	f.store_16(16)         # 位深
	f.store_buffer("data".to_utf8_buffer())
	f.store_32(data_size)
	for i in range(samples.size()):
		var v = int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		f.store_16(v & 0xFFFF)   # 显式取补码低 16 位，保证负值正确
	f.close()
	written.append("%s(%d)" % [name, data_size])
