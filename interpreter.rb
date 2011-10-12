require './cellnum'
require 'pp'
require './disassembler.rb'

class CoreThread
    attr_accessor :player
    attr_accessor :eip,:iret,:r1,:r2,:acc,:ptr
    attr_accessor :interrupt_enable,:Imem,:Icza,:Iclk #interrupt flags
    attr_accessor                   :Tmem,:Tcza,:Tclk #interrupt vector target addresses
    attr_accessor :ImemPtr,:IczaVal, :IclkVal #interrupt values
    attr_accessor :equal,:above,:smaller,:clk
    attr_accessor :ILastAcc, :ILastMem
  attr_accessor :lastExec

    attr_reader :threadID

  def to_s
    "thread: #{@player.name}, @#{eip.to_i} acc,ptr,r1,r2=#{[@acc,@ptr,@r1,@r2].join ","}"
  end

    def initialize(eip,threadid,player)
        @eip,@iret,@r1,@r2,@acc,@ptr,@player=Cellnum.new(eip),Cellnum.new(eip),Cellnum.new(0),Cellnum.new(0),Cellnum.new(0),Cellnum.new(0),player
        @clk=Cellnum.new(0)
        @interrupt_enable,@Imem,@Icza,@Iclk =false,false,false,false
                          @Tmem,@Tcza,@Tclk =nil,nil,nil
                          @ImemPtr,@IczaVal,@IclkVal =Cellnum.new(0),Cellnum.new(0),Cellnum.new(0)
        @equal,@above,@smaller=false,false,false
    @ILastAcc=@acc
    @ILastMem=Cellnum.new(0)
        @threadID=threadID
    @lastExec=Cellnum.new(eip)
    end

    def tick(interpreter)

    if  @IclkVal!=0 and @clk!=0 and (@clk % @IclkVal)==0
      @Iclk = true
    end
        @clk+=1

        if (thismem=interpreter.getCellNum(@ImemPtr))!=@ILastMem
            @Imem = true
            @ILastMem=thismem
        end

        if @acc==@IczaVal && @acc!=@ILastAcc
            @Icza =true
        end
        @ILastAcc=@acc
    end

end


class Player
    attr_accessor :threads, :playerID
    attr_reader :threadcount, :threadindex
  attr_accessor :name
  attr_accessor :lastRead, :lastWritten
  attr_accessor :bot_id
  attr_accessor :wins
  attr_accessor :ties


    def initialize
        @threads=[]
        @threadindex=0
        @threadcount=0
        @lastRead=[]
        @lastWritten=[]
    end

    #return the next thread to run
    def choose
        return nil if @threads.length==0
        @threadindex+=1
        @threadindex%=@threads.length
        return @threads[@threadindex]
    end

    def split(position)
      t=CoreThread.new(position,@threadcount+=1,self)
      @threads<<t
    end

    def kill(thread)
        @threads-=[thread]
    end

    def alive?
        @threads.length!=0
    end
end

