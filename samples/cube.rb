require 'gosu'
require 'wads'
#require 'rdia-games'
require_relative '../lib/rdia-games'

include Wads
include RdiaGames

GAME_WIDTH = 1280
GAME_HEIGHT = 720

MODE_ISOMETRIC = "iso"
MODE_REAL_THREE_D = "real3d"

AXIS_BEGIN = -500
AXIS_END = 500
CAMERA_Z_START = 800

class ThreeDPoint
    attr_accessor :x
    attr_accessor :y 
    attr_accessor :z 

    def initialize(x, y, z) 
        @x = x 
        @y = y 
        @z = z
    end
end

class ThreeDObject 
    attr_accessor :model_points
    attr_accessor :render_points
    attr_accessor :angle_x
    attr_accessor :angle_y
    attr_accessor :angle_z
    attr_accessor :speed
    attr_accessor :color

    def initialize(color = COLOR_AQUA)
        @move_x = 0     # TODO make public?
        @move_y = 0     # TODO make public?
        clear_points 
        reset_angle_and_scale
        @color = color
    end 

    def clear_points 
        @model_points = []
        @render_points = []
    end

    def reset_angle_and_scale 
        @angle_x = 0
        @angle_y = 0
        @angle_z = 0
        @scale = 0.001
    end

    def move_left 
        @model_points.each do |model_point|
            model_point.x = model_point.x - 5
        end
    end 
    def move_right 
        @model_points.each do |model_point|
            model_point.x = model_point.x + 5
        end
    end 
    def move_up 
        @model_points.each do |model_point|
            model_point.y = model_point.y - 5
        end
    end 
    def move_down
        @model_points.each do |model_point|
            model_point.y = model_point.y + 5
        end
    end 
    def move_away
        @model_points.each do |model_point|
            model_point.z = model_point.z - 5
        end
    end 
    def move_towards
        @model_points.each do |model_point|
            model_point.z = model_point.z + 5
        end
    end 

    def draw_square(points)
        (0..3).each do |n|
            if n == 3
                draw_line(points, n, 0, @color)
            else 
                draw_line(points, n, n + 1, @color)
            end 
        end
    end
    
    def draw_line(points, index1, index2, color = COLOR_AQUA, z = 10)
        point1 = points[index1]
        point2 = points[index2]
        Gosu::draw_line point1.x, point1.y, color, point2.x, point2.y, color, z
    end

    def calc_points
        @render_points = [] 
        @model_points.each do |model_point|
            @render_points << calc_point(model_point,
                                         @scale,
                                         @angle_x, @angle_y, @angle_z,
                                         @move_x, @move_y)
        end 
    end 

    def calc_point(model_point, scale, angle_x = 0, angle_y = 0, angle_z = 0, move_x = 0, move_y = 0)
        # XD = X(N)-PIVX
        # YD = Y(N)-PIVY
        # ZD = Z(N)-PIVZ
        xd = model_point.x - $center_x
        yd = model_point.y - $center_y
        zd = model_point.z - $center_z

        # ZX = XD*Cos{ANGLEZ} - YD*Sin{ANGLEZ} - XD
        # ZY = XD*Sin{ANGLEZ} + YD*Cos{ANGLEZ} - YD
        zx = (xd * Math.cos(angle_z)) - (yd * Math.sin(angle_z)) - xd
        zy = (xd * Math.sin(angle_z)) + (yd * Math.cos(angle_z)) - yd

        # YX = [XD+ZX]*Cos{ANGLEY} - ZD*Sin{ANGLEY} - [XD+ZX]
        # YZ = [XD+ZX]*Sin{ANGLEY} + ZD*Cos{ANGLEY} - ZD
        yx = ((xd + zx) * Math.cos(angle_y)) - (zd * Math.sin(angle_y)) - (xd + zx)
        yz = ((xd + zx) * Math.sin(angle_y)) + (zd * Math.cos(angle_y)) - zd

        # XY = [YD+ZY]*Cos{ANGLEX} - [ZD+YZ]*Sin{ANGLEX} - [YD+ZY]
        # XZ = [YD+ZY]*Sin{ANGLEX} + [ZD+YZ]*Cos{ANGLEX} - [ZD+YZ]
        xy = ((yd + zy) * Math.cos(angle_x)) - ((zd + yz) * Math.sin(angle_x)) - (yd + zy)
        xz = ((yd + zy) * Math.sin(angle_x)) + ((zd + yz) * Math.cos(angle_x)) - (zd + yz)

        # XROTOFFSET = YX+ZX
        # YROTOFFSET = ZY+XY
        # ZROTOFFSET = XZ+YZ 
        x_rot_offset = yx + zx
        y_rot_offset = zy + xy 
        z_rot_offset = xz + yz

        #If MODE=0
        #    X = [ X(N) + XROTOFFSET + CAMX ] /SCALE +MOVEX
        #    Y = [ Y(N) + YROTOFFSET + CAMY ] /SCALE +MOVEY
        #Else
        #    Z = [ Z(N) + ZROTOFFSET + CAMZ ]
        #    X = [ X(N) + XROTOFFSET + CAMX ] /Z /SCALE +MOVEX
        #    Y = [ Y(N) + YROTOFFSET + CAMY ] /Z /SCALE +MOVEY
        #End If

        #if @mode == MODE_ISOMETRIC
        #    x = ((model_point.x + x_rot_offset + $camera_x) / scale) + move_x 
        #    y = ((model_point.y + y_rot_offset + $camera_y) / scale) + move_y
        #    z = model_point.z
        #else 
            z = model_point.z + z_rot_offset + $camera_z
            x = (((model_point.x + x_rot_offset + $camera_x) / z) / scale) + move_x 
            y = (((model_point.y + y_rot_offset + $camera_y) / z) / scale) + move_y
        #end 

        ThreeDPoint.new(x, y, z) 
    end
