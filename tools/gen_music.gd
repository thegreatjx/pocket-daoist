extends SceneTree
# 程序化合成循环背景音乐，输出 16-bit 立体声 WAV。
# 风格：修仙氛围。标题曲空灵缓慢，战斗曲带低频脉冲推进。
# 运行：godot --headless --script res://tools/gen_music.gd

const SR := 22050
var written: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var d = DirAccess.open("res://")
	if not d.dir_exists("assets/audio"):
		d.make_dir_recursive("assets/audio")
	# 两段都做成精确循环长度（约 24 秒 / 16 小节），接缝处首尾样本对齐
	_write("music_title", _title_track(24.0))
	_write("music_battle", _battle_track(24.0))
	print("MUSIC_WRITTEN=", written.size(), " ", written)
	quit(0)

func _n(sec: float) -> int:
	return int(sec * float(SR))

# 古筝/箫类音色：基频正弦 + 递减泛音 + 缓起缓落包络
func _pluck(freq: float, sec: float, gain: float, bright: float) -> PackedFloat32Array:
	var n = _n(sec)
	var buf = PackedFloat32Array()
	buf.resize(n)
	var phase = 0.0
	var attack = _n(0.02)
	for i in range(n):
		phase += TAU * freq / float(SR)
		# 4 个泛音，振幅按 bright 递减，模拟拨弦衰减
		var s = sin(phase)
		s += bright * 0.5 * sin(phase * 2.0)
		s += bright * bright * 0.25 * sin(phase * 3.0)
		s += bright * bright * bright * 0.12 * sin(phase * 4.0)
		var t = float(i) / float(n)
		var e = exp(-3.2 * t)
		if i < attack:
			e *= float(i) / float(attack)
		buf[i] = s * e * gain
	return buf

# 铺底长音：柔和正弦叠加，营造空间感
func _pad(freq: float, sec: float, gain: float) -> PackedFloat32Array:
	var n = _n(sec)
	var buf = PackedFloat32Array()
	buf.resize(n)
	var phase = 0.0
	var lfo = 0.0
	for i in range(n):
		phase += TAU * freq / float(SR)
		lfo += TAU * 0.15 / float(SR)   # 慢速起伏
		var t = float(i) / float(n)
		# 缓入缓出，首尾归零以便无缝循环拼接
		var e = sin(t * PI)
		buf[i] = sin(phase) * (0.8 + 0.2 * sin(lfo)) * e * gain
	return buf

func _mix(dst: PackedFloat32Array, src: PackedFloat32Array, at_sample: int, gain: float) -> void:
	for i in range(src.size()):
		var j = at_sample + i
		if j >= 0 and j < dst.size():
			dst[j] += src[i] * gain

# 标题曲：五声音阶缓慢琶音 + 低音铺底
func _title_track(sec: float) -> PackedFloat32Array:
	var total = _n(sec)
	var buf = PackedFloat32Array()
	buf.resize(total)
	# C 宫调式五声：C D E G A（对应 do re mi sol la）
	var scale = [130.81, 146.83, 164.81, 196.0, 220.0, 261.63, 293.66, 329.63]
	# 低音铺底：两个五度长音交替
	var beat = total / 8
	for i in range(8):
		var f = scale[0] if (i % 2 == 0) else scale[3] * 0.5
		_mix(buf, _pad(f * 0.5, sec / 8.0 + 0.3, 0.32), int(i * beat), 1.0)
	# 旋律：伪随机但固定种子的五声琶音，保证每次生成一致且循环
	var rng = RandomNumberGenerator.new()
	rng.seed = 20240101
	var step = total / 32
	for i in range(32):
		if rng.randf() < 0.35:
			continue   # 留白，制造空灵感
		var note = scale[rng.randi_range(2, scale.size() - 1)]
		_mix(buf, _pluck(note, 2.2, 0.5, 0.35), int(i * step), 1.0)
	# 首尾交叉淡化，保证循环无缝
	return _crossfade_loop(buf, 0.6)

# 战斗曲：稳定低音脉冲 + 五度动机 + 稀疏旋律
func _battle_track(sec: float) -> PackedFloat32Array:
	var total = _n(sec)
	var buf = PackedFloat32Array()
	buf.resize(total)
	var scale = [130.81, 164.81, 196.0, 220.0, 261.63, 293.66]
	# 每拍一个低音脉冲（8 拍/4 小节，循环）
	var beat = total / 16
	for i in range(16):
		var f = scale[i % 2] * 0.5
		_mix(buf, _pluck(f, 0.5, 0.42, 0.2), int(i * beat), 1.0)
	# 持续铺底
	_mix(buf, _pad(scale[0] * 0.5, sec, 0.22), 0, 1.0)
	# 旋律动机
	var rng = RandomNumberGenerator.new()
	rng.seed = 777001
	for i in range(32):
		if rng.randf() < 0.5:
			continue
		var note = scale[rng.randi_range(1, scale.size() - 1)]
		_mix(buf, _pluck(note * 2.0, 1.4, 0.34, 0.3), int(i * beat * 0.5), 1.0)
	return _crossfade_loop(buf, 0.6)

# 循环接缝处理：把末尾 xfade 秒与开头交叉淡化，消除循环爆点
func _crossfade_loop(buf: PackedFloat32Array, xfade_sec: float) -> PackedFloat32Array:
	var xf = _n(xfade_sec)
	var total = buf.size()
	if xf <= 0 or xf * 2 >= total:
		return buf
	var body = total - xf
	var out = PackedFloat32Array()
	out.resize(body)
	for i in range(body):
		out[i] = buf[i]
	# 末尾 xf 段与开头 xf 段叠加淡入淡出
	for i in range(xf):
		var t = float(i) / float(xf)
		var tail = buf[body + i]
		var head = buf[i]
		out[i] = head * t + tail * (1.0 - t)
	_normalize(out, 0.82)
	return out

func _normalize(buf: PackedFloat32Array, peak: float) -> void:
	var m = 0.0
	for i in range(buf.size()):
		m = maxf(m, absf(buf[i]))
	if m > 0.0001:
		var k = peak / m
		for i in range(buf.size()):
			buf[i] *= k

func _write(name: String, samples: PackedFloat32Array) -> void:
	var path = "res://assets/audio/%s.wav" % name
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("cannot open %s" % path)
		return
	var data_size = samples.size() * 4   # 立体声 16-bit
	f.store_buffer("RIFF".to_utf8_buffer())
	f.store_32(36 + data_size)
	f.store_buffer("WAVE".to_utf8_buffer())
	f.store_buffer("fmt ".to_utf8_buffer())
	f.store_32(16)
	f.store_16(1)      # PCM
	f.store_16(2)      # 立体声
	f.store_32(SR)
	f.store_32(SR * 4) # 字节率
	f.store_16(4)      # 块对齐
	f.store_16(16)     # 位深
	f.store_buffer("data".to_utf8_buffer())
	f.store_32(data_size)
	for i in range(samples.size()):
		var v = int(clampf(samples[i], -1.0, 1.0) * 32767.0) & 0xFFFF
		f.store_16(v)   # 左声道
		f.store_16(v)   # 右声道（单声道内容，简化处理）
	f.close()
	written.append("%s(%d)" % [name, data_size])
