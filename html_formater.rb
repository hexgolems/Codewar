require './color.rb'
require 'rubygems'
require 'ostruct'
require 'couchrest'
require 'pp'

class HtmlFormater

  attr_accessor :header

  def color(points,max)
      val=points.to_f/max.to_f
      val/=2.5
      rgb=Color.hsvToRGB(val*255,1,1)
      return "##{rgb.map{|x| (x*255).to_i.to_s(16).rjust(2,"0")}.join}"
  end

  def cell(stats,config)
    if stats
      points=stats[0]*2+stats[1]
    return  "<td bgcolor=\"#{color(points,config.max_rounds*2)}\">"+
          text("#{stats[0]}/#{stats[1]}")+
        "</td>"
    else
      return "<td bgcolor='black'></td>"
    end
  end

  def text(str,color="black")
    "<span style='color:#{color}'>"+whitelist(str)+'</span>'
  end

  def whitelist(str)
    return str.gsub(/[^A-Za-z_\-0-9\/. !?:]/,"")
  end

  def bot_name(name,note)
    name,note=name.strip,note.strip
    if name.length>9
      short_name=name[0..6]+"..."
    else
      short_name=name
    end
    if note && note!=""
#puts "found note: #{note}"
      fullname="NAME: "+name+" NOTE: "+note
    else
      fullname="NAME: "+name
    end
    alt=whitelist(fullname)
#puts alt
    return "<a style='text-decoration:none' href='' alt='#{alt}' title='#{alt}'>#{whitelist(short_name)}</a>"
  end

  def format(bots,config)
    i=0

    bot_sorted=bots.map do |bot|
                st=bot.stats.each_value.to_a.compact.inject([0,0]) { |sum,val| sum[0]+=val[0]; sum[1]+=val[1]; sum}
                score=st[0]*3+st[1]
                [bot,score,st]
              end.sort_by{|x| x[1]}.reverse

    return <<EOF
    <html>
    <html>
    <META http-equiv="Pragma" content="no-cache">
    <META http-equiv="Content-Type" content="text/html; charset=UTF-8" />
    </html>
    <body textcolor='white' link="#FFFFFF" vlink="#FFFFFF" alink="#A0A0A0"  >
      <h>#{@header}</h>
      <img src="nyan.gif" alt="nyannyannyan..."/> <br>
      <table bgcolor='black'>

        <tr>
          <td> #{text("config option","white")}</td>
          <td> #{text(":","white")}</td>
          <td> #{text("value","white")}</td>
        </tr>
        <tr>
          <td> #{text("Size of the arena in memory cells","white")}</td>
          <td> #{text(":","white")}</td>
          <td> #{text(config.arena_length.to_s,"green")}</td>
        </tr>
        <tr>
          <td> #{text("Max number of instructions per bot","white")}</td>
          <td> #{text(":","white")}</td>
          <td> #{text(config.max_program_length.to_s,"green")}</td>
        </tr>
        <tr>
          <td> #{text("Number of clockcycles per game","white")}</td>
          <td> #{text(":","white")}</td>
          <td> #{text(config.max_cycles.to_s,"green")}</td>
        </tr>

        <tr>
          <td> #{text("Max number of threads per player","white")}</td>
          <td> #{text(":","white")}</td>
          <td> #{text(config.max_player_threads.to_s,"green")}</td>
        </tr>

        <tr>
          <td> #{text("Number of games played per match","white")}</td>
          <td> #{text(":","white")}</td>
          <td> #{text(config.max_rounds.to_s,"green")}</td>
        </tr>
        <tr>
          <td> #{text("Blacklisted instructions","white")}</td>
          <td> #{text(":","white")}</td>
          <td> #{text(config.blacklist.join(" "),"green")}</td>
      </table>

      <table>
        <tr>
          <td>
            <table bgcolor='black'>
              <tr>
                <td>#{text("pos","white")}</td>
                <td>#{text("name","white")}</td>
                <td>#{text("team","white")}</td>
                <td>#{text("points","white")}</td>
                <td>#{text("wins/ties","white")}</td>
              </tr>
              #{bot_sorted.inject("") do |s,bot_arr|
              bot,score,st=bot_arr
              s+"<tr>"+
              "<td>#{text((i+=1).to_s,"white")}</td>"+
              "<td>#{bot_name(bot.name,bot.desc)}</td>"+
              "<td>#{text(bot.group,"white")}</td>"+
              "<td bgcolor='#{color(score,config.max_rounds*(bots.length-1)*2)}'>#{text(score.to_s,"black")}</td>"+
              "<td bgcolor='#{color(score,config.max_rounds*(bots.length-1)*2)}'>#{text(st.join("/"),"black")}</td>"+
              "<td></td>"+
              "</tr>"
              end}
            </table>
          </td>
          <td>
            <table bgcolor='black'>
              <tr><td></td>#{bot_sorted.map{|x|x.first}.inject(""){|s,bot| s+"<td>#{bot_name(bot.name,bot.desc)}</td>"}}</tr>
                #{bot_sorted.map{|x|x.first}.inject("") do |s,bot|
                  s+"<tr><td>#{bot_name(bot.name,bot.desc)}</td>"+
                    bot_sorted.map{|x|x.first}.inject("") do |str,other_bot|
                      str+cell(bot.stats[other_bot],config)
                    end+"</tr>"
                  end
                }
            </table>
          </td>
        </tr>
      </table>
    </body>
    </html>
EOF
  end
end



def get_active_bots()
  bot_ids = $config.db.view('codewars/active_bots',"group_level"=>1)['rows']
  bot_ids=bot_ids.map{|x| x["value"]["_id"]}
  return $config.db.get_bulk(bot_ids)["rows"].map{|x| x["doc"]}
end

class Bot
  attr_accessor :stats,:group,:desc
  attr_accessor :name,:code, :id, :owner
end

def generate_html_from_db(header)

  bots_doc = get_active_bots()
  bots={}

  bots_doc.each do |bot_info|
    bot=Bot.new
    bot.name=bot_info["name"]
    bot.id=bot_info["_id"]
    bot.stats=bot_info["scores"]
    bot.group=bot_info["group"]
    bot.desc=bot_info["note"]
    bots[bot.id]=bot
  end

  newbots={}
  bots.values.each do |bot|
    newstats={}
    bot.stats.each_pair do |bid,res|
      next unless bots.include? bid
      newres=[res["wins"],res["ties"]]
      newstats[bots[bid]]=newres
    end
    bot.stats=newstats
  end


  f=HtmlFormater.new
  f.header=header
  return f.format(bots.values,$config)
end