class Interpreter
    attr_accessor :players, :arena, :quit, :next, :blacklist
    attr_reader :cmds

    def initialize(config)
    @config=config
        @arena=Array.new(config.arena_length){Cellnum.new(0)}
    @quit,@next=false

        @cmds={
            :add => lambda{|p1,p2,t| arithmetic_op( p1 , t,  value(p1,t)+value(p2,t)) },
            :sub => lambda{|p1,p2,t| arithmetic_op( p1 , t,  value(p1,t)-value(p2,t)) },
            :mul => lambda{|p1,p2,t| arithmetic_op( p1 , t,  value(p1,t)*value(p2,t)) },
            :div => lambda{|p1,p2,t| arithmetic_op( p1 , t,  value(p1,t)/value(p2,t)) },
            :mod => lambda{|p1,p2,t| arithmetic_op( p1 , t,  value(p1,t)%value(p2,t)) },
            :and => lambda{|p1,p2,t| arithmetic_op( p1 , t,  value(p1,t)&value(p2,t)) },
            :or  => lambda{|p1,p2,t| arithmetic_op( p1 , t,  value(p1,t)|value(p2,t)) },
            :xor => lambda{|p1,p2,t| arithmetic_op( p1 , t,  value(p1,t)^value(p2,t)) },

            :not => lambda{|p1,t| arithmetic_op( p1 , t,  value(p1,t).not) },
            :inc => lambda{|p1,t| arithmetic_op( p1 , t,  value(p1,t)+1) },
            :dec => lambda{|p1,t| arithmetic_op( p1 , t,  value(p1,t)-1) },
            :neg => lambda{|p1,t| arithmetic_op( p1 , t,  value(p1,t)*-1) },

            :ada => lambda{|p1,t| arithmetic_op( [:immediate,:acc,nil] , t, value([:immediate,:acc,nil],t)+value(p1,t)) },
            :sba => lambda{|p1,t| arithmetic_op( [:immediate,:acc,nil] , t, value([:immediate,:acc,nil],t)-value(p1,t)) },

            :ica => lambda{|t| arithmetic_op( [:immediate,:acc,nil] , t,  value([:immediate,:acc,nil],t)+1) },
            :dca => lambda{|t| arithmetic_op( [:immediate,:acc,nil] , t,  value([:immediate,:acc,nil],t)-1) },

            :mov => lambda{|p1,p2,t| arithmetic_op( p1 , t,  value(p2,t)) },
            :mvp => lambda{|p1,t| arithmetic_op( [:direct,:ptr,nil] , t,  value(p1,t)) },
            :mva => lambda{|p1,t| arithmetic_op( [:immediate,:acc,nil] , t,  value(p1,t)) },

            :jmp => lambda{|p1,t| jmp_op( t,  value(p1,t),true) },

            :jie => lambda{|p1,t| jmp_op( t,  value(p1,t),t.equal) },
            :jia => lambda{|p1,t| jmp_op( t,  value(p1,t),t.above) },
            :jis => lambda{|p1,t| jmp_op( t,  value(p1,t),t.smaller) },

            :jne => lambda{|p1,t| jmp_op( t,  value(p1,t),!t.equal) },
            :jna => lambda{|p1,t| jmp_op( t,  value(p1,t),!t.above) },
            :jns => lambda{|p1,t| jmp_op( t,  value(p1,t),!t.smaller) },

            :cmp => lambda{|p1,p2,t| cmp_op(t,value(p1,t),value(p2,t))},

            :sti => lambda{|t|  t.interrupt_enable=true;  t.eip+=1;},
            :cli => lambda{|t|  t.interrupt_enable=false; t.eip+=1;},
            :rti => lambda{|t|  t.interrupt_enable=true;  t.eip=t.iret;},

            :clk => lambda{|p1,p2,t|
                    t.IclkVal=Cellnum.new([value(p1,t).to_i,4].max)
                    t.Tclk=value(p2,t);
                    if t.Tclk==0
                      t.Tclk=nil
                    else
                      t.Tclk+=t.eip
                    end
                    t.Iclk=false
                    t.eip+=1
            t.clk=Cellnum.new(0)
            },

      #TODO set the lastMem and lastcza values
            :mem => lambda{|p1,p2,t|
                    t.ImemPtr=t.eip+value(p1,t);
                    t.Tmem=value(p2,t);
                    if t.Tmem==0
                      t.Tmem=nil
                    else
                      t.Tmem+=t.eip
                    end
                    t.Imem=false
                    t.ILastMem=getCellNum(t.ImemPtr)
                    t.eip+=1
            },

            :cza => lambda{|p1,p2,t|
                    t.IczaVal=value(p1,t);
                    t.Tcza=value(p2,t);
                    if t.Tcza==0
                      t.Tcza=nil
                    else
                      t.Tcza+=t.eip
                    end
                    t.Icza=false
                    t.ILastAcc=t.acc
                    t.eip+=1
            }
        }
    end

    def cmp_op(thread,value1,value2)
        thread.equal=(value1==value2)
        thread.smaller=(value1<value2)
        thread.above=(value1>value2)
        thread.eip+=1
    end

    def arithmetic_op(param,thread,value)
        store(param,thread,value)
        thread.equal=(value==0)
        thread.smaller=(value<0)
        thread.above=(value>0)
        thread.eip+=1
    end

    def jmp_op(thread,value, do_jump)
        if do_jump
            thread.eip+=value.to_i
        else
            thread.eip+=1
        end
    end

    def do_instruction(code,player,thread)

    cmd,param1,param2=code
    raise "process die due to blacklisted cmd" if @blacklist and @blacklist.include? cmd
    old_eip=thread.eip
    thread.lastExec=thread.eip
        if @cmds.include? cmd
            exec=@cmds[cmd]

            if exec.arity==3 && param1 && param2
                exec.call(param1,param2,thread)
            elsif exec.arity==2 && param1
                exec.call(param1,thread)
            elsif exec.arity==1
                exec.call(thread)
            else
                raise "process died due to invalid parameters for #{cmd}"
            end
        elsif cmd==:splt
            if param1
        if player.threads.length < @config.max_player_threads
          player.split(old_eip+value(param1,thread))
        end
        thread.eip+=1
            else
                raise "process died due to invalid parameters for #{cmd}"
            end
        else
            raise "process died due to invalid opcode #{cmd}"
        end
        post_op(param1,thread,old_eip)
        post_op(param2,thread,old_eip)
    end

    def value(param,thread)
        type,val,op=param
