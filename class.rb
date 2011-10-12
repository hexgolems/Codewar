class Class
    def class_attr *symb
        symb.each{|sym|
            module_eval "def self.#{sym}() @@#{sym} end"
            module_eval "def self.#{sym}=(x) @@#{sym}=x end"
        }
    end
end
