require 'sketchup.rb'
Sketchup::require 'DT-Tools/ExportCBECC.rb'

if( not file_loaded?("DT-Tools/DT-Tools.rb") )
	loadDTMenus(File.expand_path(File.dirname(__FILE__)))
end#if
file_loaded("DT-Tools/DT-Tools.rb")
