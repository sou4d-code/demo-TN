#DECLARE($htmlPath : Text; $formName : Text; $apiKey : Text) : Object

var $result : Object:={success: False; outputPath: ""; error: ""}

Try
	// Read the HTML file
	var $htmlFile : 4D.File:=File($htmlPath; fk platform path)
	If (Not($htmlFile.exists))
		throw({message: "HTML file not found: "+$htmlPath})
	End if

	var $htmlContent : Text:=$htmlFile.getText()

	// Build system prompt encoding the correct .4dform schema + HTML mapping rules
	var $systemPrompt : Text
	$systemPrompt:="You are a 4D form generator. Your job is to read an HTML file and convert it into a valid .4dform JSON file for 4D project mode.\n"
	$systemPrompt:=$systemPrompt+"Output ONLY raw JSON. No markdown. No explanation. No code fences.\n\n"

	$systemPrompt:=$systemPrompt+"## Exact .4dform structure to produce:\n"
	$systemPrompt:=$systemPrompt+"{\n"
	$systemPrompt:=$systemPrompt+"  \"$4d\": {\"version\": \"1\", \"kind\": \"form\"},\n"
	$systemPrompt:=$systemPrompt+"  \"windowSizingX\": \"variable\",\n"
	$systemPrompt:=$systemPrompt+"  \"windowSizingY\": \"variable\",\n"
	$systemPrompt:=$systemPrompt+"  \"windowMinWidth\": 0,\n"
	$systemPrompt:=$systemPrompt+"  \"windowMinHeight\": 0,\n"
	$systemPrompt:=$systemPrompt+"  \"windowMaxWidth\": 32767,\n"
	$systemPrompt:=$systemPrompt+"  \"windowMaxHeight\": 32767,\n"
	$systemPrompt:=$systemPrompt+"  \"rightMargin\": 20,\n"
	$systemPrompt:=$systemPrompt+"  \"bottomMargin\": 20,\n"
	$systemPrompt:=$systemPrompt+"  \"events\": [\"onLoad\", \"onClick\"],\n"
	$systemPrompt:=$systemPrompt+"  \"windowTitle\": \"<derived from HTML page title or main heading>\",\n"
	$systemPrompt:=$systemPrompt+"  \"destination\": \"detailScreen\",\n"
	$systemPrompt:=$systemPrompt+"  \"pages\": [\n"
	$systemPrompt:=$systemPrompt+"    {\"objects\": {}},\n"
	$systemPrompt:=$systemPrompt+"    {\"objects\": {\n"
	$systemPrompt:=$systemPrompt+"      \"<camelCaseObjectName>\": {\n"
	$systemPrompt:=$systemPrompt+"        \"type\": \"<4d-type>\",\n"
	$systemPrompt:=$systemPrompt+"        \"left\": 0, \"top\": 0, \"width\": 200, \"height\": 24\n"
	$systemPrompt:=$systemPrompt+"      }\n"
	$systemPrompt:=$systemPrompt+"    }}\n"
	$systemPrompt:=$systemPrompt+"  ]\n"
	$systemPrompt:=$systemPrompt+"}\n\n"

	$systemPrompt:=$systemPrompt+"CRITICAL rules:\n"
	$systemPrompt:=$systemPrompt+"- pages[0].objects must always be empty {} (it is the shared/all-pages placeholder).\n"
	$systemPrompt:=$systemPrompt+"- ALL form objects go into pages[1].objects — never at the root level.\n"
	$systemPrompt:=$systemPrompt+"- Do NOT add an \"objects\" key at the root level.\n"
	$systemPrompt:=$systemPrompt+"- events must be strings (\"onLoad\", \"onClick\"), never integers.\n\n"

	$systemPrompt:=$systemPrompt+"## HTML to 4D type mapping:\n"
	$systemPrompt:=$systemPrompt+"<input type=\"text\"> or <input>   → type: \"input\"\n"
	$systemPrompt:=$systemPrompt+"<label>                           → type: \"text\"     (add \"text\": \"<label content>\")\n"
	$systemPrompt:=$systemPrompt+"<button>                          → type: \"button\"   (add \"text\": \"<button label>\", events: [\"onClick\"])\n"
	$systemPrompt:=$systemPrompt+"<select>                          → type: \"dropDown\"\n"
	$systemPrompt:=$systemPrompt+"<input type=\"checkbox\">           → type: \"checkbox\" (add \"text\": \"<associated label>\")\n"
	$systemPrompt:=$systemPrompt+"<textarea>                        → type: \"input\"    (add \"scrollbar\": \"vertical\")\n"
	$systemPrompt:=$systemPrompt+"<fieldset>                        → type: \"groupBox\" (add \"text\": \"<legend text>\")\n"
	$systemPrompt:=$systemPrompt+"<img>                             → type: \"picture\"\n"
	$systemPrompt:=$systemPrompt+"<h1>/<h2>/<h3>                    → type: \"text\"     (increase fontSize accordingly)\n\n"

	$systemPrompt:=$systemPrompt+"## Layout rules:\n"
	$systemPrompt:=$systemPrompt+"- Start at left: 20, top: 20 for the first element.\n"
	$systemPrompt:=$systemPrompt+"- Increment top by ~30px per row; labels share a row with their input.\n"
	$systemPrompt:=$systemPrompt+"- Default label:  width 120, height 20.\n"
	$systemPrompt:=$systemPrompt+"- Default input:  width 260, height 24; placed at left 150 (beside its label).\n"
	$systemPrompt:=$systemPrompt+"- Default button: width 120, height 28.\n"
	$systemPrompt:=$systemPrompt+"- Infer form width from content (typically 460); height proportional to rows.\n"
	$systemPrompt:=$systemPrompt+"- Object names must be unique camelCase strings derived from id, name, or content.\n"
	$systemPrompt:=$systemPrompt+"- Every object MUST have: type, left, top, width, height."

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
	If (OB Is defined($parsedForm; "pages")=False)
		throw({message: "Generated JSON is missing the 'pages' key"})
	End if
	var $pages : Collection:=$parsedForm.pages
	If ($pages.length<2)
		throw({message: "Generated JSON must have at least 2 pages entries (pages[0] placeholder + pages[1] content)"})
	End if
	If (OB Is defined($pages[1]; "objects")=False)
		throw({message: "Generated JSON is missing objects inside pages[1]"})
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
