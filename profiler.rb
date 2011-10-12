require './interpreter.rb'
require './compiler'
require './assembler.rb'
require './disassembler.rb'
require 'ostruct'
require 'rubygems'
require 'parallel'
$: << File.expand_path(File.dirname(__FILE__) )
require 'configer/configer.rb'
require 'pp'
require 'json'
require 'time'

class MyConfig < Configer::Template

  config_path "profiler.conf" #where to store the config file
  auto_write #every change to the config struktur will be written back to the config file immediately (disable with "auto_write false")
  value :name=>"profiler" do
    value :name=>"max_program_length", :type => Integer, :default => 40, :docu=>"this defines the maximum number of instructions used per bot"
    value :name=>"min_dist", :type => Integer, :default => 100, :docu => "min distance between two bots"
    value :name=>"max_cycles", :type => Integer, :default => 10000, :docu => "max cycles used per game"
    value :name=>"max_rounds", :type => Integer, :default => 10000, :docu => "max rounds played before debugger closes"
    value :name=>"arena_length", :type => Integer, :default => 2400, :docu => "seize of the arena"
    value :name=>"max_player_threads", :type => Integer, :default => 64, :docu => "threads every player can spawn"
    value :name=>"threads", :type => Integer, :default => 10, :docu => "threads used for execution, set to max 2times cpus in your machine"
    end
end

MyConfig.load() #creates default config file if not found

class Bot
  attr_accessor :name,:code
end

#$DEBUG=true


def run(bot_file_names,config)

  bots=[]

  bot_file_names.each_index do |i|
    bot=Bot.new
    bot.name=bot_file_names[i]
    lines=File.open(bot_file_names[i]).lines
    cmds=Compiler.compile(Compiler.preprocess(lines))

    if cmds.length>config.max_program_length
      puts "bot #{bot_file_names[i]} rejected because he is to long"
      next
    end

    bot.code=cmds
    puts "bot #{bot_file_names[i]}"
#puts cmds.map{|c| Disassembler.bin_to_code(c)}.inspect
    bots<<bot
  end

raise "number of rounds not divisible by number of threads -> aborting" if config.max_rounds % config.threads != 0

stepsize=(config.arena_length-80-2*config.min_dist)/config.max_rounds.to_f

puts "stepsize: #{stepsize}"

a=Parallel.in_processes(config.threads) do |index|

    num_rounds=config.max_rounds/config.threads

    wins=Array.new(bots.size){0}
    ties=Array.new(bots.size){0}

    avg=[0,0]

    (num_rounds).times do |round|
      interpreter=Interpreter.new(config)
      players=[]
      bots.each_index do |i|
        p=Player.new
        if i==0
          start=0
        else
          start = (num_rounds*index*stepsize) + stepsize*round + 40+config.min_dist + rand(stepsize)
          start = start.to_i

          avg[0]+=start
          avg[1]+=config.arena_length-start

          puts [index,0,start].inspect
        end

        p.split(start)
        bots[i].code.each_index do |j|
          interpreter.setCellNum(start+j,bots[i].code[j].to_i(2),p)
        end
        players<<p
      end
      interpreter.run(config.max_cycles,*players)

      if players.count{|p| p.threads.length>0} == 1
        #one of them is a winner
        players.each_index do |i|
          wins[i] +=1 if players[i].threads.length>0
        end
      else
        #game endet in a draw
        players.each_index do |i|
          ties[i] +=1 if players[i].threads.length>0
        end
      end
    end

    puts "avg_dist: #{avg.map{|x| x/config.max_rounds}.inspect}"

    [wins,ties]

  end.inject() do |result, element|
    ws,ts=result
    we,te=element
    ws.each_index do |i|
      ws[i]+=we[i]
      ts[i]+=te[i]
    end
    [ws,ts]
  end

end

bot_names=[]
ARGV.each_index do |i|
  if ARGV[i]=="-d"
    $DEBUG=true
    next
  end
  if ARGV[i]=="-p"
    $PROFILE=true
    next
  end
  bot_names<<ARGV[i]
end

puts run(bot_names,MyConfig.profiler).inspect

if $PROFILE
  require 'rubygems'
  require 'ruby-prof'
  RubyProf.start
end

if $PROFILE
  result = RubyProf.stop
  printer = RubyProf::GraphPrinter.new(result)
  printer = RubyProf::FlatPrinter.new(result)
  printer.print(STDOUT, 0)
end
