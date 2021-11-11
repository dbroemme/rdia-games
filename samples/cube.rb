require 'gosu'
require 'wads'
#require 'rdia-games'
require_relative '../lib/rdia-games'

include Wads
include RdiaGames

WORLD_X_START = -1000
WORLD_X_END = 1000
WORLD_Z_START = -500
WORLD_Z_END = 9000

GAME_WIDTH = 1280
GAME_HEIGHT = 720

MODE_ISOMETRIC = "iso"
MODE_REAL_THREE_D = "real3d"



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
        register_hold_down_key(Gosu::KbUp)
        register_hold_down_key(Gosu::KbDown)
        register_hold_down_key(Gosu::KbM)
        register_hold_down_key(Gosu::KbPeriod)

    end 
end

class CubeRenderDisplay < Widget
    include Gosu

    def initialize
        super(0, 0, GAME_WIDTH, GAME_HEIGHT)
        disable_border

        @image_external_wall = Gosu::Image.new("./media/tile5.png")
        @image_tile_18 = Gosu::Image.new("./media/tile18.png")

        # Draw offsets so the zero centered world is centered visually on the screen
        # This allows the initial center of the world to be 0, 0
        @offset_x = 600
        @offset_y = 300

        $stats = Stats.new("Perf")
        $cos_cache = {}
        $sin_cache = {}

        $center_x = 0
        $center_y = 0
        $center_z = -300   # orig -300
        $camera_x = 0
        $camera_y = 150
        $camera_z = 800   # orig 800

        @dir_x = 1     # initial direction vector
        @dir_y = 0   
        determine_directional_quadrant

        @pause = false
        @speed = 10
        @mode = MODE_ISOMETRIC
        @continuous_movement = true


        # Our objects
        @cube = Cube.new(-300, 300, 100, COLOR_LIME)
        @all_objects = [@cube]
        @other_objects = []

        @grid = GridDisplay.new(0, 0, 100, 21, 95, {ARG_X_OFFSET => 10, ARG_Y_OFFSET => 5})
        instantiate_elements(@grid, @all_objects, File.readlines("./data/editor_board.txt")) 
        puts "World Map"
        puts "---------"
        (0..94).each do |y|
            str = ""
            (0..20).each do |x|
                str = "#{str}#{@world_map[x][y]}"
            end 
            puts str
        end

        puts "Raycast Map"
        puts "-----------"
        (0..20).each do |y|
            str = ""
            (0..94).each do |x|
                str = "#{str}#{@raycast_map[x][y]}"
            end 
            puts str
        end

        @raycaster = RayCaster.new(@raycast_map, GAME_WIDTH, GAME_HEIGHT)

        # Near and far walls
        x = -1000
        while x < 550
            far_wall = Wall.new(x, 8900, 500, 100, @image_external_wall, true)
            far_wall.set_visible_side(QUAD_S)
            @all_objects << far_wall
            wall_behind_us = Wall.new(x, -500, 500, 100, @image_external_wall, true)
            wall_behind_us.set_visible_side(QUAD_N)
            @all_objects << wall_behind_us
            x = x + 500
        end

        # Side walls
        z = -500
        while z < 8910
            left_wall = Wall.new(-1000, z, 100, 500, "./media/tile5.png", true)
            left_wall.set_visible_side(QUAD_W)
            @all_objects << left_wall
            right_wall = Wall.new(1000, z, 100, 500, "./media/tile5.png", true)
            right_wall.set_visible_side(QUAD_E)
            @all_objects << right_wall
            z = z + 500
        end

        x = -1000
        while x < 950
            z = -500
            while z < 8890
                @all_objects << FloorTile.new(x, z, 200)
                z = z + 200
            end 
            x = x + 200
        end

        @text_1 = Text.new(10, 10, "")
        add_child(@text_1)
        @text_2 = Text.new(10, 40, camera_text)
        add_child(@text_2)
        @text_3 = Text.new(10, 70, angle_text)
        add_child(@text_3)
        @text_4 = Text.new(10, 100, dir_text)
        add_child(@text_4)
        @text_5 = Text.new(10, 130, objects_text)
        add_child(@text_5)
        @text_6 = Text.new(10, 160, center_text)
        add_child(@text_6)
        @text_7 = Text.new(10, 190, cube_text)
        add_child(@text_7)
    end 

    def add_to_maps(x, y, val)
        #puts "Array #{x},#{y} -> #{val}"
        @world_map[x][y] = val
        @raycast_map[y][x] = val
    end 

    def instantiate_elements(grid, all_objects, dsl)
        @world_map = Array.new(grid.grid_width) do |x|
            Array.new(grid.grid_height) do |y|
                0
            end 
        end 
        @raycast_map = Array.new(grid.grid_height) do |y|
            Array.new(grid.grid_width) do |x|
                0
            end 
        end 
        grid.clear_tiles
        grid_y = 89
        grid_x = -10
        dsl.each do |line|
            index = 0
            while index < line.size
                char = line[index..index+1].strip
                img = nil
                # set_tile is already using the grid offsets, but here
                # we are directly creating a world map array so we need
                # to use the same offsets
                # So the Grid should probably do this, not here, but oh well
                array_grid_x = grid_x + grid.grid_x_offset
                array_grid_y = grid_y + grid.grid_y_offset
                #if char == "B"
                #    img = Brick.new(@blue_brick)
                if char == "5"
                    # ignore 5 because we manually constructed the wall using bigger chunks
                    add_to_maps(array_grid_x, array_grid_y, 5)
                    #img = Wall.new(grid_x * 100, grid_y * 100)
                elsif char == "18"
                    add_to_maps(array_grid_x, array_grid_y, 18)
                    img = Wall.new(grid_x * 100, grid_y * 100, 100, 100, @image_tile_18)
                end
                
                if not img.nil?
                    puts "Set tile #{grid_x},#{grid_y}  =  #{char}"
                    grid.set_tile(grid_x, grid_y, img)
                    all_objects << img
                end

                grid_x = grid_x + 1
                index = index + 2
            end
            grid_x = -10
            grid_y = grid_y - 1
        end
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

        # Show the origin (pivot) point as a cube
        #@center_cube = Cube.new($center_x, $center_z, 25, COLOR_LIGHT_BLUE)
        #@center_cube.angle_y = @all_objects[0].angle_y
        #@center_cube.calc_points

        # Darren Show the directional vector as a cube
        # initial direction vector    @dir_x = -1   @dir_y = 0   
        dir_scale = 100
        extended_dir_x = @dir_x * dir_scale  
        extended_dir_y = @dir_y * dir_scale  
        @dir_cube = Cube.new($center_x + extended_dir_y, $center_z + extended_dir_x, 25, COLOR_PEACH)
        @dir_cube.angle_y = @all_objects[0].angle_y
        @dir_cube.calc_points
    end 

    def render
        Gosu.translate(@offset_x, @offset_y) do
            #@center_cube.render
            #@dir_cube.render

            modify do |n|
                if n.is_behind_us 
                    # do not draw 
                    #puts "Not drawing #{n.class.name}"
                else
                    n.render
                end
            end

            # Other objects are essentially debug objects
            # we draw on top of everything else
            @other_objects.each do |oo|
                oo.render(20)
            end
        end 
    end

    def handle_update update_count, mouse_x, mouse_y
        return if @pause
        modify do |n|
            n.reset_visible_side
        end
        raycast_for_visibility

        calc_points
        @other_objects.each do |other_obj| 
            other_obj.calc_points 
        end

        @text_1.label = "Mouse: #{mouse_x}, #{mouse_y}"
        @text_2.label = camera_text
        @text_3.label = angle_text
        @text_4.label = dir_text
        number_of_invisible_objects = 0
        @all_objects.each do |obj| 
            if not obj.visible
                number_of_invisible_objects = number_of_invisible_objects + 1
            end 
        end
        @text_5.label = "#{objects_text}/#{number_of_invisible_objects}"
        @text_6.label = center_text
        @text_7.label = cube_text
    end

    def camera_text 
        "Camera: #{$camera_x.round(2)}, #{$camera_y.round(2)}, #{$camera_z.round(2)}" 
    end 
    def center_text 
        "Center: #{$center_x.round}, #{$center_y.round}, #{$center_z.round}" 
    end 
    def location_text 
        "Location: #{@cube.model_points[0].x.round}, #{@cube.model_points[0].y.round}, #{@cube.model_points[0].z.round}"
    end 
    def angle_text 
        "Angle: #{@cube.angle_x.round(2)}, #{@cube.angle_y.round(2)}, #{@cube.angle_z.round(2)}"
    end 
    def dir_text 
        "Direction: #{@dir_y.round(2)}, #{@dir_x.round(2)}    quad: #{@dir_quad}   grid: #{@grid.determine_grid_x($center_x)}, #{@grid.determine_grid_y($center_z)}"
    end 
    def objects_text 
        "Objects: #{@all_objects.size} "
    end
    def cube_text 
        #if @dir_cube
        #    return "Dir Cube: #{@dir_cube.model_points[0].x.round(2)}, #{@dir_cube.model_points[0].y.round(2)}, #{@dir_cube.model_points[0].z.round(2)}"
        #end
        "" 
    end

    def tile_at_proposed_grid(proposed_x, proposed_y) 
        tile_x = @grid.determine_grid_x(proposed_x) + @grid.grid_x_offset
        tile_y = @grid.determine_grid_y(proposed_y) + @grid.grid_y_offset
        #puts "tile_x/y:  #{tile_x}, #{tile_y}"
        @world_map[tile_x][tile_y]
    end 

    def determine_directional_quadrant
        if @all_objects.nil?
            @dir_quad = QUAD_N
            return
        end 
        if @all_objects.empty? 
            @dir_quad = QUAD_N 
            return
        end
        angle_y = @all_objects[0].angle_y
        angle_y = angle_y % DEG_360 
        if angle_y < DEG_22_5
            @dir_quad = QUAD_N
        elsif angle_y < DEG_67_5 
            @dir_quad = QUAD_NE
        elsif angle_y < DEG_112_5 
            @dir_quad = QUAD_E
        elsif angle_y < DEG_157_5 
            @dir_quad = QUAD_SE
        elsif angle_y < DEG_202_5 
            @dir_quad = QUAD_S
        elsif angle_y < DEG_247_5 
            @dir_quad = QUAD_SW
        elsif angle_y < DEG_292_5
            @dir_quad = QUAD_W 
        elsif angle_y < DEG_337_5 
            @dir_quad = QUAD_NW 
        else 
            @dir_quad = QUAD_N
        end
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
            @speed = @speed + 5
        elsif id == Gosu::KbDown
            @speed = @speed - 5
            if @speed < 5
                @speed = 5
            end
        elsif id == Gosu::KbC
            puts "------------"
            
            #cx = $camera_x
            #cz = -$camera_z
            cx = $center_x
            cz = $center_z

            size_square = 1000
            dx, dz = perpendicular_direction_counter_clockwise(@dir_y, @dir_x)
            #side_left = Point3D.new(cx + (dx * size_square), 0, cz + (dz * size_square))
            side_left = Point2D.new(cx + (dx * size_square), cz + (dz * size_square))

            dx, dz = perpendicular_direction_clockwise(@dir_y, @dir_x)
            #side_right = Point3D.new(cx + (dx * size_square), 0, cz + (dz * size_square))
            side_right = Point2D.new(cx + (dx * size_square), cz + (dz * size_square))

            # TODO run this out to the edges of the world
            #      how to do best do that?
            #      line intersection seems non-trivial
            #forward_left = Point3D.new(side_left.x + (@dir_y * size_square), 0, side_left.z + (@dir_x * size_square))
            #forward_right = Point3D.new(side_right.x + (@dir_y * size_square), 0, side_right.z + (@dir_x * size_square))
            forward_left = Point2D.new(side_left.x + (@dir_y * size_square), side_left.y + (@dir_x * size_square))
            forward_right = Point2D.new(side_right.x + (@dir_y * size_square), side_right.y + (@dir_x * size_square))
            
            puts "Find intersecting lines with worlds edge"
            bottom_line = Line2D.new(side_left, side_right)
            world_left_edge = Line2D.new(Point2D.new(WORLD_X_START, WORLD_Z_START), side_right)



            vb = [side_left, forward_left, forward_right, side_right]

            puts "The visibility polygon is #{vb}"

            pip = PointInsidePolygon.new
            @all_objects.each do |an_obj|
                if an_obj.is_external or an_obj.is_a? FloorTile 
                    # skip 
                else 
                    point = Point2D.new(an_obj.model_points[0].x, an_obj.model_points[0].z)
                    
                    if pip.isInside(vb, 4, point)
                        # do nothing
                        puts "Inside #{an_obj}"
                        an_obj.color = COLOR_AQUA
                    else
                        puts "Setting #{an_obj} to invisible"
                        an_obj.color = COLOR_LIME
                        #@all_objects.delete(an_obj)
                    end
                end 
            end 

            @other_objects = []
            @other_objects << Line3D.new(Point3D.new(vb[0].x, 0, vb[0].y), Point3D.new(vb[1].x, 0, vb[1].y), COLOR_RED)
            @other_objects << Line3D.new(Point3D.new(vb[1].x, 0, vb[1].y), Point3D.new(vb[2].x, 0, vb[2].y), COLOR_RED)
            @other_objects << Line3D.new(Point3D.new(vb[2].x, 0, vb[2].y), Point3D.new(vb[3].x, 0, vb[3].y), COLOR_RED)
            @other_objects << Line3D.new(Point3D.new(vb[3].x, 0, vb[3].y), Point3D.new(vb[0].x, 0, vb[0].y), COLOR_RED)
        
        
        
        
        
        
        elsif id == Gosu::KbR
            modify do |n|
                if n.is_external 
                    # do nothing
                elsif n.is_a? Cube 
                    # do nothing
                elsif n.is_a? FloorTile 
                    # do nothing
                else
                    n.set_visible_side(QUAD_ALL)
                    n.color = COLOR_AQUA 
                end
            end
        elsif id == Gosu::KbV 
            @pause = !@pause
        end
    end

    def visibility_polygon
        # TODO put the code back here
    end 

    def perpendicular_direction_clockwise(x, y)
        [y, -x]
    end

    def perpendicular_direction_counter_clockwise(x, y)
        [-y, x]
    end

    def display_quad(qfs)
        if qfs == QUAD_NW
            return "QUAD_NW"
        elsif qfs == QUAD_N
            return "QUAD_N"
        elsif qfs == QUAD_NE
            return "QUAD_NE"
        elsif qfs == QUAD_SW
            return "QUAD_SW"
        elsif qfs == QUAD_S
            return "QUAD_S"
        elsif qfs == QUAD_SE
            return "QUAD_SE"
        elsif qfs == QUAD_E
            return "QUAD_E"
        elsif qfs == QUAD_W
            return "QUAD_W"
        end
    end 

    def raycast_for_visibility
        (0..1279).each do |x|
            ray_data = raycast(x) 
            if ray_data.at_ray != 0
                # Get the tile at this spot
                tile = @grid.get_tile(ray_data.map_y, ray_data.map_x)
                if tile
                    quad = ray_data.quad_from_slope
                    tile.set_visible_side(quad)
                end
            end
        end
    end

    def raycast(x, plane_x = 0, plane_y = 0.66) 
        #tile_x = @grid.determine_grid_x($camera_x)   # If you really see what is visible, use the camera
        #tile_y = @grid.determine_grid_y($camera_z)
        tile_x = @grid.determine_grid_x($center_x)
        tile_y = @grid.determine_grid_y($center_z)
        adj_tile_x = tile_x + @grid.grid_x_offset
        adj_tile_y = tile_y + @grid.grid_y_offset
        drawStart, drawEnd, mapX, mapY, side, orig_map_x, orig_map_y = @raycaster.ray(x, adj_tile_y, adj_tile_x, @dir_x, @dir_y, plane_x, plane_y)
        adj_map_x = mapX - @grid.grid_y_offset   # The raycast map is set the other way
        adj_map_y = mapY - @grid.grid_x_offset
        adj_orig_map_x = orig_map_x - @grid.grid_y_offset
        adj_orig_map_y = orig_map_y - @grid.grid_x_offset

        at_ray = @raycast_map[mapX][mapY]
        if at_ray == 5
            color_to_use = COLOR_AQUA
            if side == 1
                color_to_use = COLOR_BLUE
            end
        elsif at_ray == 18
            color_to_use = COLOR_LIME
            if side == 1
                color_to_use = COLOR_PEACH
            end
        end
        
        RayCastData.new(x, tile_x, tile_y, adj_map_x, adj_map_y, at_ray, side, drawStart, drawEnd, color_to_use, adj_orig_map_x, adj_orig_map_y)
    end

    def handle_movement id, mouse_x, mouse_y 
        if id == Gosu::KbQ
            # Lateral movement
            $camera_x = $camera_x + @speed
            $center_x = $center_x - @speed
        elsif id == Gosu::KbE
            # Lateral movement
            $camera_x = $camera_x - @speed
            $center_x = $center_x + @speed
        elsif id == Gosu::KbW
            # Primary movement keys (WASD)
            movement_x = @dir_y * @speed
            movement_z = @dir_x * @speed

            proposed_x = $center_x + movement_x
            proposed_z = $center_z + movement_z
            proposed = tile_at_proposed_grid(proposed_x, proposed_z)
            if proposed == 0 
                $camera_x = $camera_x - movement_x
                $center_x = proposed_x

                $camera_z = $camera_z - movement_z
                $center_z = proposed_z
            end

        elsif id == Gosu::KbS
            movement_x = @dir_y * @speed
            movement_z = @dir_x * @speed

            proposed_x = $center_x - movement_x
            proposed_z = $center_z - movement_z
            proposed = tile_at_proposed_grid(proposed_x, proposed_z)
            if proposed == 0 
                $camera_x = $camera_x + movement_x
                $center_x = proposed_x

                $camera_z = $camera_z + movement_z
                $center_z = proposed_z
            end

        elsif id == Gosu::KbD
            modify do |n|
                n.angle_y = n.angle_y + 0.05
            end
            angle_y = @cube.angle_y  # just grab the value from one of the objects
            # Now calculate the new dir_x, dir_y
            @dir_x = Math.cos(angle_y)
            @dir_y = Math.sin(angle_y)
            determine_directional_quadrant
            #puts "Math.cos/sin(#{angle_y}) = #{@dir_y}, #{@dir_x}"
        elsif id == Gosu::KbA
            modify do |n|
                n.angle_y = n.angle_y - 0.05
            end
            angle_y = @cube.angle_y  # just grab the value from one of the objects
            # Now calculate the new dir_x, dir_y
            @dir_x = Math.cos(angle_y)
            @dir_y = Math.sin(angle_y)
            determine_directional_quadrant
        end
    end

    def handle_key_up id, mouse_x, mouse_y
        # nothing to do
    end

    def handle_mouse_down mouse_x, mouse_y
        @mouse_dragging = true
    end

    def handle_mouse_up mouse_x, mouse_y
        @mouse_dragging = false
    end
end

CubeRender.new.show
