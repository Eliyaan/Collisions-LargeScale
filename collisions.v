module main

import gg
import gx
import rand as rd
import time
import math as m

const multithreaded = true

const win_width = 600
const win_height = 600
const bg_color = gx.white
const dt = 0.016
const big_circle_radius = 300
const big_circle_pos = 300
const text_cfg = gx.TextCfg{
	color:          gx.black
	size:           20
	align:          .left
	vertical_align: .top
}
const response_coef = 1.0
const half_response_coef = response_coef * 0.5

@[inline]
fn sqrt(a f64) f64 {
	if a == 0.0 {
		return a
	}
	mut x := a
	mut y := *unsafe { &u64(&x) }
	ex := int((y >> 52) & 0x7ff) - 0x3fe
	y &= u64(0x800fffffffffffff)
	y |= u64(0x3fe0000000000000)
	z := *unsafe { &f64(&y) }
	w := a

	x = 4.17e-1 + 5.90e-1 * z
	if (ex & 1) != 0 {
		x *= 1.41
	}
	t := u64((0x3ff + ex >> 1)) << 52
	x = x * *unsafe { &f64(&t) }
	x = 0.5 * (x + w / x)
	return x
}

@[heap]
struct Particle {
mut:
	x        f64
	y        f64
	radius   int
	fradius  f32
	old_x    f64
	old_y    f64
	acc_x    f64
	acc_y    f64
	delta_x  f64
	delta_y  f64
	pression f64
	id       int
	opti_y   int
	opti_x   int
}

@[inline]
fn (mut parti Particle) update_pos(delta_time f64) {
	velocity_x := parti.x - parti.old_x
	velocity_y := parti.y - parti.old_y

	parti.old_x = parti.x
	parti.old_y = parti.y

	parti.x = parti.x + velocity_x + parti.acc_x * delta_time * delta_time
	parti.y = parti.y + velocity_y + parti.acc_y * delta_time * delta_time
}

@[inline]
fn (mut parti Particle) correct_constraints_square() {
	if parti.y + parti.radius >= win_height {
		parti.y += win_height - (parti.y + parti.radius)
	} else if parti.y - parti.radius < 0 {
		parti.y += -(parti.y - parti.radius)
	}
	if parti.x + parti.radius >= win_width {
		parti.x += win_width - (parti.x + parti.radius)
	} else if parti.x - parti.radius < 0 {
		parti.x += -(parti.x - parti.radius)
	}
}

@[inline]
fn (mut parti Particle) correct_constraints_circle() {
	to_obj_x := big_circle_pos - parti.x
	to_obj_y := big_circle_pos - parti.y
	mut dist := to_obj_x * to_obj_x + to_obj_y * to_obj_y
	normal_dist := big_circle_radius - parti.radius
	if dist > normal_dist * normal_dist {
		dist = sqrt(dist)
		n_x := to_obj_x / dist
		n_y := to_obj_y / dist
		parti.x = big_circle_pos - n_x * normal_dist
		parti.y = big_circle_pos - n_y * normal_dist // thalès
	}
}

@[inline]
fn (mut parti Particle) accelerate(new_acc_x f64, new_acc_y f64) {
	parti.acc_x = new_acc_x
	parti.acc_y = new_acc_y
}

@[inline]
fn abs(a f64) f64 {
	/*
	mut b := *unsafe{&u64(&a)}
	b &= 0x7FFFFFFFFFFFFFFF
	return *unsafe{&f64(&b)}
	*/
	return if a < 0 { -a } else { a }
}

@[heap]
struct App {
mut:
	gg &gg.Context = unsafe { nil }

	list_parti      []Particle
	list_opti       [][][]&Particle
	parti_size      int = 12
	pow_radius      int
	fps_counter     []time.Duration = []time.Duration{len: 30}
	time_last_frame time.Time

	pression_view bool
	carre_circle  bool
	mouse_x       f32
	mouse_y       f32
	mouse_pressed bool
	substeps      f32 = 8.0
	red_factor    int = -2
	green_factor  int = 16
	blue_factor   int = 64