end 

class ThreeDLine < ThreeDObject
    def initialize(a, b, color = COLOR_AQUA)
        super(color)
        @model_points << a 
        @model_points << b
    end

    def a 
        @model_points[0]
    end
    def b
        @model_points[1]
    end

    def render 
        # Darren
        # If either of the points is behind you, then don't draw it
        #if @model_points[0].z > $camera_z
        #    puts "Not displaying line because 0 point z #{@render_points[0].z} > #{$camera_z}"
        #elsif @model_points[1].z > $camera_z
        #    puts "Not displaying line because 1 point z #{@render_points[1].z} > #{$camera_z}"
        #else
            draw_line(@render_points, 0, 1, @color, 9)
        #end
    end 
end 

class Cube < ThreeDObject
    # The x, y, z coordinates are for the upper left corner
    def initialize(x, y, z, length)
        super()
        @x = x 
        @y = y 
        @z = z
        @length = length
        # TODO really we need to add camera values to x and y also, they were just zero to begin
        reset
    end 

    def reset 
        reset_angle_and_scale
        @model_points << ThreeDPoint.new(@x,           @y,           @z)
        @model_points << ThreeDPoint.new(@x + @length, @y,           @z)
        @model_points << ThreeDPoint.new(@x + @length, @y - @length, @z)
        @model_points << ThreeDPoint.new(@x,           @y - @length, @z)
        @model_points << ThreeDPoint.new(@x,           @y,           @z + @length)
        @model_points << ThreeDPoint.new(@x + @length, @y,           @z + @length)
        @model_points << ThreeDPoint.new(@x + @length, @y - @length, @z + @length)
        @model_points << ThreeDPoint.new(@x,           @y - @length, @z + @length)
    end

    def render 
        a = @render_points[0]
        b = @render_points[1]
        c = @render_points[2]
        d = @render_points[3]
        e = @render_points[4]
        f = @render_points[5]
        g = @render_points[6]
        h = @render_points[7]

        draw_square([a, b, c, d])
        draw_square([a, e, h, d])
        draw_square([b, f, g, c])

        draw_square([e, f, g, h])
        draw_square([a, e, f, b])
        draw_square([d, h, g, c])
    end 
end

