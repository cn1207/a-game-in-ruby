#!/usr/bin/env ruby
require 'gosu'
require 'chingu'
 
MOVE_SPEED = 5
BULLET_SPEED = 15
DEBUG = false

include Gosu
include Chingu

class Game < Chingu::GameState
  STAR_NUM  = 10
  ENEMY_NUM = 10
  
  def setup
    @background_image = Image["space.png"]
    @sound_beep = Sound["beep.wav"]    
    @sound_explosion = Sound["explosion.ogg"]
    @sound_laser = Sound["laser.wav"]

    @player = Player.create(image: Image["starfighter.bmp"])
    @player.input = { [:mouse_left, :space] => :fire }

    @score = 0
    @score_text = Text.create("Score: #{@score}", :x => 10, :y => 10, :size=>20)
    
    self.input = { :esc => :exit_confirm } 
  end

  def exit_confirm  
    options = @score > 0 ? {:game_over => false} : {:game_over => true} 
    state = ExitWindow.new(options)
    push_game_state(state)
  end

  def update
    super
    Star.create(x: rand*$window.width, y: rand*$window.height) if rand(60) < 2 && Star.all.size < STAR_NUM   
    Enemy.create(:player => @player) if rand(60) < 2 && Enemy.all.size < ENEMY_NUM - 1
    Enemy.create(:player => @player, :color => Gosu::Color::RED, :scale => 1.2, :move => :trace) if rand(60*5) < 1 && Enemy.all.size < ENEMY_NUM
    
    Star.each_collision(@player, PlayerBullet, Enemy, EnemyBullet) {|o1, o2| @score += 10 if o2.is_a?(Player); o1.destroy; @sound_beep.play } 
    @player.each_collision(Enemy)       { |p, e| @score -= 10; e.valish; @sound_explosion.play }   
    @player.each_collision(EnemyBullet) { |p, b| @score -= 10;  b.destroy; p.flash; @sound_laser.play }
    PlayerBullet.each_collision(Enemy)  { |b, e| @score += 10; b.destroy; e.valish; @sound_explosion.play }
    EnemyBullet.each_collision(Enemy)   { |b, e| b.destroy }
    
    debug_info = "/FPS: #{$window.fps}/objs: #{@game_objects.size.to_s}" if DEBUG
    @score_text.text = "Score: #{@score} #{debug_info}"
	# exit_confirm if @score < 0 
 end

  def draw
    super
    draw_rotating_star_background
  end

  def draw_rotating_star_background
    angle = Gosu.milliseconds / 1000.0
    scale = (Gosu.milliseconds % 10000) / 10000.0 
    [1, 0].each { |extra_scale| @background_image.draw_rot( $window.width/2, $window.height/2, 0, 
                 angle, 0.5, 0.5, scale + extra_scale, scale + extra_scale) }
  end
end

class Player < Chingu::GameObject  
  traits :bounding_circle, :collision_detection, :timer
  attr_reader :movement

  def fire
    PlayerBullet.create(x: @x, y: @y, velocity_y: -BULLET_SPEED, color: Gosu::Color::RED) #if Gosu.milliseconds % 30 == 0
  end 

  def setup
    @c_ori = @color
    @y = $window.height - @image.height
    @x = $window.width / 2
  end

  def update
  	@x = $window.mouse_x
  	@y = $window.mouse_y
    # @movement = 0 # movement, 0 => stay, -1=>left, 1=>right 
    # nearest = $window.width

    # distance = ->(x1, y1, x2, y2){ ((x1 - x2)**2 + (y1 - y2)**2)**0.5 }
    # Enemy.all.each do |o|
    #   next if !o.collidable
    #   d = distance.call(o.x, o.y, @x, @y) 
    #   if  d < nearest 
    #     nearest = d
    #     @movement = o.x <=> @x
    #   end
    # end
    
    # @x += MOVE_SPEED * @movement

    # Enemy.all.each do |o|
    #   fire if o.collidable && (o.x - @x).abs < (o.image.width + @image.width)/2 
    # end
  end  

  def flash
    during(100) {@color = Gosu::Color::RED}.then {@color = @c_ori}
  end

  def move_left
    @x -= MOVE_SPEED
  end

  def move_right
    @x += MOVE_SPEED
  end
