module main
import gg
import gx
import rand as rd
import math as m
import time

const (
    win_width    = 600
    win_height   = 600
    bg_color     = gx.white
	dt = 0.016
	big_circle_radius = 300
	big_circle_pos = 300
	text_cfg = gx.TextCfg{color: gx.black, size: 20, align: .left, vertical_align: .top}
	response_coef = 1.0
	half_response_coef = response_coef * 0.5
)

[heap]
struct Particle{
    mut:
    x f64
    y f64
	radius int
	fradius f32
	old_x f64
	old_y f64
	acc_x f64
	acc_y f64
	delta_x f64
	delta_y f64
	pression f64
	id int
	opti_y int
	opti_x int
}


fn (mut parti Particle) update_pos(delta_time f64){
	velocity_x := parti.x - parti.old_x
	velocity_y := parti.y - parti.old_y

	parti.old_x = parti.x
	parti.old_y = parti.y

	parti.x = parti.x + velocity_x + parti.acc_x * delta_time * delta_time
	parti.y = parti.y + velocity_y + parti.acc_y * delta_time * delta_time
}


fn (mut parti Particle) correct_constraints_square(){
	if parti.y + parti.radius >= win_height{
		parti.y += win_height - (parti.y+parti.radius)
	}else if parti.y - parti.radius < 0{
		parti.y += -(parti.y-parti.radius)
	}
	if parti.x + parti.radius >= win_width{
		parti.x += win_width - (parti.x+parti.radius)
	}
	else if parti.x - parti.radius < 0{
		parti.x += -(parti.x-parti.radius)
	}
}


fn (mut parti Particle) correct_constraints_circle(){
	to_obj_x := big_circle_pos - parti.x 
	to_obj_y := big_circle_pos - parti.y
	mut dist := to_obj_x*to_obj_x+to_obj_y*to_obj_y
	normal_dist := big_circle_radius - parti.radius
	if dist > normal_dist*normal_dist{
		dist= m.sqrt(dist)
		n_x := to_obj_x/dist
		n_y := to_obj_y/dist
		parti.x = big_circle_pos - n_x * normal_dist
		parti.y = big_circle_pos - n_y * normal_dist//thalès
	}
}


fn (mut parti Particle) accelerate(new_acc_x f64, new_acc_y f64){
	parti.acc_x = new_acc_x
	parti.acc_y = new_acc_y
}

[heap]
struct App {
mut:
    gg    &gg.Context = unsafe { nil }

	list_parti []Particle
	list_opti [][][]&Particle
	parti_size int = 12
	pow_radius int
	fps_counter []time.Duration = []time.Duration{len: 30}
	time_last_frame time.Time

	pression_view bool
	carre_circle bool 
	mouse_x f32
	mouse_y f32
	mouse_pressed bool
	substeps f32 = 8.0
	red_factor int = -2
	green_factor int = 16
	blue_factor int = 64

	min_parti_size int = 2
	max_parti_size int = 16

	array_width_max int
	array_height_max int

	portable_parti_size int = 6
	portable_parti bool
}


fn (mut app App) init_opti_list(){
	app.list_opti = [][][]&Particle{len:app.array_height_max, init:[][]&Particle{len:app.array_width_max, init:[]&Particle{}}}
	for mut parti in app.list_parti{
		x_index := int(parti.x/(2*(app.max_parti_size-1)))
		y_index := int(parti.y/(2*(app.max_parti_size-1)))
		parti.id = app.list_opti[y_index][x_index].len
		parti.opti_x = x_index
		parti.opti_y = y_index
		app.list_opti[y_index][x_index] << &parti
	}
}


fn main() {
    mut app := &App{
        gg: 0
    }
    app.gg = gg.new_context(
        width: win_width
        height: win_height
        create_window: true
        window_title: '- Application -'
        user_data: app
        bg_color: bg_color
        frame_fn: on_frame
		event_fn: on_event
		fullscreen: true
        sample_count: 6
    )

	app.init_opti_list()
	app.pow_radius = (4*app.parti_size*app.parti_size)
	app.array_height_max = int(m.ceil(win_height/(2*(app.max_parti_size-1))))
	app.array_width_max = int(m.ceil(win_width/(2*(app.max_parti_size-1))))

    //lancement du programme/de la fenêtre
    app.gg.run()
}


