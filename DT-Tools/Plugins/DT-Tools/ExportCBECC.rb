# This script gathers area data from the selected objects in Sketchup
# and exports to 2013 CBECC Res .ribd file.
# Author : Jeremiah Ellis
# Date	: 08/29/2016
# Ver	 : 1.0


# these help convert from inches to feet and feet squared.
@area_divisor = 144 
@length_divisor = 12

# Initialise menu system for DT_Tools
def loadDTMenus(mePath)
	dtTools = UI.menu("PlugIns").add_submenu("DT Tools") 
	#dirtomenu(formatpath , dtTools)
	
	
	if (dtTools)
		#Add Menu Items list string, Method to call
			dtTools.add_item("Export to CBECC") { getMaterialData(Sketchup.active_model) }
	else
		UI.messagebox "Failure creating Menu."
	end
end #loadDTMenus

def initData
	@mats.clear # Material names
	@areas.clear # total area of above material
	@orients.clear # angle of material
	@angles.clear
	@windows.clear
	@win_areas.clear
	@win_orients.clear
	@win_angles.clear
	@win_wall.clear
	@win_wall_types.clear
	@win_wall_totals.clear
	@fdtn_length.clear # length of fdtn section
	@fdtn_height.clear # height of above fdtn section derived from its area
	@fdtn_loc.clear # location of above section
	@fdtn_area.clear 
	@envelope = 0 # total envelope area
	@conditioned1st = 0
	@conditioned2nd = 0
	@conditioned3rd = 0
	@unconditioned = 0
	@slab_name.clear
	@slab_onGrade.clear # length of slab edge on grade.
	@slab_perimeter.clear # total boundary of slab
	@slab_exposed.clear # exposed edge of slab
	@slab_belowGrade.clear # depth slab is below top of fdtn
	@slab_area.clear # area of individual slab
end #initData

def getAngle(face)
	normal = face.normal
  	return 0 if normal.x == 0 and normal.y == 0
  	normal.z = 0
  	angle = normal.angle_between(Geom::Vector3d.new(0,-1,0)).radians
  	angle = 360-angle if normal.x < 0
  	angle = round(angle)
  	return angle
end #getAngle

def whatMaterial (face)	
	#if face.typename == "Face"
		angle=0
		angleOut = '0'
		orient = 'Front'

		front = face.material
		back = face.back_material
		area = face.area

		angle = getAngle(face)

		case angle.to_s
		when '0'
			angleOut = '0'
		when '90'
			angleOut = '270'
			orient = 'Right'
  		when '180'
  			angleOut = '180'
  			orient = 'Back'
  		when '270'
  			angleOut = '90'
  			orient = 'Left'
  		else
  			angleOut = angle.to_s
  			orient = angle.to_s
  		end

		if not front and back # check its not inverted...
			face.material= back
			face.back_material= nil
			face.reverse!
		else
			if front and back #Material on both sides.
				if sprintf("%.3s", back.display_name).eql?('sla') or sprintf("%.3s", back.display_name).eql?('FFl') #or sprintf("%.4s", back.display_name).eql?('Cond') or sprintf("%.7s", back.display_name).eql?('GarageA')
					face.back_material= front
					face.material= back
					face.reverse!
				end #if

				addMaterial(face.back_material.display_name, area, orient, angleOut)
			end #if
		end

		if front = face.material
			mat_name = front.display_name
			puts mat_name
			case mat_name
			when "win_Oper", "win_Fixed", "win_SGD", "win_FRD", "win_Door"
				wallIn = orient + "_" + getWallFace(face)
				addWindow(mat_name, area, wallIn)
			else
				addMaterial(mat_name, area, orient, angleOut)
			end
			# Get slab data; boundary, on-grade etc.
			getSlabBoundary(face) if mat_name == "slab_Living" or mat_name == "slab_Garage"

		end #if
	#end #if
end #WhatMaterial

def addMaterial(nameIn, areaIn, orientIn, angleIn)
	#puts 'Add Material: ' + orientIn + '_' + nameIn
	at = @mats.length
	anew = true
	unless sprintf("%.3s",nameIn) == 'sla'
		# Go through total list and add in new area.
		while at > 0 and anew == true
			at -= 1
			if @mats[at] == nameIn and @orients[at] == orientIn
				@areas[at] += areaIn
				@orients[at] = orientIn
				@angles[at] = angleIn
				anew = false
			end #if
		end #while
	end #unless
	if anew
		@mats.push nameIn
		@areas.push areaIn
		@orients.push orientIn 
		@angles.push angleIn
	end #if
end #addMaterial

def getWallFace(windowFace)
	# win_area = 0
	# @window_name.push windowFace.material.display_name
	# @window_area.push windowFace.area
	#fnum = @window_area.length-1 # number of windows currently in list.
	windowEdges = windowFace.edges

	windowFaceName = windowFace.material.display_name
	# if windowFaceName.index('Window')
		# Exposed and on-grade edge; all edges not attached to other slab or to ftd to bsmt/crawl
		windowEdges.each{|bEdg|
			bEdg.faces.each{|wallFace|
				if wallFace.material != nil
					case wallFace.material.display_name
					when "win_Oper", "win_Fixed", "win_SGD", "win_FRD", "win_Door"
						puts "win_wall: " + wallFace.material.display_name
					else
						puts "win_wall: " + wallFace.material.display_name
						return wallFace.material.display_name
					end
					
				end
			}
		}
	
	# end # on_grade
end #getWallFace

def addWindow(nameIn, areaIn, wallIn)
	
		@windows.push nameIn
		@win_areas.push areaIn
		@win_wall.push wallIn


		at = @win_wall_types.length
		anew = true
			# Go through total list and add in new area.
			while at > 0 and anew == true
				at -= 1
				if @win_wall_types[at] == wallIn
					@win_wall_totals[at] += areaIn
					anew = false
				end #if
			end #while
		if anew
			@win_wall_types.push wallIn
			@win_wall_totals.push areaIn
		end #if
end #addWindow

def getWinTotals(wallFace, orient)
	at = @win_wall_types.length
	# Go through total list and add in new area.
	while at > 0
		at -= 1
		if @win_wall_types[at] == orient + '_' + wallFace
			if @win_wall_totals[at] != nil
				return @win_wall_totals[at]
			else
				return 0
			end
		end #if

	end #while
	return 0
end #getWinTotals

def addStep(aLen, aHgt, aLoc, aArea)
	at = @fdtn_height.length
	anew = true
	# Go through total list and add in new area.
	while at > 0 and anew == true
		at -= 1
		if round(@fdtn_height[at]) == round(aHgt) and @fdtn_loc[at].eql?(aLoc.to_s)
			@fdtn_length[at] += aLen
			@fdtn_area[at] += aArea
			anew = false
		end #if
	end #while
	if anew
		@fdtn_height.push aHgt
		@fdtn_length.push aLen
		@fdtn_loc.push aLoc.to_s
		@fdtn_area.push aArea
	end #if
end #addStep

