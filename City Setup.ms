/*  
[INFO] 

NAME = City Setup
VERSION = 1.1.2
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

[1.0.5]

+ Added: Fixed MultiScatter error dialog=

[1.0.6]

* Changed: UI "Browse File" changed to "..."=
+ Added: Batch Render Button=

[1.0.7]

* Changed: Baloon Tooltips=
+ Added: Setup & Save path=
- BugFix: VRay save render elements=

[1.0.8]

* Changed: Set Move To Layer for Auto Material=

[1.0.9]

+ Added: Set "on" setting Smooth Group for FBX importer=

[1.1.0]

+ Added: Cameras sort=

[1.1.1]

- BugFix: Get cam list=

[1.1.2]

- BugFix: Cam target=

[ABOUT] 

Quick apply actions to the city=

[TEST]

[SCRIPT]
*/	




try(closeRolloutFloater rCitySetup)catch()
global rCitySetup = newRolloutFloater "City Setup" 320 960

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

fn showTooltip c t title: "Info!" args: undefined show: 10000 active: false enable: true align: #right =
(			
	toolTip = dotNetObject "System.Windows.Forms.ToolTip"	
	toolTip.Active = active
	
	--if(args != undefined and args.Button != args.Button.Middle) do return false
	if(not enable) do return false
			
	toolTip.SetToolTip c t  
	toolTip.isBalloon = true
	toolTip.InitialDelay = 100
	toolTip.AutoPopDelay = show
	toolTip.ReshowDelay = 50
	toolTip.ToolTipTitle = title
	
	
	y = c.Height - 5 
	x = if(align == #right) then c.Width - 5 else 5
	
	
	toolTip.Show t c x y show
	i = dotNetClass "System.Windows.Forms.ToolTipIcon"
	case title of
	(
		"Warning!": toolTip.ToolTipIcon = i.Warning
		"Info!": toolTip.ToolTipIcon = i.Info
		"Error!": toolTip.ToolTipIcon = i.Error
	)
	
	return toolTip
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

fn isVray =
(
	rr = renderers.current
	if(matchPattern (rr as string) pattern:"V_Ray_Adv*") do return true
	return false
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

fn getSortedCamList = (
	cc = for i in cameras as array where classOf i != Targetobject collect i.name
	sort cc	
	l = for i in cc collect execute ("$'" + i + "'")
	return l
)

fn animateCamera = (
	cams = getSortedCamList()
	c1 = cams[1]
	if(c1 == undefined) do return false
		
	sliderTime = 0f
	animatedCam = freeCamera fov: c1.fov name: "Animated Camera Render"
		
	animate on (
		for c in 1 to cams.count do (
			at time (c-1) (
				animatedCam.transform = cams[c].transform
				animatedCam.pos = cams[c].pos
			)
		)
	)

	animationRange = interval 0 (cams.count-1)
	
	return animatedCam
)

global pathAutoMaterial = ""
global pathAutoMaterialIni = ""

rollout _CITY_SETUPL_STEP1 "Main"
(
	group "Load City (*.fbx)" (
		edittext edtCityFBX "" readonly: true height: 25 across: 2 align: #left fieldwidth: 238
		button btnLoadCityFBX "..." width: 35 height: 25 align: #right
	)
	
	group "Material Libraries (Auto Material)" (
		listbox lbxMatLibs "" offset: [0, 5] height: 6
		button btnSelectMatPath "Load Mat Libs" across: 2 width: 100 height: 25 offset: [0, 5]
		button btnClearMatLibs "Clear All" width: 100 height: 25 offset: [0, 5]
	)
	
	group "Load Cameras (*.max) (optional)" (
		edittext edtCameras "" readonly: true height: 25 across: 2 align: #left fieldwidth: 238
		button btnLoadCameras "..." width: 35 height: 25 align: #right
	)
	
	group "Load Assets (*.max)" (
		edittext edtAssets "" readonly: true height: 25 across: 2 align: #left fieldwidth: 238
		button btnLoadAssets "..." width: 35 height: 25 align: #right
	)
	
	group "Load Render Preset (*.rps)" (
		edittext edtPreset "" readonly: true height: 25 across: 2 align: #left fieldwidth: 238
		button btnLoadPreset "..." width: 35 height: 25 align: #right		
	)
	
	group "Attach Objects by Name Pattern (optional)" (
		dotNetControl _btnTooltip1 "System.Windows.Forms.Button" align:#right offset: [270, 0]
		dotNetControl edtAttachPattern "System.Windows.Forms.TextBox" width: 285  height: 60
	)

	
	group "MultiScatter (optional)" (
		dotNetControl _btnTooltip2 "System.Windows.Forms.Button" align:#right offset: [270, 0]
		dotNetControl edtMultiScatter "System.Windows.Forms.TextBox" width: 285  height: 60
	)
	
	group "Setup && Save" (
		edittext edtSaveToPath "" readonly: true height: 25 across: 2 align: #left fieldwidth: 238
		button btnSaveToPath "..." width: 35 height: 25 align: #right
		
		checkbox cbxAutoRender "Auto Render" checked: false
		button btnSetupCity "Setup City" height: 35 width: 280 offset: [0, 5]		
	)
	
	group "Render" (
		edittext edtBatchRenderPath "" readonly: true height: 25 across: 2 align: #left fieldwidth: 238
		button btnSetBatchRenderPath "..." width: 35 height: 25 align: #right
		
		button btnBatchCamsRender "Batch Cams Render" width: 280 height: 35
	)
	
	on _btnTooltip1 mouseDown s a do showTooltip s "Unique part of name\r\nEach name from new line\r\nEx.: Roof_Grass or Ground_Grass ..." title: "Info!" show: 25000 args: a
	on _btnTooltip2 mouseDown s a do showTooltip s "Apply objects to MultiScatter\r\nEach setting from new line\r\nMultiScatter Helper Name = Object Name Pattern\r\n\r\nEx.: Side_Trees = Tree_place_holder\r\n------\r\nFor apply UVW Map (Face) put @ at start of string\r\n\r\nEx.: @Side_Trees = Tree_place_holder" title: "Info!" show: 25000 args: a
	
	fn initTooltip c = 
	(	
		c.text = "?"
		c.height = 16
		c.width = 16
		c.flatStyle = c.flatStyle.Popup 	
	)
	
	fn initDotNet = 
	(			
		initTooltip _btnTooltip1				
		initTooltip _btnTooltip2				
	)
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
	
	fn loadBatchRender = (
		v = useSettings "BATCH_RENDER" undefined type:#get
		if(v != "") do (
			edtBatchRenderPath.text = v		
			return v
		)
		edtBatchRenderPath.text = ""
		return ""
	)
	
	fn loadSaveToPath = (
		v = useSettings "SAVETO" undefined type:#get
		if(v != "") do (
			edtSaveToPath.text = v		
			return v
		)
		edtSaveToPath.text = ""
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
	
	fn batchCamsRender = (	
					
		if(not isVray()) do return messageBox "V-Ray not assigned!" title: "Error!"
		vr = renderers.current
		cams = cameras as array
				
		bb = edtBatchRenderPath.text
		if(bb == "") do return messageBox "Please Batch Render Path!" title: "Warning!"	
		if(maxFileName == "") do return messageBox "City setup? Seems the clear scene!" title: "Warning!"	
		if(cams.count == 0) do return messageBox "Cameras not found!" title: "Warning!"	
			
		tmp = @"C:\temp\temp_out_render_.jpg"
		for ii in (getFiles @"C:\temp\temp_out_render_*.jpg") do deleteFile ii
		deleteFile tmp
			
		n = bb + (getFileNameFile maxFileName) + "_.png"
			
		c = animateCamera()
		viewport.setCamera c
		if (renderSceneDialog.isOpen()) do renderSceneDialog.close() 
			
		rendSaveFile = true
		rendOutputFilename = tmp		
		rendTimeType = 2
		
		/*vr.output_saveRawFile = true 
		vr.output_on = true
		vr.output_rawFileName = n*/
		vr.output_splitgbuffer = true
		vr.output_splitfilename = n
			
		split_bitmap = Bitmap 10 10 fileName: n	
		save split_bitmap
		close split_bitmap
			
		vr.output_splitbitmap = split_bitmap
		deleteFile n
			
		renderSceneDialog.update()
		
		max quick render
	)
	
	on btnBatchCamsRender pressed do (
		q = queryBox "Do you really want to render this city?" title: "Confirm?"
		if(not q) do return false	
		
		batchCamsRender()
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
		if(edtSaveToPath.text == "") do return messageBox "Please choose save path!" title: "Warning!"
		if(edtBatchRenderPath.text == "") do return messageBox "Please Batch Render Path!" title: "Warning!"		
				
		outFile = (edtSaveToPath.text) + (getFilenameFile  f) + ".max"
						
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

		-- FBX Settings
		FBXImporterSetParam "SmoothingGroups" true
		importFile f #noPrompt using:FBXImporter	
		
		objs = $*
		if(objs.count == 0) do return messageBox "Error while loading City FBX.\nPlease check FBX manually!" title: "Error!"
		
		-- Set pivot and scale
		alignObjects name: (getFilenameFile edtCityFBX.text)
		

		-- Apply Materials
		szMatLibs= getMatLibs()
		fileIn pathAutoMaterial
		setFocus btnLoadCityFBX
		::_AUTO_MATERIAL_STEP1.rdoAssignTo.state = 1
		::_AUTO_MATERIAL_STEP1.cbxMoveToLayer.checked = true
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
		
		if(cbxAutoRender.checked) then (
			batchCamsRender()
		) else (
			messageBox "City loaded success!" title: "Success!" beep: false
		)
	) 
	
	on btnSetBatchRenderPath pressed do (		
			
		f = getSaveFileName filename: "DO NOT CHANGE NAME" caption:"Save File" types:"PNG (*.png)|*.png"
		if(f == undefined) do return false
		
		p = getFileNamePath f
				
		useSettings "BATCH_RENDER" p type:#set
		
		loadBatchRender()
	)
	
	on btnSaveToPath pressed do (
		f = getSaveFileName filename: "DO NOT CHANGE NAME" caption:"Save File" types:"3ds Max (*.max)|*.max"
		if(f == undefined) do return false
		
		p = getFileNamePath f
				
		useSettings "SAVETO" p type:#set
		
		loadSaveToPath()
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
			return fatalError m
		)
		
		initDotNet()
				
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
		loadBatchRender()
		loadMatLibs()
		loadSaveToPath()
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