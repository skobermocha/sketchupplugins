require 'sketchup.rb'
require "extensions.rb"

# Load plugin as extension (so that user can disable it)

module SkoberCoders
	module ExportCBECC
		unless file_loaded?(__FILE__)
	      # Development
	      ex = SketchupExtension.new('DT Tools', '~/%userprofile%/Documents/Code Projects/sketchupplugins/DT-Tools/Plugins/DT-Tools/ExportCBECC')
	      # Production 
	      #ex = SketchupExtension.new('DT Tools', 'DT-Tools/ExportCBECC')
	      ex.description = 'Sends selected model to a CBECC-Res RIBD file.'
	      ex.version     = '1.1.0'
	      ex.copyright   = 'SkoberCoders 2022'
	      ex.creator     = 'SkoberCoders'
	      Sketchup.register_extension(ex, true)
	      file_loaded(__FILE__)
	    end
	end # module ExportCBECC
end # module SkoberCoders




