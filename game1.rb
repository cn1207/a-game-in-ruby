require 'gosu'


module ZOrder
  BACKGROUND, STARS, ENEMIES, PLAYER, UI = *0..4
end


class Player
  attr_reader :energy, :score
  def initialize
    @image = Gosu::Image.new("media/starfighter.bmp")
    @beep = Gosu::Sample.new("media/beep.wav")
    @x = @y = @vel_x = @vel_y = 0.0
    @angle = 90.0
    @score = 0
    @energy = 10
    @x0 = @y0 = 0.0
  end

  def warp(x, y)
    @x, @y = x, y
  end
  
  
  def move(mouse_x, mouse_y)
    @x = mouse_x-(mouse_x-@x)/1.5
    @y = mouse_y-(mouse_y-@y)/1.5
    if Gosu.distance(@x, @y, @x0, @y0) > 1
      @to_angle = Math.atan2(@y-@y0, @x-@x0) * 180.0/Math::PI + 90
      @x0, @y0 = @x, @y
      if @angle - @to_angle > 180
        @to_angle += 360
      elsif @to_angle - @angle > 180
        @angle += 360
      end          
    end
    @angle += (@to_angle-@angle) / 5

  end

  def draw
	@image.draw_rot(@x, @y, 1, @angle)
  end
  

  def collect_stars(stars)
    stars.reject! { |star| star.life < 0 }
    stars.reject! do |star|
      if Gosu.distance(@x, @y, star.x, star.y) < 35
        @score += 10
        @beep.play
        true
      else
        false
      end
    end

    stars.each { |star| star.update }

  end

  def calculate_energy(enemies)
    enemies.reject! do |enemy|
      if Gosu.distance(@x, @y, enemy.x, enemy.y) < 35
        @energy -= 1
        @beep.play
        true
      else
        false
      end
    end
  end

end

class Star
  attr_reader :x, :y, :life

  def initialize(animation)
    @animation = animation
    @color = Gosu::Color::BLACK.dup
    @color.red = rand(256 - 40) + 40
    @color.green = rand(256 - 40) + 40
    @color.blue = rand(256 - 40) + 40
    @x = rand * 640
    @y = rand * 480
    @life = 3*30 #diminish in these ms
  end

  def update
    @life -= 1
  end

  def draw  
    img = @animation[Gosu.milliseconds / 100 % @animation.size]
    img.draw(@x - img.width / 2.0, @y - img.height / 2.0,
      ZOrder::STARS, 1, 1, @color, :add)
  end
end

class Enemy
  attr_reader :x, :y 
  def initialize(animation)
    @animation = animation
    @color = Gosu::Color::BLACK.dup
    @color.red = rand(256 - 40) + 40
    @color.green = rand(256 - 40) + 40
    @color.blue = rand(256 - 40) + 40
    @x = rand * 640
    @y = rand * 480
  end

  def move
    @x = rand * 640 if @y>480 
    @y = (@y+1)%480
  end

  def draw  
  img = @animation[0]#Gosu.milliseconds / 100 % @animation.size]
    img.draw(@x - img.width / 2.0, @y - img.height / 2.0,
      ZOrder::ENEMIES, 1, 1, @color, :add)
  end
end


class Tutorial < Gosu::Window
  def initialize
    super 640, 480
    self.caption = "Tutorial Game"

    @background_image = Gosu::Image.new("media/space.png", :tileable => true)

    @player = Player.new
    @player.warp(320, 240)

    @star_anim = Gosu::Image.load_tiles("media/star.png", 25, 25)
    @stars = Array.new

    @enemy_anim = Gosu::Image.load_tiles("media/enemy.png", 50, 50)
    @enemies = Array.new


    @font = Gosu::Font.new(20)
  end

  def update
    @player.move(mouse_x, mouse_y)

    @player.collect_stars(@stars)
    if rand(100) < 4 and @stars.size < 25
      @stars.push(Star.new(@star_anim))
    end

    @player.calculate_energy(@enemies)
    if rand(100) < 4 and @enemies.size < 5
      @enemies.push(Enemy.new(@enemy_anim))
    end


  end

  def draw
    @player.draw
    #@background_image.draw_rot 640 * 0.5, 480 * 0.75, 0, 0, 0.5, 0.5, 1, 1
    @stars.each { |star| star.draw }
    @enemies.each do |enemy| 
      enemy.move 
      enemy.draw 
    end

    @font.draw("Score: #{@player.score} #{@player.energy}", 10, 10, ZOrder::UI, 1.0, 1.0, Gosu::Color::YELLOW)

	draw_rotating_star_backgrounds()
  end

  def draw_rotating_star_backgrounds
    # Disregard the math in this method, it doesn't look as good as I thought it
    # would. =(
    
    angle = Gosu.milliseconds / 100.0
    scale = (Gosu.milliseconds % 10000) / 10000.0
    
  	[1, 0].each do |extra_scale|
      @background_image.draw_rot( 640 * 0.5, 480 * 0.5, 0, angle, 0.5, 0.5, scale + extra_scale, scale + extra_scale)
  	end    

  end

  def button_down(id)
    if id == Gosu::KB_ESCAPE
      close
    else
      super
    end
  end
end


w = Tutorial.new()
w.show

