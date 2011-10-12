require 'compiler'
require 'disassembler'
lines=File.open(ARGV[0]).lines
puts cmp=Compiler.compile(Compiler.preprocess(lines))
cmp.each do |e|
	puts Disassembler.bin_to_code(e).inspect
end
cmp.each do |e|
	puts Disassembler.disassemble(Disassembler.bin_to_code(e)).inspect
end