class CubeRender < RdiaGame
    def initialize
        super(GAME_WIDTH, GAME_HEIGHT, "Cube Render", CubeRenderDisplay.new)
        register_hold_down_key(Gosu::KbQ)    
        register_hold_down_key(Gosu::KbW)    
        register_hold_down_key(Gosu::KbE)    
        register_hold_down_key(Gosu::KbR)
        register_hold_down_key(Gosu::KbT)
        register_hold_down_key(Gosu::KbY)
        register_hold_down_key(Gosu::KbU)
        register_hold_down_key(Gosu::KbI)
        register_hold_down_key(Gosu::KbO)

        register_hold_down_key(Gosu::KbA)
        register_hold_down_key(Gosu::KbS)
        register_hold_down_key(Gosu::KbD)
        register_hold_down_key(Gosu::KbF)
        register_hold_down_key(Gosu::KbG)
        register_hold_down_key(Gosu::KbH)
        register_hold_down_key(Gosu::KbJ)
        register_hold_down_key(Gosu::KbK)
        register_hold_down_key(Gosu::KbL)

        # scaling
        register_hold_down_key(Gosu::KbUp)
        register_hold_down_key(Gosu::KbDown)
        
    end 
end

class CubeRenderDisplay < Widget
    include Gosu

    def initialize
        super(0, 0, GAME_WIDTH, GAME_HEIGHT)
        disable_border

        @x_axis_lines = []
        @z_axis_lines = []

        @offset_x = 600
        @offset_y = 300

        $center_x = 0
        $center_y = 0
        $center_z = 100
        $camera_x = 0
        $camera_y = 150
        $camera_z = CAMERA_Z_START   # If this started at zero, we would be inside the cube

        @speed = 5
        @mode = MODE_ISOMETRIC
        @continuous_movement = true
        #@scale = 0.5
        @scaling_speed = 0.05

        # Axis lines
        @x_axis = ThreeDLine.new(ThreeDPoint.new(-1000, 0, 0), ThreeDPoint.new(1000, 0, 0))
        @y_axis = ThreeDLine.new(ThreeDPoint.new(0, -AXIS_END, 0), ThreeDPoint.new(0, AXIS_END, 0))
        @z_axis = ThreeDLine.new(ThreeDPoint.new(0, 0, -AXIS_END), ThreeDPoint.new(0, 0, AXIS_END))

        # Our objects
        @cube = Cube.new(100, 0, 0, 100)

        @all_objects = [@cube, @x_axis, @y_axis, @z_axis]

        # Darren
        # Floor lines. Floor is y=0, because y is really height
        x = -1000
        while x < 1050
            x_axis_line = ThreeDLine.new(ThreeDPoint.new(x, 0, -500), ThreeDPoint.new(x, 0, 10000), COLOR_WHITE)
            @x_axis_lines << x_axis_line
            @all_objects << x_axis_line
            x = x + 100
        end
        z = -500
        while z < 9010
            z_axis_line = ThreeDLine.new(ThreeDPoint.new(-1000, 0, z), ThreeDPoint.new(1000, 0, z), COLOR_PINK)
            @z_axis_lines << z_axis_line
            @all_objects << z_axis_line
            z = z + 100
        end

        @current_mouse_text = Text.new(10, 130, "0, 0")
        add_child(@current_mouse_text)
        @current_scale_text = Text.new(10, 100, objects_text)
        add_child(@current_scale_text)
        @current_mode_text = Text.new(10, 70, axis_text)
        add_child(@current_mode_text)

        @camera_text = Text.new(10, 40, "Camera: #{$camera_x}, #{$camera_y}, #{$camera_z}")
        add_child(@camera_text)
        @location_text = Text.new(10, 10, "")
        add_child(@location_text)
    end 

    def modify(&block)
        @all_objects.each do |obj|
            yield obj
        end
    end

    # This uses algorithm described in https://www.skytopia.com/project/cube/cube.html
    def calc_points
        modify do |n|
            n.calc_points
        end
    end 

    def render
        Gosu.translate(@offset_x, @offset_y) do
            modify do |n|
                n.render
            end
            @z_axis_lines.each do |z_axis_line|
                WadsConfig.instance.current_theme.font.draw_text("#{z_axis_line.a.z}", 10, z_axis_line.render_points[0].y, 10, 1, 1, COLOR_WHITE)
            end
        end 
    end

    def handle_update update_count, mouse_x, mouse_y
        @x_axis_lines.each do |x_axis_line|
            x_axis_line.a.z = -$camera_z + 5
        end
        calc_points
        @current_mouse_text.label = "Mouse: #{mouse_x}, #{mouse_y}"
        @current_scale_text.label = objects_text
        @current_mode_text.label = axis_text
        @camera_text.label = "Camera: #{$camera_x}, #{$camera_y}, #{$camera_z}"
        @location_text.label = location_text 
    end

    def location_text 
        "Location: #{@cube.model_points[0].x.round}, #{@cube.model_points[0].y.round}, #{@cube.model_points[0].z.round}"
    end 

    def axis_text 
        "X Axis: #{@x_axis_lines[0].a.z} - #{@x_axis_lines[0].b.z}"
    end

    def objects_text 
        "Num objs: #{@all_objects.size}"
    end

    def handle_key_held_down id, mouse_x, mouse_y
        if @continuous_movement
            handle_movement id, mouse_x, mouse_y 
        end 
    end

    def handle_key_press id, mouse_x, mouse_y
        handle_movement(id, mouse_x, mouse_y)
        if id == Gosu::KbSpace 
            @continuous_movement = !@continuous_movement
        elsif id == Gosu::KbP
            @cube.clear_points 
            @cube.reset
            modify do |n|
                n.angle_x = 0
                n.angle_y = 0
                n.angle_z = 0
            end
        elsif id == Gosu::KbUp
            # TODO this needs to delegate to the objects
            @scale = @scale + @scaling_speed
        elsif id == Gosu::KbDown
            # TODO this needs to delegate to the objects
            if @scale > 0.3
                @scale = @scale - 0.05
            else 
                @scale = @scale - 0.01
            end
            if @scale < 0 
                @scale = 0.001
            end
        end
    end

    def handle_movement id, mouse_x, mouse_y 
        if id == Gosu::KbA
            @cube.move_left
        elsif id == Gosu::KbD
            @cube.move_right
        elsif id == Gosu::KbQ
            @cube.move_up
        elsif id == Gosu::KbE
            @cube.move_down
        elsif id == Gosu::KbW
            @cube.move_towards
        elsif id == Gosu::KbS
            @cube.move_away

        elsif id == Gosu::KbJ                # solid
            $camera_x = $camera_x + @speed
        elsif id == Gosu::KbL                # solid
            $camera_x = $camera_x - @speed
        elsif id == Gosu::KbU
            $camera_y = $camera_y - @speed
        elsif id == Gosu::KbO
            $camera_y = $camera_y + @speed
        elsif id == Gosu::KbI                # solid
            $camera_z = $camera_z - @speed
        elsif id == Gosu::KbK                # solid
            $camera_z = $camera_z + @speed

        elsif id == Gosu::KbF
            modify do |n|
                n.angle_x = n.angle_x - 0.05
            end
        elsif id == Gosu::KbH
            modify do |n|
                n.angle_x = n.angle_x + 0.05
            end
        elsif id == Gosu::KbR
            modify do |n|
                n.angle_y = n.angle_y - 0.05
            end
        elsif id == Gosu::KbY
            modify do |n|
                n.angle_y = n.angle_y + 0.05
            end
        elsif id == Gosu::KbT
            modify do |n|
                n.angle_z = n.angle_z - 0.05
            end
        elsif id == Gosu::KbG
            modify do |n|
                n.angle_z = n.angle_z + 0.05
            end
        end
    end

    def handle_key_up id, mouse_x, mouse_y
        # nothing to do here
    end

    def handle_mouse_down mouse_x, mouse_y
        @mouse_dragging = true
    end

    def handle_mouse_up mouse_x, mouse_y
        @mouse_dragging = false
    end
end

CubeRender.new.show
