
def hash(string,seed=123)
	nums=[seed]+string.split("").map{|x| x[0]}
	rounds=16
	rounds.times do
		(nums.length).each do |i|
			nums[i]=(nums[i]*nums[(i-2)%nums.length])%256
		end
		nums=nums[nums.length/2..-1]+nums[0...nums.length/2]
	end
	chars="01234567890_.$%&/()abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ*+"
	nums.map{|x| chars[x%chars.length].chr}.join
end

loop do
	puts hash(gets)
end
