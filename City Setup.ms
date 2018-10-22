/*  
[INFO] 

NAME = City Setup
VERSION = 1.0.4
AUTHOR = Vasily Lukyanenko
DEV = 3DGROUND
CUSTOMER = Andrew Andreyuk
SKYPE = notfun1
HELP = 
WEB=https://3dground.net

[INSTALL]

MACRO=CitySetup
CAT=3DGROUND
TEXT=City Setup
ICON=#("PhysX_Main", 31)

[1.0.0]

* First release =
+ Added: New Script Info function=

[1.0.1]

+ Added: Save file dialog when press Setup City=
+ Added: Group name for city=
- BugFix: Units setup=

[1.0.2]

+ Added: Apply UVW Map (Face) to scatter object if string begins from "@"=

[1.0.3]

+ Added: Update system=

[1.0.4]

+ Added: Fixed MultiScatter error dialog=

[ABOUT]

Quick apply actions to the city=

[TEST]

[SCRIPT]
*/	




try(closeRolloutFloater rCitySetup)catch()
global rCitySetup = newRolloutFloater "City Setup" 280 940

global _CITY_SETUPL_STEP1
global BitmapTypes = #(Bitmaptexture, CoronaBitmap)

fn trim s c: " " = trimRight (trimLeft s c) c
fn explode s tag: ";" = (
	a = filterString s tag
	return for i in a collect trim i
)
fn implode a tag: ";" = 
(
	s = ""
	for i in a do s += i as string + tag
	return trimRight s tag
)


struct scriptInfo (
	ini = getThisScriptFilename(),
	fn implode a tag: "\n"= (
		s = ""
		for i in 1 to a.count do s += a[i] + (if(i != a.count) then tag else "")			
		return s
	),
	web = getINISetting ini "INFO" "WEB",
	version = getINISetting ini "INFO" "VERSION",
	author = getINISetting ini "INFO" "AUTHOR",
	name = getINISetting ini "INFO" "NAME",
	overview = implode (getINISetting ini "ABOUT"),
	dev = getINISetting ini "INFO" "DEV",
	help = getINISetting ini "INFO" "HELP",
	fn release num = (
		return implode (getINISetting ini num)
	),
	fn releases = (
		for i in (getINISetting ini) where matchPattern i pattern: "*.*.*"  collect i
	)
)

fn showTooltip c t =
(
	toolTip = dotnetobject "System.Windows.Forms.ToolTip"
	toolTip.SetToolTip c t   
	--toolTip.Active = true    
	toolTip.isBalloon = true
	toolTip.InitialDelay = 100
	toolTip.AutoPopDelay = 500
	toolTip.ReshowDelay = 50
	toolTip.ToolTipTitle = "Warning!"
	toolTip.Show t c 3000	
	toolTip.ToolTipIcon = (dotnetclass "System.Windows.Forms.ToolTipIcon").Warning
)

fn stripName n = (
	nn = filterString n "_"
	if(nn.count ==  0) do return undefined
	if(nn.count == 1) do return nn[1]
	
	s = ""
	for i in 1 to nn.count - 1 do (
		s += nn[i]
		if(i != (nn.count - 1)) do s += "_"
	)
	
	return s
)

fn useSettings k v type:#get =
(
	f = getThisScriptFilename() + ".ini"
	case type of
	(
		#set: setIniSetting f "SETTINGS" k v
		default: getIniSetting f "SETTINGS" k
	)
)

fn boost = if (((maxVersion())[1] / 1000) >= 13) do windows.processPostedMessages() 

fn freezeUi =
(
  	source = ""
  	source += "using System;\n"
  	source += "using System.Runtime.InteropServices;\n"
  	source += "class WindowsGhosting\n"
  	source += "{\n"
  	source += " [DllImport(\"user32.dll\")]\n"
  	source += " public static extern void DisableProcessWindowsGhosting();\n"
  	source += "}\n"
  
  	csharpProvider = dotnetobject "Microsoft.CSharp.CSharpCodeProvider"
  	compilerParams = dotnetobject "System.CodeDom.Compiler.CompilerParameters"
  
  	compilerParams.GenerateInMemory = on
  	compilerResults = csharpProvider.CompileAssemblyFromSource compilerParams #(source)
  
  	assembly = compilerResults.CompiledAssembly
  	windowsGhosting = assembly.CreateInstance "WindowsGhosting"
  	windowsGhosting.DisableProcessWindowsGhosting()
)