end


class Bullet < Chingu::GameObject  
  traits :bounding_circle, :collision_detection
  trait :velocity
  def setup
    @image = Image["bullet.png"]
  end

  def update
    super
    self.destroy if outside_window?    
  end
end

class PlayerBullet < Bullet; end
class EnemyBullet < Bullet; end


class Enemy < Chingu::GameObject  
  traits :bounding_circle, :collision_detection
  traits :velocity, :timer
  trait :animation, :debug => false, :size => [50,50]
  
  def setup
    @image = @animations[:default].first
    if !options[:color]
      @color.red    = rand(256 - 20) + 20
      @color.green  = rand(256 - 20) + 20
      @color.blue   = rand(256 - 20) + 20
    else @color = options[:color]
    end

    @mode = :additive
    @velocity_x = rand(-2..2)
    @velocity_y = rand(1..2)
    @player = options[:player] || nil
    @collision_flag = false
    @x = rand(@image.width..($window.width-@image.width))
    @y = 0
    @move = options[:move] || :default
  end

  def update
    super
    return if !@collidable

    case @move
    when :trace
      @velocity_x, @velocity_y = cal_vx_vy(MOVE_SPEED)
    when :default
      @velocity_x *= -1  if @x < @image.width / 2 || @x > $window.width - @image.width / 2      
    end

    if outside_window?
      @y = 0
      @x = rand*$window.width; 
    end
    
    self.each_collision(Enemy) do |e1, e2|
      e1.velocity_x, e2.velocity_x = e2.velocity_x, e1.velocity_x
      t = e1.x > e2.x ? 1 : -1
      e1.x += t; e2.x -= t
    end

    fire
  end

  def cal_vx_vy(speed)
    dx = @player.x - @x
    dy = @player.y - @y
    xy = Math::sqrt(dx**2 + dy**2)
    return speed*dx/xy, speed*dy/xy
  end
    
  def fire
    if rand(60) < 1 &&  @y < @player.y
      vx, vy = cal_vx_vy(BULLET_SPEED)
      EnemyBullet.create(:x => @x, :y => @y + height/2, :velocity_x => vx, :velocity_y => vy, :color => @color) 
    end
  end

  def valish
    @collidable = false
    @image = @animations[:explode].first
    @velocity_x /= 2
    @velocity_y /= 2
    during(1000) { @image = @animations[:explode].next }.then { destroy }
  end
end



class Star < Chingu::GameObject
  traits :bounding_circle, :collision_detection
  trait :timer

  def setup
    @mode = :additive
    @animation = Chingu::Animation.new(:file => "#{self.filename}.png", :size => 25)
    @image = @animation.first
    @fade_rate = 1
    @color.red    = rand(256 - 40) + 40
    @color.green  = rand(256 - 40) + 40
    @color.blue   = rand(256 - 40) + 40
    after(5000) { self.destroy }
  end
  
  def update
      @color.alpha -= @fade_rate
      @image = @animation.next
  end
end


class ExitWindow < Chingu::GameState

  def initialize(options={game_over: false})
    super

    @game_over = @options[:game_over]
    image = @game_over? "ruby.png" : "video_games.png"

    text = "Q: Quit\n"
    text << "ESC: Continue" if !@game_over
    text << "N: New Game" if @game_over

    Chingu::GameObject.create(:image => image, :x  => $window.width/2, :y => $window.height/2, :scale => 0.25)
    Chingu::Text.create(text, :align => :left, :x  => $window.width/3, :y => $window.height - 100, :size => 20)
    
    input_agent = @game_over? "self.input = { :q => :exit, :n => :new_game }" : "self.input = { :esc => :un_pause, :q => :exit}"
    self.instance_eval(input_agent)
  end

  def un_pause    
    pop_game_state(:setup => false)
  end

  def new_game
    previous_game_state.input_clients.clear
    previous_game_state.game_objects.each {|o| o.destroy}
    pop_game_state(:setup => true)
  end

  def draw
    previous_game_state.draw
    super
  end
end


class MainWindow < Chingu::Window
  def initialize
    super(800, 600, false)
    push_game_state(Game)
  end
end

MainWindow.new.show