	min_parti_size int = 2
	max_parti_size int = 16

	array_width_max  int
	array_height_max int

	portable_parti_size int = 6
	portable_parti      bool

	hori_mult  f64
	verti_mult f64 = 1
	
	remove_particles []&Particle = []&Particle{len: 50, init: unsafe { nil }}
}

@[direct_array_access; inline]
fn (mut app App) init_opti_list() {
	for mut list_of_list in app.list_opti {
		for mut liste in list_of_list {
			if liste.len > 0 {
				liste.clear()
			}
		}
	}
	for mut parti in app.list_parti {
		x_index := int(parti.x / (2 * (app.max_parti_size - 1)))
		y_index := int(parti.y / (2 * (app.max_parti_size - 1)))
		parti.id = app.list_opti[y_index][x_index].len
		parti.opti_x = x_index
		parti.opti_y = y_index
		app.list_opti[y_index][x_index] << &parti
		assert app.list_opti[y_index][x_index].last().id == app.list_opti[y_index][x_index].len - 1
	}
}

@[inline]
fn main() {
	mut app := &App{}
	app.gg = gg.new_context(
		width:         win_width
		height:        win_height
		create_window: true
		window_title:  '- Application -'
		user_data:     app
		bg_color:      bg_color
		frame_fn:      on_frame
		event_fn:      on_event
		fullscreen:    true
		sample_count:  4
	)

	app.pow_radius = (4 * app.parti_size * app.parti_size)
	app.array_height_max = int(ceil(win_height / f64(2 * (app.max_parti_size - 1))))
	app.array_width_max = int(ceil(win_width / f64(2 * (app.max_parti_size - 1))))
	app.list_opti = [][][]&Particle{len: app.array_height_max, init: [][]&Particle{len: app.array_width_max, init: []&Particle{}}}

	// lancement du programme/de la fenêtre
	if multithreaded {
		spawn app.compute()
	}
	app.gg.run()
}

@[inline]
fn floor(x f64) int {
	return int(x)
}

@[inline]
fn ceil(x f64) f64 {
	return if x < 0 { int(x) - 1 } else { int(x) + 1 }
}

