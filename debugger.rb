require './optics'
require './compiler'
require './assembler.rb'
require 'set'
require 'ostruct'
$: << File.expand_path(File.dirname(__FILE__) )
require 'configer/configer.rb'
require 'pp'
require 'json'
require 'time'

class MyConfig < Configer::Template

  config_path "debugger.conf" #where to store the config file
  auto_write #every change to the config struktur will be written back to the config file immediately (disable with "auto_write false")
  value :name=>"debugger" do
    value :name=>"max_program_length", :type => Integer, :default => 40, :docu=>"this defines the maximum number of instructions used per bot"
    value :name=>"min_dist", :type => Integer, :default => 100, :docu => "min distance between two bots"
    value :name=>"max_cycles", :type => Integer, :default => 10000, :docu => "max cycles used per game"
    value :name=>"max_rounds", :type => Integer, :default => 10000, :docu => "max rounds played before debugger closes"
    value :name=>"arena_length", :type => Integer, :default => 2400, :docu => "seize of the arena"
    value :name=>"max_player_threads", :type => Integer, :default => 64, :docu => "threads every player can spawn"
    value :name=>"threads", :type => Integer, :default => 2, :docu => "threads used for execution, set to max 2times cpus in your machine"
    end
end

MyConfig.load() #creates default config file if not found

class Bot
  attr_accessor :name,:code,:wins,:ties

  def initialize
    @wins=0
    @ties=0
  end

end

#$DEBUG=true

wins=[0,0]
ties=0
bots=[]

ARGV.each_index do |i|
  if ARGV[i]=="-d"
    $DEBUG=true
    next
  end
  if ARGV[i]=="-p"
    $PROFILE=true
    next
  end
  bot=Bot.new
  bot.name=ARGV[i]
  lines=File.open(ARGV[i]).lines
  cmds=Compiler.compile(Compiler.preprocess(lines))
  if cmds.length>MyConfig.debugger.max_program_length
    puts "bot #{ARGV[i]} rejected because he is to long"
    next
  end
  bot.code=cmds
  bots<<bot
end

if bots.length !=2
  puts "you need exactly two bots for the debugger. use bots/lame if you just want to watch your bot running"
  exit 1
end

if $PROFILE
  require 'rubygems'
  require 'ruby-prof'
  RubyProf.start
end


    (MyConfig.debugger.max_rounds).times do |round|

      GC.start
      interpreter=Gui.new(MyConfig.debugger,bots)
      interpreter.blacklist=Set.new()

      players=[]
      bots.each_index do |bot_index|
        b=bots[bot_index]
        p=Player.new
        p.playerID=players.length
        p.name=b.name
        if bot_index==0
          start=0
        else
          start=bots[0].code.length+MyConfig.debugger.min_dist+rand(MyConfig.debugger.arena_length-bots[0].code.length - bots[1].code.length-2*MyConfig.debugger.min_dist)
        end

        p.split(start)
        b.code.each_index do |i|
          interpreter.setCellNum(start+i,b.code[i].to_i(2),p)
        end
        players<<p
      end

      interpreter.run(MyConfig.debugger.max_cycles,*players)

      if players.count{|p| p.threads.length>0} == 1
        #one of them is a winner
        players.each_index do |i|
          bots[i].wins+=1 if players[i].threads.length>0
        end
      else
        #game endet in a draw
        players.each_index do |i|
          bots[i].ties+=1 if players[i].threads.length>0
        end
      end
      break if interpreter.quit
    end

if $PROFILE
  result = RubyProf.stop
  printer = RubyProf::GraphPrinter.new(result)
#printer = RubyProf::FlatPrinter.new(result)
  printer.print(STDERR, 0)
end

