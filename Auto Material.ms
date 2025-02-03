/*  
[INFO] 

NAME = Auto Material
VERSION = 1.1.4
AUTHOR = Vasily Lukyanenko
DEV = 3DGROUND
CUSTOMER = Andrew Andreyuk
SKYPE = notfun1
HELP = 

[INSTALL]

MACRO=AutoMaterial
CAT=3DGROUND
TEXT=Auto Material
ICON=#("PhysX_Main", 30)

[1.0.0]

* First release =

[1.0.1]

- BugFix: Select path exception =

[1.0.2]

+ Added: Choose apply materials to all or selected objects =
+ Added: Highlight error log with special symbols =

[1.0.3]

+ Added: Assign random materials from library with use brakets in the name=

[1.0.4]

+ Added: Option move objects to layer=

[1.1.0]

* Changed: Load several libraries at time=
- Removed: Load material lib path option=

[1.1.2]

* Changed: Avoid list libs list cleaning=

[1.1.3]

+ Added: Assign materials by layers name=

[1.1.4]

+ Added: Options Freeze Mappped Layers and Hide Mapped Layers=

[ABOUT]

Assign materials from library to objects with according names=

[TEST]

[SCRIPT]
*/	


try(closeRolloutFloater rAutoMaterial)catch()
global rAutoMaterial = newRolloutFloater "Auto Material" 280 695

global _AUTO_MATERIAL_STEP1
global BitmapTypes = #(Bitmaptexture, CoronaBitmap)

fn trim s c: " " = trimRight (trimLeft s c) c

