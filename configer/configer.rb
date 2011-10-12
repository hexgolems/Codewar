require 'configer/value.rb'
require 'configer/map.rb'

module Configer
	module DummyType
	end
#this class is a Tempalte for a config file. Create your own config file by deriving from this class and calling the value funktion to create the config options.
	class Template

	def self.name
		:name
	end

	def self.docu
		:docu
	end

	def self.type
		:type
	end

	def self.default
		:default
	end

#This function adds another config option to the configuration. If you call it without a block, a value will be added.
#  If you pass a block, a new category is added, then the is block executed, with all members created in this block being added to the new category. 
#@param [Hash] params params is a hash containing the different parameters for the new config option. Possible members for the hash are: ":name" maps to a String (mandatory) the name of the option, ":docu" maps to a String, this string is added to the config file documenting the config option, ":default" (not for categorys) maps to any value. If no config value is given in the config file, this value will be assigned to the option, ":type" (not for categorys) maps to any class (e.g. String) if given, the values for this option are typechecked. If the class Responds to .to_config_s and .from_config_s this class is serialized in the config file.
		def Template.value(params,&block)

			@root=@curr=Configer::Map.new({:name=>"root"},self) unless @root

			if !block
				@curr.add_value Configer::Value.new(params)
			else
				map=Configer::Map.new(params,self)
				@curr.add_value map
				oldcurr=@curr
				@curr=map
				block.call
				@curr=oldcurr
			end
		end

#sets the path to the config file
#@param [String] path the path to the config file (will get expanded - therefore the path can user ~ to access home etc.)
		def Template.config_path(path)
			@file_path=File.expand_path(path)
		end

#enables/disables the auto_write feature. If set, the config file will be written everytime the config strukture is changed.
#@param [Bool] enable This paramter decides if auto_write is enabled (defaults to true)
		def Template.auto_write(enable=true)
			@auto_write=enable
		end

#loads the config file, creating a new one, filled with the default values if the file does not exist jet.
		def Template.load
			raise "cannot load file withour file path, use config_path(path) to set it" unless @file_path
			begin
			string=File.read(@file_path)
			rescue 
				write
				return
			end
			struct=JSON.parse(string)
			autowrite,@auto_write=@auto_write,false #deactivate autowrite_while loading
			@root.from_hash(struct)
			@auto_write=auto_write
		end

#writes the config structure back to the config file
		def Template.write
			string=JSON.pretty_generate(@root)
			File.open(@file_path, 'w') {|f| f.write(string) }
		end

#returns the tree of config options
		def Template.get_tree
			@root
		end

#this function gets called everytime a option is changed. 
		def Template.update(node)
			write if @auto_write
		end

		def Template.method_missing(name,*params,&block)
			return @root.get_child(name.to_s) if @root.has_child?(name.to_s) and params==[] and block==nil
			super
		end
	end

end#end of module Configer