[direct_array_access]
fn (mut app App) solve_collisions(){
	for mut parti in app.list_parti{
		app.list_opti[parti.opti_y][parti.opti_x].delete(parti.id)
		for u in parti.id..app.list_opti[parti.opti_y][parti.opti_x].len{
			app.list_opti[parti.opti_y][parti.opti_x][u].id -= 1
		}
		for y in -1..2{
			y_index := parti.opti_y+y
			if y_index >= 0 && y_index < app.array_height_max{
				for x in -1..2{
					x_index := parti.opti_x+x
					if x_index >= 0 && x_index < app.array_width_max{
						mut remove_particles := []&Particle{cap:app.list_opti[y_index][x_index].len}
						for o_i, mut other in app.list_opti[y_index][x_index]{
							dist_x := parti.x - other.x
							dist_y := parti.y - other.y
							mut dist := dist_x * dist_x + dist_y * dist_y
							min_dist := parti.radius + other.radius
							// Check overlapping
							if dist < min_dist * min_dist && dist >= 1{
								dist  = m.sqrt(dist)
								n_x := dist_x / dist
								n_y := dist_y / dist
								delta := half_response_coef * (dist - min_dist)
								mass_ratio_a := (parti.fradius / min_dist) * delta  //not just mass ratio
								mass_ratio_b := (other.fradius / min_dist) * delta
								// Update positions
								xb := n_x * (mass_ratio_b)
								yb := n_y * (mass_ratio_b)
								xa := n_x * (mass_ratio_a)
								ya := n_y * (mass_ratio_a)
								parti.x -= xb
								parti.y -= yb
								other.x += xa
								other.y += ya
								if app.pression_view{
									parti.pression += m.abs(xb + yb)
									other.pression += m.abs(xa + ya)
								}
								if app.carre_circle{
									other.correct_constraints_circle()
								}else{
									other.correct_constraints_square()
								}
								remove_particles << app.list_opti[y_index][x_index][o_i]
							}
						}
						for ok_i, mut other_killed in remove_particles{
							app.list_opti[y_index][x_index].delete(other_killed.id)
							for u in other_killed.id..app.list_opti[y_index][x_index].len{
								app.list_opti[y_index][x_index][u].id -= 1
							}
							if app.carre_circle{
								other_killed.correct_constraints_circle()
							}else{
								other_killed.correct_constraints_square()
							}
							new_loc_y := int(other_killed.y/(2*(app.max_parti_size-1)))
							new_loc_x := int(other_killed.x/(2*(app.max_parti_size-1)))
							app.list_opti[new_loc_y][new_loc_x] << remove_particles[ok_i]
							other_killed.id = app.list_opti[new_loc_y][new_loc_x].len-1
							other_killed.opti_x = new_loc_x
							other_killed.opti_y = new_loc_y
						}
					}
				}
			}
		}
		if app.carre_circle{
			parti.correct_constraints_circle()
		}else{
			parti.correct_constraints_square()
		}
		new_loc_y := int(parti.y/(2*(app.max_parti_size-1)))
		new_loc_x := int(parti.x/(2*(app.max_parti_size-1)))
		app.list_opti[new_loc_y][new_loc_x] << &parti
		parti.id = app.list_opti[new_loc_y][new_loc_x].len-1
		parti.opti_x = new_loc_x
		parti.opti_y = new_loc_y
	}
}


fn (mut app App) solve_portable_parti(){
	for mut other in app.list_parti{
		dist_x := app.mouse_x - other.x
		dist_y := app.mouse_y - other.y
		mut dist := dist_x * dist_x + dist_y * dist_y
		min_dist := f32(app.portable_parti_size + other.radius)
		// Check overlapping
		if dist < min_dist * min_dist && dist >= 1{
			dist  = m.sqrt(dist)
			n_x := dist_x / dist
			n_y := dist_y / dist
			delta := half_response_coef * (dist - min_dist)
			mass_ratio_a := (app.portable_parti_size / min_dist) * delta  //not just mass ratio
			// Update positions
			xa := n_x * (mass_ratio_a)
			ya := n_y * (mass_ratio_a)
			other.x += xa
			other.y += ya
			if app.pression_view{
				other.pression += m.abs(xa + ya)
			}
		}
	}
}


