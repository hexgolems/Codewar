require 'gserver'
require 'rubygems'
require 'couchrest'
require 'json'
require 'pp'

require 'digest/md5'
require 'net/http'

require 'set'
require 'ostruct'
require 'pp'
require 'rubygems'
require 'parallel'
require 'couchrest'
require './html_formater.rb'
require 'timeout'

$auth=""
$config=OpenStruct.new
$config.db=CouchRest.database!("http://#{$auth}127.0.0.1:5984/codewars")
$config.write_mutex=Mutex.new

res=$config.db.get("config")

$config.max_program_length=res['arena']['max_program_length']
$config.max_cycles=res['arena']['num_cycles']
$config.max_rounds=res['arena']['num_rounds']
$config.max_player_threads=res['arena']['max_player_threads']
$config.arena_length=res['arena']['num_cells']
$config.threads=res['interpreter']['num_threads']
$config.updatetime=res['output']['round_time']
$config.generate_on_every_update=res['output']['generate_every_update']
$config.output_file=res['output']['file']
$config.blacklist=res['interpreter']['blacklist'].map{|cmd| cmd.to_sym}


Thread.abort_on_exception=true

class GameServer < GServer

  def initialize(*params)
    super
    @auth={}
    @auth["1337"]=Digest::MD5.hexdigest("pass")
    @auth["hexkids"]=Digest::MD5.hexdigest("pass")
    @auth["fnord"]=Digest::MD5.hexdigest("pass")
    @runner=Thread.new{runner()}
  end

  def exists(x)
    raise "value should be given" unless x
    x
  end

  def write_html(header="")
    begin
    puts "generating html"
    File.open($config.output_file,"w") do |f|
      html=generate_html_from_db(header)
      puts "done generating"
      f.write(html)
    end
    puts "done writing"
    rescue => e
    puts "boom ->> generation gone bad"
    puts e.inspect
    puts e.backtrace.join "\n"

    end
  end

def get_active_bots()
  bot_ids = $config.db.view('codewars/active_bots',"group_level"=>1)['rows']
  bot_ids=bot_ids.map{|x| x["value"]["_id"]}
  return $config.db.get_bulk(bot_ids)["rows"].map{|x| x["doc"]}
end

def get_active_scores()
  bots_doc = get_active_bots()
  bots={}

  bots_doc.each do |bot_info|
    bot=OpenStruct.new
    bot.name=bot_info["name"]
    bot.bid=bot_info["_id"]
    bot.stats=bot_info["scores"]
    bot.group=bot_info["group"]
    bot.desc=bot_info["note"]
    bots[bot.bid]=bot
  end

  newbots=[]
  bots.values.each do |bot|
    newstats={}
    bot.stats.each_pair do |bid,res|
      next unless bots.include? bid
      newres=[res["wins"],res["ties"]]
      newstats[bots[bid]]=newres
    end
    bot.stats=newstats
    st=bot.stats.each_value.to_a.compact.inject([0,0]) { |sum,val| sum[0]+=val[0]; sum[1]+=val[1]; sum}
    score=st[0]*3+st[1]
    bot.score=score
    newbots<<bot
  end
  return newbots.sort_by{|bot| bot.score}
end

def get_best_team()
  blacklist=Set.new
  blacklist+=File.read("blacklist.txt").lines.map{|x| x.strip}
  begin
    bots = get_active_scores()
    bots=bots.select{|bot| not blacklist.include? bot.group}
    return bots.last.group
  rescue
    puts "no known active teams"
    puts $!,$@
    return ""
  end
end

  def runner()
    last_full_update=Time.now-20*60
    loop do

      sleep 1  while !@update && Time.now-last_full_update < $config.updatetime*60

      @update=false

      if Time.now-last_full_update >= $config.updatetime*60
        @blocked = true
        puts "full update"
        write_html("New round")
        begin
          system("ruby1.9.1 db_tournament.rb -s1")
          puts "writing html"
          write_html("Currently Running Tournament!")
        end while $?.exitstatus!=0

        begin
          best_team=get_best_team
          puts "The winner of this round is: #{best_team}"
          Timeout.timeout(2) do
            url = URI.parse('http://10.11.0.1:9001/')
            Net::HTTP.start(url.host, url.port) do |http|
              http.request_post(url.path, best_team)
            end
          end
        rescue Exception => e
          puts "="*80
          puts "failed to push winner"
          puts $!,$@
          puts "="*80
        end
        puts "writing html"
        write_html("Next round at #{Time.now+$config.updatetime*60}")
        last_full_update=Time.now

        @blocked = false

      else

        puts "update"
        puts "writing html"
        write_html("Next round at #{Time.now+$config.updatetime*60}")
        begin
            puts "#{Time.now.to_f}: starting db_torunament"
            system("ruby1.9.1 db_tournament.rb -s1")
        end while $?.exitstatus!=0 and Time.now-last_full_update < $config.updatetime*60
        if $config.generate_on_every_update
            puts "writing html"
            write_html("Next round at #{Time.now+$config.updatetime*60}")
        end

      end

    end
  end


  def valid(group,password)
    return false unless group and password
    return true
    return true if @auth[group]==Digest::MD5.hexdigest(password)
    return false
  end

  def serve(io)
    begin
      io.puts "CodeWars GameServer v:0.01"

      if @blocked
        io.puts "unable to commit - round update is in process"
        return
      end

      json=JSON.parse(io.gets)

      group=io.peeraddr.last.split(".")[2]+json['group']
      password=json['password']

      unless valid(group,password)
        io.puts "invalid login"
        puts "invalid login"
        raise "invalid login"
      end

      code=json['code']

      raise "invalid code" unless code.is_a? Array
      code.each do |line|
        raise "invalid code" unless line.is_a? String
        unless line=~/\A[01]{48}\Z/
          io.puts "code lines are not binary format"
          raise "code line not binary"
        end
      end

      unless code.length<=$config.max_program_length
        io.puts "your code is to long, (max #{$config.max_program_length} instructions)"
        raise "code to long"
      end


      doc={
        'code'=>code,
        'timestamp'=>Time.now.to_f,
        'name'=>json['name'] || Digest::MD5.hexdigest(code),
        'group'=>group,
        'note'=>json['note'] || nil,
        'scores'=>{}
      }

      db=CouchRest.database!("http://#{$auth}127.0.0.1:5984/codewars")
      db.save_doc(doc)
      io.puts "successfully commited your bot"
      @update=true

    rescue JSON::ParserError
      io.puts "you be to stupid to send proper json"
    rescue => e
      puts io.addr.inspect
      puts e.inspect
      puts e.backtrace.join "\n"
      raise e
    end

  end
end

server=GameServer.new(7125,"0.0.0.0",100)
#server.audit=true
server.start
server.join
