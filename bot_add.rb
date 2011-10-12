require 'socket'
require './compiler.rb'
require './disassembler.rb'

if ARGV.join(" ") =~ /-h/ or not (3..4)===ARGV.length
  puts "You seem to be in trouble, here is some help:
  usage: ruby bot_add.rb /path/to/bot_name.cw ipaddress_of_server [team_name] password"
  exit
end

puts ARGV.inspect
bot_file=ARGV[0]
server=ARGV[1]
if ARGV.length == 4
  group=ARGV[2]
  pass=ARGV[3]
elsif ARGV.length == 3
  pass=ARGV[2]
end

sock=TCPSocket.new(server,7125)
puts "warning, no header recieved" and exit if sock.gets!="CodeWars GameServer v:0.01\n"

lines=File.open(bot_file).lines
puts cmd=Compiler.compile(Compiler.preprocess(lines))

puts "binary of your bot:"
puts cmd

puts "internal representation of your bot:"
cmd.each do |e|
  puts Disassembler.bin_to_code(e).inspect
end

puts "disassembly of your code:"
cmd.each do |e|
  puts Disassembler.disassemble(Disassembler.bin_to_code(e)).inspect
end
code=cmd

lines=File.open(bot_file).lines.to_a
name=bot_file[/.*\/([^\/.]*)(\.[^\/])?/,1]
note=""

lines.grep(/;[\s]*name:(.*)\Z/) do
  puts "found name tag: #{$1}"
  name=$1.strip
end

lines.grep(/;desc:(.*)\Z/) do
  puts "found description tag: #{$1}"
  note=$1.strip
end

json=%({"group":#{group.to_s.inspect},"password":#{pass.to_s.inspect},"name":#{name.inspect},"code":#{code.inspect},"note":#{note.inspect}})
puts json
sock.puts json
puts sock.gets
sleep 0.1