#puts "val #{val.inspect}"
        nval= case val
                when :ptr then Cellnum.new(thread.ptr)
                when :acc then Cellnum.new(thread.acc)
                when :r1 then Cellnum.new(thread.r1)
                when :r2 then Cellnum.new(thread.r2)
                when Fixnum,Bignum then Cellnum.new(val)
            end
#puts "nval #{nval.inspect}"
        return nval if type==:immediate
    thread.player.lastRead<<thread.eip+nval
        nval = getCellNum(thread.eip+nval)
        return nval if type==:direct
    thread.player.lastRead<<thread.eip+nval
        nval = getCellNum(thread.eip+nval)
        return nval if type==:indirect
        raise "Interpretation failed, invalid type #{param.inspect}"
    end


    def store(param,thread,value)
        type,val,op=param
        if type==:immediate
            case val
                    when :ptr then thread.ptr=value ; return
                    when :acc then thread.acc=value ; return
                    when :r1 then thread.r1=value   ; return
                    when :r2 then thread.r2=value   ; return
                    else raise "ERROR in Store: Trying to change a constant instead of a register"
            end
        end

        addr= thread.eip + case val
                    when :ptr then thread.ptr
                    when :acc then thread.acc
                    when :r1 then thread.r1
                    when :r2 then thread.r2
                    when Fixnum,Bignum then val
                    else raise "ERROR in Store: Wrong direct parameter"
                end

        addr=thread.eip+getCellNum(addr) if type==:indirect

        setCellNum(addr,value,thread.player)
    end

    def getCellNum(addr)
        @arena[addr.to_i % @arena.length]
    end

    def getCellCode(addr)
    #Disassembler.bin_to_code(getCellNum(addr).to_bin)
        getCellNum(addr).to_code
    end

    def getCellChar(addr)
    begin
        char=case getCellCode(addr)[0].to_s
            when /^([mjc])/  then $1
            when "die" then  "!"
            else "a"
        end
    return char
    rescue Exception => e
    return "#"
    end
    end

    def setCellNum(addr,value,owner=nil)
        @arena[addr.to_i % @arena.length]=Cellnum.new(value)
        @arena[addr.to_i % @arena.length].owner=owner
    owner.lastWritten<<addr if owner
    end

    def post_op(param,thread,eip)

    #we need the old eip befor a jump
    #TODO needs to be fixed in runcmd
    #should be fixed now (testing)!
    oldeip=thread.eip
    thread.eip=eip

    type,val,op=param

    if op
      cval=value(param,thread)
      case op
        when :inc then cval+=1
        when :dec then cval-=1
      end
      store(param,thread,cval)
    end
    thread.eip=oldeip
    end

  def round_callback(round)
  end

  def end_callback(players)
  end

  def run_callback(players)
  end

    def run(maxrounds,*players)
    players.each_index { |e| players[e].playerID=e}
    @players=players # for use in the callbacks
        finished=false
        rounds=0
    run_callback(players)
        while not finished
#puts "round #{rounds}"
            rounds+=1
            alivecount=0

            players.sort_by{rand}.each do |p|

        p.lastWritten=[]
        p.lastRead=[]
                t=p.choose

                next if not t
                t.tick(self) #update interrupt values
                #check for interrupt occurance
                if t.interrupt_enable
                    if t.Imem  && t.Tmem
                        t.Imem=false
                        t.iret=t.eip
                        t.eip=t.Tmem

                    elsif t.Icza && t.Tcza
                        t.Icza=false
                        t.iret=t.eip
                        t.eip=t.Tcza

                    elsif t.Iclk && t.Tclk
                        t.Iclk=false
                        t.iret=t.eip
                        t.eip=t.Tclk
                    end
                end
                #try to execute code or kill thread
                begin
                  begin
                    code=getCellNum(t.eip).to_code
                  ensure
                    if $DEBUG
                      STDERR.puts "thread: #{t}"
                      STDERR.puts "executes: #{code.inspect}"
                      #STDERR.puts "in context #{@arena.map {|e| e.to_i}.inspect}"
                    end
                  end
                  do_instruction(code,p,t)
                rescue
          if $DEBUG
            STDERR.puts "thread #{t} from player #{t.player.name} died at addr. #{t.eip} in round #{rounds} because of #{$!}\n #{$!.backtrace.join("\n")}"
          end
                    p.kill(t)
                end
                alivecount+=1 if p.alive?
            end
      round_callback(rounds)
            finished=true if @next or @quit or alivecount<=1 or rounds>=maxrounds
        end
    end_callback(players)
    end
end