@[inline; direct_array_access]
fn (mut app App) solve_collisions() {
	// sw := time.new_stopwatch(); defer { eprintln('> ${@FN} ${sw.elapsed().microseconds():6} us') }
	mut rp_top := 0 // index of next item in remove_particles
	for mut parti in app.list_parti {
		mut array_dest := app.list_opti[parti.opti_y][parti.opti_x]
		array_dest[parti.id] = unsafe { nil }
		for y in -1 .. 2 {
			y_index := parti.opti_y + y
			if y_index >= 0 && y_index < app.array_height_max {
				for x in -1 .. 2 {
					x_index := parti.opti_x + x
					if x_index >= 0 && x_index < app.array_width_max {
						array_dest = app.list_opti[y_index][x_index]
						if array_dest.len > 0 {
							rp_top = 0
							for o_i in 0 .. array_dest.len { // for each particle in the same chunk
								if array_dest[o_i] == unsafe { nil } {
									continue
								}
								mut other := array_dest[o_i]
								dist_x := parti.x - other.x
								dist_y := parti.y - other.y
								mut dist := dist_x * dist_x + dist_y * dist_y
								min_dist := parti.radius + other.radius
								// Check overlapping
								if dist < min_dist * min_dist {
									if dist < 0.2 { 
										dist = 0.2
									} else {
										dist = sqrt(dist)
									}
									n_x := dist_x / dist
									n_y := dist_y / dist
									delta := half_response_coef * (dist - min_dist)
									mass_ratio_a := (parti.fradius / min_dist) * delta // not just mass ratio
									mass_ratio_b := (other.fradius / min_dist) * delta
									// Update positions
									xb := n_x * mass_ratio_b
									yb := n_y * mass_ratio_b
									xa := n_x * mass_ratio_a
									ya := n_y * mass_ratio_a
									parti.x -= xb
									parti.y -= yb
									other.x += xa
									other.y += ya
									if app.pression_view {
										parti.pression += abs(xb) + abs(yb)
										other.pression += abs(xa) + abs(ya)
									}
									if app.carre_circle {
										other.correct_constraints_circle()
									} else {
										other.correct_constraints_square()
									}
									assert o_i == array_dest[o_i].id
									app.remove_particles[rp_top] or {
										panic('remove_particles too small')
									} = array_dest[o_i]
									rp_top++
								}
							}
							for ok_i in 0 .. rp_top {
								mut other_killed := app.remove_particles[ok_i]
								array_dest[other_killed.id] = unsafe { nil }
								if app.carre_circle {
									other_killed.correct_constraints_circle()
								} else {
									other_killed.correct_constraints_square()
								}
								new_loc_y := int(other_killed.y / (2 * (app.max_parti_size - 1)))
								new_loc_x := int(other_killed.x / (2 * (app.max_parti_size - 1)))
								mut found := false
								for new_i in 0 .. app.list_opti[new_loc_y][new_loc_x].len {
									if app.list_opti[new_loc_y][new_loc_x][new_i] == unsafe { nil } {
										app.list_opti[new_loc_y][new_loc_x][new_i] = app.remove_particles[ok_i]
										found = true
										other_killed.id = new_i
										// assert app.list_opti[new_loc_y][new_loc_x][new_i].id == new_i
										break
									}
								}
								if !found {
									app.list_opti[new_loc_y][new_loc_x] << app.remove_particles[ok_i]
									other_killed.id = app.list_opti[new_loc_y][new_loc_x].len - 1
									// assert app.list_opti[new_loc_y][new_loc_x].last().id == app.list_opti[new_loc_y][new_loc_x].len - 1
								}
								other_killed.opti_x = new_loc_x
								other_killed.opti_y = new_loc_y
							}
						}
					}
				}
			}
		}
		if app.carre_circle {
			parti.correct_constraints_circle()
		} else {
			parti.correct_constraints_square()
		}
		new_loc_y := int(parti.y / (2 * (app.max_parti_size - 1)))
		new_loc_x := int(parti.x / (2 * (app.max_parti_size - 1)))
		mut found := false
		for new_i in 0 .. app.list_opti[new_loc_y][new_loc_x].len {
			if app.list_opti[new_loc_y][new_loc_x][new_i] == unsafe { nil } {
				app.list_opti[new_loc_y][new_loc_x][new_i] = &parti
				found = true
				parti.id = new_i
				// assert app.list_opti[new_loc_y][new_loc_x][new_i].id == new_i
				break
			}
		}
		if !found {
			app.list_opti[new_loc_y][new_loc_x] << &parti
			parti.id = app.list_opti[new_loc_y][new_loc_x].len - 1
			// assert app.list_opti[new_loc_y][new_loc_x].last().id == app.list_opti[new_loc_y][new_loc_x].len - 1
		}
		parti.opti_x = new_loc_x
		parti.opti_y = new_loc_y
	}
}

@[direct_array_access; inline]
fn (mut app App) solve_portable_parti() {
	for mut other in app.list_parti {
		dist_x := app.mouse_x - other.x
		dist_y := app.mouse_y - other.y
		mut dist := dist_x * dist_x + dist_y * dist_y
		min_dist := f32(app.portable_parti_size + other.radius)
		// Check overlapping
		if dist < min_dist * min_dist {
			if dist < 0.2 { 
				dist = 0.2
			} else {
				dist = sqrt(dist)
			}
			n_x := dist_x / dist
			n_y := dist_y / dist
			delta := half_response_coef * (dist - min_dist)
			mass_ratio_a := (app.portable_parti_size / min_dist) * delta // not just mass ratio
			// Update positions
			xa := n_x * mass_ratio_a
			ya := n_y * mass_ratio_a
			other.x += xa
			other.y += ya
			if app.pression_view {
				other.pression += abs(xa + ya)
			}
		}
	}
}

