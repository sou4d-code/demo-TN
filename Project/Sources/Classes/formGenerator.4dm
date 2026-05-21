property htmlPath : Text
property formName : Text
property apiKey : Text
property logText : Text
property previewUrl : Text
property statusText : Text
property actions : Object

Class constructor()
	This.htmlPath:=""
	This.formName:=""
	This.apiKey:=""
	This.logText:=""
	This.previewUrl:="about:blank"
	This.statusText:="Ready — select an HTML file to begin."
	This.actions:={converting: {running: 0}}

//MARK: - Form & form objects event handlers

Function formEventHandler($formEventCode : Integer)
	Case of
		: ($formEventCode=On Load)
			OBJECT SET VISIBLE(*; "spinnerConvert"; False)
	End case

Function btnBrowseEventHandler($formEventCode : Integer)
	Case of
		: ($formEventCode=On Clicked)
			var $docName : Text:=Select document(""; ""; "Select an HTML file"; 0)
			If (OK=1)
				This.htmlPath:=Document
				This.previewUrl:="file://"+This.htmlPath
				This.statusText:="File selected: "+This.htmlPath
				This.log("HTML file loaded: "+This.htmlPath)
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
			This.log("Starting conversion → form name: "+This.formName)

			var $result : Object:=ConvertHTMLTo4DForm(This.htmlPath; This.formName; This.apiKey)

			This.actions.converting.running:=0
			OBJECT SET VISIBLE(*; "spinnerConvert"; False)
			OBJECT SET TITLE(*; "btnConvert"; "Convert →")

			If ($result.success)
				This.statusText:="✓ Form created at: "+$result.outputPath
				This.log("Success! Written to: "+$result.outputPath)
				ALERT("Form generated successfully!\n\nPath: "+$result.outputPath)
			Else
				This.statusText:="✗ Conversion failed"
				This.log("Error: "+$result.error)
				ALERT("Conversion failed:\n"+$result.error)
			End if
	End case

//MARK: - Helpers

Function log($message : Text)
	If (This.logText#"")
		This.logText:=This.logText+Char(13)
	End if
	This.logText:=This.logText+"["+String(Current time; HH_MM_SS)+"] "+$message