fn getScriptInfo s releaseInfo: "" =
(		
	if(releaseInfo != "") do
	(
		r = getINISetting s releaseInfo
		return r
	)
	
	v = getINISetting s "INFO" "VERSION"
	a = getINISetting s "INFO" "AUTHOR"
	n = getINISetting s "INFO" "NAME"
	o = getINISetting s "ABOUT"
	c = getINISetting s "INFO" "DEV"
	h = getINISetting s "INFO" "HELP"
	
	r = for i in (getINISetting s) where i != "ABOUT" and i != "SCRIPT" and i != "COPY" collect i
	
	return #(n, a, v, o, r, c, h)
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

rollout _AUTO_MATERIAL_STEP1 "Material Renamer"
(
	group "Info" (		
		dotNetControl edtMiniManual "System.Windows.Forms.TextBox" width: 240  height: 200
	)
	
	group "Material Libraries" (
		radiobuttons rdoAssignTo "Assign Materials To:" labels: #("All scene objects", "Selected objects", "All scene layers") align: #left
		listbox lbxMatLibs "" offset: [0, 5]
		button btnSelectMatPath "Load Mat Libs" across: 2 width: 100 height: 25 offset: [0, 5]
		button btnClearMatLibs "Clear All" width: 100 height: 25 offset: [0, 5]
	)
	
	group "Settings" (
		checkbox cbxMoveToLayer "Move objects to layer" align: #left
		checkbox cbxFreezeMappedLayers "Freeze mapped layers" align: #left enabled: false
		checkbox cbxHideMappedLayers "Hide mapped layers" align: #left enabled: false
	)
	
	button btnAutoAssignMaterials "Assign Materials to Objects" height: 35 width: 240 offset: [0, 12]
	
	fn loadSettings = (
		local szApplyTo = useSettings "APPLY_TO" "" type:#get
		if(szApplyTo != "") do try(rdoAssignTo.state = szApplyTo as integer) catch()
		
		
		local szMoveToLayer = useSettings "MOVE_TO_LAYER" "" type:#get
		if(szMoveToLayer != "") do try(cbxMoveToLayer.checked = szMoveToLayer as booleanClass) catch()
		
		
		local isFreezeMappedLayers = useSettings "FREEZE_MAPPED_LAYERS" "" type:#get
		local isHideMappedLayers = useSettings "HIDE_MAPPED_LAYERS" "" type:#get
		
		
		if (isFreezeMappedLayers != "") do try(cbxFreezeMappedLayers.checked = isFreezeMappedLayers as booleanClass) catch()
		if (isHideMappedLayers != "") do try(cbxHideMappedLayers.checked = isHideMappedLayers as booleanClass) catch()
		
		cbxMoveToLayer.enabled = rdoAssignTo.state != 3						
		
		if (cbxMoveToLayer.enabled == false) then (
			cbxFreezeMappedLayers.enabled = true
			cbxHideMappedLayers.enabled = true
		) else (
			cbxFreezeMappedLayers.enabled = false
			cbxHideMappedLayers.enabled = false
		)
	)
	
	fn clearMatLibs = (
		q = queryBox "Do you really want to clear all material libraries from list?" title: "Confirm?"
		if(not q) do return false
		
		ini = getThisScriptFilename() + ".ini"
		delIniSetting ini "MAT_LIBS"				
		lbxMatLibs.items = #()
	)
	
	fn getMatLibs = (
		ini = getThisScriptFilename() + ".ini"
		f = getIniSetting ini "MAT_LIBS" 		
		libs = for i in f where doesFileExist i collect i 				
		if(libs.count == 0) do return undefined		
		return libs
	)
	
	fn compareFN v1 v2 =
	(
		local d = v1.count - v2.count
		case of
		(
			(d < 0.): -1
			(d > 0.): 1
			default: 0
		)
	)
	
	fn getMatByName n matLib = (
		for i in 1 to matLib.count where matLib[i] != undefined and (matLib[i].name == n) do return matLib[i]
		return undefined
	)
	
	fn findVariations m matLib = (
		mm = for i in 1 to matLib.count where matLib[i] != undefined and (matchPattern matLib[i].name pattern: (m.name + "[*]")) collect matLib[i]
		append mm m
			
		return mm[random 1 mm.count]
	)
	
	fn moveToLayer o n = (
		local s = rdoAssignTo.state
		if (not cbxMoveToLayer.checked) do return false
		if (s != 1 and s != 2) do return false
		
		local l = LayerManager.getLayerFromName n
		if(l == undefined) do 
		(
			l = LayerManager.NewLayer()
			l.setName n
		)
		if(l != undefined) do  l.addNode o
	)
	
	fn setStatusMappedLayer oo = (
		local s = rdoAssignTo.state
		if (s != 3) do return false
		if (oo[1] == undefined or  oo[1].layer == undefined) do return false
		
		local l = oo[1].layer
		if (cbxFreezeMappedLayers.checked) do (
			l.isFrozen = true
		)
		
		if (cbxHideMappedLayers.checked) do (
			l.on = false
		)		
	)
	
	fn getLayerNodes n = (
		local l = LayerManager.getLayerFromName n
		if (l == undefined) do return #()
		l.nodes &nodes
		return nodes
	)

	
	fn assignAutoMaterial szMatLibs = (		
		
		freezeUi()
		
		if(rdoAssignTo.state == 2 and selection.count == 0) do return messageBox "Please select objects!" title: "Warning!"
		
		for lib in szMatLibs do (
			local assignType = rdoAssignTo.state
		
			matLib = loadTempMaterialLibrary lib
				
			szMatName = getFilenameFile lib
			
			if(matLib == undefined or matLib.count == 0) do (				
				print ("!!! Material library \"" + szMatName + "\" is empty !!!")
				continue
			)
			
			c = matLib.count
			
			matNames = for i in 1 to c where matLib[i] != undefined and (matchPattern matLib[i].name pattern: ("*[*]")) == false collect matLib[i].name
			qsort matNames compareFN
			
			progressStart "Apply Auto Material"
			disableSceneRedraw()
			for i in 1 to matNames.count do (
				n = matNames[i]
				
				m = getMatByName n matLib
				if(m == undefined) do (
					print ("==== Error material \"" + n + "\" not found! ====")
					continue
				)
				
				objs = #()
				
				n = substituteString n @"\" @"\\"
				n = substituteString n "'" @"\'"

				local all_scene_objs = try(execute("$'" + n + "'* as array")) catch(
					print ("====  Can't get objects with name \"" + n + "\" ====")
				)
				
				case assignType of (
					1: objs = all_scene_objs
					2: (
						for oo in (selection as array) do (
							if(findItem all_scene_objs oo != 0) do append objs oo
						)
					)
					3: (
						objs = getLayerNodes n
					)
				)
				
				progressUpdate (100 * i / matNames.count)
				
				if(objs == undefined or objs.count == 0) do (
					print ("==== Objects for material \"" + n + "\" not found! ====")
					continue
				)
				
				setStatusMappedLayer objs
				
				for o in objs where o != undefined do try(
					--o.material = m
					o.material = findVariations m matLib
					
					moveToLayer o szMatName
					
					print ("Assign material \"" + o.material.name + "\" to \"" + o.name + "\"")
				) catch()
			)
			enableSceneRedraw()
			progressEnd()
		)
		
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
	
	on btnClearMatLibs pressed do clearMatLibs()
	
	on btnSelectMatPath pressed do
	(						
		f = getOpenMatFiles()
			
		if(f.count == 0) do return false
		
		ini = getThisScriptFilename() + ".ini"
		
		--delIniSetting ini "MAT_LIBS"
				
		for i in f do setIniSetting ini "MAT_LIBS" i ""
			
		libs = getMatLibs()
			
		lbxMatLibs.items = for i in libs collect getFileNameFile i				
	)
	
	on cbxMoveToLayer changed a do (
		useSettings "MOVE_TO_LAYER" (a as string) type:#set
	)
	
	on cbxFreezeMappedLayers changed a do (
		useSettings "FREEZE_MAPPED_LAYERS" (a as string) type:#set
	)
	
	on cbxHideMappedLayers changed a do (
		useSettings "HIDE_MAPPED_LAYERS" (a as string) type:#set
	)
	
	on rdoAssignTo changed a do (
		useSettings "APPLY_TO" (a as string) type:#set
		loadSettings()
	)
		
	on _AUTO_MATERIAL_STEP1 open do (
		szMatLibs = getMatLibs()
		if(szMatLibs != undefined) do (
			lbxMatLibs.items = for i in szMatLibs collect getFileNameFile i
		)
				
		loadSettings()
		
		n = "\r\n"
		initText = "Quick Tips:" + n + n
		initText += "1. Do not use cyrillic symbols in object names!" + n
		initText += "2. Be careful when copy objects with SHIFT hotkey. Double check the names after cloning!" + n
		initText += "3. Use brackets in material library names for define random materials ex.: test_02[1], test_02[2], test_02[3] ..." + n
		
		edtMiniManual.MultiLine = true
		edtMiniManual.scrollbars = (dotnetclass "System.Windows.Forms.ScrollBars").vertical		
		edtMiniManual.acceptsReturn = true
		edtMiniManual.acceptsTab = true
		edtMiniManual.wordWrap = true
		edtMiniManual.readOnly = true
		
		edtMiniManual.text =  initText
	)
	
	on btnAutoAssignMaterials pressed do (
		local r = rdoAssignTo.state
		type = case r of (
			1: "all scene objects"
			2: "selected objects"
			3: "all scene layers"
		)
		
		if(r == 2 and selection.count == 0) do return messageBox "Please select objects!" title: "Warning!"
		local q = queryBox ("Do you really want to assign materials from library to " + type + "?") title: "Confirm?"
		if(not q) do return false
				
		szMatLibs= getMatLibs()
		if(szMatLibs == undefined) do return messageBox "Please select at least one material library!" title: "Error!"
		
		undo off (
			assignAutoMaterial szMatLibs		
		)
	)
)

rollout _rAbout "About" 
(
	label lblName "" 
	label lblVer "" 
	
	label lblAuthor "" height: 30
	label lblCopy ""  height: 30
	
	local c = color 200 200 200 
	hyperLink href1 "http://3dground.net/" address: "http://3dground.net/" align: #center hoverColor: c visitedColor: c offset: [0, 20]
	
	on _rAbout open do
	(		
		i = getScriptInfo (getThisScriptFilename())
			
		lblName.caption = i[1]
		lblAuthor.caption = i[2]
		lblVer.caption = i[3]
		lblCopy.caption = i[6]
	)
)

addRollout _AUTO_MATERIAL_STEP1 rAutoMaterial 
addRollout _rAbout rAutoMaterial rolledUp:true