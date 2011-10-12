#!/usr/bin/env ruby

require 'rubygems'
require "ncurses"
require "./interpreter"




class ErrorThread < Thread
  def initialize(*args, &block)
    super(*args) do
      begin
        block.call
      rescue Exception => e
        $stderr.print "Exception occured: #{e.message} at " +
        e.backtrace.join("\n")
        exit! 1
      end
    end
  end
end

    $init=false

class Gui < Interpreter
  attr_accessor :ties
  attr_accessor :wins

    def setCellNum(addr,val,owner)
        super(addr,val,owner)
        draw(addr,getCellChar(addr),owner)
    end

  def initialize(config,bots)

    @@status  ||= :pause
    @@cursor_pos||=[0,0]
    @@cursor_addr||=0
    @@sleep_time||=0.1
    @@quit=false
    @@step||=false
    @lastModified=[]
    @selected_thread=0
    @ties = bots[1].ties
    @wins = [bots[0].wins,bots[1].wins]

    Ncurses.initscr if not $init

    $init=true
    Ncurses.start_color     #use the color
    Ncurses.cbreak          # provide unbuffered input
    Ncurses.noecho          # turn off input echoing
    Ncurses.nonl            # turn off newline translation
    Ncurses.stdscr.intrflush(false) # turn off flush-on-interrupt
    Ncurses.stdscr.keypad(true)     # turn on keypad mode

    Ncurses.init_pair(6, Ncurses::COLOR_BLACK, Ncurses::COLOR_BLUE);
    Ncurses.init_pair(5, Ncurses::COLOR_BLACK, Ncurses::COLOR_RED);
    Ncurses.init_pair(4, Ncurses::COLOR_WHITE, Ncurses::COLOR_BLACK);
    Ncurses.init_pair(2, Ncurses::COLOR_BLUE, Ncurses::COLOR_BLACK);
    Ncurses.init_pair(1, Ncurses::COLOR_RED, Ncurses::COLOR_BLACK);

    @bg = Ncurses::WINDOW.new(Ncurses.stdscr.getmaxy-2, 0, 0, 0)
    @fg = Ncurses::WINDOW.new(@bg.getmaxy-2, @bg.getmaxx-2, 1, 1)
    @fg.attrset(Ncurses.COLOR_PAIR(1))
    @bg.attrset(Ncurses.COLOR_PAIR(4))
    border(@bg)
    super(config)
    @key_event_thread = ErrorThread.new {key_events}
  end



  def run_callback(players)
    @players=players
        @bg.noutrefresh
        @bg.refresh()

        @fg.move(0,0)
    addr=@arena.size
        @fg.attrset(Ncurses.COLOR_PAIR(4))
    x = addr.to_i % (Ncurses.COLS-2)
    y = addr.to_i / (Ncurses.COLS-2)
    @fg.mvaddstr(y, x, "~")
        @fg.move(0,0)
    round_callback("init ")
