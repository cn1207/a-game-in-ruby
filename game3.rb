#!/usr/bin/env ruby
require 'chingu'
include Gosu
include Chingu
 
class Game < Chingu::GameState
  STAR_NUM = 10
  ENEMY_NUM = 8
  DEBUG = true

 	def setup
    @background_image = Image["space.png"]
    @sound_beep = Sound["beep.wav"]    
    @sound_explosion = Sound["explosion.ogg"]
    @sound_laser = Sound["laser.wav"]

	  @player = Player.create(:image => Image["starfighter.bmp"])
    @player.input = { [:mouse_left, :space] => :fire }

    @score = 0
    @score_text = Text.create("Score: #{@score}", :x => 10, :y => 10, :size=>20)
    
    self.input = { :esc => :exit_confirm, :enter => :pause } 
 	end

 	def pause
 		push_game_state(Chingu::GameStates::Pause)
 	end

  def exit_confirm		    
  	push_game_state(ExitWindow)
  end

  def update
    super
    if rand(60) < 2 && Star.all.size < STAR_NUM;   		Star.create(:x =>rand*$window.width, :y =>rand*$window.height); end
    if rand(60) < 1 && Enemy.all.size < ENEMY_NUM-1;   	Enemy.create(:player => @player); end
    if rand(60*5) < 1 && Enemy.all.size < ENEMY_NUM
      Enemy.create(:player => @player, :color => Gosu::Color::RED, :scale => 1.2, :move => :trace)
    end


    Star.each_collision(@player, PlayerBullet, Enemy, EnemyBullet) { |o1, o2|
    													@score += 50 if o2.is_a?(Player); o1.destroy; @sound_beep.play }
    @player.each_collision(Enemy) 			{ |p, e| @score -= 100; e.valish; @sound_explosion.play }   
    @player.each_collision(EnemyBullet) { |p, b| @score -= 10;  b.destroy; p.flash; @sound_laser.play }
    PlayerBullet.each_collision(Enemy) 	{ |b, e| @score += 100; b.destroy; e.valish; @sound_explosion.play }
    EnemyBullet.each_collision(Enemy) 	{ |b, e| b.destroy }
    
    Enemy.all.each {|e| e.collision_flag = false }
    Enemy.each_collision(Enemy) do |e1, e2|
    	next if e1.collision_flag
    	e1.velocity_x, e2.velocity_x = e2.velocity_x, e1.velocity_x
    	t = e1.x > e2.x ? 1 : -1
   		e1.x += t; e2.x -= t
    	e2.collision_flag = true
    end
   
    debug_info = DEBUG ? "/FPS: #{$window.fps}/objs:" + @game_objects.size.to_s  : ""
    @score_text.text = "Score: #{@score}#{debug_info}"
    if @score < 0 
      push_game_state(GameOver)
    end
  end

  def draw
    super
    draw_rotating_star_backgrounds
  end

	def draw_rotating_star_backgrounds
    angle = Gosu.milliseconds / 1000.0
    scale = (Gosu.milliseconds % 10000) / 10000.0 
    [1, 0].each {|extra_scale| @background_image.draw_rot( 800/2, 600/2, 0, 
                                            angle, 0.5, 0.5, scale + extra_scale, scale + extra_scale)}
  end
end

class Player < Chingu::GameObject  
  traits :bounding_circle, :collision_detection, :timer

  def fire
  	PlayerBullet.create(:x => @x, :y => @y, :velocity_y => -12, :scale =>1.5, :color => Gosu::Color::RED)
  end 

  def setup
  	@c_ori = @color
    #@y = $window.height - @image.height
  end

  def update
    @x = $window.mouse_x
    @y = $window.mouse_y
  end  

  def flash
  	during(100) {@color = Gosu::Color::RED}.then {@color = @c_ori}
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

class PlayerBullet < Bullet
end


class EnemyBullet < Bullet
end


class Enemy < Chingu::GameObject  
  traits :bounding_circle, :collision_detection
  traits :velocity, :timer
  trait :animation, :debug => false, :size => [50,50]
	
	attr_accessor :collision_flag  
  
  def setup
    @image = @animations[:default].first
    if !options[:color]
	    @color.red 		= rand(256 - 20) + 20
	    @color.green 	= rand(256 - 20) + 20
	    @color.blue 	= rand(256 - 20) + 20
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
    if @move == :trace and @collidable
      @velocity_x, @velocity_y = cal_vx_vy(5)
    elsif  @x < @image.width/2 or @x > $window.width - @image.width/2      
      @velocity_x *= -1 
    end
    if outside_window?
      @y = 0; @x = rand*$window.width; 
    end
    fire if @collidable    
  end

  def cal_vx_vy(speed)
    dx = @player.x - @x
    dy = @player.y - @y
    xy = Math::sqrt(dx**2 + dy**2)
    return speed*dx/xy, speed*dy/xy
  end
    
  def fire
    if rand(100)<1 and @player.y > @y 
      vx, vy = cal_vx_vy(10)
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
    @color.red 		= rand(256 - 40) + 40
    @color.green 	= rand(256 - 40) + 40
    @color.blue 	= rand(256 - 40) + 40
    after(5000) { self.destroy }

  end
  
  def update
      @color.alpha -= @fade_rate
      @image = @animation.next
  end
end


class ExitWindow < Chingu::GameState
  def initialize
    super
    Chingu::GameObject.create(:image => "video_games.png", :x  => $window.width/2, :y => $window.height/2, :scale => 0.5)
    Chingu::Text.create("'ESC' to continue\n'q' to quit", :align => :left, :x  => $window.width/3, :y => $window.height - 100, :size => 20)
    self.input = { :esc => :un_pause, :q => :exit}    
  end
  
  def un_pause    
    pop_game_state(:setup => false)
  end

  def draw
    previous_game_state.draw
    super
  end
end

class GameOver < Chingu::GameState
  def initialize
    super
    Chingu::GameObject.create(:image => "ruby.png", :x  => $window.width/2, :y => $window.height/2, :scale => 0.25)
    Chingu::Text.create("'q' to quit\n'n' to star a new game", :align => :left, :x  => $window.width/3, :y => $window.height - 100, :size => 20)
    self.input = { :q => :exit, :n => :new_game }    
  end
  
  def draw
    previous_game_state.draw
    super
  end

  def new_game
    previous_game_state.input_clients.clear
    previous_game_state.game_objects.each {|o| o.destroy}
    pop_game_state(:setup => true)
  end
end


class MainWindow < Chingu::Window
  def initialize
    super(800, 600, false)
    push_game_state(Game)
  end
end

MainWindow.new.show
