/*  
[INFO] 

NAME = Auto Material
VERSION = 1.0.2
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

[ABOUT]

Assign materials from library to objects with according names=

[TEST]

[SCRIPT]
*/	


try(closeRolloutFloater rAutoMaterial)catch()
global rAutoMaterial = newRolloutFloater "Auto Material" 280 600

global _STEP1
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

rollout _STEP1 "Material Renamer"
(
	group "Info" (		
		dotNetControl edtMiniManual "System.Windows.Forms.TextBox" width: 240  height: 200
	)
	
	group "Material Lib Path"
	(
		radiobuttons rdoAssignTo "Assign Materials To:" labels: #("All scene objects", "Selected objects") align: #left
		edittext edtMatPath "" height: 25 readOnly: true
		button btnSelectMatPath "Select Path" 
	)
	
	
	button btnAutoAssignMaterials "Assign Materials to Objects" height: 35 width: 240 offset: [0, 12]
	
	
	fn getMatPath = (
		szMatPath = useSettings "MAT_PATH" "" type:#get
		
		if(doesFileExist szMatPath) do return szMatPath
		return undefined
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
		for i in 1 to matLib.count where matLib[i] != undefined and matLib[i].name == n do return matLib[i]
		return undefined
	)
	
	fn assignAutoMaterial szMatPath = (		
		
		freezeUi()
		
		clearListener()
		matLib = loadTempMaterialLibrary szMatPath
				
		if(matLib == undefined or matLib.count == 0) do return messageBox "Material library is empty!" title: "Error!"
		if(rdoAssignTo.state == 2 and selection.count == 0) do return messageBox "Please select objects!" title: "Warning!"
		
		
		c = matLib.count
		
		matNames = for i in 1 to c where matLib[i] != undefined collect matLib[i].name
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

			tmp_objs = try(execute("$'" + n + "'* as array")) catch(
				print ("====  Can't get objects with name \"" + n + "\" ====")
			)
			
			if(rdoAssignTo.state == 2) then (
				for oo in (selection as array) do (
					if(findItem tmp_objs oo != 0) do append objs oo
				)
			) else (
				objs = tmp_objs
			)
			
			progressUpdate (100 * i / matNames.count)
			
			if(objs == undefined or objs.count == 0) do (
				print ("==== Objects for material \"" + n + "\" not found! ====")
				continue
			)
			
			for o in objs where o != undefined do try(
				o.material = m
				print ("Assign material \"" + m.name + "\" to \"" + o.name + "\"")
			) catch()
		)
		enableSceneRedraw()
		progressEnd()
		
	)
	
	on btnSelectMatPath pressed do
	(
		szMatPath = getMatPath()
		tmp = szMatPath
		if(tmp == undefined) do tmp = ""
		
		f = getOpenFileName caption:"Choose Material Lib Path" filename: tmp types:"mat (*.mat)|*.mat"
			
		if(f == undefined) do return false
		
		szMatPath = f
		edtMatPath.text = szMatPath
		
		useSettings "MAT_PATH" szMatPath type:#set
	)
	
	on rdoAssignTo changed a do (
		useSettings "APPLY_TO" (a as string) type:#set
	)
		
	on _STEP1 open do (
		szMatPath = getMatPath()
		if(szMatPath != undefined) do edtMatPath.text = szMatPath
		
		szApplyTo = useSettings "APPLY_TO" "" type:#get
		if(szApplyTo != "") do try(rdoAssignTo.state = szApplyTo as integer) catch()
				
		
		n = "\r\n"
		initText = "Quick Tips:" + n + n
		initText += "1. Do not use cyrillic symbols in object names!" + n
		initText += "2. Be careful when copy objects with SHIFT hotkey. Double check the names after cloning!" + n
		
		edtMiniManual.MultiLine = true
		edtMiniManual.scrollbars = (dotnetclass "System.Windows.Forms.ScrollBars").vertical		
		edtMiniManual.acceptsReturn = true
		edtMiniManual.acceptsTab = true
		edtMiniManual.wordWrap = true
		edtMiniManual.readOnly = true
		
		edtMiniManual.text =  initText
	)
	
	on btnAutoAssignMaterials pressed do (
		r = rdoAssignTo.state
		type = if(r == 2) then "selected" else "all"
		if(r == 2 and selection.count == 0) do return messageBox "Please select objects!" title: "Warning!"
		q = queryBox ("Do you really want to assign materials from library to " + type + " scene objects?") title: "Confirm?"
		if(not q) do return false
				
		szMatPath = getMatPath()
		if(szMatPath == undefined) do return messageBox "Please select correct material library" title: "Error!"
		
		undo off (
			assignAutoMaterial szMatPath		
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

addRollout _STEP1 rAutoMaterial 
addRollout _rAbout rAutoMaterial rolledUp:true