def getSlabBoundary(baseFace)
	bg_area = 0 # total area of fdtn wall used to calc height
	bg_length = 0 # total length of fdtn wall used to calc height
	@slab_name.push baseFace.material.display_name
	@slab_area.push baseFace.area
	@slab_onGrade.push 0
	@slab_exposed.push 0
	@slab_perimeter.push 0
	@slab_belowGrade.push 0
	fnum = @slab_area.length-1 # number of slabs currently in list.
	baseEdges = baseFace.edges

	# Calculate slab perimeter
	baseEdges.each{|edg| @slab_perimeter[fnum] += edg.length}
		
	# what type of slab are we working with
	baseFaceName = baseFace.material.display_name
	if baseFaceName.index('onGrade')
		# Exposed and on-grade edge; all edges not attached to other slab or to ftd to bsmt/crawl
		baseEdges.each{|bEdg|
			bEdg.faces.each{|wallFace|
				ignore = 0
				if wallFace.material != nil
					# is it connected to another slab or we have navigated back to self
					ignore = 1 if wallFace.material.display_name.index('Bsmt') or 
									wallFace.material.display_name.index('onGrade') or 
									wallFace.material.display_name.index('Party') or
									wallFace.material.display_name.index('ToGarage')
					# is it connected to fdtn thats connected to bsmt or crawl
					if wallFace.material.display_name.index('Fdt')
						wallFace.edges.each{|wallEdge| 
							wallEdge.faces.each{|f| 
								if f.material != nil
									ignore += 1 if f.material.display_name.index('Bsmt') or f.material.display_name.index('Crawl')
								end 
							}
						}
					end
					if ignore == 0
						# extent of exposed edge is determined by where rater draws line.
						@slab_exposed[fnum] += bEdg.length
						addStep(bEdg.length, (wallFace.area/bEdg.length), wallFace.material.display_name, wallFace.area) if sprintf("%.3s",wallFace.material.display_name) == 'Fdt'
					end
						
				end
			}
		}
		@slab_onGrade[fnum] = @slab_exposed[fnum]
	else
		if baseFaceName.index('Crawl')
			# exposed edge is all edges that have faces not attached to another slab_Bsmt, include those to on_grade
			baseEdges.each{|bEdg|
				bEdg.faces.each{|wallFace|
					ignore = 0
					# we only need to check fdtn walls for connection to other slab.
					if wallFace.material != nil  and 
						baseFace.entityID != wallFace.entityID and 
						wallFace.material.display_name.index('Fdt') and 
						not wallFace.material.display_name.index('Party')
						wallFace.edges.each{|wallEdge| 
							wallEdge.faces.each{|f| 
								if f.material != nil
									ignore += 1 if f.material.display_name.index('Bsmt')
								end 
							}
						}
						if ignore == 0
							@slab_exposed[fnum] += bEdg.length
							bg_length += bEdg.length
							bg_area += wallFace.area
							addStep(bEdg.length, (wallFace.area/bEdg.length), wallFace.material.display_name, wallFace.area)
						end
						# on grade are edges that connect to agw
						@slab_onGrade[fnum] += bEdg.length if sprintf("%.3s", wallFace.material.display_name) == 'AGW'
					end
				}
			}
			@slab_belowGrade[fnum] = bg_area/bg_length
		else
			if baseFaceName.index('Bsmt')
				# go round all the edges connected to this face.
				baseEdges.each{|bEdg|
					# go through all the faces attached to this edge.
					bEdg.faces.each{|wallFace|
						# other attached face that is not this, conditioned, empty
						if wallFace.material != nil and baseFace.entityID != wallFace.entityID and sprintf("%.3s", wallFace.material.display_name) != 'Flr' and sprintf("%.3s", wallFace.material.display_name) != 'FlrGar'
							ignore = 0
							# To calc the fdtn height we need to ignore any wall that connects to a crawl
							wallFace.edges.each{|wallEdge| 
								wallEdge.faces.each{|f| 
									if f.material != nil
										ignore += 1 if f.material.display_name.index('Crawl')
									end 
								}
							}
							if ignore == 0
								bg_length += bEdg.length
								bg_area += wallFace.area 
							end
							# exposed edge all edges not connected to other slab
							@slab_exposed[fnum] += bEdg.length if sprintf("%.3s", wallFace.material.display_name) != 'sla' and wallFace.material.display_name.index('Party') == nil
							# on grade are edges connected to agw
							@slab_onGrade[fnum] += bEdg.length if sprintf("%.3s", wallFace.material.display_name) == 'AGW'
							# Calc steps in foundation wall connected to edge.
							addStep(bEdg.length, (wallFace.area/bEdg.length), wallFace.material.display_name, wallFace.area) if sprintf("%.3s", wallFace.material.display_name) == 'Fdt'
						end
					}
				}
				# Below grade height, sum of fdtn edges not attached to other slabs divided into their attached fdtn wall areas.
				@slab_belowGrade[fnum] = bg_area/bg_length
			end # Bsmt
		end # crawl
	end # on_grade
end #slabBooundry

def round(numb)
	sprintf("%.0f", numb)
end #round

def getWindows(wallFace, wallOrient)
	windows_out = ''
	at = @windows.length() -1
	puts wallOrient + '_' + wallFace
	
	#loop through windows and output the data for each window attached to the wallFace we are working with into our string variable
	while at > -1
		if @win_wall[at] == wallOrient + '_' + wallFace
			case @windows[at].to_s
			when "win_Door"
				windows_out += '
				Door	"Door_' + at.to_s + '"  
					Status = "New"
					IsVerified = 0
					Area = ' + @win_areas[at]/@area_divisor +'
					Ufactor = 0.5
					exUfactor = 0.5
					..
				'
				puts "Door_" + at.to_s
			else
				windows_out += '
				Win	"Win_' + at.to_s + '"  
					Status = "New"
					IsVerified = 0
					SpecMethod = "Overall Window Area"
					Area = ' + @win_areas[at]/@area_divisor +'
					Multiplier = 1
					WinType = "' + @windows[at] + '"
					exArea = '+ @win_areas[at]/@area_divisor +'
					exMultiplier = 1
					exUfactorSHGCSource = "NFRC"
					exExteriorShade = "Insect Screen (default)"
					ModelFinsOverhang = 0
					OverhangDepth = 0
					OverhangDistUp = 0
					OverhangExL = 0
					OverhangExR = 0
					OverhangFlap = 0
					exOverhangDepth = 0
					exOverhangDistUp = 0
					exOverhangExL = 0
					exOverhangExR = 0
					exOverhangFlap = 0
					LeftFinDepth = 0
					LeftFinTopUp = 0
					LeftFinDistL = 0
					LeftFinBotUp = 0
					exLeftFinDepth = 0
					exLeftFinTopUp = 0
					exLeftFinDistL = 0
					exLeftFinBotUp = 0
					RightFinDepth = 0
					RightFinTopUp = 0
					RightFinDistR = 0
					RightFinBotUp = 0
					exRightFinDepth = 0
					exRightFinTopUp = 0
					exRightFinDistR = 0
					exRightFinBotUp = 0
					..
				'
				puts "Win_" + at.to_s
			end #when
		end
		at -= 1
	end

	#return our string variable
	return windows_out
end #getWindows