#@fg.noutrefresh
#@fg.refresh()
  end

  def pre_round_callback(round)
  end

  def round_callback(round)
    sleep @@sleep_time

    if round=="init "
      @lastModified=[]
      @players.each do |player|
        player.lastWritten=[]
        player.threads.each do |thread|
          draw(thread.eip,getCellChar(thread.eip),player,true)
          @lastModified<<[thread.eip,player]
        end
      end
    end

      @lastModified.each do |wrt|
        addr,owner=wrt
        draw(addr,getCellChar(addr),owner)
      end

      @lastModified=[]

      @players.each do |player|
        player.lastRead.each do |addr|
          draw(addr,"^",player)
          @lastModified<<[addr,player]
        end
        player.lastWritten.each do |addr|
          draw(addr,"v",player)
          @lastModified<<[addr,player]
        end

        player.threads.each do |thread|
          draw(thread.eip,getCellChar(thread.eip),player,true)
          draw(thread.lastExec,getCellChar(thread.lastExec),player) if thread.lastExec!=thread.eip
          @lastModified<<[thread.lastExec,player]
          @lastModified<<[thread.eip,player]
        end
      end


      @bg.attrset(Ncurses.COLOR_PAIR(4))
      @bg.move(0,1)
      @bg.addstr("[#{round.to_s.rjust(5,"0")}]")

      @bg.move(0,9)
      @bg.addstr "["
      @bg.attrset(Ncurses.COLOR_PAIR(1))
      @bg.addstr "#{@players[0].name}"
      @bg.attrset(Ncurses.COLOR_PAIR(4))
      @bg.addstr " vs "
      @bg.attrset(Ncurses.COLOR_PAIR(2))
      @bg.addstr "#{@players[1].name}"
      @bg.attrset(Ncurses.COLOR_PAIR(4))
      @bg.addstr "]"
      name_length=10+"[#{@players[0].name} vs #{@players[1].name}]".length
      @bg.move(0,name_length)

      @bg.addstr "[threads: "
      @bg.attrset(Ncurses.COLOR_PAIR(1))
      @bg.addstr "#{@players[0].threads.length.to_s.rjust(2,"0")}"
      @bg.attrset(Ncurses.COLOR_PAIR(4))
      @bg.addstr "/"
      @bg.attrset(Ncurses.COLOR_PAIR(2))
      @bg.addstr "#{@players[1].threads.length.to_s.rjust(2,"0")}"
      @bg.attrset(Ncurses.COLOR_PAIR(4))
      @bg.addstr "]"
      thread_length=name_length+1+"[threads: 01/01]".length
      @bg.move(0,thread_length)

      @bg.addstr "[wins: "
      @bg.attrset(Ncurses.COLOR_PAIR(1))
      @bg.addstr "#{@wins[0].to_s.rjust(2,"0")}"
      @bg.attrset(Ncurses.COLOR_PAIR(4))
      @bg.addstr "/"
      @bg.attrset(Ncurses.COLOR_PAIR(2))
      @bg.addstr "#{@wins[1].to_s.rjust(2,"0")}"
      @bg.attrset(Ncurses.COLOR_PAIR(4))
      @bg.addstr "]"
      win_length=thread_length+1+"[wins: 01/01]".length
      @bg.move(0,win_length)

      @bg.addstr "[ties: "
      @bg.addstr "#{@ties.to_s.rjust(2,"0")}"
      @bg.addstr "]"

      first=true
      while first or (@@status==:pause and (not @quit) and (not @next) and (not @@step)) do
        Ncurses.stdscr.attrset(Ncurses.COLOR_PAIR(4))
        Ncurses.stdscr.move(@bg.getmaxy,0)
        Ncurses.stdscr.addstr " "*@bg.getmaxy
        Ncurses.stdscr.move(@bg.getmaxy,0)
        Ncurses.stdscr.addstr cell_info(@@cursor_addr)

        @fg.move(@@cursor_pos[1],@@cursor_pos[0])
        @bg.move(@@cursor_pos[1]+1,@@cursor_pos[0]+1)
