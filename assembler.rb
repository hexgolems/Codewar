require "./cellnum.rb"
require "./class.rb"

class Assembler

class_attr :cmdnums, :cmds, :regnums, :regs

    #===============================================================================
    #will generate a intermediate code representation from a text line
    #e.g. [:cmd [:param1_type,param1_value,param1_op],[:param2_type,param2_value,param2_op]]
    def Assembler.assemble(linep)
  raise "invalid line" if not linep
    line=linep
    line.gsub!(/;.*$|,|[ \t]/," ")
    line.tr_s(" "," ");
    parts=line.split
    case parts.length
        when 1 then
            return [Assembler.assemble_cmd(parts[0]),nil,nil]
        when 2 then
            return [Assembler.assemble_cmd(parts[0]),Assembler.assemble_param(parts[1]),nil]
        when 3 then
            return [Assembler.assemble_cmd(parts[0]),Assembler.assemble_param(parts[1]),Assembler.assemble_param(parts[2])]
        else
        raise "failure, unknown instruction \"#{linep}\" in line: #{@@linenum}, unable to seperate into parts"
        end
    end

    #===============================================================================
    #will take a cmd as a string and return the symbol coresponding to this cmd or raise an error
    def Assembler.assemble_cmd(cmdp)
        if @@cmdnames.include? cmdp
            return @@cmdnames[cmdp]
        else
            raise "failure, unknown cmd \"#{cmdp}\" in line: #{@@linenum}"
        end
    end

    #===============================================================================
    #will take a param as string (e.g. "**ptr-") and generate a list representation
    # (e.g.) [:indirect,:ptr,:dec] or raise an error
    # {{{
    def Assembler.assemble_param(paramp)
        if paramp=~/^(\*|\*\*)?(-?[0-9]+|-?0b[01]+|-?0x[0-9a-f]+|ptr|acc|r1|r2)([+-]?)$/i then

            t,v,o=$1,$2,$3

            type=case t
                when "*" then  :direct
                when "**"then  :indirect
                else  :immediate
            end
            val=case v
                when 'ptr' then :ptr
                when 'acc' then :acc
                when 'r1'  then :r1
                when 'r2'  then :r2
                when /0x/  then v.to_i(16)
                when /0b/  then v.to_i(2)
                else v.to_i
            end

            op=case o
                when '+' then :inc
                when '-' then :dec
                when '' then nil
            end

            return [type,val,op]
        else
            raise "failure, unknown param \"#{paramp}\" in line#{@@linenum}"
        end
    end
    #}}}
    #===============================================================================
    #will take an intermediat representation from Assembler.assemble(line) and generate a 48 character
    #binary string representation
    def Assembler.code_to_bin(code) #output of Assembler.assemble
        cmd,param1,param2=code
        Assembler.param_to_bin(param1)+Assembler.param_to_bin(param2)+Assembler.cmd_to_bin(cmd)
    end
    #===============================================================================
    #will convert a cmd into the binary string representing cmd
    def Assembler.cmd_to_bin(cmd)
        return @@cmdnums[cmd].to_s(2).rjust(6,"0")
    end

    #===============================================================================
    #will convert a param into the binary string representing param
    def Assembler.param_to_bin(param)
        return "0"*21 if not param
        type, val, op = param
        type_bin=case type
            when :direct then "01"
            when :indirect then "10"
            when :immediate then "11"
        end

        val_bin,val_type=case val
            when Symbol then [@@regnums[val].to_s(2).rjust(16,"0"),"1"]
            when Fixnum then [Cellnum.to_16_bit(val),"0"]
            when Bignum then [Cellnum.to_16_bit(val),"0"]
        end

        op_bin=case op
            when :inc then "01"
            when :dec then "10"
            when nil then "11"
        end
        return type_bin + val_type + val_bin + op_bin
    end

    #setter for linenum
    def Assembler.linenum=(x);@@linenum=x;end

    #list of valid registers
    @@regs= [
                :free,
                :ptr,
                :acc,
                :r1,
                :r2
            ]

    @@regnums = {}
    @@regs.each_index do |regi|
        @@regnums[@@regs[regi]]=regi;
    end

    #list of valid commands
    @@cmds= [   :die,
                :mov,:mvp,:mva,
                :add,:sub,:mul,:div,:mod,:ada,:sba, :neg,
                :xor,:and,:not,:or,
                :inc,:dec,:ica,:dca,:jmp,
                :jie,:jia,:jis,
                :jne,:jna,:jns,
                :cmp,
                :splt,
                :cli,:rti,:sti,
                :mem,:cza,:clk
            ]

    @@cmdnums={}
    @@cmdnames={}

    @@cmds.each_index do |cmdi|
        @@cmdnames[@@cmds[cmdi].to_s]=@@cmds[cmdi]
        @@cmdnums[@@cmds[cmdi]]=cmdi;
#puts "#{@@cmds[cmdi]}:#{cmdi.to_s(2).rjust(6,"0")}"
    end
end
