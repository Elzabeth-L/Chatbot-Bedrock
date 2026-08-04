$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$outputPath = Join-Path $projectRoot "docs\Chatbot-Bedrock-Solution-Design-Document.docx"
$documentDate = "04 August 2026"
$version = "1.1"
$script:blocks = [Collections.Generic.List[string]]::new()
$script:tableNumber = 0
$script:figureNumber = 0

function Xml-Escape {
    param([AllowEmptyString()][string]$Text)
    if ($null -eq $Text) { return "" }
    return [Security.SecurityElement]::Escape($Text)
}

function Text-Runs {
    param([AllowEmptyString()][string]$Text, [string]$RunProperties = "")
    $parts = [regex]::Split($Text, "\r?\n")
    $runs = [Collections.Generic.List[string]]::new()
    for ($index = 0; $index -lt $parts.Count; $index++) {
        if ($index -gt 0) { $runs.Add("<w:r>$RunProperties<w:br/></w:r>") }
        $runs.Add("<w:r>$RunProperties<w:t xml:space=`"preserve`">$(Xml-Escape $parts[$index])</w:t></w:r>")
    }
    return ($runs -join "")
}

function Add-XmlParagraph {
    param(
        [AllowEmptyString()][string]$Text,
        [string]$Style = "Normal",
        [bool]$Bold = $false,
        [bool]$Italic = $false,
        [ValidateSet("left", "center", "right")][string]$Alignment = "left",
        [int]$SpaceAfter = 100
    )
    $runProperties = "<w:rPr>" + $(if ($Bold) { "<w:b/>" } else { "" }) + $(if ($Italic) { "<w:i/>" } else { "" }) + "</w:rPr>"
    $paragraph = "<w:p><w:pPr><w:pStyle w:val=`"$Style`"/><w:jc w:val=`"$Alignment`"/><w:spacing w:after=`"$SpaceAfter`"/></w:pPr>$(Text-Runs $Text $runProperties)</w:p>"
    $script:blocks.Add($paragraph)
}

function Add-Paragraph {
    param(
        [Parameter(Position = 0)][AllowEmptyString()][string]$Text,
        [bool]$Bold = $false,
        [bool]$Italic = $false,
        [int]$Alignment = 0,
        [int]$SpaceAfter = 7
    )
    $alignmentName = switch ($Alignment) { 1 { "center" } 2 { "right" } default { "left" } }
    Add-XmlParagraph -Text $Text -Bold $Bold -Italic $Italic -Alignment $alignmentName -SpaceAfter ($SpaceAfter * 20)
}

function Add-Heading {
    param([int]$Level, [string]$Text)
    Add-XmlParagraph -Text $Text -Style "Heading$Level" -SpaceAfter 120
}

function Add-Bullets {
    param([string[]]$Items)
    foreach ($item in $Items) { Add-XmlParagraph -Text ([char]0x2022 + "  " + $item) -Style "ListParagraph" -SpaceAfter 55 }
    Add-XmlParagraph -Text "" -SpaceAfter 20
}

function Add-NumberedSteps {
    param([string[]]$Items)
    for ($index = 0; $index -lt $Items.Count; $index++) {
        Add-XmlParagraph -Text ("{0}.  {1}" -f ($index + 1), $Items[$index]) -Style "ListParagraph" -SpaceAfter 70
    }
    Add-XmlParagraph -Text "" -SpaceAfter 20
}

function Add-Caption {
    param([ValidateSet("Table", "Figure")][string]$Kind, [string]$Title)
    if ($Kind -eq "Table") { $script:tableNumber++ } else { $script:figureNumber++ }
    $number = if ($Kind -eq "Table") { $script:tableNumber } else { $script:figureNumber }
    $field = "<w:fldSimple w:instr=`" SEQ $Kind \* ARABIC `"><w:r><w:t>$number</w:t></w:r></w:fldSimple>"
    $script:blocks.Add("<w:p><w:pPr><w:pStyle w:val=`"Caption`"/><w:jc w:val=`"center`"/></w:pPr><w:r><w:t>$Kind </w:t></w:r>$field<w:r><w:t xml:space=`"preserve`"> - $(Xml-Escape $Title)</w:t></w:r></w:p>")
}

function Table-Cell {
    param([AllowEmptyString()][string]$Text, [bool]$Header = $false, [bool]$Alternate = $false, [int]$Width = 2500)
    $shading = if ($Header) { "5B3B1F" } elseif ($Alternate) { "F3F6F2" } else { "FFFFFF" }
    $color = if ($Header) { "FFFFFF" } else { "262626" }
    $bold = if ($Header) { "<w:b/>" } else { "" }
    return "<w:tc><w:tcPr><w:tcW w:w=`"$Width`" w:type=`"dxa`"/><w:shd w:fill=`"$shading`"/><w:vAlign w:val=`"center`"/></w:tcPr><w:p><w:pPr><w:spacing w:after=`"50`"/></w:pPr><w:r><w:rPr><w:rFonts w:ascii=`"Aptos`" w:hAnsi=`"Aptos`"/><w:sz w:val=`"18`"/><w:color w:val=`"$color`"/>$bold</w:rPr><w:t xml:space=`"preserve`">$(Xml-Escape $Text)</w:t></w:r></w:p></w:tc>"
}

function Add-Table {
    param([string]$Caption, [string[]]$Headers, [object[]]$Rows)
    Add-Caption -Kind "Table" -Title $Caption
    $width = [math]::Floor(9000 / $Headers.Count)
    $xml = [Text.StringBuilder]::new()
    [void]$xml.Append("<w:tbl><w:tblPr><w:tblW w:w=`"9000`" w:type=`"dxa`"/><w:tblLayout w:type=`"fixed`"/><w:tblBorders><w:top w:val=`"single`" w:sz=`"4`" w:color=`"B7C6B8`"/><w:left w:val=`"single`" w:sz=`"4`" w:color=`"B7C6B8`"/><w:bottom w:val=`"single`" w:sz=`"4`" w:color=`"B7C6B8`"/><w:right w:val=`"single`" w:sz=`"4`" w:color=`"B7C6B8`"/><w:insideH w:val=`"single`" w:sz=`"3`" w:color=`"D9E1DA`"/><w:insideV w:val=`"single`" w:sz=`"3`" w:color=`"D9E1DA`"/></w:tblBorders><w:tblCellMar><w:top w:w=`"80`" w:type=`"dxa`"/><w:left w:w=`"90`" w:type=`"dxa`"/><w:bottom w:w=`"80`" w:type=`"dxa`"/><w:right w:w=`"90`" w:type=`"dxa`"/></w:tblCellMar></w:tblPr><w:tblGrid>")
    foreach ($header in $Headers) { [void]$xml.Append("<w:gridCol w:w=`"$width`"/>") }
    [void]$xml.Append("</w:tblGrid><w:tr><w:trPr><w:tblHeader/></w:trPr>")
    foreach ($header in $Headers) { [void]$xml.Append((Table-Cell -Text $header -Header $true -Width $width)) }
    [void]$xml.Append("</w:tr>")
    for ($rowIndex = 0; $rowIndex -lt $Rows.Count; $rowIndex++) {
        [void]$xml.Append("<w:tr>")
        for ($column = 0; $column -lt $Headers.Count; $column++) {
            $value = if ($column -lt $Rows[$rowIndex].Count) { [string]$Rows[$rowIndex][$column] } else { "" }
            [void]$xml.Append((Table-Cell -Text $value -Alternate (($rowIndex % 2) -eq 1) -Width $width))
        }
        [void]$xml.Append("</w:tr>")
    }
    [void]$xml.Append("</w:tbl><w:p/>")
    $script:blocks.Add($xml.ToString())
}

function Add-Callout {
    param([string]$Title, [string]$Text)
    $content = "<w:tbl><w:tblPr><w:tblW w:w=`"9000`" w:type=`"dxa`"/><w:tblBorders><w:left w:val=`"single`" w:sz=`"18`" w:color=`"557A61`"/></w:tblBorders></w:tblPr><w:tr><w:tc><w:tcPr><w:shd w:fill=`"E8F0E7`"/><w:tcMar><w:top w:w=`"120`" w:type=`"dxa`"/><w:left w:w=`"180`" w:type=`"dxa`"/><w:bottom w:w=`"120`" w:type=`"dxa`"/><w:right w:w=`"180`" w:type=`"dxa`"/></w:tcMar></w:tcPr><w:p><w:r><w:rPr><w:b/><w:color w:val=`"365A43`"/></w:rPr><w:t>$(Xml-Escape $Title)</w:t></w:r></w:p><w:p><w:r><w:t>$(Xml-Escape $Text)</w:t></w:r></w:p></w:tc></w:tr></w:tbl><w:p/>"
    $script:blocks.Add($content)
}

function Add-FigurePlaceholder {
    param([string]$Title, [string]$Content)
    $runs = Text-Runs -Text $Content -RunProperties "<w:rPr><w:rFonts w:ascii=`"Aptos Mono`" w:hAnsi=`"Aptos Mono`"/><w:sz w:val=`"17`"/><w:color w:val=`"365A43`"/></w:rPr>"
    $script:blocks.Add("<w:tbl><w:tblPr><w:tblW w:w=`"9000`" w:type=`"dxa`"/><w:tblBorders><w:top w:val=`"single`" w:sz=`"6`" w:color=`"95AA99`"/><w:left w:val=`"single`" w:sz=`"6`" w:color=`"95AA99`"/><w:bottom w:val=`"single`" w:sz=`"6`" w:color=`"95AA99`"/><w:right w:val=`"single`" w:sz=`"6`" w:color=`"95AA99`"/></w:tblBorders></w:tblPr><w:tr><w:trPr><w:trHeight w:val=`"1700`" w:hRule=`"atLeast`"/></w:trPr><w:tc><w:tcPr><w:shd w:fill=`"F4F6F4`"/><w:vAlign w:val=`"center`"/></w:tcPr><w:p><w:pPr><w:jc w:val=`"center`"/></w:pPr>$runs</w:p></w:tc></w:tr></w:tbl>")
    Add-Caption -Kind "Figure" -Title $Title
}

function Add-PageBreak { $script:blocks.Add("<w:p><w:r><w:br w:type=`"page`"/></w:r></w:p>") }

function Add-ResourceSection {
    param([string]$Title, [string]$TerraformResources, [string]$Purpose, [string]$Operation, [string]$Security, [string]$ScaleAvailability, [string]$FailureOperations, [string]$Alternatives)
    Add-Heading 2 $Title
    Add-Table -Caption "$Title design summary" -Headers @("Design aspect", "Implementation") -Rows @(
        @("Terraform resources", $TerraformResources), @("Purpose and responsibilities", $Purpose),
        @("Runtime behavior and dependencies", $Operation), @("Security", $Security),
        @("Availability, failure, and operations", "$ScaleAvailability $FailureOperations")
    )
}

function Add-Toc {
    Add-Heading 1 "Table of Contents"
    $script:blocks.Add("<w:p><w:fldSimple w:instr=`" TOC \o &quot;1-3&quot; \h \z \u `"><w:r><w:t>Open this document in Microsoft Word to update the automatic Table of Contents.</w:t></w:r></w:fldSimple></w:p>")
    Add-PageBreak
}

function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)
    [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
}

# Cover page.
1..4 | ForEach-Object { Add-XmlParagraph -Text "" -SpaceAfter 80 }
Add-XmlParagraph -Text "CHATBOT-BEDROCK" -Style "Title" -Alignment "center" -SpaceAfter 100
Add-XmlParagraph -Text "Solution Design Document" -Style "Subtitle" -Alignment "center" -SpaceAfter 100
Add-XmlParagraph -Text "Architecture, Infrastructure, Application, CI/CD, Deployment and Operations Guide" -Alignment "center" -Italic $true -SpaceAfter 500
Add-Table -Caption "Document identification" -Headers @("Attribute", "Value") -Rows @(
    @("Project", "Low-cost Amazon Bedrock RAG Chatbot (Chatbot-Bedrock)"),
    @("Author", "Elzabeth-L (repository owner; inferred from repository metadata)"),
    @("Organization", "Not specified - Chatbot-Bedrock project repository"),
    @("Document version", $version), @("Document date", $documentDate),
    @("Document status", "Issued for technical review"),
    @("Classification", "Confidential - project stakeholders and authorized reviewers")
)
Add-Paragraph -Text "CONFIDENTIALITY STATEMENT" -Bold $true -Alignment 1
Add-Paragraph -Text "This document contains project architecture, deployment, security, and operational information. Distribution should be limited to authorized project stakeholders. It contains no credentials, secret values, or private customer data." -Alignment 1
Add-PageBreak

# Reuse the repository-derived content definitions from the companion source file.
$contentSource = Get-Content -Raw (Join-Path $PSScriptRoot "generate-sdd.ps1")
$controlStart = $contentSource.IndexOf('    Add-Heading 1 "Document Control"')
$tocStart = $contentSource.IndexOf('    Add-Heading 1 "Table of Contents"')
$mainStart = $contentSource.IndexOf('    Add-Heading 1 "1 Executive Summary"')
$bodyEnd = $contentSource.IndexOf('    # Headers and footers')
if ($controlStart -lt 0 -or $tocStart -lt 0 -or $mainStart -lt 0 -or $bodyEnd -lt 0) {
    throw "Unable to locate enterprise document content blocks."
}
Invoke-Expression $contentSource.Substring($controlStart, $tocStart - $controlStart)
Add-Toc
Invoke-Expression $contentSource.Substring($mainStart, $bodyEnd - $mainStart)

$bodyXml = $script:blocks -join ""
$documentXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <w:body>$bodyXml<w:sectPr><w:headerReference w:type="default" r:id="rId3"/><w:footerReference w:type="default" r:id="rId4"/><w:pgSz w:w="12240" w:h="15840"/><w:pgMar w:top="1247" w:right="1134" w:bottom="1134" w:left="1304" w:header="500" w:footer="500"/><w:titlePg/></w:sectPr></w:body>
</w:document>
"@

$stylesXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Aptos" w:hAnsi="Aptos"/><w:sz w:val="21"/><w:color w:val="262626"/></w:rPr></w:rPrDefault><w:pPrDefault><w:pPr><w:spacing w:after="140" w:line="270" w:lineRule="auto"/></w:pPr></w:pPrDefault></w:docDefaults>
  <w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:qFormat/></w:style>
  <w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/><w:basedOn w:val="Normal"/><w:qFormat/><w:rPr><w:rFonts w:ascii="Aptos Display" w:hAnsi="Aptos Display"/><w:b/><w:color w:val="5B3B1F"/><w:sz w:val="60"/></w:rPr></w:style>
  <w:style w:type="paragraph" w:styleId="Subtitle"><w:name w:val="Subtitle"/><w:basedOn w:val="Normal"/><w:qFormat/><w:rPr><w:rFonts w:ascii="Aptos Display" w:hAnsi="Aptos Display"/><w:color w:val="365A43"/><w:sz w:val="36"/></w:rPr></w:style>
  <w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/><w:pPr><w:keepNext/><w:keepLines/><w:pageBreakBefore/><w:spacing w:before="280" w:after="140"/><w:outlineLvl w:val="0"/></w:pPr><w:rPr><w:rFonts w:ascii="Aptos Display" w:hAnsi="Aptos Display"/><w:b/><w:color w:val="5B3B1F"/><w:sz w:val="36"/></w:rPr></w:style>
  <w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="heading 2"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/><w:pPr><w:keepNext/><w:keepLines/><w:spacing w:before="220" w:after="100"/><w:outlineLvl w:val="1"/></w:pPr><w:rPr><w:rFonts w:ascii="Aptos Display" w:hAnsi="Aptos Display"/><w:b/><w:color w:val="61462C"/><w:sz w:val="28"/></w:rPr></w:style>
  <w:style w:type="paragraph" w:styleId="Heading3"><w:name w:val="heading 3"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/><w:pPr><w:keepNext/><w:keepLines/><w:spacing w:before="160" w:after="80"/><w:outlineLvl w:val="2"/></w:pPr><w:rPr><w:rFonts w:ascii="Aptos Display" w:hAnsi="Aptos Display"/><w:b/><w:color w:val="365A43"/><w:sz w:val="23"/></w:rPr></w:style>
  <w:style w:type="paragraph" w:styleId="Caption"><w:name w:val="caption"/><w:basedOn w:val="Normal"/><w:qFormat/><w:pPr><w:keepNext/><w:spacing w:before="80" w:after="100"/></w:pPr><w:rPr><w:i/><w:color w:val="5A665D"/><w:sz w:val="18"/></w:rPr></w:style>
  <w:style w:type="paragraph" w:styleId="ListParagraph"><w:name w:val="List Paragraph"/><w:basedOn w:val="Normal"/><w:qFormat/><w:pPr><w:ind w:left="360" w:hanging="180"/></w:pPr></w:style>
</w:styles>
"@

$headerXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:p><w:pPr><w:jc w:val="right"/><w:pBdr><w:bottom w:val="single" w:sz="4" w:color="B5C7B8"/></w:pBdr></w:pPr><w:r><w:rPr><w:rFonts w:ascii="Aptos" w:hAnsi="Aptos"/><w:sz w:val="16"/><w:color w:val="666666"/></w:rPr><w:t>CHATBOT-BEDROCK  |  SOLUTION DESIGN DOCUMENT</w:t></w:r></w:p></w:hdr>'
$footerXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:ftr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:p><w:pPr><w:jc w:val="center"/></w:pPr><w:r><w:rPr><w:rFonts w:ascii="Aptos" w:hAnsi="Aptos"/><w:sz w:val="16"/><w:color w:val="666666"/></w:rPr><w:t xml:space="preserve">Confidential  |  Version 1.1  |  04 August 2026  |  Page </w:t></w:r><w:fldSimple w:instr=" PAGE "><w:r><w:t>1</w:t></w:r></w:fldSimple></w:p></w:ftr>'
$settingsXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:settings xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:updateFields w:val="true"/><w:defaultTabStop w:val="720"/><w:evenAndOddHeaders w:val="false"/></w:settings>'
$contentTypes = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/><Override PartName="/word/settings.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml"/><Override PartName="/word/header1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml"/><Override PartName="/word/footer1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml"/><Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/><Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/></Types>'
$rootRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/><Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/></Relationships>'
$documentRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings" Target="settings.xml"/><Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header" Target="header1.xml"/><Relationship Id="rId4" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" Target="footer1.xml"/></Relationships>'
$coreXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><dc:title>Chatbot-Bedrock Solution Design Document</dc:title><dc:subject>Architecture, Infrastructure, CI/CD, Deployment and Operations</dc:subject><dc:creator>Elzabeth-L / Project Engineering</dc:creator><cp:lastModifiedBy>Codex</cp:lastModifiedBy><dcterms:created xsi:type="dcterms:W3CDTF">2026-08-03T00:00:00Z</dcterms:created><dcterms:modified xsi:type="dcterms:W3CDTF">2026-08-04T00:00:00Z</dcterms:modified><cp:revision>2</cp:revision></cp:coreProperties>'
$appXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes"><Application>Microsoft Office Word</Application><AppVersion>16.0000</AppVersion><Company>Chatbot-Bedrock project</Company></Properties>'

$tempRoot = Join-Path $projectRoot ".docx-build"
if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
New-Item -ItemType Directory -Path (Join-Path $tempRoot "_rels"), (Join-Path $tempRoot "word\_rels"), (Join-Path $tempRoot "docProps") -Force | Out-Null
Write-Utf8NoBom (Join-Path $tempRoot "[Content_Types].xml") $contentTypes
Write-Utf8NoBom (Join-Path $tempRoot "_rels\.rels") $rootRels
Write-Utf8NoBom (Join-Path $tempRoot "word\document.xml") $documentXml
Write-Utf8NoBom (Join-Path $tempRoot "word\styles.xml") $stylesXml
Write-Utf8NoBom (Join-Path $tempRoot "word\settings.xml") $settingsXml
Write-Utf8NoBom (Join-Path $tempRoot "word\header1.xml") $headerXml
Write-Utf8NoBom (Join-Path $tempRoot "word\footer1.xml") $footerXml
Write-Utf8NoBom (Join-Path $tempRoot "word\_rels\document.xml.rels") $documentRels
Write-Utf8NoBom (Join-Path $tempRoot "docProps\core.xml") $coreXml
Write-Utf8NoBom (Join-Path $tempRoot "docProps\app.xml") $appXml

if (Test-Path -LiteralPath $outputPath) { Remove-Item -LiteralPath $outputPath -Force }
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression
$archive = [IO.Compression.ZipFile]::Open($outputPath, [IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($file in Get-ChildItem -LiteralPath $tempRoot -Recurse -File) {
        $entryName = $file.FullName.Substring($tempRoot.Length + 1).Replace("\", "/")
        $null = [IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $archive,
            $file.FullName,
            $entryName,
            [IO.Compression.CompressionLevel]::Optimal
        )
    }
} finally {
    $archive.Dispose()
}
Remove-Item -LiteralPath $tempRoot -Recurse -Force

Write-Output "output=$outputPath"
Write-Output "bytes=$((Get-Item -LiteralPath $outputPath).Length)"
Write-Output "paragraph_blocks=$($script:blocks.Count)"
Write-Output "tables=$script:tableNumber"
Write-Output "figures=$script:figureNumber"
