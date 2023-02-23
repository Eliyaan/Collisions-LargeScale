module main
import gg
import gx
import rand as rd
import math as m
import time

const (
    win_width    = 600
    win_height   = 600
    bg_color     = gx.black
	dt = 0.016
	big_circle_radius = 300
	big_circle_pos = 300
	text_cfg = gx.TextCfg{color: gx.white, size: 20, align: .left, vertical_align: .top}
	response_coef = 1.0
	half_response_coef = response_coef * 0.5
	sub = 8.0
	isub = int(sub)
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
	if parti.y + parti.radius > win_height{
		parti.y += win_height - (parti.y+parti.radius)
	}else if parti.y - parti.radius < 0{
		parti.y += -(parti.y-parti.radius)
	}
	if parti.x + parti.radius> win_width{
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
	fps_counter time.Duration
	old_fps time.Duration
	very_old_fps time.Duration
	very_very_old_fps time.Duration
	time_last_frame time.Time

}


fn (mut app App) create_opti_list(){
	for mut parti in app.list_parti{
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

	app.list_opti = [][][]&Particle{len:win_height/app.parti_size, init:[][]&Particle{len:win_width/app.parti_size, init:[]&Particle{cap:4}}}
	app.pow_radius = (4*app.parti_size*app.parti_size)
    //lancement du programme/de la fenêtre
    app.gg.run()
}



fn (mut app App) solve_collisions(){
	len := app.list_parti.len
	for i in 0..len{
		mut parti := &(app.list_parti[i])
		for j := i+1; j < len; j+=1{
			mut other := &(app.list_parti[j])
			dist_x := parti.x - other.x
			dist_y := parti.y - other.y
			mut dist := dist_x * dist_x + dist_y * dist_y
			min_dist := parti.radius + other.radius
			// Check overlapping
			if dist < min_dist * min_dist {
				dist  = m.sqrt(dist)
				n_x := dist_x / dist
				n_y := dist_y / dist
				delta := half_response_coef * (dist - min_dist)
				mass_ratio_a := (parti.fradius / min_dist) * delta  //not just mass ratio
				mass_ratio_b := (other.fradius / min_dist) * delta
				// Update positions
				parti.x -= n_x * (mass_ratio_b)
				parti.y -= n_y * (mass_ratio_b)
				other.x += n_x * (mass_ratio_a)
				other.y += n_y * (mass_ratio_a)
			}
			
		}
	}
}


fn on_frame(mut app App) {
	for i in 0..isub{
		for mut parti in app.list_parti{
			parti.accelerate(0, 10000/sub)
		}
		for mut parti in app.list_parti{
			parti.update_pos(dt/sub)
		}
		app.solve_collisions()
		for mut parti in app.list_parti{
			parti.correct_constraints_square()
		}
	}
    //Draw
	app.gg.begin()
	for parti in app.list_parti{
		app.gg.draw_circle_filled(f32(parti.x), f32(parti.y), parti.radius, gx.Color{u8(parti.radius*8%255),u8(parti.radius*16%255),u8(parti.radius*64%255), 255})
	}
	app.gg.draw_text(840, 55, "Nb particles: ${app.list_parti.len}", text_cfg)
	app.gg.draw_text(840, 85, "FPS: ${1000/((app.fps_counter+app.old_fps+app.very_old_fps+app.very_very_old_fps)/4+1)}", text_cfg)
	app.very_very_old_fps = app.very_old_fps
	app.very_old_fps = app.old_fps
	app.old_fps = app.fps_counter
	app.fps_counter = (time.now()-app.time_last_frame).milliseconds()
	app.time_last_frame = time.now()
    app.gg.end()
}


fn on_event(e &gg.Event, mut app App){
    match e.typ {
        .key_down {
            match e.key_code {
                .escape {app.gg.quit()}
                else {}
            }
        }
        .mouse_down {
            match e.mouse_button{
                .left{app.spawn_parti(e.mouse_x, e.mouse_y)}
                else{}
        }}
        else {}
    }
}


fn (mut app App) spawn_parti(x f32, y f32){
	if x < win_width && y < win_height{
		for i in 0..5{
			radius := rd.int_in_range(2, 10) or {12}
			app.list_parti << Particle{x+i, y+i, radius, f32(radius), x, y, 0, 0, 0, 0}
		}
	}
}