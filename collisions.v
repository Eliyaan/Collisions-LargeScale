module main
import gg
import gx
import rand as rd
import math as m

const (
    win_width    = 600
    win_height   = 600
    bg_color     = gx.black
)

[heap]
struct Particle{
    mut:
    x f64
    y f64
	radius int
	old_x f64
	old_y f64
	acc_x f64
	acc_y f64
	delta_x f64
	delta_y f64
}


fn (mut parti Particle) update_pos(){
	velocity_x := parti.x - parti.old_x
	velocity_y := parti.y - parti.old_y

	parti.old_x = parti.x
	parti.old_y = parti.y

	parti.x = parti.x + velocity_x + parti.acc_x 
	parti.y = parti.y + velocity_y + parti.acc_y

	parti.correct_constraints()
}


fn (mut parti Particle) correct_constraints(){
	if parti.y + parti.radius > win_height{
		parti.y += win_height - (parti.y+parti.radius)
		parti.old_y = parti.y
	}else if parti.y - parti.radius < 0{
		parti.y += -(parti.y-parti.radius)
		parti.old_y = parti.y
	}
	if parti.x + parti.radius> win_width{
		parti.x += win_width - (parti.x+parti.radius)
		parti.old_x = parti.x
	}
	else if parti.x - parti.radius < 0{
		parti.x += -(parti.x-parti.radius)
		parti.old_x = parti.x
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
	parti_size int = 16
	pow_radius int
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





fn on_frame(mut app App) {
	for mut parti in app.list_parti{
		parti.accelerate(0, 0.1)
		parti.update_pos()
		parti.correct_constraints()
	}
	for i in 0..1{
		for mut parti in app.list_parti{
			for mut other in app.list_parti{
				if other != parti{
					diff_x := parti.x - other.x
					diff_y := parti.y - other.y
					if diff_x*diff_x + diff_y*diff_y < app.pow_radius{
						if diff_x > 0{
							parti.delta_x += (app.parti_size - diff_x/2)
						}else if diff_x < 0{
							parti.delta_x += (-app.parti_size - diff_x/2)
						}else{
						}
						if diff_y > 0{
							parti.delta_y += (app.parti_size - diff_y/2)
						}else if diff_y < 0{
							parti.delta_y += (-app.parti_size - diff_y/2)
						}else{
						}
					}
				}
			}
			parti.x += parti.delta_x
			parti.y += parti.delta_y
			parti.delta_x = 0
			parti.delta_y = 0
			parti.correct_constraints()
		}
	}
    //Draw
	app.gg.begin()
	for mut parti in app.list_parti{
		app.gg.draw_circle_filled(f32(parti.x), f32(parti.y), app.parti_size, gx.white)
	}
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
		app.list_parti << Particle{x, y, app.parti_size, x, y, 0, 0, 0, 0}
	}
}