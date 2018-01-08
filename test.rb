#!/usr/bin/env ruby
require 'chingu'
include Gosu
include Chingu
 

class Player < Chingu::GameObject  
end


class Enemy < Chingu::GameObject  
end


class MainWindow < Chingu::Window

  def setup

    10.times {Player.create}

    game_objects.each { |o| o.destroy}

    puts game_objects.size.to_s
    puts Player.all.size.to_s

  end

end

MainWindow.new.show
