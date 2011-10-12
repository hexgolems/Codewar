require './interpreter.rb'
require './compiler'
require './assembler.rb'
require './disassembler.rb'
require 'ostruct'
require 'rubygems'
require 'parallel'

$config=OpenStruct.new
$config.max_program_length=40
$config.max_cycles=2_000
$config.max_rounds=10
$config.arena_length=500
$config.threads=2

class Bot
	attr_accessor :name,:code
end

#$DEBUG=true


allbots=[]

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
	if cmds.length>$config.max_program_length
		puts "bot #{ARGV[i]} rejected because he is to long"
		next
	end
	bot.code=cmds
	puts cmds.map{|c| Disassembler.bin_to_code(c)}.inspect
	allbots<<bot
end

if $PROFILE
	require 'rubygems'
  require 'ruby-prof'
  RubyProf.start
end


class Array
	def perm(n = size)
		if size < n or n < 0
		elsif n == 0
			yield([]) 
		else  
			self[1..-1].perm(n - 1) do |x|
				(0...n).each do |i|
					yield(x[0...i] + [first] + x[i..-1])
				end   
			end
			self[1..-1].perm(n) do |x|
				yield(x)
			end
		end 
	end
end
permbots = []

allbots.perm(2) do |x|
	permbots << x
	end

permbots.each do |x|

bots = x
a=Parallel.in_processes($config.threads) do
		wins=Array.new(bots.size){0}
		ties=Array.new(bots.size){0}
		($config.max_rounds/$config.threads).times do |round|
			interpreter=Interpreter.new($config.arena_length)
			players=[]
			bots.each do |b|
				p=Player.new
				start=rand $config.arena_length
				p.split(start)
				b.code.each_index do |i|
					interpreter.setCellNum(start+i,b.code[i].to_i(2),p)
				end
				players<<p
			end
			interpreter.run($config.max_cycles,*players)

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
	[wins,ties]
end.inject(){|result, element|
	ws,ts=result
	we,te=element
	ws.each_index do |i| 
		ws[i]+=we[i]
		ts[i]+=te[i]
	end 
	[ws,ts]
}

bots.each_index do |i|
	puts "bot #{bots[i].name} scored #{a[0][i]} wins and #{a[1][i]} ties"
end

end

if $PROFILE
	result = RubyProf.stop
	printer = RubyProf::GraphPrinter.new(result)
	printer = RubyProf::FlatPrinter.new(result)
	printer.print(STDOUT, 0)
end