fn quickAttach objs name: undefined = (
	
	freezeUi()		
	clearSelection()
	cnt = 0
	
	tmp = #()
	chunk = 300
	
	t = Editable_Mesh()	
	convertTo t Editable_Poly
	t.name = objs[1].name
	if(name != undefined) do t.name = name
	
	append tmp t
			
	progressStart "Quick Attach"
	
	for i in 1 to objs.count do (
		cnt += 1
		
		if(cnt >= chunk) do (
			cnt = 1
			t = Editable_Mesh()
			convertTo t Editable_Poly
			t.name = objs[i].name
			append tmp t
			gc()
			boost()
		)
		
		if (SuperClassOf objs[i] == GeometryClass) and (IsValidNode objs[i]) do (
			polyop.attach  t objs[i] 
			
			boost()
			if (keyboard.EscPressed) do (
				q = queryBox "Do you want to stop Quick Attach?" title: "Confirm"
				progressEnd()
				if(q) do return t
			)
		) 
		
		progressUpdate (100 * i / objs.count)
	)
	
	progressEnd()
	
	progressStart "Quick Attach"
		
	if(tmp.count != 0) do (
		t = Editable_Mesh()	
		convertTo t Editable_Poly
		t.name = tmp[1].name
		
		for i in 1 to tmp.count do (
			polyop.attach  t tmp[i] 				
			progressUpdate (100 * i / tmp.count)
		)
		
		gc()
	)
	
	progressEnd()
		
	select t
	t.pivot = t.center
	free tmp
	free objs
			
	return t
)

global pathAutoMaterial = ""
global pathAutoMaterialIni = ""