fn (mut app App) compute_step() {
		if app.mouse_pressed {
			if !app.portable_parti {
				app.spawn_parti()
			}
			app.check_buttons()
			app.init_opti_list()
		}
		for _ in 0 .. int(app.substeps) {
			for mut parti in app.list_parti {
				parti.accelerate((10000 * app.hori_mult) / app.substeps, (10000 * app.verti_mult) / app.substeps)
				parti.pression = 0
			}
			for mut parti in app.list_parti {
				parti.update_pos(dt / app.substeps)
			}
			if app.carre_circle {
				for mut parti in app.list_parti {
					parti.correct_constraints_circle()
				}
			} else {
				for mut parti in app.list_parti {
					parti.correct_constraints_square()
				}
			}

			app.solve_collisions()
			if app.portable_parti {
				app.solve_portable_parti() // TODO : pretty bad?! -> forgot to update the opti array so missplaced particles 
			}
			
			// TODO: if particule has too much momentum -> max_momentum
		}

		app.fps_counter.delete(0)
		now := time.now()
		app.fps_counter << (now - app.time_last_frame).milliseconds()
		app.time_last_frame = now
}

fn (mut app App) compute() {
	for {
		app.compute_step()
	}
}

@[direct_array_access; inline]
fn on_frame(mut app App) {
	// Draw
	app.gg.begin()
	if app.carre_circle {
		app.gg.draw_circle_filled(300, 300, 300, gx.black)
	} else {
		app.gg.draw_square_filled(0, 0, 600, gx.black)
	}
	if app.pression_view {
		for parti in app.list_parti {
			pression := parti.pression * 82
			if pression > 255 {
				app.gg.draw_circle_filled(f32(parti.x), f32(parti.y), parti.radius, gx.Color{163, 0, 38, 255})
			} else {
				app.gg.draw_circle_filled(f32(parti.x), f32(parti.y), parti.radius, gx.Color{255, 255 - u8(pression), 255 - u8(pression), 255})
			}
		}
	} else {
		for parti in app.list_parti {
			app.gg.draw_circle_filled(f32(parti.x), f32(parti.y), parti.radius, gx.Color{u8(parti.radius * app.red_factor % 255), u8(parti.radius * app.green_factor % 255), u8(parti.radius * app.blue_factor % 255), 255})
		}
	}

	mut fpstime := 0
	for elem in app.fps_counter {
		fpstime += elem
	}
	fpstime /= app.fps_counter.len
	app.gg.draw_text(840, 585, 'ComputePS: ${1000 / (fpstime + 1)}', text_cfg)

// TODO: make all UI pos variables

	app.gg.draw_text(840, 555, 'Nb particles: ${app.list_parti.len}', text_cfg)

	app.gg.draw_text(840, 25, 'Pression view: ', text_cfg)
	app.gg.draw_square_filled(1040, 26, 20, gx.Color{255, 182, 193, 255})

	app.gg.draw_text(840, 55, 'Square/Circle: ', text_cfg)
	app.gg.draw_square_filled(1040, 56, 20, gx.Color{255, 182, 193, 255})

	app.gg.draw_text(840, 85, 'Nb substeps: ${app.substeps}', text_cfg)
	app.gg.draw_square_filled(1040, 86, 20, gx.Color{ r: 230, g: 200, b: 255 })
	app.gg.draw_square_filled(1070, 86, 20, gx.Color{ r: 255, g: 160, b: 255 })

	app.gg.draw_text(840, 115, 'Reset the particles: ', text_cfg)
	app.gg.draw_square_filled(1040, 116, 20, gx.Color{255, 182, 193, 255})

	app.gg.draw_text(840, 145, 'Red Factor: ${app.red_factor}', text_cfg)
	app.gg.draw_square_filled(1040, 146, 20, gx.Color{ r: 230, g: 200, b: 255 })
	app.gg.draw_square_filled(1070, 146, 20, gx.Color{ r: 255, g: 160, b: 255 })

	app.gg.draw_text(840, 175, 'Green Factor: ${app.green_factor}', text_cfg)
	app.gg.draw_square_filled(1040, 176, 20, gx.Color{ r: 230, g: 200, b: 255 })
	app.gg.draw_square_filled(1070, 176, 20, gx.Color{ r: 255, g: 160, b: 255 })

	app.gg.draw_text(840, 205, 'Blue Factor: ${app.blue_factor}', text_cfg)
	app.gg.draw_square_filled(1040, 206, 20, gx.Color{ r: 230, g: 200, b: 255 })
	app.gg.draw_square_filled(1070, 206, 20, gx.Color{ r: 255, g: 160, b: 255 })

	app.gg.draw_text(840, 235, 'Min parti size: ${app.min_parti_size}', text_cfg)
	app.gg.draw_square_filled(1040, 236, 20, gx.Color{ r: 230, g: 200, b: 255 })
	app.gg.draw_square_filled(1070, 236, 20, gx.Color{ r: 255, g: 160, b: 255 })

	app.gg.draw_text(840, 265, 'Max parti size: ${app.max_parti_size - 1}', text_cfg)
	app.gg.draw_square_filled(1040, 266, 20, gx.Color{ r: 230, g: 200, b: 255 })
	app.gg.draw_square_filled(1070, 266, 20, gx.Color{ r: 255, g: 160, b: 255 })

	app.gg.draw_text(840, 295, 'Pick a rock (r) (size->scroll): ', text_cfg)
	app.gg.draw_square_filled(1040, 296, 20, gx.Color{255, 182, 193, 255})

	app.gg.draw_text(840, 325, 'Vertical grav: ${app.verti_mult}', text_cfg)
	app.gg.draw_square_filled(1040, 326, 20, gx.Color{ r: 230, g: 200, b: 255 })
	app.gg.draw_square_filled(1070, 326, 20, gx.Color{ r: 255, g: 160, b: 255 })

	app.gg.draw_text(840, 355, 'Horizontal grav: ${app.hori_mult}', text_cfg)
	app.gg.draw_square_filled(1040, 356, 20, gx.Color{ r: 230, g: 200, b: 255 })
	app.gg.draw_square_filled(1070, 356, 20, gx.Color{ r: 255, g: 160, b: 255 })

	if app.portable_parti {
		app.gg.draw_circle_filled(app.mouse_x, app.mouse_y, app.portable_parti_size, gx.gray)
	}

	app.gg.end()
	if !multithreaded {
		app.compute_step()
	}
}

