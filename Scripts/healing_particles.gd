class_name HealingParticles
extends Node2D

const PARTICLE_INTERVAL := 0.14
const PARTICLE_LIFETIME := 0.9

var emitting := false
var _spawn_time_left := 0.0
var _particles: Array[Dictionary] = []


func _process(delta: float) -> void:
	if emitting:
		_spawn_time_left -= delta
		while _spawn_time_left <= 0.0:
			_particles.append({"position": Vector2(randf_range(-12.0, 12.0), randf_range(8.0, 17.0)), "age": 0.0})
			_spawn_time_left += PARTICLE_INTERVAL
	for index in range(_particles.size() - 1, -1, -1):
		var particle := _particles[index]
		particle["age"] = float(particle["age"]) + delta
		particle["position"] = particle["position"] + Vector2(sin(float(particle["age"]) * 8.0 + index) * 10.0 * delta, -30.0 * delta)
		if float(particle["age"]) >= PARTICLE_LIFETIME:
			_particles.remove_at(index)
		else:
			_particles[index] = particle
	queue_redraw()


func _draw() -> void:
	for particle in _particles:
		var progress := clampf(float(particle["age"]) / PARTICLE_LIFETIME, 0.0, 1.0)
		var color := Color(0.40, 0.95, 0.50, (1.0 - progress) * 0.82)
		draw_circle(particle["position"], lerpf(3.0, 1.0, progress), color)