rollout _CITY_SETUPL_STEP1 "Main"
(
	group "Load City (*.fbx)" (
		edittext edtCityFBX "" readonly: true height: 25
		button btnLoadCityFBX "Browse File" width: 100 height: 25 
	)
	
	group "Material Libraries (Auto Material)" (
		listbox lbxMatLibs "" offset: [0, 5] height: 6
		button btnSelectMatPath "Load Mat Libs" across: 2 width: 100 height: 25 offset: [0, 5]
		button btnClearMatLibs "Clear All" width: 100 height: 25 offset: [0, 5]
	)
	
	group "Load Cameras (*.max) (optional)" (
		edittext edtCameras "" readonly: true height: 25
		button btnLoadCameras "Browse File" width: 100 height: 25 
	)
	
	group "Load Assets (*.max)" (
		edittext edtAssets "" readonly: true height: 25
		button btnLoadAssets "Browse File" width: 100 height: 25 
	)
	
	group "Load Render Preset (*.rps)" (
		edittext edtPreset "" readonly: true height: 25
		button btnLoadPreset "Browse File" width: 100 height: 25 
	)
	
	group "Attach Objects by Name Pattern (optional)" (
		label lblEx1 "Unique part of name" align: #left
		label lblEx2 "Each name from new line" align: #left
		label lblEx3 "Ex.: Roof_Grass or Ground_Grass ..." align: #left
		dotNetControl edtAttachPattern "System.Windows.Forms.TextBox" width: 240  height: 60
	)
	
	group "MultiScatter (optional)" (
		label lblEx21 "Apply objects to MultiScatter" align: #left
		label lblEx22 "Each setting from new line" align: #left
		label lblEx23 "MultiScatter Helper Name = Object Name Pattern" align: #left
		label lblEx24 "Ex.: Side_Trees = Tree_place_holder" align: #left
		label lblEx255 "------" align: #left
		label lblEx25 "For apply UVW Map (Face) put @ at start of string" align: #left		
		label lblEx26 "Ex.: @Side_Trees = Tree_place_holder" align: #left
		dotNetControl edtMultiScatter "System.Windows.Forms.TextBox" width: 240  height: 60
	)
	
	button btnSetupCity "Setup City" height: 35 width: 240 offset: [0, 12]
	
	fn getObjectsByName n = (execute ("$" + n + "*")) as array
	
	fn clearMatLibs = (
		q = queryBox "Do you really want to clear all material libraries from list?" title: "Confirm?"
		if(not q) do return false
		
		ini = pathAutoMaterialIni
		delIniSetting ini "MAT_LIBS"				
		lbxMatLibs.items = #()
	)
	
	fn getMatLibs = (
		ini = pathAutoMaterialIni
		f = getIniSetting ini "MAT_LIBS" 		
		libs = for i in f where doesFileExist i collect i 				
		if(libs.count == 0) do return undefined		
		return libs
	)
	
	fn loadCityFBX = (
		v = useSettings "CITY_FBX" undefined type:#get
		if(doesFileExist v) do (
			edtCityFBX.text = v		
			return v
		)
		edtCityFBX.text = ""
		return ""
	)
	
	fn loadCameras = (
		v = useSettings "CAMERAS_MAX" undefined type:#get
		if(doesFileExist v) do (
			edtCameras.text = v		
			return v
		)
		edtCameras.text = ""
		return ""
	)
	
	fn loadAssets = (
		v = useSettings "ASSETS_MAX" undefined type:#get
		if(doesFileExist v) do (
			edtAssets.text = v		
			return v
		)
		edtAssets.text = ""
		return ""
	)
	
	fn loadAttachPatterns = (
		v = useSettings "ATTACH_PATTERNS" undefined type:#get
		if(v != "") do (
			edtAttachPattern.text = substituteString v "|" "\r\n"
			return v
		)
		edtAttachPattern.text = "Roof_Grass\r\nGround_Grass\r\nTree_place_holder"
		return ""
	)
	
	fn loadMultiscatter = (
		v = useSettings "MULTISCATTER" undefined type:#get
		if(v != "") do (
			edtMultiScatter.text = substituteString v "|" "\r\n"
			return v
		)
		edtMultiScatter.text = ""
		return ""
	)
		
	fn getAttachPatterns = (
		t = edtAttachPattern.text 
		a = explode t tag: "\r\n"	

		out = #()
			
		for i in a where i != "" and i != " " do (
			o = getObjectsByName i
			if(o.count == 0) do (
				print ("!!! Objects for attach \"" + i + "\" not found !!!")
				continue
			)
			append out #(o, i)
		)
		
		return out
	)
	
	fn getMultiScatter = (
		t = edtMultiScatter.text 
		a = explode t tag: "\r\n"
		out = #()
				
		for i in a where i != "" and i != " " do (			
			isApplyFaceMapping = false
			if(findString i "@" != undefined) do (
				i = substituteString i "@" ""
				isApplyFaceMapping = true
			)
			
			j = explode i tag: "="
			if(j.count != 2) do continue
			if(j[1].count < 2 or j[2].count < 2) do (
				print ("!!! Wrong name format for multiscatter \"" + i + "\" objects !!!")
				continue
			)
		
			m = getObjectsByName j[1]
			o = getObjectsByName j[2]
				
			if(m.count == 0 or o.count == 0) do (
				print ("!!! Objects for multiscatter \"" + i + "\" not found !!!")
				continue
			)
			
			if(isApplyFaceMapping) do (
				uvwFace = Uvwmap()
				uvwFace.maptype = 5
				try(addModifier o[1] uvwFace) catch(print ("!!! Error when apply face mappinf for \"" + i + "\" !!!"))
			)
					
			append out #(m[1], o[1])			
		)
		
		return out
	)
	
	fn applyMultiScatter = (
		o = getMultiScatter()
		
		for i in o do (
			if(classOf i[1] == Multiscatter and superClassOf i[2] == GeometryClass) do (
				i[1].Node_Mesh = i[2]
			)
		)
	)
		
	fn loadPreset = (
		v = useSettings "PRESET_RPS" undefined type:#get
		if(doesFileExist v) do (
			edtPreset.text = v		
			return v
		)
		edtPreset.text = ""
		return ""
	)
	
	fn loadMatLibs = (
		szMatLibs = getMatLibs()
		if(szMatLibs != undefined) do (
			lbxMatLibs.items = for i in szMatLibs collect getFileNameFile i
		)
	)
	
	-- name as FBX
	fn alignObjects name: "City" = (
		objs = $*		
		g = group objs name: name		
		g.pivot = objs.center
		g.pivot.z = objs.min.z
		g.pos = [0,0,0]
	)
	
	fn getOpenMatFiles = 
	(
		f = #()
		
		d = dotNetObject "System.Windows.Forms.OpenFileDialog" 
		d.title = "Select Files"
		d.Multiselect = true
		d.Filter = "Material Libraries (*.mat)|*.mat"
		d.FilterIndex = 1
		
		result = d.showDialog() 
		result.ToString() 
		result.Equals result.OK 
		result.Equals result.Cancel 
		
		f = d.fileNames 
				 
		return f
	)
	
	on edtAttachPattern TextChanged s a do (
		t = edtAttachPattern.text
		bad = #("\t", "*", "\"", "'", "|")
		for i in bad do t = substituteString t i ""
		t = substituteString t "\r\n\r\n" "\r\n"
		edtAttachPattern.text = t
		useSettings "ATTACH_PATTERNS" (substituteString t "\r\n" "|") type:#set
	)
	
	on edtMultiScatter TextChanged s a do (
		t = edtMultiScatter.text
		bad = #("\t", "*", "\"", "'", "|")
		for i in bad do t = substituteString t i ""
		t = substituteString t "\r\n\r\n" "\r\n"
		edtMultiScatter.text = t
		useSettings "MULTISCATTER" (substituteString t "\r\n" "|") type:#set
	)
	
	fn breakLine s e = (
		if e.KeyCode == e.KeyCode.Enter do 
		(
			local sel = s.selectionstart
			s.text = (dotNetobject "system.string" s.text).insert s.selectionStart (dotNetClass "System.Environment").newline
			s.selectionStart=sel+2
			s.selectionLength=0
			s.scrollToCaret()
			s.refresh()
		)
	)
	
	on edtAttachPattern KeyUp s e do breakLine s e 		
	on edtMultiScatter KeyUp s e do breakLine s e
	
	
	on btnSelectMatPath pressed do
	(						
		f = getOpenMatFiles()
			
		if(f.count == 0) do return false
		
		ini = pathAutoMaterialIni
		
		for i in f do setIniSetting ini "MAT_LIBS" i ""
			
		libs = getMatLibs()
			
		lbxMatLibs.items = for i in libs collect getFileNameFile i				
	)
	
	on btnClearMatLibs pressed do clearMatLibs()
	
	fn mrg f = try(mergeMaxFile f #deleteOldDups #useMergedMtlDups #noRedraw quiet: true) catch(print ("Error to load 3ds Max file " + (getFileNameFile f)))		
	fn loadRPS f = renderPresets.LoadAll 0 f
		
	fn fatalError m = (
		messageBox m title: "Error!"
			
		try(closeRolloutFloater rCitySetup)catch()
		return false
	)
	
	fn attachByPatternName = (
		p = getAttachPatterns()
		
		for i in p do quickAttach i[1] name: i[2]
	)
	
	fn stripMapPaths = (
		for b in BitmapTypes where b != undefined do (
			for i in getClassInstances b where i != undefined and i.filename != undefined do (
				i.filename = filenameFromPath i.filename
			)
		)
	)
	
	fn setupUnits = (
		units.displayType = #Metric
		units.metricType = #Meters
		units.SystemType = #Meters
	)
		
	on btnSetupCity pressed do (
		
		q = queryBox "Do you really want to setup this city?" title: "Confirm?"
		if(not q) do return false
		
		f = edtCityFBX.text
		if(f == "") do return messageBox "Please select City FBX file!" title: "Warning!"			
		if(lbxMatLibs.items.count == 0) do return messageBox "Please add at least one material library!" title: "Warning!"	
		if(edtAssets.text == "") do return messageBox "Please choose assets!" title: "Warning!"
		if(edtPreset.text == "") do return messageBox "Please choose Render Presets (*.rps)!" title: "Warning!"
		
		
		outFile = getSaveFileName caption:"Save File" types:"3ds Max (*.max)|*.max"
		if(outFile == undefined) do return false
		
				
		boost()
		
		-- Seup Meters
				
		setupUnits()		
		-- Import FBX
		resetMaxFile #noPrompt 		
		setupUnits()
		resetMaxFile #noPrompt 	
		setupUnits()
		
		saveMaxFile outFile quiet: true
		resetMaxFile #noPrompt 
		loadMaxFile  outFile useFileUnits: true quiet: true

		importFile f #noPrompt		
		
		objs = $*
		if(objs.count == 0) do return messageBox "Error while loading City FBX.\nPlease check FBX manually!" title: "Error!"
		
		-- Set pivot and scale
		alignObjects name: (getFilenameFile edtCityFBX.text)
		

		-- Apply Materials
		szMatLibs= getMatLibs()
		fileIn pathAutoMaterial
		setFocus btnLoadCityFBX
		::_AUTO_MATERIAL_STEP1.rdoAssignTo.state = 1
		::_AUTO_MATERIAL_STEP1.assignAutoMaterial szMatLibs
		try(closeRolloutFloater rAutoMaterial)catch()
		
		-- Load Render Presets
		loadRPS edtPreset.text
				
		-- Merge MAX files
		mrg edtCameras.text
		mrg edtAssets.text
				
		-- Attach by pattern name
		attachByPatternName()	

		-- Add objects to MultiScatter
		applyMultiScatter()
		
		-- Strip Paths
		stripMapPaths()
		
		saveMaxFile outFile quiet: true
		
		setFocus btnLoadCityFBX
		messageBox "City loaded success!" title: "Success!" beep: false
	) 
	
	on btnLoadCityFBX pressed do (
		f = getOpenFileName caption:"Choose File" types:"FBX (*.fbx)|*.fbx"
		if(f == undefined) do return false
		
		useSettings "CITY_FBX" f type:#set
		
		loadCityFBX()
	)
	
	on btnLoadCameras pressed do (
		f = getOpenFileName caption:"Choose File" types:"3ds Max (*.max)|*.max"
		if(f == undefined) do return false
		
		useSettings "CAMERAS_MAX" f type:#set
		
		loadCameras()
	)
	
	on btnLoadAssets pressed do (
		f = getOpenFileName caption:"Choose File" types:"3ds Max (*.max)|*.max"
		if(f == undefined) do return false
		
		useSettings "ASSETS_MAX" f type:#set
		
		loadAssets()
	)
	
	on btnLoadPreset pressed do (
		f = getOpenFileName caption:"Choose File" types:"Render Presets File (*.rps)|*.rps"
		if(f == undefined) do return false
		
		useSettings "PRESET_RPS" f type:#set
		
		loadPreset()
	)
	
	
	on _CITY_SETUPL_STEP1 open do (
		pathAutoMaterial = getFileNamePath (getThisScriptFileName()) + "Auto Material.ms"
		pathAutoMaterialIni = getFileNamePath (getThisScriptFileName()) + "Auto Material.ms.ini"
					
		if(not doesFileExist pathAutoMaterial) do (
			m = "Please download and put Auto Material.ms script in the same folder with City Setup.ms!\n\n"
			m += "Download and unpack all scripts again!"
						
			return fatalError m
		)
		
		if(Multiscatter == undefined) do (
			m = "MultiScatter not installed!"			
			--return fatalError m
		)
				
		setFocus btnLoadCityFBX
		
		edtAttachPattern.MultiLine = true
		edtAttachPattern.scrollbars = (dotnetclass "System.Windows.Forms.ScrollBars").vertical		
		edtAttachPattern.acceptsReturn = true
		edtAttachPattern.acceptsTab = true
		edtAttachPattern.wordWrap = true
		edtAttachPattern.readOnly = false
		
		edtMultiScatter.MultiLine = true
		edtMultiScatter.scrollbars = (dotnetclass "System.Windows.Forms.ScrollBars").vertical		
		edtMultiScatter.acceptsReturn = true
		edtMultiScatter.acceptsTab = true
		edtMultiScatter.wordWrap = true
		edtMultiScatter.readOnly = false
		
		-- Load Settings
		--loadCityFBX()
		loadMatLibs()
		--loadCameras()
		loadAssets()
		loadPreset()
		loadAttachPatterns()	
		loadMultiscatter()				
	)
)

rollout _rAbout "About" 
(
	label lblName "" 
	label lblVer "" 
	
	label lblAuthor "" height: 30
	label lblCopy ""  height: 30
	
	local c = color 200 200 200 
	hyperLink href1 "" address: "" align: #center hoverColor: c visitedColor: c offset: [0, 20]
	
	button btnUpdate "Update" offset: [0, 20] enabled: false
	
	on btnUpdate pressed do 
	(
		currPath = getFilenamePath (getThisScriptFileName())
		
		try(
			fileIn (currPath + "InstallAndUpdate.ms")
			closeRolloutFloater rCitySetup			
		)catch()
	)
	
	on _rAbout open do
	(				
		i = scriptInfo()
			
		lblName.caption = i.name
		lblAuthor.caption = i.author
		lblVer.caption = i.version
		lblCopy.caption = i.dev
		href1.address = i.web
		href1.caption = i.web	

		currPath = getFilenamePath (getThisScriptFileName())				
		if(doesFileExist (currPath + "InstallAndUpdate.ms")) do btnUpdate.enabled = true		
	)
)

addRollout _CITY_SETUPL_STEP1 rCitySetup 
addRollout _rAbout rCitySetup rolledUp:true