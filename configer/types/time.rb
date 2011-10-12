class Time
	def Time.to_config_s(val)
		val.to_s
	end

	def Time.from_config_s(val)
		Time.parse(val)
	end
end