#       a=[]
#Ncurses.in_wch(a)
#       STDERR.puts a.inspect
        Ncurses.stdscr.move(@@cursor_pos[1]+1,@@cursor_pos[0]+1)
        Ncurses.stdscr.noutrefresh
        Ncurses.stdscr.refresh()
        @bg.noutrefresh
        @bg.refresh()
        @fg.noutrefresh
        @fg.refresh()

        if first
          first=false
        else
          sleep 0.1
        end
      end
      @@step=false
  end

  def end_callback(players)
    release
  end

  def release
    Ncurses.echo
    Ncurses.nocbreak
    Ncurses.nl
    Ncurses.endwin
    @key_event_thread.kill if @key_event_thread
  end

  def get_threads(addr)
    threads=[]
    @players.each do |player|
      threads+=player.threads.select{|t| t.eip % @arena.length ==addr % @arena.length}
    end
    return threads
  end

  def b2s(bool)
    if bool then '1' else '0' end
  end

  def get_thread_info(thread)
    return "" unless thread
    return "Reg: [acc=#{thread.acc.to_i} ptr=#{thread.ptr.to_i} r1=#{thread.r1.to_i} r2=#{thread.r2.to_i}] "+
            "Flags: [=#{b2s(thread.equal)} >#{b2s(thread.above)} <#{b2s(thread.smaller)}  inter:#{b2s(thread.interrupt_enable)} "+
            " Imem:#{b2s(thread.Tmem)} Icza:#{b2s(thread.Tcza)} Iclk:#{b2s(thread.Tclk)}]"
  end

  def get_length_info(list)
    l=list.length
    if l==0
    return "-/-"
    else
      return "#{@selected_thread+1}/#{l}"
    end
  end

  def cell_info(addr)
    cell=getCellNum(addr)
    begin
    code=Disassembler.disassemble(cell.to_code)
    rescue Exception => e
    code="DATA"
    end
    bin=cell.to_bin
    threads=get_threads(addr)
    if threads.length!=0
      @selected_thread%=threads.length
    else
      @selected_thread=0
    end
    status="at 0x#{addr.to_s(16).rjust(4,"0")} "+
    ":: Code: #{code.rjust(15," ")}   "+
    "Bin: [#{bin[0...20]}][#{bin[20...40]}][#{bin[40...48]}] "+
    "Dec: #{cell.to_i.to_s.rjust(15," ")} "+
    "curr thread: #{get_length_info(threads)} \n"+
    get_thread_info(threads[@selected_thread])+" "*100

    return status
  end

  def get_next_thread_position(curr)
    threads=@players.inject([]){|threads,player|
        threads+=player.threads.map{|t| (t.eip% @arena.length).to_i}
    }.sort
    return 0 if threads.length==0
    return threads.first if curr>threads.last
    return threads.find{|a| a>curr}
  end

  def move_to_next_thread()
    addr=@@cursor_pos[0]+(Ncurses.COLS-2)*@@cursor_pos[1]
    new_addr=get_next_thread_position(addr)
    @@cursor_pos[0] = new_addr.to_i % (Ncurses.COLS-2)
    @@cursor_pos[1] = new_addr.to_i / (Ncurses.COLS-2)
  end

  def move_cur(dir)
    maxx,maxy=Ncurses.COLS-3,Ncurses.LINES-4
    case dir
      when :left then @@cursor_pos[0]-=1
      when :right then @@cursor_pos[0]+=1
      when :up then @@cursor_pos[1]-=1
      when :down then @@cursor_pos[1]+=1
    end

    if @@cursor_pos[0]<0 then
      if @@cursor_pos[1]==0 then
        @@cursor_pos[0] = @arena.length % (Ncurses.COLS-2)-1
        @@cursor_pos[1] = @arena.length / (Ncurses.COLS-2)
      else
        @@cursor_pos[0]=maxx
        move_cur(:up)
      end
    end

    if @@cursor_pos[0]>maxx then
      @@cursor_pos[0]=0
      move_cur(:down)
    end

    if @@cursor_pos[1]<0 then
      @@cursor_pos[1]=maxy
    end

    if @@cursor_pos[1]>maxy then
      @@cursor_pos[1]=0
    end

    addr=@@cursor_pos[0]+(Ncurses.COLS-2)*@@cursor_pos[1]
    if addr >= @arena.length
      @@cursor_pos[1]=0;
      @@cursor_pos[0]=0 if(dir!=:down)
    end

    @@cursor_addr=@@cursor_pos[0]+(Ncurses.COLS-2)*@@cursor_pos[1]

        @fg.move(@@cursor_pos[1],@@cursor_pos[0])
  end

  def draw(addr, char, owner, inverted=false)
    addr%=@arena.length
    color=case (owner and owner.playerID)
      when 0 then
        (inverted)?5:1
      when 1 then
        (inverted)?6:2
      else 4
    end
    @fg.attrset(Ncurses.COLOR_PAIR(color))
        @fg.move(0,0)
    x = addr.to_i % (Ncurses.COLS-2)
    y = addr.to_i / (Ncurses.COLS-2)
      @fg.mvaddstr(y, x, char)
        @fg.move(@@cursor_pos[1],@@cursor_pos[0])
  end


  def border(scr)
    scr.clear()
    Ncurses.init_pair(3, Ncurses::COLOR_WHITE, Ncurses::COLOR_BLACK);
    scr.attrset(Ncurses.COLOR_PAIR(3))
    scr.border(*([0]*8)) # calls WINDOW#border(0, 0, 0, 0, 0, 0, 0, 0)
    scr.move(1,1)
  end

  def key_events
    loop do
      case Ncurses::getch
        when Ncurses::ERR then
        when Ncurses::KEY_F6 then
        when 0x20  then @@status=(@@status==:running)?:pause: :running
        when ?h,Ncurses::KEY_LEFT then move_cur(:left)
        when ?j,Ncurses::KEY_DOWN then move_cur(:down)
        when ?k,Ncurses::KEY_UP then  move_cur(:up)
        when ?l,Ncurses::KEY_RIGHT then move_cur(:right)
        when ?- then @@sleep_time=[@@sleep_time+0.03,10  ].min
        when ?+ then @@sleep_time=[@@sleep_time-0.03,0.01].max
        when ?q then @quit=true
        when ?n then @next=true
        when ?t then @selected_thread+=1
        when ?m then move_to_next_thread
        when ?s then @@step=true;@@status=:pause
        else
      end
      sleep 0.01
    end
  end

end
