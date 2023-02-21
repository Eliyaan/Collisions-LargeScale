module main
import gg
import gx
import rand as rd
import math as m

const (
    win_width    = 600
    win_height   = 600
    bg_color     = gx.black
	dt = 0.016
	big_circle_radius = 300
	big_circle_pos = 300
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

	parti.x = parti.x + velocity_x + parti.acc_x * dt * dt
	parti.y = parti.y + velocity_y + parti.acc_y * dt * dt

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
	dist := m.sqrt(m.pow(to_obj_x,2)+m.pow(to_obj_y,2))
	if dist > big_circle_radius - parti.radius{
		n_x := to_obj_x/dist
		n_y := to_obj_y/dist
		parti.x = big_circle_pos - n_x * (big_circle_radius-parti.radius)
		parti.y = big_circle_pos - n_y * (big_circle_radius-parti.radius)//thalès
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
		parti.accelerate(0, 10000)
	}
	for mut parti in app.list_parti{
		parti.update_pos()
	}
	for mut parti in app.list_parti{
		parti.correct_constraints_circle()
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