
class Color

	def Color.hsvToRGB(h,s,v)
		hi = (h/60.0).floor % 6
		f = h/60.0 - (h/60.0).floor
		p = v * (1 - s)
		q = v * (1 - f * s)
		t = v * (1 - (1 - f) * s)
		rgb = []
		case hi
			when 0
				rgb = [v, t, p]
			when 1
				rgb = [q, v, p]
			when 2
				rgb = [p, v, t]
			when 3
				rgb = [p, q, v]
			when 4
				rgb = [t, p, v]
			when 5
				rgb = [v, p, q]
		end
		return rgb
	end

end