fn on_frame(mut app App) {
	if app.mouse_pressed{
		if !app.portable_parti{
			app.spawn_parti()
		}
		app.check_buttons()
	}
	for _ in 0..int(app.substeps){
		for mut parti in app.list_parti{
			parti.accelerate(0, 10000/app.substeps)
			parti.pression = 0
		}
		for mut parti in app.list_parti{
			parti.update_pos(dt/app.substeps)
		}
		if app.carre_circle{
			for mut parti in app.list_parti{
				parti.correct_constraints_circle()
			}
		}else{
			for mut parti in app.list_parti{
				parti.correct_constraints_square()
			}
		}
		app.init_opti_list()
		
		app.solve_collisions()
		if app.portable_parti{
			app.solve_portable_parti()  // TODO : reassign de list
		}
	}
    //Draw
	app.gg.begin()
	if app.carre_circle{
		app.gg.draw_circle_filled(300, 300, 300, gx.black)
	}else{
		app.gg.draw_square_filled(0, 0, 600, gx.black)
	}
	if app.pression_view{
		for parti in app.list_parti{
			pression := parti.pression*82
			if pression > 255{
				app.gg.draw_circle_filled(f32(parti.x), f32(parti.y), parti.radius, gx.Color{163, 0, 38, 255})
			}else{
				app.gg.draw_circle_filled(f32(parti.x), f32(parti.y), parti.radius, gx.Color{255, 255-u8(pression), 255-u8(pression), 255})
			}
		}
	}else{
		for parti in app.list_parti{
		app.gg.draw_circle_filled(f32(parti.x), f32(parti.y), parti.radius, gx.Color{u8(parti.radius*app.red_factor%255),u8(parti.radius*app.green_factor%255),u8(parti.radius*app.blue_factor%255), 255})
		}
	}

	
	mut fpstime := 0
	for elem in app.fps_counter{
		fpstime += elem
	}
	fpstime /= app.fps_counter.len
	app.gg.draw_text(840, 585, "FPS: ${1000/(fpstime+1)}", text_cfg)
	app.fps_counter.delete(0)
	app.fps_counter << (time.now()-app.time_last_frame).milliseconds()
	app.time_last_frame = time.now()

	app.gg.draw_text(840, 555, "Nb particles: ${app.list_parti.len}", text_cfg)

	app.gg.draw_text(840, 25, "Pression view: ", text_cfg)
    app.gg.draw_rounded_rect_filled(1040, 26, 20, 20, 4,  gx.Color{255,182,193,255})

	app.gg.draw_text(840, 55, "Square/Circle: ", text_cfg)
    app.gg.draw_rounded_rect_filled(1040, 56, 20, 20, 4,  gx.Color{255,182,193,255})

	app.gg.draw_text(840, 85, "Nb substeps: ${app.substeps}", text_cfg)
    app.gg.draw_rounded_rect_filled(1040, 86, 20, 20, 4,  gx.Color{r: 230, g: 200, b: 255})
	app.gg.draw_rounded_rect_filled(1070, 86, 20, 20, 4,  gx.Color{r: 255, g: 160, b: 255})

	app.gg.draw_text(840, 115, "Reset the particles: ", text_cfg)
    app.gg.draw_rounded_rect_filled(1040, 116, 20, 20, 4,  gx.Color{255,182,193,255})

	app.gg.draw_text(840, 145, "Red Factor: ${app.red_factor}", text_cfg)
    app.gg.draw_rounded_rect_filled(1040, 146, 20, 20, 4,  gx.Color{r: 230, g: 200, b: 255})
	app.gg.draw_rounded_rect_filled(1070, 146, 20, 20, 4,  gx.Color{r: 255, g: 160, b: 255})

	app.gg.draw_text(840, 175, "Green Factor: ${app.green_factor}", text_cfg)
    app.gg.draw_rounded_rect_filled(1040, 176, 20, 20, 4,  gx.Color{r: 230, g: 200, b: 255})
	app.gg.draw_rounded_rect_filled(1070, 176, 20, 20, 4,  gx.Color{r: 255, g: 160, b: 255})

	app.gg.draw_text(840, 205, "Blue Factor: ${app.blue_factor}", text_cfg)
    app.gg.draw_rounded_rect_filled(1040, 206, 20, 20, 4,  gx.Color{r: 230, g: 200, b: 255})
	app.gg.draw_rounded_rect_filled(1070, 206, 20, 20, 4,  gx.Color{r: 255, g: 160, b: 255})

	app.gg.draw_text(840, 235, "Min parti size: ${app.min_parti_size}", text_cfg)
    app.gg.draw_rounded_rect_filled(1040, 236, 20, 20, 4,  gx.Color{r: 230, g: 200, b: 255})
	app.gg.draw_rounded_rect_filled(1070, 236, 20, 20, 4,  gx.Color{r: 255, g: 160, b: 255})

	app.gg.draw_text(840, 265, "Max parti size: ${app.max_parti_size}", text_cfg)
    app.gg.draw_rounded_rect_filled(1040, 266, 20, 20, 4,  gx.Color{r: 230, g: 200, b: 255})
	app.gg.draw_rounded_rect_filled(1070, 266, 20, 20, 4,  gx.Color{r: 255, g: 160, b: 255})

	app.gg.draw_text(840, 295, "Pick a rock (size->scroll): ", text_cfg)
    app.gg.draw_rounded_rect_filled(1040, 296, 20, 20, 4,  gx.Color{255,182,193,255})


	if app.portable_parti{
		app.gg.draw_circle_filled(app.mouse_x, app.mouse_y, app.portable_parti_size, gx.gray)
	}

    app.gg.end()
}


