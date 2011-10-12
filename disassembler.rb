require "./cellnum.rb"
require "./assembler.rb"

class Disassembler

    def Disassembler.disassemble(code)
        cmd,param1,param2=code
        return ("#{cmd} "+Disassembler.disassemble_param(param1)+" "+Disassembler.disassemble_param(param2)).strip
    end

    def Disassembler.disassemble_param(param)
        return "" if not param
        type,val,op = param
        str_type = case type 
            when :indirect then "**"
            when :direct then "*"
            else ""
            end
        str_op = case op
            when :inc then "+"
            when :dec then "-"
            else ""
            end
        return str_type + "#{val}"+str_op
    end

    def Disassembler.bin_to_code(bin)

        raise "Dissambler failed at bin_to_code invalid data: #{bin}" if not
            bin=~/([01]{2})([01])([01]{16})([01]{2})([01]{2})([01])([01]{16})([01]{2})([01]{6})/

        param1=$~[1..4]
        param2=$~[5..8]
        cmd=$~[9]
        code = [Disassembler.bin_to_cmd(cmd),Disassembler.bin_to_param(param1),Disassembler.bin_to_param(param2)]
        raise "Dissasembler failed  because of unexpected nonempty second param"if code[1]==nil &&  code[2]!=nil 
        return code
    end

    def Disassembler.bin_to_cmd(bin)
        index=bin.to_i(2)
        if (0...Assembler.cmds.length)===index then
            return Assembler.cmds[index]
        else
            raise "Disassembling failed at bin_to_cmd invalid data: #{bin}"
        end
    end

    def Disassembler.bin_to_param(param)
        bin_type,bin_val_type,bin_val,bin_op=param

        return nil if ["00","0","0"*16,"00"]==param


        type = case bin_type
            when "00" then raise "Disassembly failed: unknown bin_type 00"
            when "01" then :direct
            when "10" then :indirect
            when "11" then :immediate
        end

        if bin_val_type == "1" then
            if (0...Assembler.regs.length)===bin_val.to_i(2)  then
                    val = Assembler.regs[bin_val.to_i(2)]
            else raise "Disassembler failed at bin_val_type: invalid register #{bin_val.to_i(2)}"
                    Assembler.regs[bin_val.to_i(2)]
            end
        elsif bin_val_type == "0" then
                val = Cellnum.from_16_bit(bin_val)
        else 
                raise "Disassembler is really angry! srsly this should never happen"
        end

        op = case bin_op
            when "00" then raise "Disassembly failed: unknown bin_op 00"
            when "01" then :inc
            when "10" then :dec
            when "11" then nil
        end

        return type,val,op
    end

end
