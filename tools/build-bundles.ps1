# Build printable bundles by concatenating 01–04 markdown files per case
# Output goes to case-studies\_bundles\<case-folder>.md

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$caseStudies = Join-Path $repoRoot 'case-studies'
$bundlesDir = Join-Path $caseStudies '_bundles'

if (-not (Test-Path $bundlesDir)) {
    New-Item -ItemType Directory -Path $bundlesDir | Out-Null
}

function To-TitleCaseFromFolder([string]$folderName) {
    # Remove leading number and hyphen prefix like "01-"
    $name = $folderName -replace '^[0-9]{2}-', ''
    # Replace hyphens with spaces and title-case words
    $textInfo = (Get-Culture).TextInfo
    return $textInfo.ToTitleCase(($name -replace '-', ' '))
}

# Gather case folders (e.g., 01-..., 02-..., ..., 30-...)
$caseDirs = Get-ChildItem -Path $caseStudies -Directory | Where-Object { $_.Name -match '^[0-9]{2}-' } | Sort-Object Name

$bundleIndex = @()

foreach ($dir in $caseDirs) {
    $casePath = $dir.FullName
    $caseName = $dir.Name
    $title = To-TitleCaseFromFolder $caseName

    $files = @(
        '01-requirements.md',
        '02-architecture.md',
        '03-key-decisions.md',
        '04-wrap-up.md'
    )

    $missing = @()
    $parts = @()

    foreach ($f in $files) {
        $fp = Join-Path $casePath $f
        if (Test-Path $fp) {
            $parts += $fp
        } else {
            $missing += $f
        }
    }

    if ($missing.Count -gt 0) {
        Write-Warning ("Skipping {0}: missing files: {1}" -f $caseName, ($missing -join ', '))
        continue
    }

    $outFile = Join-Path $bundlesDir ("$caseName.md")

    ("# {0} - {1}" -f $caseName, $title) | Out-File -FilePath $outFile -Encoding UTF8
    ("Generated: {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')) | Out-File -FilePath $outFile -Encoding UTF8 -Append

    foreach ($fp in $parts) {
        $rel = Resolve-Path $fp | Split-Path -Leaf
        "`n---`n" | Out-File -FilePath $outFile -Encoding UTF8 -Append
        ("<!-- Source: {0} -->" -f $rel) | Out-File -FilePath $outFile -Encoding UTF8 -Append
    Get-Content -Raw -Path $fp -Encoding UTF8 | Out-File -FilePath $outFile -Encoding UTF8 -Append
        "`n" | Out-File -FilePath $outFile -Encoding UTF8 -Append
    }

    $bundleIndex += [PSCustomObject]@{
        Case = $caseName
        Title = $title
        File  = (Join-Path '_bundles' ("$caseName.md"))
    }
}

# Write bundles index
$indexFile = Join-Path $bundlesDir 'README.md'
"# Printable Bundles" | Out-File -FilePath $indexFile -Encoding UTF8
("Generated: {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')) | Out-File -FilePath $indexFile -Encoding UTF8 -Append

foreach ($item in $bundleIndex) {
    ("- [{0} - {1}](./{0}.md)" -f $item.Case, $item.Title) | Out-File -FilePath $indexFile -Encoding UTF8 -Append
}