fn on_event(e &gg.Event, mut app App){
	app.mouse_x = e.mouse_x
	app.mouse_y = e.mouse_y
    match e.typ {
        .key_down {
            match e.key_code {
                .escape {app.gg.quit()}
                else {}
            }
        }
        .mouse_down {
            match e.mouse_button{
                .left{app.mouse_pressed = true
						}
                else{}
        }}
		.mouse_up {
            match e.mouse_button{
                .left{
						app.mouse_pressed = false
						}
                else{}
        }}
		.mouse_scroll{
			app.portable_parti_size += int(e.scroll_y)/4
		}
        else {}
    }
}


fn (mut app App) spawn_parti(){
	if app.mouse_x < win_width && app.mouse_y < win_height{
		radius := rd.int_in_range(app.min_parti_size, app.max_parti_size) or {12}
		app.list_parti << Particle{app.mouse_x, app.mouse_y, radius, f32(radius), app.mouse_x, app.mouse_y, 0, 0, 0, 0, 0, 0, 0, 0}
	}
}


fn (mut app App) check_buttons(){
    if app.mouse_x > 1040 && app.mouse_x < 1090{
        if app.mouse_x < 1060{
            match true{
                (app.mouse_y > 26 && app.mouse_y < 46){app.pression_view = !app.pression_view
					app.mouse_pressed = false}
				(app.mouse_y > 56 && app.mouse_y < 76){app.carre_circle = !app.carre_circle
					app.mouse_pressed = false}
				(app.mouse_y > 86 && app.mouse_y < 106){app.substeps -= 1.0
					app.mouse_pressed = false}
				(app.mouse_y > 116 && app.mouse_y < 136){app.list_parti = []
					app.mouse_pressed = false}
				(app.mouse_y > 146 && app.mouse_y < 166){app.red_factor -= 1
					app.mouse_pressed = false}
				(app.mouse_y > 176 && app.mouse_y < 196){app.green_factor -= 1
					app.mouse_pressed = false}
				(app.mouse_y > 206 && app.mouse_y < 226){app.blue_factor -= 1
					app.mouse_pressed = false}
				(app.mouse_y > 236 && app.mouse_y < 256){app.min_parti_size -= 1
					app.mouse_pressed = false}
				(app.mouse_y > 266 && app.mouse_y < 286){app.max_parti_size -= 1
					app.array_height_max = int(m.ceil(win_height/(2*(app.max_parti_size-1))))
					app.array_width_max = int(m.ceil(win_width/(2*(app.max_parti_size-1))))
					app.mouse_pressed = false}
				(app.mouse_y > 296 && app.mouse_y < 316){app.portable_parti = !app.portable_parti
					app.mouse_pressed = false}
                else{}
            }
        }else if app.mouse_x > 1070{
            match true{
                (app.mouse_y > 86 && app.mouse_y < 106){app.substeps += 1.0
					app.mouse_pressed = false}
				(app.mouse_y > 146 && app.mouse_y < 166){app.red_factor += 1
					app.mouse_pressed = false}
				(app.mouse_y > 176 && app.mouse_y < 196){app.green_factor += 1
					app.mouse_pressed = false}
				(app.mouse_y > 206 && app.mouse_y < 226){app.blue_factor += 1
					app.mouse_pressed = false}
				(app.mouse_y > 236 && app.mouse_y < 256){app.min_parti_size += 1
					app.mouse_pressed = false}
				(app.mouse_y > 266 && app.mouse_y < 286){app.max_parti_size += 1
					app.array_height_max = int(m.ceil(win_height/(2*(app.max_parti_size-1))))
					app.array_width_max = int(m.ceil(win_width/(2*(app.max_parti_size-1))))
					app.mouse_pressed = false}
                else{}
            }
        }
    }
}