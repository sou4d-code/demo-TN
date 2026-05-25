#DECLARE($htmlPath : Text; $formName : Text; $apiKey : Text) : Object

var $result : Object:={success: False; outputPath: ""; json: ""; tokenCount: 0; error: ""}

Try
	// Read the HTML file
	var $htmlFile : 4D.File:=File($htmlPath; fk platform path)
	If (Not($htmlFile.exists))
		throw({message: "HTML file not found: "+$htmlPath})
	End if

	var $htmlContent : Text:=$htmlFile.getText()

	// Build system prompt encoding the correct .4dform schema + HTML mapping rules
	var $systemPrompt : Text
	$systemPrompt:="You are an expert 4D UI engineer. Convert the HTML file into a polished, professional .4dform JSON for 4D project mode.\n"
	$systemPrompt:=$systemPrompt+"Output ONLY raw JSON. No markdown. No explanation. No code fences.\n\n"

	// ── 1. Root JSON skeleton ──────────────────────────────────────────────────
	$systemPrompt:=$systemPrompt+"## Root JSON skeleton (exact keys, exact order):\n"
	$systemPrompt:=$systemPrompt+"{\n"
	$systemPrompt:=$systemPrompt+"  \"$4d\": {\"version\": \"1\", \"kind\": \"form\"},\n"
	$systemPrompt:=$systemPrompt+"  \"windowSizingX\": \"fixed\",\n"
	$systemPrompt:=$systemPrompt+"  \"windowSizingY\": \"fixed\",\n"
	$systemPrompt:=$systemPrompt+"  \"windowMinWidth\": 0, \"windowMinHeight\": 0,\n"
	$systemPrompt:=$systemPrompt+"  \"windowMaxWidth\": 32767, \"windowMaxHeight\": 32767,\n"
	$systemPrompt:=$systemPrompt+"  \"rightMargin\": 20, \"bottomMargin\": 20,\n"
	$systemPrompt:=$systemPrompt+"  \"events\": [\"onLoad\", \"onClick\"],\n"
	$systemPrompt:=$systemPrompt+"  \"windowTitle\": \"<title from HTML>\",\n"
	$systemPrompt:=$systemPrompt+"  \"destination\": \"detailScreen\",\n"
	$systemPrompt:=$systemPrompt+"  \"formClass\": \"formClass\",\n"
	$systemPrompt:=$systemPrompt+"  \"pages\": [ {\"objects\": {}}, {\"objects\": { ... }} ]\n"
	$systemPrompt:=$systemPrompt+"}\n\n"

	// ── 2. Structural rules ────────────────────────────────────────────────────
	$systemPrompt:=$systemPrompt+"## CRITICAL structural rules:\n"
	$systemPrompt:=$systemPrompt+"- pages[0].objects MUST be empty {}.\n"
	$systemPrompt:=$systemPrompt+"- ALL objects go in pages[1].objects only — never at root level.\n"
	$systemPrompt:=$systemPrompt+"- events are strings (\"onLoad\"), never integers.\n"
	$systemPrompt:=$systemPrompt+"- Every object MUST have: type, class, left, top, width, height.\n"
	$systemPrompt:=$systemPrompt+"- Object names: unique camelCase derived from id/name/content.\n\n"

	// ── 3. Visual design system ────────────────────────────────────────────────
	$systemPrompt:=$systemPrompt+"## Visual design — MANDATORY rules for a polished result:\n\n"

	$systemPrompt:=$systemPrompt+"### A. Header bar (ALWAYS add one)\n"
	$systemPrompt:=$systemPrompt+"Add a full-width rectangle at top (left:0, top:0, width:formWidth, height:52).\n"
	$systemPrompt:=$systemPrompt+"  class: \"header\"  → rectHeader\n"
	$systemPrompt:=$systemPrompt+"Add a text label inside it for the form title.\n"
	$systemPrompt:=$systemPrompt+"  class: \"headerTitle\", text: \"<form title>\", left:20, top:14, height:24\n\n"

	$systemPrompt:=$systemPrompt+"### B. Section cards (one per <fieldset> or logical group)\n"
	$systemPrompt:=$systemPrompt+"For each section: place a rectangle BEHIND its fields as a background card.\n"
	$systemPrompt:=$systemPrompt+"  type: \"rectangle\", class: \"panelCard\"\n"
	$systemPrompt:=$systemPrompt+"  left: 20, width: formWidth-40\n"
	$systemPrompt:=$systemPrompt+"  top: <sectionTop-12>, height: <enough to wrap all fields + 20px padding>\n"
	$systemPrompt:=$systemPrompt+"  Name it: rectCard<SectionName>\n\n"

	$systemPrompt:=$systemPrompt+"### C. Section title labels\n"
	$systemPrompt:=$systemPrompt+"For each section/fieldset legend, add a text object ABOVE the card:\n"
	$systemPrompt:=$systemPrompt+"  type: \"text\", class: \"sectionLabel\", text: \"SECTION NAME\"\n"
	$systemPrompt:=$systemPrompt+"  left: 24, top: <cardTop-18>, height: 16\n\n"

	$systemPrompt:=$systemPrompt+"### D. Field rows (label + input side by side)\n"
	$systemPrompt:=$systemPrompt+"  Label: left:32, width:120, height:20, verticalAlign:\"middle\", class:\"formLabel\"\n"
	$systemPrompt:=$systemPrompt+"  Input: left:160, width:formWidth-200, height:26, class:\"inputField\"\n"
	$systemPrompt:=$systemPrompt+"  Row spacing: 36px between row tops.\n"
	$systemPrompt:=$systemPrompt+"  First field row top inside a card: cardTop+16.\n\n"

	$systemPrompt:=$systemPrompt+"### E. Buttons — CRITICAL: 4D buttons cannot have fill/background-color.\n"
	$systemPrompt:=$systemPrompt+"  Always use a RECTANGLE + BUTTON pair. The rectangle provides the background color.\n"
	$systemPrompt:=$systemPrompt+"  Primary button pair:\n"
	$systemPrompt:=$systemPrompt+"    1. type:\"rectangle\", class:\"primaryBtnBg\", same left/top/width/height as button, name: rectSubmitBg\n"
	$systemPrompt:=$systemPrompt+"    2. type:\"button\", class:\"primaryBtn\", style:\"toolbar\", width:120, height:32, events:[\"onClick\"]\n"
	$systemPrompt:=$systemPrompt+"  Secondary button pair:\n"
	$systemPrompt:=$systemPrompt+"    1. type:\"rectangle\", class:\"secondaryBtnBg\", same left/top/width/height as button, name: rectCancelBg\n"
	$systemPrompt:=$systemPrompt+"    2. type:\"button\", class:\"secondaryBtn\", style:\"toolbar\", width:100, height:32, events:[\"onClick\"]\n"
	$systemPrompt:=$systemPrompt+"  Place button pairs right-aligned, 20px from right edge, 20px below last card.\n\n"

	$systemPrompt:=$systemPrompt+"### F. Dividers between sections\n"
	$systemPrompt:=$systemPrompt+"  type: \"rectangle\", class: \"divider\", height:1, left:20, width:formWidth-40\n\n"

	$systemPrompt:=$systemPrompt+"### G. Status bar (ALWAYS add one at the bottom)\n"
	$systemPrompt:=$systemPrompt+"  type: \"rectangle\", class: \"statusBar\", left:0, width:formWidth, height:28, top:formHeight-28\n"
	$systemPrompt:=$systemPrompt+"  Add a text label inside: class:\"statusText\", dataSource:\"Form.statusText\"\n\n"

	// ── 4. HTML → 4D type mapping ──────────────────────────────────────────────
	$systemPrompt:=$systemPrompt+"## HTML to 4D type mapping:\n"
	$systemPrompt:=$systemPrompt+"<input type=\"text\">/<input>  → type:\"input\",    class:\"inputField\"\n"
	$systemPrompt:=$systemPrompt+"<input type=\"password\">      → type:\"input\",    class:\"inputField\", enterable:true\n"
	$systemPrompt:=$systemPrompt+"<input type=\"date\">          → type:\"input\",    class:\"inputField\"\n"
	$systemPrompt:=$systemPrompt+"<input type=\"number\">        → type:\"input\",    class:\"inputField\"\n"
	$systemPrompt:=$systemPrompt+"<label>                      → type:\"text\",     class:\"formLabel\",  text:\"<content>\"\n"
	$systemPrompt:=$systemPrompt+"<button type=\"submit\">        → type:\"button\",   class:\"primaryBtn\", text:\"<label>\", events:[\"onClick\"]\n"
	$systemPrompt:=$systemPrompt+"<button> (other)             → type:\"button\",   class:\"secondaryBtn\",text:\"<label>\", events:[\"onClick\"]\n"
	$systemPrompt:=$systemPrompt+"<select>                     → type:\"dropDown\", class:\"inputField\"\n"
	$systemPrompt:=$systemPrompt+"<input type=\"checkbox\">      → type:\"checkbox\", class:\"inputField\",  text:\"<associated label>\"\n"
	$systemPrompt:=$systemPrompt+"<textarea>                   → type:\"input\",    class:\"inputField\",  multiline:\"yes\", scrollbarVertical:\"visible\"\n"
	$systemPrompt:=$systemPrompt+"<fieldset>                   → rectangle card + section label (see Visual Design B+C above)\n"
	$systemPrompt:=$systemPrompt+"<h1>                         → type:\"text\",     class:\"headerTitle\"\n"
	$systemPrompt:=$systemPrompt+"<h2>/<h3>                    → type:\"text\",     class:\"sectionLabel\"\n"
	$systemPrompt:=$systemPrompt+"<img>                        → type:\"picture\"\n\n"

	// ── 5. CSS classes (no inline styles) ─────────────────────────────────────
	$systemPrompt:=$systemPrompt+"## CSS classes — set \"class\" property ONLY. NEVER add fill/stroke/fontSize/fontWeight/borderStyle/borderRadius inline.\n"
	$systemPrompt:=$systemPrompt+"  \"formLabel\"    → static label text beside an input\n"
	$systemPrompt:=$systemPrompt+"  \"sectionLabel\" → uppercase section/group heading text\n"
	$systemPrompt:=$systemPrompt+"  \"inputField\"   → editable input, select, textarea\n"
	$systemPrompt:=$systemPrompt+"  \"inputReadOnly\"→ display-only value field\n"
	$systemPrompt:=$systemPrompt+"  \"primaryBtn\"   → main submit/confirm button\n"
	$systemPrompt:=$systemPrompt+"  \"secondaryBtn\" → cancel/reset/secondary button\n"
	$systemPrompt:=$systemPrompt+"  \"panelCard\"    → background rectangle behind a section\n"
	$systemPrompt:=$systemPrompt+"  \"divider\"      → 1px horizontal separator rectangle\n"
	$systemPrompt:=$systemPrompt+"  \"header\"       → top banner rectangle\n"
	$systemPrompt:=$systemPrompt+"  \"headerTitle\"  → title text inside the header\n"
	$systemPrompt:=$systemPrompt+"  \"statusBar\"    → bottom bar rectangle\n"
	$systemPrompt:=$systemPrompt+"  \"statusText\"   → text inside the status bar\n\n"

	// ── 6. dataSource binding ─────────────────────────────────────────────────
	$systemPrompt:=$systemPrompt+"## dataSource binding:\n"
	$systemPrompt:=$systemPrompt+"- Every editable input/select/checkbox MUST have: \"dataSource\": \"Form.<camelCaseFieldName>\"\n"
	$systemPrompt:=$systemPrompt+"- Status text: \"dataSource\": \"Form.statusText\"\n"
	$systemPrompt:=$systemPrompt+"- Do NOT bind labels or read-only decorative text.\n\n"

	// ── 7. Dimension guide ────────────────────────────────────────────────────
	$systemPrompt:=$systemPrompt+"## Form dimension guide:\n"
	$systemPrompt:=$systemPrompt+"- Preferred form width: 520px for simple forms, 660px for complex forms.\n"
	$systemPrompt:=$systemPrompt+"- Form height: headerHeight(52) + sections*(fieldsPerSection*36+48) + buttonRow(52) + statusBar(28) + 20 padding.\n"
	$systemPrompt:=$systemPrompt+"- Horizontal layout: label left:32, input left:160, input width:formWidth-200.\n"
	$systemPrompt:=$systemPrompt+"- Cards: left:20, width:formWidth-40, borderRadius applied via panelCard class.\n"
	$systemPrompt:=$systemPrompt+"- Buttons: right-aligned — primary at left:formWidth-140, secondary at left:formWidth-250."

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

	var $outputFile : 4D.File:=$formFolder.file("form.4dform")

	var $prettyJson : Text:=JSON Stringify($parsedForm; *)
	$outputFile.setText($prettyJson)

	$result.success:=True
	$result.outputPath:=$outputFile.path
	$result.json:=$prettyJson

	// Capture token usage if available
	Try
		$result.tokenCount:=$response.usage.total_tokens
	Catch
	End try

Catch
	$result.error:=Last errors.first().message
End try

return $result
