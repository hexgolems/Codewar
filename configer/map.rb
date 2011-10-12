module Configer
  class Map

    def initialize(params,config)
      @children={}
#puts "Map.new with #{config.inspect}"
      @config=config
      @name,@docu=nil,nil
      params.each_pair do |key,value|
        case key
        when :name
          @name=value
        when :docu
          @docu=value
        else
          raise "unknown parameter for a Map #{key}"
        end
      end
    end

    def get_name; @name; end
    def get_docu; @docu; end
    def get_children; @children; end

    def get_child(name)
      child=@children[name]
      if child.is_a?(Value)
        return child.get_value
      end
      return child
    end

    def to_json(*a)
      hash=Hash.new
      @children.each_pair do |k,v|
        if v.is_a? Value
          v.to_json_hash.each_pair{|vk,vv| hash[vk]=vv}
        elsif v.is_a? Map
          hash["##{v.get_name}_desc"]=v.get_docu if v.get_docu
          hash[k]=v
        end
      end
      return hash.to_json(*a)
    end

    def from_hash(hash)
      raise "from hash can only be called with a Hash" unless hash.is_a? Hash
      hash.each_pair do |key,val|
        if @children.include? key and @children[key].is_a? Map and val.is_a? Hash
          @children[key].from_hash(val)
        elsif @children.include? key and @children[key].is_a? Value
          @children[key].from_config_s(val)
        elsif key=~/\A#.*_desc\Z/
        else
          raise "unknown config option #{key}:#{val}"
        end
      end
    end

    def has_child?(name)
      @children.include? name
    end
    def add_value(other)
      @children[other.get_name]=other
    end

    def method_missing(name,*params,&block)

      name_s=name.to_s

      if has_child?(name_s) and params==[] and block==nil
        return get_child(name_s)
      end

      if name_s=~/[^=]+=\Z/
        if has_child?(name_s[0..-2]) and params.length==1 and block==nil
          child=@children[name_s[0..-2]]
          raise "cannot set value for a config categorie" unless child.is_a? Value
          child.set_value(params[0])
          @config.update(child)
          return params[0]
        end
      end

      super
    end
  end
end
