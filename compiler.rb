require './assembler'

class Compiler

    def Compiler.preprocess(lines)
        lables={}
        vars={}

        offset=0
        linenum=1

        reg=/^(\*|\*\*)?(ptr|acc|r1|r2)([+-]?)$/i
        arith=/^(\*\*|\*)?((-?[0-9]+|-?0b[01]+|-?0x[0-9a-f]+|[+\-\/*^&|]|@\w+|\$\w+)+)[+-]?$/i

        lines=lines.map do |line|
            line.gsub!(/;.*/,"")
            line=line.strip

            if line=~/^:(\w*)[ \t]*(.*)$/
                lables["@"+$1]=offset
                line=$2.strip
            end

            cmd,p1,p2=line.gsub(/;.*$|,|[ \t]/," ").tr_s(" "," ").split
            valid=true

            begin 
                Assembler.assemble cmd
            rescue 
                valid=false
            end

            valid &= (!p1 || p1=~reg || p1=~arith)
            valid &= (!p2 || p2=~reg || p2=~arith)

            retval=[offset,linenum,cmd,p1,p2]

            if valid
                offset+=1
            end

            linenum+=1

            if line==""
                nil
            else
                retval
            end
        end
        lines.compact!

        lines.map! do |rep|
            o,linenum,cmd,p1,p2=rep
            lables.keys.sort_by{|s| s.length}.reverse.each do |key| #replace lables with descending length to avoid prefix problems (e.g. "lable" and "lablea"
				value=lables[key]
                cmd.gsub!(key,(value-o).to_s);
                p1 and p1.gsub!(key,(value-o).to_s);
                p2 and p2.gsub!(key,(value-o).to_s)
				end
            [o,linenum,cmd,p1,p2]
        end

        lines.map! do |rep|
            o,linenum,cmd,p1,p2=rep
            valid=true
            if cmd=~/(\$\w*)=(.*)/
                vars[$1]=Compiler.math_eval($2,vars,linenum)
                valid=nil
            end

            if p1=~arith
                pre,val,op=$1,$2,""
				val,op=$1,$2 if val=~/^(.*)([\-+])$/
					
                p1="#{pre}#{Compiler.math_eval(val,vars,linenum)}#{op}" 
            end

            if p2=~arith
                pre,val,op=$1,$2,""
				val,op=$1,$2 if val=~/^(.*)([\-+])$/

                p2="#{pre}#{Compiler.math_eval(val,vars,linenum)}#{op}" 
            end
            valid and [o,linenum,"#{cmd} #{p1} #{p2}".strip]
        end
        lines.compact!
		return lines
    end

    def Compiler.math_eval(expr,vars,linenum)
        vars.each_pair{|key,val| expr.gsub!(key,val.to_s)}
        raise "unknown variable #{$1} in #{linenum}" if expr=~/(\$\w*)/ 
        raise "invalid expression #{expr} in #{linenum}" if not expr =~/(-?(0x|0b)?[0-9]+|[*\/\-&^|])+/
        res=eval expr
		return res
    end

    def  Compiler.compile(preprocresult)
        preprocresult.map do |rep|
			offset,linenum,code=rep
			Assembler.linenum=linenum
			Assembler.code_to_bin(Assembler.assemble(code))
        end
    end

end
