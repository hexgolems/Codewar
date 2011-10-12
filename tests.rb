require './assembler.rb'
require './disassembler.rb'
require './cellnum.rb'
require './interpreter.rb'
require './optics.rb'

def test(name,&b)
    begin
    puts "test #{name} failed!" if not b.call
    rescue Exception => e
    puts "test #{name} failed with an exception: '#{e}'"
    end
end

Assembler.linenum=1


test(p="*123+")  {Assembler.assemble_param(p)==[:direct,123,:inc]}
test(p="**ptr-") {Assembler.assemble_param(p)==[:indirect,:ptr,:dec]}
test(p="0x456-") {Assembler.assemble_param(p)==[:immediate,1110,:dec]}
test(p="*r1") {Assembler.assemble_param(p)==[:direct,:r1,nil]}

test(p="add r1, 3;") {Assembler.assemble(p)==[:add, [:immediate, :r1, nil], [:immediate, 3, nil]]}
test(p="ica;") {Assembler.assemble(p)==[:ica, nil, nil]}

a=Cellnum.new(4)
test("cellnum creation"){a.to_s=="#4"}
test("cellnum +"){(a+3).to_s=="#7"}
test("cellnum +="){(a+=3).to_s=="#7" && a.to_s=="#7"}
a=Cellnum.new(4)
test("cellnum -"){(a-3).to_s=="#1"}
test("cellnum -="){(a-=3).to_s=="#1" && a.to_s=="#1"}

test("cell num == #1"){     Cellnum.new(3)==Cellnum.new(4-1)}
test("cell num == #2"){ not Cellnum.new(3)==Cellnum.new(4)}

test("cell num < #1"){      Cellnum.new(3)<Cellnum.new(4)}
test("cell num < #2"){  not Cellnum.new(4)<Cellnum.new(4)}

test("cell num > #1"){      Cellnum.new(4)>Cellnum.new(3)}
test("cell num > #2"){  not Cellnum.new(4)>Cellnum.new(4)}

test("cell num <= #1"){     Cellnum.new(3)<=Cellnum.new(4)}
test("cell num <= #2"){     Cellnum.new(4)<=Cellnum.new(4)}
test("cell num <= #2"){ not Cellnum.new(5)<=Cellnum.new(4)}

test("cell num >= #1"){     Cellnum.new(4)>=Cellnum.new(3)}
test("cell num >= #2"){     Cellnum.new(4)>=Cellnum.new(4)}
test("cell num >= #2"){ not Cellnum.new(4)>=Cellnum.new(5)}

test("cell num not"){ Cellnum.new(4).not.not==4} 
test("cell num not"){ Cellnum.new(-4).not.not==-4} 
test("cell overflow positive #{Cellnum.new((2**47)).to_bin}"){ Cellnum.new(2**47)==-(2**47)} 
test("cell overflow negative"){ Cellnum.new(-(2**47))==-(2**47)} 
test("cell overflow negative"){ Cellnum.new(-(2**47)-1)==(2**47)-1} 


lines=[
[       "die",						"0"*48],
[       "ica",						"0"*42+																					"010001"],
[       "mov r1, 100",				"11"+"1"+"11".rjust(16,"0")+"11"+       "11"+"0"+"1100100".rjust(16,"0")+"11"+			"000001"],
[       "jmp 0b11",					"11"+"0"+"11".rjust(16,"0")+"11"+       "0"*21 +										"010011"],
[       "cmp 0x1 0b1",				"11"+"0"+"1".rjust(16,"0")+ "11"+       "11"+"0"+"1".rjust(16,"0") +"11"+				"011011"],
[       "cmp **ptr- *acc+",			"10"+"1"+"01".rjust(16,"0")+"10"+       "01"+"1"+"10".rjust(16,"0")+"01"+				"011011"]
       ]
lines.each{|line| 
    cmd,res=line
    test("Assemly #{cmd}") {Assembler.code_to_bin(Assembler.assemble(cmd))==res}
}
lines2=["foo bar", "cmp jmp foo"]
lines2.each{|line| 
    test("Incorrect Assembly #{line}") {
    valid = false;
    begin
        puts Assembler.code_to_bin(Assembler.assemble(line))
    rescue
        valid = true; 
    end
        valid
    }
}

cmds=["add r1 123","sub *r1 ptr-","cmp **ptr *ptr","jmp 123","ica","jmp -3"]
cmds.each do |cmd|
    test("Assembling and Dissassembling #{cmd}"){
        Disassembler.disassemble(
                Disassembler.bin_to_code(
                    Assembler.code_to_bin(
                        Assembler.assemble(cmd))))==cmd
        }
