property htmlPath : Text
property htmlHint : Text
property formName : Text
property apiKey : Text
property logText : Text
property previewUrl : Text
property statusText : Text
property tokenText : Text
property versionText : Text
property generatedJson : Text
property activeTab : Integer
property actions : Object

Class constructor()
	This.htmlPath:=""
	This.htmlHint:="No file selected"
	This.formName:=""
	This.apiKey:=""
	This.logText:=""
	This.previewUrl:="about:blank"
	This.statusText:="Ready — select an HTML file to begin"
	This.tokenText:=""
	This.versionText:="4D v21 · Project Mode"
	This.generatedJson:=""
	This.activeTab:=1
	This.actions:={converting: {running: 0}}

//MARK: - Form & form objects event handlers

Function formEventHandler($formEventCode : Integer)
	Case of
		: ($formEventCode=On Load)
			OBJECT SET VISIBLE(*; "spinnerConvert"; False)
			OBJECT SET VISIBLE(*; "areaJsonOutput"; False)
	End case

Function btnBrowseEventHandler($formEventCode : Integer)
	Case of
		: ($formEventCode=On Clicked)
			var $docName : Text:=Select document(""; ""; "Select an HTML file"; 0)
			If (OK=1)
				This.htmlPath:=Document
				var $file : 4D.File:=File(Document; fk platform path)
				This.htmlHint:=$file.name+" · "+String(Round($file.size/1024; 1))+" KB"
				This.previewUrl:="file://"+Document
				This.statusText:="File selected: "+$file.name
				This.log("File loaded: "+$file.name)
			End if
	End case

Function btnConvertEventHandler($formEventCode : Integer)
	Case of
		: ($formEventCode=On Clicked)
			If (This.htmlPath="")
				ALERT("Please select an HTML file first.")
				return
			End if
			If (This.formName="")
				ALERT("Please enter an output form name.")
				return
			End if
			If (This.apiKey="")
				ALERT("Please enter your OpenAI API key.")
				return
			End if

			This.actions.converting.running:=1
			OBJECT SET VISIBLE(*; "spinnerConvert"; True)
			OBJECT SET TITLE(*; "btnConvert"; "Converting…")
			This.statusText:="Calling OpenAI API…"
			This.tokenText:=""
			This.log("Starting → "+This.formName)
			This.log("Calling OpenAI API…")

			var $result : Object:=ConvertHTMLTo4DForm(This.htmlPath; This.formName; This.apiKey)

			This.actions.converting.running:=0
			OBJECT SET VISIBLE(*; "spinnerConvert"; False)
			OBJECT SET TITLE(*; "btnConvert"; "Convert →")

			If ($result.success)
				This.generatedJson:=$result.json
				If ($result.tokenCount>0)
					This.tokenText:="gpt-4o · "+String($result.tokenCount)+" tokens"
				End if
				This.statusText:="✓ form.4dform written"
				This.log("✓ Written to Sources/Forms/"+This.formName+"/")
			Else
				This.statusText:="✗ "+$result.error
				This.log("✗ "+$result.error)
				ALERT("Conversion failed:\n"+$result.error)
			End if
	End case

Function tabMainEventHandler($formEventCode : Integer)
	Case of
		: ($formEventCode=On Clicked)
			// activeTab is 1-based: 1 = Live Preview, 2 = Output JSON
			var $showPreview : Boolean:=(This.activeTab=1)
			OBJECT SET VISIBLE(*; "webPreview"; $showPreview)
			OBJECT SET VISIBLE(*; "areaJsonOutput"; Not($showPreview))
	End case

//MARK: - Helpers

Function log($message : Text)
	var $ts : Text:=String(Current time; HH_MM_SS)
	If (This.logText#"")
		This.logText:=This.logText+Char(13)
	End if
	This.logText:=This.logText+$ts+"  "+$message