@[direct_array_access; inline]
fn on_event(e &gg.Event, mut app App) {
	app.mouse_x = e.mouse_x
	app.mouse_y = e.mouse_y
	match e.typ {
		.key_down {
			match e.key_code {
				.escape { app.gg.quit() }
				.r {
					app.portable_parti = !app.portable_parti
				}
				else {}
			}
		}
		.mouse_down {
			match e.mouse_button {
				.left {
					app.mouse_pressed = true
				}
				else {}
			}
		}
		.mouse_up {
			match e.mouse_button {
				.left {
					app.mouse_pressed = false
				}
				else {}
			}
		}
		.mouse_scroll {
			app.portable_parti_size += int(e.scroll_y)
		}
		else {}
	}
}

@[direct_array_access; inline]
fn (mut app App) spawn_parti() {
	if app.mouse_x < win_width && app.mouse_y < win_height {
		for _ in 0 .. 5 {
			radius := rd.int_in_range(app.min_parti_size, app.max_parti_size) or { 12 }
			app.list_parti << Particle{app.mouse_x + rd.f64_in_range(-2, 2) or { panic(err) }, app.mouse_y + rd.f64_in_range(-2, 2) or {
				panic(err)
			}, radius, f32(radius), app.mouse_x, app.mouse_y, 0, 0, 0, 0, 0, 0, 0, 0}
		}
	}
}