def outCBECCdata (user_input)
	
	#determine which CBECC version user has requested
	case user_input[0] 
	when "CA Res 2013"
		filetype = '.ribd'
		standardVersion = "Compliance 2015"
		refrigeff = "default (669 kWh/yr)"
	when "CA Res 2016"
		filetype = '.ribd16'
		standardVersion = "Compliance 2017"
		refrigeff = "from # bedrooms/unit"
	else
		filetype = '.ribd'
		standardVersion = "Compliance 2015"
		refrigeff = "default (669 kWh/yr)"
	end
	puts filetype


	filepath = Sketchup.active_model.path
	puts filepath
	if (RUBY_PLATFORM.downcase =~ /darwin/) == nil
		#Windows Machine
		savelocation = File.join(File.dirname( filepath ), File.basename(filepath, '.skp') + filetype).gsub(%r{/}) { "\\" }
	else
		#not windows, so we dont need to convert file path delimiters
		savelocation = File.join(File.dirname( filepath ), File.basename(filepath, '.skp') + filetype)
	end
	puts savelocation
	out_file = File.new(savelocation, "w")


	if out_file
		
	####this is default file requirements
		out_file.puts('
			RulesetFilename	"' + user_input[0] + '.bin"

			Proj	"' + user_input[1] + '"  
				SoftwareVersion = "CBECC-Res 2013-4b (812)"
				BEMVersion = 5
				CreateDate = 1472056558
				ModDate = 1472056726
				AnalysisType = "Proposed and Standard"
				StandardsVersion = "' + standardVersion + '"
				AnalysisReport = "Building Summary (csv)"
				ComplianceReportPDF = 1
				ComplianceReportXML = 1
			')

			#if user selected CBECC 2016 file, we need to inject this stuff too.
			if user_input[0] == "CA Res 2016"
				out_file.puts('
				PVCompCredit = 0
				PVWInputs = "Simplified"
				PVWDCSysSize = ( 0, 0, 0, 0, 0 )
				PVWModuleType = ( "Standard", "Standard", "Standard", "Standard", 
					"Standard" )
					PVWCalFlexInstall = ( 1, 1, 1, 1, 1 )
					PVWArrayTiltInput = ( "deg", "deg", "deg", "deg", "deg" )
					')
				end	 

		#continue default file stuff
			out_file.puts('  
				SimSpeedOption = "Compliance"
				DesignRatingCalcs = 0
				DRtgLtgCredit = 0
				DRtgLtgReduction = 0
				CAHPProgram = "California Advanced Homes Program Single Family (CAHP)"
				IsCAHPElecUtil = 1
				IsCAHPNGasUtil = 1
				IsCAHPDOEChalHome = 0
				IsCAHPFutureCode = 0
				ClimateZone = "' + user_input[5] + '"
				Address = "' + user_input[2] + '"
				ZipCode = ' + user_input[4] + '
				RunScope = "Newly Constructed"
				City = "' + user_input[3] + '"
				IsMultiFamily = 0
				CentralMFamLaundry = 0
				ZonalControl = 0
				ACH50 = 5
				Status = "New"
				IsVerified = 0
				IsAddAlone = 0
				AlterIncl2Categs = 0
				InsulConsQuality = "Standard"
				NumBedrooms = ' + user_input[7] + '
				NumAddBedrooms = 0
				AllOrientations = 1
				FrontOrientation = 0
				NatGasAvailable = 1
				GasType = "Natural Gas"
				HasGarage = 1
				UnitIAQOption[1] = "Default Minimum IAQ Fan"
				UnitIAQFanCnt1[1] = 1
				UnitIAQFanCnt2[1] = 1
				UnitIAQFanCnt3[1] = 1
				UnitIAQFanCnt4[1] = 1
				UnitClVentOption = "- none -"
				UnitClVentLowArea = 0
				Appl_HaveRefrig[1] = 1
				Appl_HaveDish[1] = 1
				Appl_HaveCook[1] = 1
				Appl_HaveWasher[1] = 1
				Appl_HaveDryer[1] = 1
				ApplCookFuel[1] = "Electricity"
				ApplDryerFuel[1] = "Electricity"
				Appl_RefrigUsage[1] = 669
				ApplRefrigEffMethod[1] = "' + refrigeff + '"
				ApplDishUsageMethod[1] = "from # bedrooms/unit"
				..

			Zone	"Living Area"  
				Type = "Conditioned"
				Status = "New"
				HVACSysStatus = "New"
				HVACSysVerified = 0
				HVACSystem = "HVAC System 1"
				DHWSys1Status = "New"
				DHWSys1Verified = 0
				DHWSys1 = "DHW System 1"
				DHWSys2Status = "New"
				DHWSys2Verified = 0
				WinHeadHeight = 7.67
				Bottom = 0
				FloorArea = ' + user_input[6] + '
				NumStories = ' + user_input[8] + '
				CeilingHeight = ' + user_input[9] + '
				..
			')
	### Defaults End	

	##### Living Area Zone Looping through faces and determine material painted on.
		mat_out = ''
		at = @mats.length() -1
	
		while at > -1
			mat_out = @mats[at] 
		
			#determine what material we are working with
			case @mats[at].to_s
			when '2x4ExtWall-Stucco'
				out_file.puts('
				ExtWall	"'+ @orients[at] + '_' + mat_out + '"
						Status = "New"
						IsVerified = 0
						Construction = "2x4 Ext Wall -Stucco"
						Orientation = "' + @orients[at] + '"
						OrientationValue = ' + @angles[at] + '
						Tilt = 90
						Area = ' + round(@areas[at]/@area_divisor + getWinTotals(mat_out, @orients[at])/@area_divisor)  +'
						..
					')

					out_file.puts(getWindows mat_out, @orients[at])

			when '2x6ExtWall-Stucco'
				out_file.puts('
				ExtWall	"'+ @orients[at] + '_'  + mat_out + '"
						Status = "New"
						IsVerified = 0
						Construction = "2x6 Ext Wall -Stucco"
						Orientation = "' + @orients[at] + '"
						OrientationValue = ' + @angles[at] + '
						Tilt = 90
						Area = ' + round(@areas[at]/@area_divisor + getWinTotals(mat_out, @orients[at])/@area_divisor)  +'
						..
					')
					
					out_file.puts(getWindows mat_out, @orients[at])

			when '2x4ExtWall-Siding'
				out_file.puts('
				ExtWall	"'+ @orients[at] + '_'  + mat_out + '"
						Status = "New"
						IsVerified = 0
						Construction = "2x4 Ext Wall -Siding"
						Orientation = "' + @orients[at] + '"
						OrientationValue = ' + @angles[at] + '
						Tilt = 90
						Area = ' + round(@areas[at]/@area_divisor + getWinTotals(mat_out, @orients[at])/@area_divisor)  +'
						..
					')
					
					out_file.puts(getWindows mat_out, @orients[at])

			when '2x6ExtWall-Siding'
				out_file.puts('
				ExtWall	"'+ @orients[at] + '_' + mat_out + '"
						Status = "New"
						IsVerified = 0
						Construction = "2x6 Ext Wall -Siding"
						Orientation = "' + @orients[at] + '"
						OrientationValue = ' + @angles[at] + '
						Tilt = 90
						Area = ' + round(@areas[at]/@area_divisor + getWinTotals(mat_out, @orients[at])/@area_divisor)  +'
						..
					')
					
					out_file.puts(getWindows mat_out, @orients[at])

			when '2x4ToGarageWall'
				out_file.puts('
				IntWall	"'+ @orients[at] + '_' + mat_out + '"
						Status = "New"
						IsVerified = 0
						Construction = "2x4 ToGarage Wall"
						IsPartySurface = 0
						OtherSideModeled = 0
						Outside = "Garage"
						Area = ' + round(@areas[at]/@area_divisor + getWinTotals(mat_out, @orients[at])/@area_divisor)  +'
						..
					')
			when '2x6ToGarageWall'
				out_file.puts('
				IntWall	"'+ @orients[at] + '_' + mat_out + '"
						Status = "New"
						IsVerified = 0
						Construction = "2x6 ToGarage Wall"
						IsPartySurface = 0
						OtherSideModeled = 0
						Outside = "Garage"
						Area = ' + round(@areas[at]/@area_divisor + getWinTotals(mat_out, @orients[at])/@area_divisor)  +'
						..
					')
			when 'KneeWall'
				out_file.puts('
				IntWall	"'+ @orients[at] + '_' + mat_out + '"
						Status = "New"
						IsVerified = 0
						Construction = "Knee Wall"
						IsPartySurface = 0
						OtherSideModeled = 0
						Area = ' + round(@areas[at]/@area_divisor) + '
						..
					')
			when 'PartyWall'
				out_file.puts('
				IntWall	"'+ @orients[at] + '_' + mat_out + '"
						Status = "New"
						IsVerified = 0
						Construction = "Party Wall"
						IsPartySurface = 1
						OtherSideModeled = 0
						Area = ' + round(@areas[at]/@area_divisor) + '
						..
				')
			when 'CeilingBelowAttic'
				##### Have to Create Attic Space first!!!!
				out_file.puts('
				CeilingBelowAttic	"CLG_Living"  
						Status = "New"
						IsVerified = 0
						Construction = "Ceiling"
						AtticZone = "Attic_Living"
						Area = ' + round(@areas[at]/@area_divisor) + '
						..

					Attic	"Attic_Living"  
						Type = "Ventilated"
						Status = "New"
						IsVerified = 0
						RoofRise = 5
						Construction = "Roof Deck"
						RoofSolReflect = 0.1
						RoofEmiss = 0.85
						..
					')
				when 'CeilingCathedral'
				out_file.puts('
				CathedralCeiling	"' + mat_out + '"  
						Status = "New"
						RoofRise = 5
					Orientation = "Front"
					OrientationValue = 0
					Construction = "Cathedral"
					RoofSolReflect = 0.1
					RoofEmiss = 0.85
						Area = ' + round(@areas[at]/@area_divisor) + '
						..
					')
				when 'FloorToGarage'
					out_file.puts('
					InteriorFloor	"' + mat_out + '"  
						Status = "New"
						IsVerified = 0
						Area = ' + round(@areas[at]/@area_divisor) + '
						FloorZ = ' + user_input[9] + '
						Construction = "Floor to Garage"
						IsPartySurface = 0
						OtherSideModeled = 0
						Outside = "Garage"
						..
					')
			when 'FloorToOutside'
				out_file.puts('
					ExteriorFloor	"' + mat_out + '"  
						Type = "Raised Light Floor"
						Status = "New"
						IsVerified = 0
						Area = ' + round(@areas[at]/@area_divisor) + '
						FloorZ = ' + user_input[9] + '
						Construction = "Floor to Outside"
						..
					')
			when 'FloorToCrawlspace'
				out_file.puts('
					FloorOverCrawl	"' + mat_out + '"  
						Status = "New"
						IsVerified = 0
						Area = ' + round(@areas[at]/@area_divisor) + '
						FloorZ = 0
						Construction = "Crawlspace"
						..

					CrawlSpace	"Crawl Space zn"  
						Type = "Normal (vented)"
						Perimeter = 140.513
						AvgWallHeight = 2
						..
					')
			when  'Zone_Living'
				@conditioned = round(@areas[at]/@area_divisor)
			when 'Zone_Garage'
				@unconditioned = round(@areas[at]/@area_divisor)
			end #case

			at -= 1
		end #while

		# go through each slab outputing its details.
		for at in 0..(@slab_area.length-1)
			case @slab_name[at]
			when 'slab_Living'
			out_file.puts('
			SlabFloor	"' + @slab_name[at] + '"  
				Status = "New"
				IsVerified = 0
				Surface = "Default (80% carpeted/covered, 20% exposed)"
				Area = ' + round(@slab_area[at]/@area_divisor) + '
				Perimeter = ' + round(@slab_perimeter[at]/@length_divisor) + '
				HeatedSlab = 0
				EdgeInsulation = 0
				EdgeInsulOption = "R-5, 8 inches"
				exSurface = "Default (80% carpeted/covered, 20% exposed)"
				exEdgeInsulOption = "R-5, 8 inches"
				..
			')
			end
		end #for
	### Living Area End

	##### Garage Looping through faces and determine material painted on.
		volume = user_input[9].to_i * @unconditioned.to_i
		out_file.puts ('
			Garage	"Garage"  
				Area = ' + @unconditioned.to_s + '
				Volume = ' + volume.to_s + '
				Bottom = 0
					..
				')

		mat_out = ''
		at = @mats.length() -1
	
		while at > -1
			mat_out = @mats[at] 
			
			case @mats[at].to_s #sprintf("%.6s", @mats[at].to_s)
			when 'GarExtWall-Stucco'
				out_file.puts('
				ExtWall	"'+ @orients[at] + '_' + mat_out + '"
						Status = "New"
						IsVerified = 0
						Construction = "Gar Ext Wall -Stucco"
						Orientation = "' + @orients[at] + '"
						OrientationValue = ' + @angles[at] + '
						Tilt = 90
						Area = ' + round(@areas[at]/@area_divisor + getWinTotals(mat_out, @orients[at])/@area_divisor)  +'
						..
					')

					out_file.puts(getWindows mat_out, @orients[at])
			when 'GarExtWall-Siding'
				out_file.puts('
				ExtWall	"'+ @orients[at] + '_' + mat_out + '"
						Status = "New"
						IsVerified = 0
						Construction = "Gar Ext Wall -Siding"
						Orientation = "' + @orients[at] + '"
						OrientationValue = ' + @angles[at] + '
						Tilt = 90
						Area = ' + round(@areas[at]/@area_divisor + getWinTotals(mat_out, @orients[at])/@area_divisor)  +'
						..
					')

				out_file.puts(getWindows mat_out, @orients[at])

			when 'CeilingAtGarage'
				##### Have to Create Attic Space first!!!!
				out_file.puts('
				CeilingBelowAttic	"CLG_Garage"  
						Status = "New"
						IsVerified = 0
						Construction = "Ceiling at Garage"
						AtticZone = "Attic_Garage"
						Area = ' + round(@areas[at]/@area_divisor) + '
						..

					Attic	"Attic_Garage"  
						Type = "Ventilated"
						Status = "New"
						IsVerified = 0
						RoofRise = 5
						Construction = "Roof Deck at Garage"
						RoofSolReflect = 0.1
						RoofEmiss = 0.85
						..
					')
			end
			at -= 1
		end #while

		# go through each slab outputing its details.
		for at in 0..(@slab_area.length-1)
			case @slab_name[at]
			when 'slab_Garage'
				out_file.puts('
				SlabFloor	"' + @slab_name[at] + '"  
					Status = "New"
					IsVerified = 0
					Surface = "Default (80% carpeted/covered, 20% exposed)"
					Area = ' + round(@slab_area[at]/@area_divisor) + '
					Perimeter = ' + round(@slab_perimeter[at]/@length_divisor) + '
					HeatedSlab = 0
					EdgeInsulation = 0
					EdgeInsulOption = "R-5, 8 inches"
					exSurface = "Default (80% carpeted/covered, 20% exposed)"
					exEdgeInsulOption = "R-5, 8 inches"
					..
			')
			end
		end #for
	### Garage Area End


	##### Adding Construction Types to the file #######
		out_file.puts('
			Cons	"2x4 Ext Wall -Stucco"  
				CanAssignTo = "Exterior Walls"
				Type = "Wood Framed Wall"
				RoofingLayer = "Light Roof (Asphalt Shingle)"
				AbvDeckInsulLayer = "- no insulation -"
				RoofDeckLayer = "Wood Siding/sheathing/decking"
				InsideFinishLayer = "Gypsum Board"
				AtticFloorLayer = "- no attic floor -"
				FloorSurfaceLayer = "Carpeted"
				FlrConcreteFillLayer = "- no concrete fill -"
				FloorDeckLayer = "Wood Siding/sheathing/decking"
				SheathInsul2Layer = "- no sheathing/insul. -"
				MassLayer = "- none -"
				MassThickness = "- none -"
				FurringInsul2Layer = "- no insulation -"
				FurringInsulLayer = "- no insulation -"
				Furring2Layer = "- none -"
				FurringLayer = "- none -"
				CavityLayer = "R 13"
				FrameLayer = "2x4 @ 16 in. O.C."
				SheathInsulLayer = "- no sheathing/insul. -"
				WallExtFinishLayer = "3 Coat Stucco"
				OtherSideFinishLayer = "Gypsum Board"
				FlrExtFinishLayer = "- select finish -"
				RadiantBarrier = 0
				RaisedHeelTruss = 0
				RaisedHeelTrussHeight = 3.5
				RoofingType = "all others"
				..

			Cons	"2x6 Ext Wall -Stucco"  
				CanAssignTo = "Exterior Walls"
				Type = "Wood Framed Wall"
				RoofingLayer = "Light Roof (Asphalt Shingle)"
				AbvDeckInsulLayer = "- no insulation -"
				RoofDeckLayer = "Wood Siding/sheathing/decking"
				InsideFinishLayer = "Gypsum Board"
				AtticFloorLayer = "- no attic floor -"
				FloorSurfaceLayer = "Carpeted"
				FlrConcreteFillLayer = "- no concrete fill -"
				FloorDeckLayer = "Wood Siding/sheathing/decking"
				SheathInsul2Layer = "- no sheathing/insul. -"
				MassLayer = "- none -"
				MassThickness = "- none -"
				FurringInsul2Layer = "- no insulation -"
				FurringInsulLayer = "- no insulation -"
				Furring2Layer = "- none -"
				FurringLayer = "- none -"
				CavityLayer = "R 19"
				FrameLayer = "2x6 @ 16 in. O.C."
				SheathInsulLayer = "- no sheathing/insul. -"
				WallExtFinishLayer = "3 Coat Stucco"
				OtherSideFinishLayer = "Gypsum Board"
				FlrExtFinishLayer = "- select finish -"
				RadiantBarrier = 0
				RaisedHeelTruss = 0
				RaisedHeelTrussHeight = 3.5
				RoofingType = "all others"
				..

			Cons	"2x4 Ext Wall -Siding"  
				CanAssignTo = "Exterior Walls"
				Type = "Wood Framed Wall"
				RoofingLayer = "Light Roof (Asphalt Shingle)"
				AbvDeckInsulLayer = "- no insulation -"
				RoofDeckLayer = "Wood Siding/sheathing/decking"
				InsideFinishLayer = "Gypsum Board"
				AtticFloorLayer = "- no attic floor -"
				FloorSurfaceLayer = "Carpeted"
				FlrConcreteFillLayer = "- no concrete fill -"
				FloorDeckLayer = "Wood Siding/sheathing/decking"
				SheathInsul2Layer = "- no sheathing/insul. -"
				MassLayer = "- none -"
				MassThickness = "- none -"
				FurringInsul2Layer = "- no insulation -"
				FurringInsulLayer = "- no insulation -"
				Furring2Layer = "- none -"
				FurringLayer = "- none -"
				CavityLayer = "R 13"
				FrameLayer = "2x4 @ 16 in. O.C."
				SheathInsulLayer = "- no sheathing/insul. -"
				WallExtFinishLayer = "Wood Siding/sheathing/decking"
				OtherSideFinishLayer = "Gypsum Board"
				FlrExtFinishLayer = "- select finish -"
				RadiantBarrier = 0
				RaisedHeelTruss = 0
				RaisedHeelTrussHeight = 3.5
				RoofingType = "all others"
				..

			Cons	"2x6 Ext Wall -Siding"  
				CanAssignTo = "Exterior Walls"
				Type = "Wood Framed Wall"
				RoofingLayer = "Light Roof (Asphalt Shingle)"
				AbvDeckInsulLayer = "- no insulation -"
				RoofDeckLayer = "Wood Siding/sheathing/decking"
				InsideFinishLayer = "Gypsum Board"
				AtticFloorLayer = "- no attic floor -"
				FloorSurfaceLayer = "Carpeted"
				FlrConcreteFillLayer = "- no concrete fill -"
				FloorDeckLayer = "Wood Siding/sheathing/decking"
				SheathInsul2Layer = "- no sheathing/insul. -"
				MassLayer = "- none -"
				MassThickness = "- none -"
				FurringInsul2Layer = "- no insulation -"
				FurringInsulLayer = "- no insulation -"
				Furring2Layer = "- none -"
				FurringLayer = "- none -"
				CavityLayer = "R 19"
				FrameLayer = "2x6 @ 16 in. O.C."
				SheathInsulLayer = "- no sheathing/insul. -"
				WallExtFinishLayer = "Wood Siding/sheathing/decking"
				OtherSideFinishLayer = "Gypsum Board"
				FlrExtFinishLayer = "- select finish -"
				RadiantBarrier = 0
				RaisedHeelTruss = 0
				RaisedHeelTrussHeight = 3.5
				RoofingType = "all others"
				..

			Cons	"Gar Ext Wall -Stucco"  
				CanAssignTo = "Exterior Walls"
				Type = "Wood Framed Wall"
				RoofingLayer = "Light Roof (Asphalt Shingle)"
				AbvDeckInsulLayer = "- no insulation -"
				RoofDeckLayer = "Wood Siding/sheathing/decking"
				InsideFinishLayer = "Gypsum Board"
				AtticFloorLayer = "- no attic floor -"
				FloorSurfaceLayer = "Carpeted"
				FlrConcreteFillLayer = "- no concrete fill -"
				FloorDeckLayer = "Wood Siding/sheathing/decking"
				SheathInsul2Layer = "- no sheathing/insul. -"
				MassLayer = "- none -"
				MassThickness = "- none -"
				FurringInsul2Layer = "- no insulation -"
				FurringInsulLayer = "- no insulation -"
				Furring2Layer = "- none -"
				FurringLayer = "- none -"
				CavityLayer = "- no insulation -"
				FrameLayer = "2x4 @ 16 in. O.C."
				SheathInsulLayer = "- no sheathing/insul. -"
				WallExtFinishLayer = "3 Coat Stucco"
				OtherSideFinishLayer = "Gypsum Board"
				FlrExtFinishLayer = "- select finish -"
				RadiantBarrier = 0
				RaisedHeelTruss = 0
				RaisedHeelTrussHeight = 3.5
				RoofingType = "all others"
				..

			Cons	"Gar Ext Wall -Siding"  
				CanAssignTo = "Exterior Walls"
				Type = "Wood Framed Wall"
				RoofingLayer = "Light Roof (Asphalt Shingle)"
				AbvDeckInsulLayer = "- no insulation -"
				RoofDeckLayer = "Wood Siding/sheathing/decking"
				InsideFinishLayer = "Gypsum Board"
				AtticFloorLayer = "- no attic floor -"
				FloorSurfaceLayer = "Carpeted"
				FlrConcreteFillLayer = "- no concrete fill -"
				FloorDeckLayer = "Wood Siding/sheathing/decking"
				SheathInsul2Layer = "- no sheathing/insul. -"
				MassLayer = "- none -"
				MassThickness = "- none -"
				FurringInsul2Layer = "- no insulation -"
				FurringInsulLayer = "- no insulation -"
				Furring2Layer = "- none -"
				FurringLayer = "- none -"
				CavityLayer = "- no insulation -"
				FrameLayer = "2x4 @ 16 in. O.C."
				SheathInsulLayer = "- no sheathing/insul. -"
				WallExtFinishLayer = "Wood Siding/sheathing/decking"
				OtherSideFinishLayer = "Gypsum Board"
				FlrExtFinishLayer = "- select finish -"
				RadiantBarrier = 0
				RaisedHeelTruss = 0
				RaisedHeelTrussHeight = 3.5
				RoofingType = "all others"
				..

			Cons	"2x4 ToGarage Wall"  
				CanAssignTo = "Interior Walls"
				Type = "Wood Framed Wall"
				RoofingLayer = "Light Roof (Asphalt Shingle)"
				AbvDeckInsulLayer = "- no insulation -"
				RoofDeckLayer = "Wood Siding/sheathing/decking"
				InsideFinishLayer = "Gypsum Board"
				AtticFloorLayer = "- no attic floor -"
				FloorSurfaceLayer = "Carpeted"
				FlrConcreteFillLayer = "- no concrete fill -"
				FloorDeckLayer = "Wood Siding/sheathing/decking"
				SheathInsul2Layer = "- no sheathing/insul. -"
				MassLayer = "- none -"
				MassThickness = "- none -"
				FurringInsul2Layer = "- no insulation -"
				FurringInsulLayer = "- no insulation -"
				Furring2Layer = "- none -"
				FurringLayer = "- none -"
				CavityLayer = "R 13"
				FrameLayer = "2x4 @ 16 in. O.C."
				SheathInsulLayer = "- no sheathing/insul. -"
				WallExtFinishLayer = "- select finish -"
				OtherSideFinishLayer = "Gypsum Board"
				FlrExtFinishLayer = "- select finish -"
				RadiantBarrier = 0
				RaisedHeelTruss = 0
				RaisedHeelTrussHeight = 3.5
				RoofingType = "all others"
				..

			Cons	"2x6 ToGarage Wall"  
				CanAssignTo = "Interior Walls"
				Type = "Wood Framed Wall"
				RoofingLayer = "Light Roof (Asphalt Shingle)"
				AbvDeckInsulLayer = "- no insulation -"
				RoofDeckLayer = "Wood Siding/sheathing/decking"
				InsideFinishLayer = "Gypsum Board"
				AtticFloorLayer = "- no attic floor -"
				FloorSurfaceLayer = "Carpeted"
				FlrConcreteFillLayer = "- no concrete fill -"
				FloorDeckLayer = "Wood Siding/sheathing/decking"
				SheathInsul2Layer = "- no sheathing/insul. -"
				MassLayer = "- none -"
				MassThickness = "- none -"
				FurringInsul2Layer = "- no insulation -"
				FurringInsulLayer = "- no insulation -"
				Furring2Layer = "- none -"
				FurringLayer = "- none -"
				CavityLayer = "R 19"
				FrameLayer = "2x6 @ 16 in. O.C."
				SheathInsulLayer = "- no sheathing/insul. -"
				WallExtFinishLayer = "- select finish -"
				OtherSideFinishLayer = "Gypsum Board"
				FlrExtFinishLayer = "- select finish -"
				RadiantBarrier = 0
				RaisedHeelTruss = 0
				RaisedHeelTrussHeight = 3.5
				RoofingType = "all others"
				..

			Cons	"Knee Wall"  
				CanAssignTo = "Interior Walls"
				Type = "Wood Framed Wall"
				RoofingLayer = "Light Roof (Asphalt Shingle)"
				AbvDeckInsulLayer = "- no insulation -"
				RoofDeckLayer = "Wood Siding/sheathing/decking"
				InsideFinishLayer = "Gypsum Board"
				AtticFloorLayer = "- no attic floor -"
				FloorSurfaceLayer = "Carpeted"
				FlrConcreteFillLayer = "- no concrete fill -"
				FloorDeckLayer = "Wood Siding/sheathing/decking"
				SheathInsul2Layer = "- no sheathing/insul. -"
				MassLayer = "- none -"
				MassThickness = "- none -"
				FurringInsul2Layer = "- no insulation -"
				FurringInsulLayer = "- no insulation -"
				Furring2Layer = "- none -"
				FurringLayer = "- none -"
				CavityLayer = "R 19"
				FrameLayer = "2x6 @ 16 in. O.C."
				SheathInsulLayer = "- no sheathing/insul. -"
				WallExtFinishLayer = "- select finish -"
				OtherSideFinishLayer = "Gypsum Board"
				FlrExtFinishLayer = "- select finish -"
				RadiantBarrier = 0
				RaisedHeelTruss = 0
				RaisedHeelTrussHeight = 3.5
				RoofingType = "all others"
				..

			Cons	"Party Wall"  
				CanAssignTo = "Interior Walls"
				Type = "Wood Framed Wall"
				RoofingLayer = "Light Roof (Asphalt Shingle)"
				AbvDeckInsulLayer = "- no insulation -"
				RoofDeckLayer = "Wood Siding/sheathing/decking"
				InsideFinishLayer = "Gypsum Board"
				AtticFloorLayer = "- no attic floor -"
				FloorSurfaceLayer = "Carpeted"
				FlrConcreteFillLayer = "- no concrete fill -"
				FloorDeckLayer = "Wood Siding/sheathing/decking"
				SheathInsul2Layer = "- no sheathing/insul. -"
				MassLayer = "- none -"
				MassThickness = "- none -"
				FurringInsul2Layer = "- no insulation -"
				FurringInsulLayer = "- no insulation -"
				Furring2Layer = "- none -"
				FurringLayer = "- none -"
				CavityLayer = "R 19"
				FrameLayer = "2x6 @ 16 in. O.C."
				SheathInsulLayer = "- no sheathing/insul. -"
				WallExtFinishLayer = "- select finish -"
				OtherSideFinishLayer = "Gypsum Board"
				FlrExtFinishLayer = "- select finish -"
				RadiantBarrier = 0
				RaisedHeelTruss = 0
				RaisedHeelTrussHeight = 3.5
				RoofingType = "all others"
				..

			Cons	"Ceiling"  
				CanAssignTo = "Ceilings (below attic)"
				Type = "Wood Framed Ceiling"
				RoofingLayer = "Light Roof (Asphalt Shingle)"
				AbvDeckInsulLayer = "- no insulation -"
				RoofDeckLayer = "Wood Siding/sheathing/decking"
				InsideFinishLayer = "Gypsum Board"
				AtticFloorLayer = "- no attic floor -"
				FloorSurfaceLayer = "Carpeted"
				FlrConcreteFillLayer = "- no concrete fill -"
				FloorDeckLayer = "Wood Siding/sheathing/decking"
				SheathInsul2Layer = "- no sheathing/insul. -"
				MassLayer = "- none -"
				MassThickness = "- none -"
				FurringInsul2Layer = "- no insulation -"
				FurringInsulLayer = "- no insulation -"
				Furring2Layer = "- none -"
				FurringLayer = "- none -"
				CavityLayer = "R 38"
				FrameLayer = "2x4 @ 16 in. O.C."
				SheathInsulLayer = "- no sheathing/insul. -"
				WallExtFinishLayer = "- select finish -"
				OtherSideFinishLayer = "Gypsum Board"
				FlrExtFinishLayer = "- select finish -"
				RadiantBarrier = 0
				RaisedHeelTruss = 0
				RaisedHeelTrussHeight = 3.5
				RoofingType = "all others"
				..

			Cons	"Ceiling at Garage"  
				CanAssignTo = "Ceilings (below attic)"
				Type = "Wood Framed Ceiling"
				RoofingLayer = "Light Roof (Asphalt Shingle)"
				AbvDeckInsulLayer = "- no insulation -"
				RoofDeckLayer = "Wood Siding/sheathing/decking"
				InsideFinishLayer = "Gypsum Board"
				AtticFloorLayer = "- no attic floor -"
				FloorSurfaceLayer = "Carpeted"
				FlrConcreteFillLayer = "- no concrete fill -"
				FloorDeckLayer = "Wood Siding/sheathing/decking"
				SheathInsul2Layer = "- no sheathing/insul. -"
				MassLayer = "- none -"
				MassThickness = "- none -"
				FurringInsul2Layer = "- no insulation -"
				FurringInsulLayer = "- no insulation -"
				Furring2Layer = "- none -"
				FurringLayer = "- none -"
				CavityLayer = "- no insulation -"
				FrameLayer = "2x4 @ 16 in. O.C."
				SheathInsulLayer = "- no sheathing/insul. -"
				WallExtFinishLayer = "- select finish -"
				OtherSideFinishLayer = "Gypsum Board"
				FlrExtFinishLayer = "- select finish -"
				RadiantBarrier = 0
				RaisedHeelTruss = 0
				RaisedHeelTrussHeight = 3.5
				RoofingType = "all others"
				..

			Cons	"Roof Deck"  
				CanAssignTo = "Attic Roofs"
				Type = "Wood Framed Ceiling"
				RoofingLayer = "Light Roof (Asphalt Shingle)"
				AbvDeckInsulLayer = "- no insulation -"
				RoofDeckLayer = "Wood Siding/sheathing/decking"
				InsideFinishLayer = "- select inside finish -"
				AtticFloorLayer = "- no attic floor -"
				FloorSurfaceLayer = "Carpeted"
				FlrConcreteFillLayer = "- no concrete fill -"
				FloorDeckLayer = "Wood Siding/sheathing/decking"
				SheathInsul2Layer = "- no sheathing/insul. -"
				MassLayer = "- none -"
				MassThickness = "- none -"
				FurringInsul2Layer = "- no insulation -"
				FurringInsulLayer = "- no insulation -"
				Furring2Layer = "- none -"
				FurringLayer = "- none -"
				CavityLayer = "- no insulation -"
				FrameLayer = "2x4 Top Chord of Roof Truss @ 24 in. O.C."
				SheathInsulLayer = "- no sheathing/insul. -"
				WallExtFinishLayer = "- select finish -"
				OtherSideFinishLayer = "Gypsum Board"
				FlrExtFinishLayer = "- select finish -"
				RadiantBarrier = 1
				RaisedHeelTruss = 0
				RaisedHeelTrussHeight = 3.5
				RoofingType = "all others"
				..	

			Cons	"Roof Deck at Garage"  
				CanAssignTo = "Attic Roofs"
				Type = "Wood Framed Ceiling"
				RoofingLayer = "Light Roof (Asphalt Shingle)"
				AbvDeckInsulLayer = "- no insulation -"
				RoofDeckLayer = "Wood Siding/sheathing/decking"
				InsideFinishLayer = "- select inside finish -"
				AtticFloorLayer = "- no attic floor -"
				FloorSurfaceLayer = "Carpeted"
				FlrConcreteFillLayer = "- no concrete fill -"
				FloorDeckLayer = "Wood Siding/sheathing/decking"
				SheathInsul2Layer = "- no sheathing/insul. -"
				MassLayer = "- none -"
				MassThickness = "- none -"
				FurringInsul2Layer = "- no insulation -"
				FurringInsulLayer = "- no insulation -"
				Furring2Layer = "- none -"
				FurringLayer = "- none -"
				CavityLayer = "- no insulation -"
				FrameLayer = "2x4 Top Chord of Roof Truss @ 24 in. O.C."
				SheathInsulLayer = "- no sheathing/insul. -"
				WallExtFinishLayer = "- select finish -"
				OtherSideFinishLayer = "Gypsum Board"
				FlrExtFinishLayer = "- select finish -"
				RadiantBarrier = 1
				RaisedHeelTruss = 0
				RaisedHeelTrussHeight = 3.5
				RoofingType = "all others"
				..

			Cons	"Cathedral"  
				CanAssignTo = "Cathedral Ceilings"
				Type = "Wood Framed Ceiling"
				RoofingLayer = "Light Roof (Asphalt Shingle)"
				AbvDeckInsulLayer = "- no insulation -"
				RoofDeckLayer = "Wood Siding/sheathing/decking"
				InsideFinishLayer = "Gypsum Board"
				AtticFloorLayer = "- no attic floor -"
				FloorSurfaceLayer = "Carpeted"
				FlrConcreteFillLayer = "- no concrete fill -"
				FloorDeckLayer = "Wood Siding/sheathing/decking"
				SheathInsul2Layer = "- no sheathing/insul. -"
				MassLayer = "- none -"
				MassThickness = "- none -"
				FurringInsul2Layer = "- no insulation -"
				FurringInsulLayer = "- no insulation -"
				Furring2Layer = "- none -"
				FurringLayer = "- none -"
				CavityLayer = "R 38"
				FrameLayer = "2x4 @ 16 in. O.C."
				SheathInsulLayer = "- no sheathing/insul. -"
				WallExtFinishLayer = "- select finish -"
				OtherSideFinishLayer = "Gypsum Board"
				FlrExtFinishLayer = "- select finish -"
				RadiantBarrier = 0
				RaisedHeelTruss = 0
				RaisedHeelTrussHeight = 3.5
				RoofingType = "all others"
				..

			Cons	"Floor to Garage"  
				CanAssignTo = "Interior Floors"
				Type = "Wood Framed Floor"
				RoofingLayer = "Light Roof (Asphalt Shingle)"
				AbvDeckInsulLayer = "- no insulation -"
				RoofDeckLayer = "Wood Siding/sheathing/decking"
				InsideFinishLayer = "Gypsum Board"
				AtticFloorLayer = "- no attic floor -"
				FloorSurfaceLayer = "Carpeted"
				FlrConcreteFillLayer = "- no concrete fill -"
				FloorDeckLayer = "Wood Siding/sheathing/decking"
				SheathInsul2Layer = "- no sheathing/insul. -"
				MassLayer = "- none -"
				MassThickness = "- none -"
				FurringInsul2Layer = "- no insulation -"
				FurringInsulLayer = "- no insulation -"
				Furring2Layer = "- none -"
				FurringLayer = "- none -"
				CavityLayer = "R 19"
				FrameLayer = "2x12 @ 16 in. O.C."
				SheathInsulLayer = "- no sheathing/insul. -"
				WallExtFinishLayer = "- select finish -"
				OtherSideFinishLayer = "Gypsum Board"
				FlrExtFinishLayer = "- select finish -"
				RadiantBarrier = 0
				RaisedHeelTruss = 0
				RaisedHeelTrussHeight = 3.5
				RoofingType = "all others"
				..

			Cons	"Floor to Outside"  
				CanAssignTo = "Exterior Floors"
				Type = "Wood Framed Floor"
				RoofingLayer = "Light Roof (Asphalt Shingle)"
				AbvDeckInsulLayer = "- no insulation -"
				RoofDeckLayer = "Wood Siding/sheathing/decking"
				InsideFinishLayer = "Gypsum Board"
				AtticFloorLayer = "- no attic floor -"
				FloorSurfaceLayer = "Carpeted"
				FlrConcreteFillLayer = "- no concrete fill -"
				FloorDeckLayer = "Wood Siding/sheathing/decking"
				SheathInsul2Layer = "- no sheathing/insul. -"
				MassLayer = "- none -"
				MassThickness = "- none -"
				FurringInsul2Layer = "- no insulation -"
				FurringInsulLayer = "- no insulation -"
				Furring2Layer = "- none -"
				FurringLayer = "- none -"
				CavityLayer = "R 19"
				FrameLayer = "2x12 @ 16 in. O.C."
				SheathInsulLayer = "- no sheathing/insul. -"
				WallExtFinishLayer = "- select finish -"
				OtherSideFinishLayer = "Gypsum Board"
				FlrExtFinishLayer = "3 Coat Stucco"
				RadiantBarrier = 0
				RaisedHeelTruss = 0
				RaisedHeelTrussHeight = 3.5
				RoofingType = "all others"
				..
	
			WindowType	"win_Oper"  
				SpecMethod = "Overall Window Area"
				NFRCUfactor = 0.32
				NFRCSHGC = 0.25
				ExteriorShade = "Insect Screen (default)"
				ModelFinsOverhang = 0
				OverhangDepth = 0
				OverhangDistUp = 0
				OverhangExL = 0
				OverhangExR = 0
				OverhangFlap = 0
				LeftFinDepth = 0
				LeftFinTopUp = 0
				LeftFinDistL = 0
				LeftFinBotUp = 0
				RightFinDepth = 0
				RightFinTopUp = 0
				RightFinDistR = 0
				RightFinBotUp = 0
				..

			 WindowType	"win_Fixed"  
				SpecMethod = "Overall Window Area"
				NFRCUfactor = 0.32
				NFRCSHGC = 0.25
				ExteriorShade = "Insect Screen (default)"
				ModelFinsOverhang = 0
				OverhangDepth = 0
				OverhangDistUp = 0
				OverhangExL = 0
				OverhangExR = 0
				OverhangFlap = 0
				LeftFinDepth = 0
				LeftFinTopUp = 0
				LeftFinDistL = 0
				LeftFinBotUp = 0
				RightFinDepth = 0
				RightFinTopUp = 0
				RightFinDistR = 0
				RightFinBotUp = 0
				..

			WindowType	"win_SGD"  
				SpecMethod = "Overall Window Area"
				NFRCUfactor = 0.32
				NFRCSHGC = 0.25
				ExteriorShade = "Insect Screen (default)"
				ModelFinsOverhang = 0
				OverhangDepth = 0
				OverhangDistUp = 0
				OverhangExL = 0
				OverhangExR = 0
				OverhangFlap = 0
				LeftFinDepth = 0
				LeftFinTopUp = 0
				LeftFinDistL = 0
				LeftFinBotUp = 0
				RightFinDepth = 0
				RightFinTopUp = 0
				RightFinDistR = 0
				RightFinBotUp = 0
				..

			WindowType	"win_FRD"  
				SpecMethod = "Overall Window Area"
				NFRCUfactor = 0.32
				NFRCSHGC = 0.25
				ExteriorShade = "Insect Screen (default)"
				ModelFinsOverhang = 0
				OverhangDepth = 0
				OverhangDistUp = 0
				OverhangExL = 0
				OverhangExR = 0
				OverhangFlap = 0
				LeftFinDepth = 0
				LeftFinTopUp = 0
				LeftFinDistL = 0
				LeftFinBotUp = 0
				RightFinDepth = 0
				RightFinTopUp = 0
				RightFinDistR = 0
				RightFinBotUp = 0
				..

			HVACSys	"HVAC System 1"  
				Type = "Other Heating and Cooling System"
				Status = "New"
				CFIClVentOption = "- none -"
				CFIClVentFlow = 0
				CFIClVentPwr = 0
				CFIClVentAttic = "Attic_Living"
				NumHeatSystemTypes = 1
				HeatSystemCount = ( 1, 0, 0, 0, 0, 0, 0, 0, 0, 0 )
				HeatSystem[1] = "Heating System 1"
				AutoSizeHeatInp = 1
				HeatDucted = 1
				NumCoolSystemTypes = 1
				CoolSystemCount = ( 1, 0, 0, 0, 0, 0, 0, 0, 0, 0 )
				CoolSystem[1] = "Cooling System 1"
				AutoSizeCoolInp = 1
				CoolDucted = 1
				NumHtPumpSystemTypes = 0
				HtPumpDucted = 0
				ServesAsDHWHtr = 0
				DHWTankVolume = 50
				DHWIntInsulRVal = 0
				DHWExtInsulRVal = 0
				DHWAmbientCond = "Unconditioned"
				DistribSystem = "Distribution System 1"
				Fan = "HVAC Fan System 1"
				..

			HVACHeat	"Heating System 1"  
				Type = "CntrlFurnace - Fuel-fired central furnace"
				AFUE = 80
				..

			HVACCool	"Cooling System 1"  
				Type = "SplitAirCond - Split air conditioning system"
				SEER = 14
				EER = 12.2
				CFMperTon = 350
				ACCharge = "Not Verified"
				RefrigerantType = "R410A"
				UseEERinAnalysis = 1
				IsMultiSpeed = 0
				IsZonal = 0
				..

			HVACDist	"Distribution System 1"  
				Type = "Ducts located in attic (Ventilated and Unventilated)"
				Status = "New"
				IsVerified = 0
				DefaultSystem = 1
				DuctLeakage = "Sealed and tested"
				DuctLeakageVal = 6
				HasBypassDuct = 0
				DuctInsRvalOpt = "6.0"
				exDuctInsRvalOpt = "4.2"
				SupplyDuctArea = 0
				ReturnDuctArea = 0
				SupplyDuctLoc = "Attic_Living"
				ReturnDuctLoc = "Attic_Living"
				SupplyDuctAttic = "Attic_Living"
				ReturnDuctAttic = "Attic_Living"
				DuctDesign = 0
				DuctDesignInsRvalue = 6
				RetDuctDesignInsRvalue = 6
				LowLkgAH = 0
				AreBuried = 0
				AreDeeplyBuried = 0
				..

			HVACFan	"HVAC Fan System 1"  
				Type = "Single Speed PSC Furnace Fan"
				DefaultSystem = 0
				WperCFMCool = 0.58
				..

			DHWSys	"DHW System 1"  
				SystemType = "Standard"
				MFamDistType = "No loops or central system pump"
				CentralDHW = 0
				DHWHeater[1] = "Water Heater 1"
				HeaterMult[1] = 1
				UseDefaultLoops = 0
				LoopPipeInsulThk[1] = 1.5
				RecircPipeLoc[1] = "Conditioned"
				SolFracType = "- none -"
				..

			DHWHeater	"Water Heater 1"  
				HeaterElementType = "Natural Gas"
				TankType = "Small Instantaneous"
				InputRating = 195000
				EnergyFactor = 0.82
				TankVolume = 0
				ExtInsulRVal = 0
				AmbientCond = "Unconditioned"
				RecovEff = 70
				HasElecMiniTank = 0
				ElecMiniTankPower = 0
				..

			END_OF_FILE')
		end
		
		#close the file we created
		out_file.close
	### Construction Types End


	##### Check to see if file saved and offer to open the file for the user.
	
	if File.file? (savelocation)

		result = UI.messagebox('File saved!' + "\n" + "\n" + 'Ready Open in CBECC!', MB_OK)
		puts "File Saved"
		if result == IDYES
			#file_to_open = '"C:/Program Files (x86)/CBECC-Res 2013/CBECC-Res13.exe -pa -nogui" "'.gsub(%r{/}) { "\\" } + savelocation +'"'
			#puts "Opening File: " + file_to_open
			#system %{cmd /c "start #{file_to_open}"}
			myVariable = show_dialog.get_element_value("start2")
			puts myVariable
		end
	else
		UI.messagebox('Error Saving File!')
	end
end #outCBECCdata

def show_dialog
	# dlg = UI::WebDialog.new("Title", scrollable, pref key, width, height, x, y, resizeable);
  dlg = UI::WebDialog.new("DialogTest", false, "DialogTest", 200, 150, 150, 150, true);
  html = <<-HTML
	 <form>
	<input id="start2" onClick="window.alert('alert from javascript');" type="button" size="100" value="input">	 
	</br>
	<a href="skp:ruby_messagebox@from link">link</a>
	 </form>
  HTML
  
  dlg.set_html html
  dlg.add_action_callback("ruby_messagebox") {|dialog, params|
	 UI.messagebox("You called ruby_messagebox with: " + params.to_s)
  }
  dlg.show
end




def drillDown(ent)
	case ent.typename
		when "Group"
			ent.entities.each{|e| drillDown(e)}
		when "Face"
			whatMaterial(ent)
	end
end #drillDown

def getMaterialData(model1) 
	initData
	if model1.selection.empty?
		UI.messagebox 'select something to measure!'
	else
		#collect all materials in the selected faces
		model1.selection.each{|e| drillDown(e)}
		
		if @mats.empty?
			UI.messagebox 'Select objects with faces'
		else
			ruleSetList = "CA Res 2013|CA Res 2016"
			czList = "CZ1  (Arcata)|CZ2  (Santa Rosa)|CZ3  (Oakland)|CZ4  (San Jose)|CZ5  (Santa Maria)|CZ6  (Torrance)|CZ7  (San Diego)|CZ8  (Fullerton)|CZ9  (Burbank)|CZ10  (Riverside)|CZ11  (Red Bluff)|CZ12  (Sacramento)|CZ13  (Fresno)|CZ 14  (Palmdale)|CZ15  (Palm Springs)|CZ16  (Blue Canyon)"
			
			prompts = ["Ruleset:", "Plan Name:", "Address:", "City, State:", "Zip Code:", "Climate Zone:", "Total SF:",  "# of Bedrooms:", "# of Stories:", "Avg Ceiling Height:"]
 			defaults = ["CA Res 2013", "Plan Name", "Project Name", "City, State", "95366", "CZ12  (Sacramento)", "1000", "3", "1", "9"]
 			list = [ruleSetList, "", "", "", "", czList, "", "", "1|2|3", ""]
 			input = UI.inputbox(prompts, defaults, list, "Project Setup")
			outCBECCdata(input)
		end #if
	end #if
end # getMaterialData

# Main program vars
@mats = []
@dt_tools_path = ''
@areas = []
@orients=[]
@angles=[]
@windows=[]
@win_areas = []
@win_orients=[]
@win_angles=[]
@win_wall=[]
@win_wall_types=[]
@win_wall_totals=[]
@fdtn_loc = []
@fdtn_length = []
@fdtn_height = []
@fdtn_area = []
@slab_name = []
@slab_area = []
@slab_belowGrade = []
@slab_perimeter = []
@slab_onGrade = []
@slab_exposed = []
@rpt_type = 0
@conditioned1st = 0
@conditioned2nd = 0
@conditioned3rd = 0
@unconditioned = 0
@envelope = 0
