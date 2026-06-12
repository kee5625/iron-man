extends Node
## Procedural sound bank (autoload "Sfx"). All sounds are synthesized into
## AudioStreamWAV buffers at startup — zero asset files. ~0.5s generation cost
## at launch, then playback is ordinary stream playing.
##
## One-shots: Sfx.play("repulsor") (global) or Sfx.play_at("explosion", pos)
## (3D positional, self-freeing). Loops: grab Sfx.stream("thruster") and run
## it in your own player so you can drive volume/pitch every frame.

const SR := 44100

var _streams: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 1337
	_streams["thruster"] = _gen_thruster()
	_streams["wind"] = _gen_wind()
	_streams["boost"] = _gen_boost()
	_streams["repulsor"] = _gen_repulsor()
	_streams["drone_shot"] = _gen_drone_shot()
	_streams["explosion"] = _gen_explosion()
	_streams["hit"] = _gen_hit()
	_streams["lock"] = _gen_lock()


func stream(sound: String) -> AudioStreamWAV:
	return _streams[sound]


func play(sound: String, vol_db := 0.0, pitch := 1.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = _streams[sound]
	p.volume_db = vol_db
	p.pitch_scale = pitch * _rng.randf_range(0.96, 1.04)
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func play_at(sound: String, pos: Vector3, vol_db := 0.0, pitch := 1.0) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = _streams[sound]
	p.volume_db = vol_db
	p.pitch_scale = pitch * _rng.randf_range(0.96, 1.04)
	p.unit_size = 20.0
	p.max_distance = 400.0
	get_tree().current_scene.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()


# --- synthesis ---

func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = SR
	s.stereo = false
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = samples.size()
	return s


## Crossfades the head into the tail so noise loops don't click, then trims.
func _loopify(out: PackedFloat32Array) -> PackedFloat32Array:
	var n := out.size()
	var m := int(SR * 0.05)
	for i in m:
		var w := float(i) / float(m)
		out[i] = out[i] * w + out[n - m + i] * (1.0 - w)
	out.resize(n - m)
	return out


func _white() -> float:
	return _rng.randf() * 2.0 - 1.0


func _gen_thruster() -> AudioStreamWAV:
	# Brown noise rumble + 65Hz sub with slow flutter. The suit's idle voice.
	var n := int(SR * 2.0)
	var out := PackedFloat32Array()
	out.resize(n)
	var brown := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / SR
		brown = clampf(brown + _white() * 0.02, -1.0, 1.0) * 0.999
		lp += 0.08 * (brown - lp)
		var sub := sin(TAU * 65.0 * t) * 0.35 * (1.0 + 0.15 * sin(TAU * 7.3 * t))
		out[i] = clampf(lp * 2.4 + sub, -1.0, 1.0) * 0.8
	return _wav(_loopify(out), true)


func _gen_wind() -> AudioStreamWAV:
	# Hissy filtered noise. Volume ramps with airspeed in player code.
	var n := int(SR * 1.5)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		lp += 0.25 * (_white() - lp)
		lp2 += 0.5 * (lp - lp2)
		out[i] = lp2 * 1.8
	return _wav(_loopify(out), true)


func _gen_boost() -> AudioStreamWAV:
	# Ignition crack: noise burst through an opening filter + decaying sub thump.
	var n := int(SR * 0.6)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / SR
		var env := minf(t / 0.01, 1.0) * exp(-t / 0.18)
		var cutoff := lerpf(0.03, 0.35, minf(t / 0.1, 1.0))
		lp += cutoff * (_white() - lp)
		var sub := sin(TAU * 48.0 * t) * exp(-t / 0.25) * 0.7
		out[i] = clampf(lp * 2.5 * env + sub, -1.0, 1.0)
	return _wav(out)


func _gen_repulsor() -> AudioStreamWAV:
	# Falling chirp + noise tail. THE Iron Man hand-zap read.
	var n := int(SR * 0.22)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / SR
		var k := t / 0.22
		var f := lerpf(1600.0, 250.0, pow(k, 0.5))
		ph += TAU * f / SR
		var env := minf(t / 0.005, 1.0) * exp(-t / 0.06)
		out[i] = (sin(ph) * 0.8 + _white() * 0.25) * env
	return _wav(out)


func _gen_drone_shot() -> AudioStreamWAV:
	# Lower, uglier zap than the repulsor — enemy fire must read different.
	var n := int(SR * 0.25)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / SR
		var f := lerpf(700.0, 180.0, t / 0.25)
		ph += TAU * f / SR
		var env := minf(t / 0.008, 1.0) * exp(-t / 0.08)
		out[i] = (sin(ph) * 0.6 + sin(ph * 2.0) * 0.3 + _white() * 0.15) * env
	return _wav(out)


func _gen_explosion() -> AudioStreamWAV:
	# Crunchy brown noise with a closing filter, hard-clipped for grit.
	var n := int(SR * 1.0)
	var out := PackedFloat32Array()
	out.resize(n)
	var brown := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / SR
		brown = clampf(brown + _white() * 0.06, -1.0, 1.0) * 0.998
		var cutoff := lerpf(0.15, 0.025, minf(t / 0.7, 1.0))
		lp += cutoff * (brown - lp)
		var env := minf(t / 0.005, 1.0) * exp(-t / 0.3)
		out[i] = clampf(lp * 6.0 * env, -1.0, 1.0)
	return _wav(out)


func _gen_hit() -> AudioStreamWAV:
	# Metallic body thud: low sine knock + click.
	var n := int(SR * 0.18)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / SR
		var knock := sin(TAU * 90.0 * t) * exp(-t / 0.05)
		var click := _white() * exp(-t / 0.01) * 0.5
		out[i] = clampf(knock + click, -1.0, 1.0) * 0.9
	return _wav(out)


func _gen_lock() -> AudioStreamWAV:
	# Two-tone HUD blip: target acquired.
	var n := int(SR * 0.09)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / SR
		var f := 950.0 if t < 0.04 else 1400.0
		var env := minf(t / 0.002, 1.0) * exp(-t / 0.04)
		out[i] = sin(TAU * f * t) * env * 0.6
	return _wav(out)
