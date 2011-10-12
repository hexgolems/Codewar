puts "start"
instructions=`ruby1.9.1 fuzzer.rb`
puts "fuzzer done"

if $?.exitstatus != 0
  puts "error"
  file = File.open("fehler","a")
  file.puts(instructions)
  file.close
end
