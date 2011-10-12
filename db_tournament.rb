#/usr/bin/ruby1.9.1
$begintime=Time.now
require './interpreter.rb'
require './compiler'
require './assembler.rb'
require './disassembler.rb'
require 'set'
require 'ostruct'
require 'pp'
require 'rubygems'
require './parallel.rb'
require 'couchrest'

alias :oldputs :puts
def puts(string)
  oldputs "#{Time.now.to_f}: #{string}"
end
puts "calling db_tournament"


$config=OpenStruct.new
$config.db=CouchRest.database!("http://127.0.0.1:5984/codewars")
$config.write_mutex=Mutex.new

res=$config.db.get("config")

$config.max_program_length=res['arena']['max_program_length']
$config.max_cycles=res['arena']['num_cycles']
$config.max_rounds=res['arena']['num_rounds']
$config.arena_length=res['arena']['num_cells']
$config.min_dist=res['arena']['min_dist']
$config.max_player_threads=res['arena']['max_player_threads']
$config.threads=res['interpreter']['num_threads']
$config.blacklist=res['interpreter']['blacklist'].map{|cmd| cmd.to_sym}
$config.blacklist=nil if $config.blacklist==[]
$config.force_update=false

($config.max_program_length and $config.max_cycles and $config.max_rounds and $config.threads and $config.arena_length) or raise "invalid config"

class Bot
  attr_accessor :stats,:group,:desc
  attr_accessor :name,:code, :id, :owner
end

$NUM_BATTLES=nil



ARGV.each_index do |i|
  if ARGV[i]=="-d"
    $DEBUG=true
    next
  end
  if ARGV[i]=="-p"
    $PROFILE=true
    next
  end
  if ARGV[i]=~/-s([0-9]+)/
    $NUM_BATTLES=$1.to_i
    next
  end
end

def get_active_bots()
  bot_ids = $config.db.view('codewars/active_bots',"group_level"=>1)['rows']
  bot_ids=bot_ids.map{|x| x["value"]["_id"]}
  return $config.db.get_bulk(bot_ids)["rows"].map{|x| x["doc"]}
end

allbots=[]

if $config.forced_update
  bits=get_active_bots
  bots.each do |doc|
    doc["scores"]={}
    $config.db.save_doc(doc) or raise "unable to clear scores"
  end
end


bots=get_active_bots

bots.each do |bot_db_entry|
  bot=Bot.new
  bot.name=bot_db_entry["name"]
  bot.id=bot_db_entry["_id"]
  bot.owner=bot_db_entry["owner"] || "no_owner"
  cmds=bot_db_entry["code"]

  if cmds.length>$config.max_program_length
    puts "bot #{bot.name} rejected because he is to long"
    next
  end

  bot.code=cmds
#puts cmds.map{|c| Disassembler.bin_to_code(c)}.inspect
  allbots<<bot
end

bot_db=bots.inject({}) do |hash,db_entry|
  hash[db_entry["_id"]]=db_entry
  hash
end

puts "db shit done"

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

allbots.each_index do |i|
  (i+1...allbots.size).each do |j|
    permbots<<[allbots[i],allbots[j]]
  end
end

puts "begin playing"

permbots.sort_by{|x| rand}.each do |game_bots|

if $NUM_BATTLES == 0
  puts "="*80
  duration=Time.now-$begintime
  puts "#{(duration).to_f}"
  File.open("runs.txt","a")do |f| f.puts duration.to_s end
  exit 1
end
doc=bot_db[game_bots[0].id]
#pp $config.db.get(game_bots[0].id)

if !$config.force_update && doc["scores"].include?(game_bots[1].id)
#puts "aborting match: #{game_bots.map{|b| b.name}.join(" vs ")} becaus the result is known"
  next
end

$NUM_BATTLES -= 1 if $NUM_BATTLES
puts ""
puts "playing match: #{game_bots.map{|b| b.name}.join(" vs ")}"

bot_ids=Set.new

game_bots.each do |bot|
  bot_ids<<bot.id
end

raise "number of rounds not divisible by number of threads -> aborting" if $config.max_rounds % $config.threads != 0
stepsize=($config.arena_length-80-2*$config.min_dist)/$config.max_rounds.to_f

result_sets=Parallel.in_processes($config.threads) do |index|

    num_rounds=$config.max_rounds/$config.threads

    scores={}

    (num_rounds).times do |round|
      interpreter=Interpreter.new($config)
      interpreter.blacklist=$config.blacklist
      players=[]
      first_player_end=nil
      game_bots.each_index do |i|
        b=game_bots[i]
        p=Player.new
        p.bot_id=b.id
        scores[p.bot_id]||=[0,0]
        bot_ids<<b.id

        if i==0
          start=0
        else
          start = (num_rounds*index*stepsize) + stepsize*round + 40+$config.min_dist + rand(stepsize)
          start = start.to_i
        end

        p.split(start)
        b.code.each_index do |i|
          interpreter.setCellNum(start+i,b.code[i].to_i(2),p)
        end
        players<<p
      end
      interpreter.run($config.max_cycles,*players)

      someone_won=false
      someone_won=true if players.count{|p| p.threads.length>0} == 1

        #one of them is a winner
        players.each do |player|
            if someone_won && player.threads.length>0
              scores[player.bot_id][0]+=1
            elsif player.threads.length>0 or players.count{|p| p.threads.length==0} == 2 #nuklear fallout(everyones dead)
              scores[player.bot_id][1]+=1
            end
        end #end of updating player values

      end #end of rounds

      puts "thread #{index} finished"
      scores
    end#end of threads (stored in result_sets)

puts "done with the games"
sum_scores=Hash.new([0,0])


result_sets.each do |scores|
  scores.each_pair do |id,points|
    sum_scores[id]=[0,0] unless sum_scores.include? id
    sum_scores[id][0]+=points[0]
    sum_scores[id][1]+=points[1]
  end
end

puts "calcuated scores"


sum_scores.each_pair do |bot_id,points|
        begin
        wins,ties=points
        doc=$config.db.get(bot_id)
        res=doc["scores"][(bot_ids-[bot_id]).first]
        res||={}
        oldwins,oldties=res["wins"],res["ties"]
        oldwins||=0
        oldties||=0
        doc["scores"][(bot_ids-[bot_id]).first]={"wins"=>oldwins+wins,"ties"=>oldties+ties}
        $config.db.save_doc(doc)
        rescue => e
          puts "boom conflict #{e.inspect}"
          retry
        end
  end

puts "stored results"

end

#$config.db.compact!

puts "compacted db"

if $PROFILE
  result = RubyProf.stop
  printer = RubyProf::GraphPrinter.new(result)
  printer = RubyProf::FlatPrinter.new(result)
  printer.print(STDOUT, 0)
end