end
i=0
(1..99).each do |p|
    (0..10).each do
        i+=1
        str=""
        valid=false
        48.times do str+=(rand(100)>p)?"1":"0" end
        begin

        code=Disassembler.bin_to_code(str)
        dis=Disassembler.disassemble(code)
        as=Assembler.code_to_bin(
            Assembler.assemble(dis))
        valid=(as==str)
        if not valid 
            puts "str :#{str}"
            puts "code :#{code.inspect}"
            puts "as  :#{as}"
            puts "dis :#{dis}"
        end

        rescue Exception => e
        valid=true;
        end
        test("#{i}: Disassembling and Assembling #{str}"){valid}
    end
end

dislines=[
 "0"*48,
 "010001"+   "0"*42,
 "000001"+   "11"+"1"+"11".rjust(16,"0")+"11"+       "11"+"0"+"1100100".rjust(16,"0")+"11",
 "010011"+   "11"+"0"+"11".rjust(16,"0")+"11"+       "0"*21,
 "011011"+   "11"+"0"+"1".rjust(16,"0")+ "11"+       "11"+"0"+"1".rjust(16,"0") +"11",
 "011011"+   "10"+"1"+"01".rjust(16,"0")+"10"+       "01"+"1"+"10".rjust(16,"0")+"01"
       ]
    dislines.each{|line|
# puts Disassembler.bin_to_code(line).inspect
#        puts Disassembler.disassemble(Disassembler.bin_to_code(line)).inspect

    }
# interpreter test:
# richtiger unit test:
a = CoreThread.new(0,0,0)
interpreter = Interpreter.new(20)
i = 10
val = 42
a.eip = 3
#test immediate
interpreter.store([:immediate,:ptr,nil], a, i)
if(a.ptr != i) then raise "Immediate test failed" end
#test direct
interpreter.store([:direct,:ptr,nil],a,val)
if(interpreter.arena[a.ptr+a.eip].to_i != val) then raise "direct test failed" end
#test indirect 
interpreter.store([:indirect,:ptr,nil],a,val)

i=Interpreter.new(220)
$DEBUG=false

p=Player.new
p.split(0)
i.setCellNum(0,Assembler.code_to_bin(Assembler.assemble("jmp 23 *3+")).to_i(2),p)
i.setCellNum(23,Assembler.code_to_bin(Assembler.assemble("add ptr- *3-")).to_i(2),p)
i.run(1,p)
test("post inc for jumps"){i.getCellNum(3)==1 or puts i.getCellNum(3).inspect}
test("jumps work properly"){p.threads.first.eip==23 or puts p.threads.first.eip}
i.run(1,p)
test("post dec for add"){i.getCellNum(23+3)==-1 or puts i.getCellNum(23+3).inspect}
test("post dec for reg"){p.threads.first.ptr==-1}

#gui tests
i=Gui.new(220)

p=Player.new
p.playerID=0
p.split(0)
i.setCellNum(0,Assembler.code_to_bin(Assembler.assemble("mov ptr 2")).to_i(2),p)
i.setCellNum(1,Assembler.code_to_bin(Assembler.assemble("mov acc 0")).to_i(2),p)
i.setCellNum(2,Assembler.code_to_bin(Assembler.assemble("add ptr 1")).to_i(2),p)
i.setCellNum(3,Assembler.code_to_bin(Assembler.assemble("add acc 0")).to_i(2),p)
i.setCellNum(4,Assembler.code_to_bin(Assembler.assemble("mov *ptr acc")).to_i(2),p)
i.setCellNum(5,Assembler.code_to_bin(Assembler.assemble("jmp -3")).to_i(2),p)
q=Player.new
q.playerID=1
q.split(100)
i.setCellNum(100,Assembler.code_to_bin(Assembler.assemble("mov ptr 2")).to_i(2),q)
i.setCellNum(101,Assembler.code_to_bin(Assembler.assemble("mov acc 100")).to_i(2),q)
i.setCellNum(102,Assembler.code_to_bin(Assembler.assemble("sub ptr 6")).to_i(2),q)
i.setCellNum(103,Assembler.code_to_bin(Assembler.assemble("add acc 1")).to_i(2),q)
i.setCellNum(104,Assembler.code_to_bin(Assembler.assemble("mov *ptr acc")).to_i(2),q)
i.setCellNum(105,Assembler.code_to_bin(Assembler.assemble("jmp -3")).to_i(2),q)

$DEBUG=false
runs = 1000

begin
i.run(runs,p,q)
ensure
i.release
end

#100.times do
#i.run(1,p,q)
#puts p.inspect
#puts q.inspect
#puts i.arena.map{|x| (x.val==0)?0:1}.inspect
#gets
#end
#drawarena(i,runs, p,q)

