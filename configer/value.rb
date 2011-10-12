module Configer
	class Value

		def get_name; @name; end
		def get_docu; @docu; end
		
		def has_valid_type?
			return	@type && @type.respond_to?(:to_config_s) && @type.respond_to?(:from_config_s)
		end

		def get_value; return @value; end

		def set_value(val)
			if @type && !val.is_a?(@type) && !@type.include?(Configer::DummyType)
				raise "invalid value #{val}(#{val.class}) for type #{@type}" 
			end
			return @value=val
			end

		def from_config_s(value)
			if	has_valid_type?() && value.is_a?(String)
				return @value=@type.from_config_s(value)
			end
			return @value=value
		end

		def to_config_s
			if	has_valid_type? && (@value.is_a?(@type) || @type.include?(Configer::DummyType))
					return @type.to_config_s(@value)
			end
			return @value
		end

		def to_json_hash
			h=Hash.new
			h["##{@name}_desc"]=@docu if @docu
			h[@name]=to_config_s
			return h
		end

		def initialize(params)
			@name,@type,@default,@value,@docu=nil,nil,nil,nil,nil
			params.each_pair do |key,value|
				case key
				when :name
					@name=value
				when :type
					@type=value
				when :default
					@default=value
					set_value(value)
				when :docu
					@docu=value
				else
					raise "unknown parameter Value#{key}"
				end
			end
		end

	end
end
