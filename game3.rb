#!/usr/bin/env ruby
require 'chingu'
include Gosu
include Chingu
 
class Game < Chingu::GameState
  STAR_NUM = 10
  ENEMY_NUM = 8
  DEBUG = true

  def initialize
    super
    @background_image = Image["space.png"]
    @sound_beep = Sound["beep.wav"]    
    @sound_explosion = Sound["explosion.ogg"]
    @sound_laser = Sound["laser.wav"]

    @player = Player.create(:image => Image["starfighter.bmp"])
    @player.input = { [:mouse_left, :space] => :fire }

    @score = 0
    @score_text = Text.create("Score: #{@score}", :x => 10, :y => 10, :size=>20)
    
    self.input = { :esc => :exit_confirm } 
 end

  def exit_confirm
  	push_game_state(ExitWindow)
  end
  
  def update
    super
    if rand(100) < 4 && Star.all.size < STAR_NUM;   	Star.create(:x =>rand*$window.width, :y =>rand*$window.height); end
    if rand(100) < 2 && Enemy.all.size < ENEMY_NUM;   Enemy.create(:player => @player); end
    
    Star.each_collision(@player, PlayerBullet, Enemy, EnemyBullet) { |o1, o2|
    													@score += 50 if o2.is_a?(Player); o1.destroy; @sound_beep.play }
    @player.each_collision(Enemy) 			{ |p, e| @score -= 100; e.destroy; @sound_explosion.play }   
    @player.each_collision(EnemyBullet) { |p, b| @score -= 10;  b.destroy; p.flash; @sound_laser.play }
    PlayerBullet.each_collision(Enemy) 	{ |p, e| @score += 100; p.destroy; e.destroy; @sound_explosion.play }
    EnemyBullet.each_collision(Enemy) 	{ |p, e| p.destroy }
    
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
  	PlayerBullet.create(:x => @x, :y => @y-@image.height/2, :velocity_y => -10, :scale =>1.5)
  end 

  def setup
  	@c_ori = @color
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
    @velocity_y = options[:velocity_y] || -10
    @color = options[:color] ? options[:color] : Gosu::Color.argb(0xff_ffffff)
  end

end

class PlayerBullet < Bullet
  def update
    self.destroy if outside_window?
    super
  end
end


class EnemyBullet < Bullet
	def setup
    @player = options[:player] ? options[:player] : nil
    @auto =  options[:auto] || false
    super
  end

  def update
  	if (@auto) 
	    dx = @player.x - @x
	    dy = @player.y - @y
	    xy = Math::sqrt(dx**2 + dy**2)
	    speed  = 4
	    @velocity_x = speed * dx / xy
	    @velocity_y = speed * dy / xy
	  end
	    @scale = 40
    self.destroy if outside_window?
    super
  end
end


class Enemy < Chingu::GameObject  
  traits :bounding_circle, :collision_detection
  traits :velocity, :timer
  trait :animation, :debug => false, :size => [50,50]
	
	attr_accessor :collision_flag  
  
  def setup
    @image = @animations[:default].first
    @color.red 		= rand(256 - 40) + 40
    @color.green 	= rand(256 - 40) + 40
    @color.blue 	= rand(256 - 40) + 40
    @mode = :additive
    @velocity_x = rand(-2..2)
    @velocity_y = rand(1..2)
    @player = options[:player] || nil
    @collision_flag = false
    @x = rand(@image.width..($window.width-@image.width))
    @y = 0
  end

  def update
    super
    @velocity_x *= -1 if @x < @image.width/2 or @x > $window.width - @image.width/2
    fire     
  end

  def fire
    if rand(100)<1 and @player.y > @y 
      dx = @player.x - @x
      dy = @player.y - @y
      xy = Math::sqrt(dx**2 + dy**2)
      speed  = 4
      velocity_x = speed * dx / xy
      velocity_y = speed * dy / xy
      EnemyBullet.create(:x => @x, :y => @y + height/2, :velocity_x => velocity_x, :velocity_y => velocity_y, :color => @color, :player => @player) 
    end
    if outside_window? then @y = 0; @x = rand*$window.width; end
  end

  def destroy        
  	@image = @animations[:explode].first
    during(1000) { self.alpha -= 1; @collidable = false; @image = @animations[:explode].next }.then { super }
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
  end
  
  def update
      self.alpha -= @fade_rate  if defined?(@fade_rate)
      @image = @animation.next
      after(5000) { self.destroy }
  end
end


class ExitWindow < Chingu::GameState
  def initialize
    super
    Chingu::GameObject.create(:image => "video_games.png", :x  => $window.width/2, :y => $window.height/2, :scale => 0.5)
    Chingu::Text.create("Press 'ESC' to quit the game, 'Enter' to continue", :align => :left, :x  => $window.width/3, :y => $window.height - 100, :size => 20)
    self.input = { :esc => :close_game, [:space, :return] => :un_pause }		
	end
  
  def un_pause
    pop_game_state
  end

  def draw
		super
		previous_game_state.draw
  end

end


class MainWindow < Chingu::Window
  def initialize
    super(800, 600, false)
    push_game_state(Game)
  end
end

MainWindow.new.show
