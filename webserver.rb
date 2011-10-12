require "webrick"

s=WEBrick::HTTPServer.new(
        :BindAddress => "0.0.0.0",
        :Port => 8080,
        :DocumentRoot => File.dirname($0)+"/"+"www/"
)

trap("INT") { s.shutdown }

s.start