@[direct_array_access; inline]
fn (mut app App) check_buttons() {
	if app.mouse_x > 1040 && app.mouse_x < 1090 {
		if app.mouse_x < 1060 {
			match true {
				(app.mouse_y > 26 && app.mouse_y < 46) {
					app.pression_view = !app.pression_view
					app.mouse_pressed = false
				}
				(app.mouse_y > 56 && app.mouse_y < 76) {
					app.carre_circle = !app.carre_circle
					app.mouse_pressed = false
				}
				(app.mouse_y > 86 && app.mouse_y < 106) {
					app.substeps -= 1.0
					app.mouse_pressed = false
				}
				(app.mouse_y > 116 && app.mouse_y < 136) {
					app.list_parti = []
					app.mouse_pressed = false
				}
				(app.mouse_y > 146 && app.mouse_y < 166) {
					app.red_factor -= 1
					app.mouse_pressed = false
				}
				(app.mouse_y > 176 && app.mouse_y < 196) {
					app.green_factor -= 1
					app.mouse_pressed = false
				}
				(app.mouse_y > 206 && app.mouse_y < 226) {
					app.blue_factor -= 1
					app.mouse_pressed = false
				}
				(app.mouse_y > 236 && app.mouse_y < 256) {
					app.min_parti_size -= 1
					app.mouse_pressed = false
				}
				(app.mouse_y > 266 && app.mouse_y < 286) {
					if app.max_parti_size > app.min_parti_size + 1 {
						app.max_parti_size -= 1
						app.array_height_max = int(ceil(win_height / f64(2 * (app.max_parti_size - 1))))
						app.array_width_max = int(ceil(win_width / f64(2 * (app.max_parti_size - 1))))
						app.list_opti = [][][]&Particle{len: app.array_height_max, init: [][]&Particle{len: app.array_width_max, init: []&Particle{}}}
						app.list_parti = []
						app.mouse_pressed = false
					}
				}
				(app.mouse_y > 296 && app.mouse_y < 316) {
					app.portable_parti = !app.portable_parti
					app.mouse_pressed = false
				}
				(app.mouse_y > 326 && app.mouse_y < 346) {
					app.verti_mult = m.round_sig(app.verti_mult - 0.1, 2)
					app.mouse_pressed = false
				}
				(app.mouse_y > 356 && app.mouse_y < 376) {
					app.hori_mult = m.round_sig(app.hori_mult - 0.1, 2)
					app.mouse_pressed = false
				}
				else {}
			}
		} else if app.mouse_x > 1070 {
			match true {
				(app.mouse_y > 86 && app.mouse_y < 106) {
					app.substeps += 1.0
					app.mouse_pressed = false
				}
				(app.mouse_y > 146 && app.mouse_y < 166) {
					app.red_factor += 1
					app.mouse_pressed = false
				}
				(app.mouse_y > 176 && app.mouse_y < 196) {
					app.green_factor += 1
					app.mouse_pressed = false
				}
				(app.mouse_y > 206 && app.mouse_y < 226) {
					app.blue_factor += 1
					app.mouse_pressed = false
				}
				(app.mouse_y > 236 && app.mouse_y < 256) {
					app.min_parti_size += 1
					app.mouse_pressed = false
				}
				(app.mouse_y > 266 && app.mouse_y < 286) {
					app.max_parti_size += 1
					app.array_height_max = int(ceil(win_height / f64(2 * (app.max_parti_size - 1))))
					app.array_width_max = int(ceil(win_width / f64(2 * (app.max_parti_size - 1))))
					app.list_opti = [][][]&Particle{len: app.array_height_max, init: [][]&Particle{len: app.array_width_max, init: []&Particle{}}}
					app.list_parti = []
					app.mouse_pressed = false
				}
				(app.mouse_y > 326 && app.mouse_y < 346) {
					app.verti_mult = m.round_sig(app.verti_mult + 0.1, 2)
					app.mouse_pressed = false
				}
				(app.mouse_y > 356 && app.mouse_y < 376) {
					app.hori_mult = m.round_sig(app.hori_mult + 0.1, 2)
					app.mouse_pressed = false
				}
				else {}
			}
		}
	}
}
