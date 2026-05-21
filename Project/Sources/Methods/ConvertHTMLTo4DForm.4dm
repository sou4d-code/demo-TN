#DECLARE($htmlPath : Text; $formName : Text; $apiKey : Text) : Object

var $result : Object:={success: False; outputPath: ""; error: ""}

Try
	// Read the HTML file
	var $htmlFile : 4D.File:=File($htmlPath; fk platform path)
	If (Not($htmlFile.exists))
		throw({message: "HTML file not found: "+$htmlPath})
	End if

	var $htmlContent : Text:=$htmlFile.getText()

	// Build system prompt encoding the .4dform schema + HTML mapping rules
	var $systemPrompt : Text
	$systemPrompt:="You are a 4D form generator. Your job is to read an HTML file and convert it into a valid .4dform JSON file for 4D project mode.\n"
	$systemPrompt:=$systemPrompt+"Output ONLY raw JSON. No markdown. No explanation. No code fences.\n\n"

	$systemPrompt:=$systemPrompt+"The .4dform schema:\n"
	$systemPrompt:=$systemPrompt+"{\"rightToLeft\": false, \"windowTitle\": \"<derived from page title or form content>\", "
	$systemPrompt:=$systemPrompt+"\"pages\": [{\"objects\": {}}], \"objects\": {"
	$systemPrompt:=$systemPrompt+"\"<camelCaseObjectName>\": {\"type\": \"<4d-type>\", \"left\": 0, \"top\": 0, \"width\": 200, \"height\": 24}}}\n\n"

	$systemPrompt:=$systemPrompt+"HTML to 4D type mapping:\n"
	$systemPrompt:=$systemPrompt+"<input type=\"text\"> or <input> → type: \"input\"\n"
	$systemPrompt:=$systemPrompt+"<label>              → type: \"text\" (add \"text\": \"<label content>\")\n"
	$systemPrompt:=$systemPrompt+"<button>             → type: \"button\" (add \"text\": \"<button label>\")\n"
	$systemPrompt:=$systemPrompt+"<select>             → type: \"dropDown\"\n"
	$systemPrompt:=$systemPrompt+"<input type=\"checkbox\"> → type: \"checkbox\" (add \"text\": \"<label>\")\n"
	$systemPrompt:=$systemPrompt+"<textarea>           → type: \"input\" (add \"scrollbar\": \"vertical\")\n"
	$systemPrompt:=$systemPrompt+"<fieldset>           → type: \"groupBox\" (add \"text\": \"<legend>\")\n"
	$systemPrompt:=$systemPrompt+"<img>                → type: \"picture\"\n"
	$systemPrompt:=$systemPrompt+"<h1>/<h2>/<h3>       → type: \"text\" (increase fontSize)\n\n"

	$systemPrompt:=$systemPrompt+"Layout rules:\n"
	$systemPrompt:=$systemPrompt+"- Start at left: 20, top: 60 for the first element.\n"
	$systemPrompt:=$systemPrompt+"- Increment top by ~30px per row (labels share a row with their input).\n"
	$systemPrompt:=$systemPrompt+"- Default label: width 120, height 20.\n"
	$systemPrompt:=$systemPrompt+"- Default input: width 260, height 24; left offset 150 (next to label).\n"
	$systemPrompt:=$systemPrompt+"- Default button: width 120, height 28; centered or right-aligned.\n"
	$systemPrompt:=$systemPrompt+"- Form width 460, height proportional to content.\n"
	$systemPrompt:=$systemPrompt+"- Object names must be unique camelCase strings derived from id/name/content.\n\n"

	$systemPrompt:=$systemPrompt+"Important: every object MUST have type, left, top, width, height."

	// Build messages collection
	var $messages : Collection:=[]
	$messages.push({role: "system"; content: $systemPrompt})
	$messages.push({role: "user"; content: $htmlContent})

	// Call OpenAI via 4D AIKit
	var $client:=cs.AIKit.OpenAI.new($apiKey)
	var $params:=cs.AIKit.OpenAIChatCompletionsParameters.new({\
		model: "gpt-4o";\
		response_format: {type: "json_object"}\
	})

	var $response:=$client.chat.completions.create($messages; $params)
	var $jsonText : Text:=$response.choice.message.content

	// Validate parsed result
	var $parsedForm : Object:=JSON Parse($jsonText)

	If ($parsedForm=Null)
		throw({message: "AI returned invalid JSON"})
	End if
	If (OB Is defined($parsedForm; "objects")=False)
		throw({message: "Generated JSON is missing the 'objects' key"})
	End if
	If (OB Is defined($parsedForm; "pages")=False)
		throw({message: "Generated JSON is missing the 'pages' key"})
	End if

	// Locate the project Forms folder and create form subfolder
	var $formsFolder : 4D.Folder:=Folder(fk project folder).folder("Sources/Forms")
	var $formFolder : 4D.Folder:=$formsFolder.folder($formName)

	If (Not($formFolder.exists))
		$formFolder.create()
	End if

	// Write the .4dform file (pretty-printed)
	var $outputFile : 4D.File:=$formFolder.file("form.4dform")
	$outputFile.setText(JSON Stringify($parsedForm; *))

	$result.success:=True
	$result.outputPath:=$outputFile.path

Catch
	$result.error:=Last errors.first().message
End try

return $result
