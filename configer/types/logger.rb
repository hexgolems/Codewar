require 'configer/configer.rb'
require 'logger'

#serialization
class Logger
	def Logger.to_config_s(val)
		val.instance_variable_get(:@logdev).filename
	end

	def Logger.from_config_s(filename)
		return Logger.new(filename)
	end
end

class LogLevel

	include Configer::Dummy

	def LogLevel.levels
		%w[DEBUG INFO WARN ERROR FATAL UNKNOWN]
	end

	def LogLevel.to_config_s(val)
		case val
			when (0..levels.length)
				levels[val]
			else
				val
		end
	end

	def LogLevel.from_config_s(val)
		begin 
			return Logger.const_get(val) if levels.include? val
		rescue
		end
		return val.to_i
	end
end
