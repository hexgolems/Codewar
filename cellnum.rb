class Cellnum

    attr_accessor  :owner
	attr_reader :code

    @@Size=48

    def initialize(x) 
		if x.is_a? Cellnum
			@val=x.val
			@code=x.code
		else
			@code=nil
			@val=Cellnum.to_bin_range(x.to_i,@@Size); 
		end
    end

	def val
		@val
	end

	def val=(v)
		@val=v
		@code=nil
	end

    def +(x)
        Cellnum.new(@val+x.to_i)
    end

    def -(x)
        Cellnum.new(@val-x.to_i)
    end

    def *(x)
        Cellnum.new(@val*x.to_i)
    end

    def /(x)
        Cellnum.new(@val/x.to_i)
    end

    def %(x)
        Cellnum.new(@val % x.to_i)
    end

    def &(x)
        Cellnum.new(@val & x.to_i)
    end

    def |(x)
        Cellnum.new(@val | x.to_i)
    end

    def ^(x)
        Cellnum.new(@val ^ x.to_i)
    end

    def not
        Cellnum.new( to_bin.tr("01","10").rjust(@@Size,"1").to_i(2))
    end

    def ==(x)
        @val==x.to_i
    end

    def <=(x)
        @val<=x.to_i
    end

    def >=(x)
        @val>=x.to_i
    end

    def >(x)
        @val>x.to_i
    end

    def <(x)
        @val<x.to_i
    end

    def to_i
		return @val
	end

    def to_s
		return "#"+@val.to_s
	end

    def to_bin
#Cellnum.to_bin(@val,@@Size)
        Cellnum.to_bin_48(@val)
    end

    def Cellnum.to_bin_48(x)
		y=to_bin_range_48(x);
        (y>=0)? format("%b",x).rjust(48,"0") : format("%b",x)[3..-1].rjust(48,"1"); 
    end

    def Cellnum.to_bin_range_48(x);
        x+=(140737488355328);
        x%=281474976710656;
        x-(140737488355328);
    end

    def Cellnum.to_bin(x,bits)
		y=to_bin_range(x,bits);
        (y>=0)? format("%b",x).rjust(bits,"0") : format("%b",x)[3..-1].rjust(bits,"1"); 
    end

    def Cellnum.to_bin_range(x,bits);
        p=2**bits;
        x+=(p>>1);
        x%=p;
        x-(p>>1);
    end

    def Cellnum.from_bin(x)
        if x[0..0]=="1" then
            return -(x.tr("01","10").to_i(2))-1
        else
            return x.to_i(2)
        end
    end

    def Cellnum.to_16_bit(x)
        to_bin(x,16)
    end

    def Cellnum.from_16_bit(x)
        from_bin(x)
    end

	def to_code()
		return @code if @code
        @code=Disassembler.bin_to_code(to_bin)
		return @code
	end

end
