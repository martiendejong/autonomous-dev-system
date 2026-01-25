<#
.SYNOPSIS
    Detect unused classes, methods, properties, and imports across entire codebase

.DESCRIPTION
    Scans C# codebase to find:
    - Unused classes (no references)
    - Unused methods (defined but never called)
    - Unused properties (defined but never accessed)
    - Unused using statements
    - Dead code candidates

    Uses regex pattern matching and cross-referencing to identify unused code.

.PARAMETER ProjectPath
    Path to project root (default: current directory)

.PARAMETER FilePattern
    File pattern to scan (default: *.cs)

.PARAMETER OutputFormat
    Output format: Table (default), JSON, CSV

.PARAMETER ExcludeTests
    Exclude test files from analysis (default: true)

.PARAMETER ExcludeGenerated
    Exclude generated files (*.g.cs, *.designer.cs) (default: true)

.PARAMETER MinConfidence
    Minimum confidence level (1-10) to report (default: 7)
    Lower confidence = more false positives but catches more unused code

.PARAMETER ShowUsings
    Show unused using statements (default: true)

.PARAMETER ShowMethods
    Show unused methods (default: true)

.PARAMETER ShowProperties
    Show unused properties (default: true)

.PARAMETER ShowClasses
    Show unused classes (default: true)

.EXAMPLE
    # Scan current project for all unused code
    .\unused-code-detector.ps1

.EXAMPLE
    # High confidence only (fewer false positives)
    .\unused-code-detector.ps1 -MinConfidence 9

.EXAMPLE
    # Include test files in analysis
    .\unused-code-detector.ps1 -ExcludeTests:$false

.EXAMPLE
    # Export to JSON for processing
    .\unused-code-detector.ps1 -OutputFormat JSON > unused-code.json

.NOTES
    Value: 9/10 - Reduces code bloat, improves maintainability
    Effort: 1/10 - Static analysis with regex
    Ratio: 9.0 (TIER S)

    LIMITATIONS:
    - Reflection-based usage not detected
    - Interface implementations may appear unused
    - Public APIs may be used externally
    - Dynamic invocation not detected

    RECOMMENDATION: Review results manually, especially for public members
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ProjectPath = (Get-Location).Path,

    [Parameter(Mandatory=$false)]
    [string]$FilePattern = "*.cs",

    [Parameter(Mandatory=$false)]
    [ValidateSet('Table', 'JSON', 'CSV', 'Summary')]
    [string]$OutputFormat = 'Table',

    [Parameter(Mandatory=$false)]
    [bool]$ExcludeTests = $true,

    [Parameter(Mandatory=$false)]
    [bool]$ExcludeGenerated = $true,

    [Parameter(Mandatory=$false)]
    [ValidateRange(1, 10)]
    [int]$MinConfidence = 7,

    [Parameter(Mandatory=$false)]
    [bool]$ShowUsings = $true,

    [Parameter(Mandatory=$false)]
    [bool]$ShowMethods = $true,

    [Parameter(Mandatory=$false)]
    [bool]$ShowProperties = $true,

    [Parameter(Mandatory=$false)]
    [bool]$ShowClasses = $true
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

Write-Host "🔍 Scanning for unused code in: $ProjectPath" -ForegroundColor Cyan
Write-Host "   Pattern: $FilePattern" -ForegroundColor Gray
Write-Host "   Min confidence: $MinConfidence/10" -ForegroundColor Gray
Write-Host ""

# Get all C# files
$files = Get-ChildItem -Path $ProjectPath -Filter $FilePattern -Recurse -File

# Filter out test files
if ($ExcludeTests) {
    $files = $files | Where-Object { $_.FullName -notmatch 'test|spec|\.test\.|\.spec\.' -and $_.FullName -notmatch '\\tests\\|\\test\\' }
}

# Filter out generated files
if ($ExcludeGenerated) {
    $files = $files | Where-Object { $_.Name -notmatch '\.g\.cs$|\.designer\.cs$|\.generated\.cs$' }
}

if ($files.Count -eq 0) {
    Write-Host "⚠️  No files found matching pattern" -ForegroundColor Yellow
    exit 0
}

Write-Host "📁 Analyzing $($files.Count) files..." -ForegroundColor Yellow
Write-Host ""

# Read all file contents
$fileContents = @{}
$files | ForEach-Object {
    $fileContents[$_.FullName] = Get-Content $_.FullName -Raw
}

$allContent = $fileContents.Values -join "`n"
$unusedItems = @()

# Find unused using statements
if ($ShowUsings) {
    Write-Host "🔍 Checking unused using statements..." -ForegroundColor Gray

    foreach ($file in $files) {
        $content = $fileContents[$file.FullName]
        $usings = [regex]::Matches($content, 'using\s+([A-Za-z0-9_.]+);')

        foreach ($using in $usings) {
            $namespace = $using.Groups[1].Value

            # Skip System namespaces (likely used)
            if ($namespace -match '^System') {
                continue
            }

            # Check if namespace is referenced anywhere in file
            $isUsed = $content -match [regex]::Escape($namespace.Split('.')[-1])

            if (-not $isUsed) {
                $unusedItems += [PSCustomObject]@{
                    Type = 'Using'
                    Name = $namespace
                    File = $file.Name
                    FilePath = $file.FullName
                    Confidence = 8
                    Suggestion = "Remove unused using statement"
                }
            }
        }
    }
}

# Find unused methods
if ($ShowMethods) {
    Write-Host "🔍 Checking unused methods..." -ForegroundColor Gray

    foreach ($file in $files) {
        $content = $fileContents[$file.FullName]

        # Match method definitions (simplified regex)
        $methods = [regex]::Matches($content, '(?:public|private|protected|internal)\s+(?:static\s+)?(?:async\s+)?(?:[\w<>]+)\s+([\w]+)\s*\(')

        foreach ($method in $methods) {
            $methodName = $method.Groups[1].Value

            # Skip common patterns (Main, constructors, Dispose, etc.)
            if ($methodName -match '^(Main|Dispose|ToString|GetHashCode|Equals|Configure|OnModelCreating)$') {
                continue
            }

            # Count references (simple approach - count occurrences of method name)
            $occurrences = ([regex]::Matches($allContent, "\b$methodName\b")).Count

            # If only 1 occurrence (the definition itself), likely unused
            if ($occurrences -eq 1) {
                $confidence = 7

                # Increase confidence if method is private
                if ($method.Value -match 'private') {
                    $confidence = 9
                }

                # Decrease confidence if method is public (may be used externally)
                if ($method.Value -match 'public') {
                    $confidence = 5
                }

                if ($confidence -ge $MinConfidence) {
                    $unusedItems += [PSCustomObject]@{
                        Type = 'Method'
                        Name = $methodName
                        File = $file.Name
                        FilePath = $file.FullName
                        Confidence = $confidence
                        Suggestion = "Consider removing unused method"
                    }
                }
            }
        }
    }
}

# Find unused properties
if ($ShowProperties) {
    Write-Host "🔍 Checking unused properties..." -ForegroundColor Gray

    foreach ($file in $files) {
        $content = $fileContents[$file.FullName]

        # Match property definitions
        $properties = [regex]::Matches($content, '(?:public|private|protected|internal)\s+(?:static\s+)?(?:[\w<>]+)\s+([\w]+)\s*\{\s*get;')

        foreach ($property in $properties) {
            $propName = $property.Groups[1].Value

            # Count references
            $occurrences = ([regex]::Matches($allContent, "\b$propName\b")).Count

            # If only 1-2 occurrences (definition + possible setter), likely unused
            if ($occurrences -le 2) {
                $confidence = 6

                if ($property.Value -match 'private') {
                    $confidence = 8
                }

                if ($property.Value -match 'public') {
                    $confidence = 4
                }

                if ($confidence -ge $MinConfidence) {
                    $unusedItems += [PSCustomObject]@{
                        Type = 'Property'
                        Name = $propName
                        File = $file.Name
                        FilePath = $file.FullName
                        Confidence = $confidence
                        Suggestion = "Consider removing unused property"
                    }
                }
            }
        }
    }
}

# Find unused classes
if ($ShowClasses) {
    Write-Host "🔍 Checking unused classes..." -ForegroundColor Gray

    foreach ($file in $files) {
        $content = $fileContents[$file.FullName]

        # Match class definitions
        $classes = [regex]::Matches($content, '(?:public|internal)\s+(?:static\s+)?(?:partial\s+)?class\s+([\w]+)')

        foreach ($class in $classes) {
            $className = $class.Groups[1].Value

            # Count references
            $occurrences = ([regex]::Matches($allContent, "\b$className\b")).Count

            # If only 1-2 occurrences (definition + possible inheritance), likely unused
            if ($occurrences -le 2) {
                $confidence = 6

                if ($class.Value -match 'internal') {
                    $confidence = 8
                }

                if ($class.Value -match 'public') {
                    $confidence = 3  # Public classes often used externally
                }

                if ($confidence -ge $MinConfidence) {
                    $unusedItems += [PSCustomObject]@{
                        Type = 'Class'
                        Name = $className
                        File = $file.Name
                        FilePath = $file.FullName
                        Confidence = $confidence
                        Suggestion = "Consider removing unused class or making it internal"
                    }
                }
            }
        }
    }
}

# Output results
Write-Host ""
Write-Host "📊 UNUSED CODE ANALYSIS RESULTS" -ForegroundColor Red
Write-Host ""

if ($unusedItems.Count -eq 0) {
    Write-Host "✅ No unused code detected (with confidence >= $MinConfidence)" -ForegroundColor Green
    exit 0
}

switch ($OutputFormat) {
    'Table' {
        $unusedItems | Sort-Object Confidence -Descending | Format-Table -AutoSize -Property @(
            @{Label='Type'; Expression={$_.Type}; Width=10}
            @{Label='Name'; Expression={$_.Name}; Width=30}
            @{Label='File'; Expression={$_.File}; Width=40}
            @{Label='Confidence'; Expression={"$($_.Confidence)/10"}; Align='Right'}
            @{Label='Suggestion'; Expression={$_.Suggestion}; Width=40}
        )

        # Summary
        Write-Host ""
        Write-Host "📈 Summary:" -ForegroundColor Cyan
        $grouped = $unusedItems | Group-Object Type
        $grouped | ForEach-Object {
            Write-Host "   $($_.Name): $($_.Count)" -ForegroundColor Gray
        }
        Write-Host ""
        Write-Host "💡 Total unused items: $($unusedItems.Count)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "⚠️  NOTE: Review results manually before deleting. Some 'unused' code may be:" -ForegroundColor Yellow
        Write-Host "   - Used via reflection" -ForegroundColor Gray
        Write-Host "   - Part of public API" -ForegroundColor Gray
        Write-Host "   - Interface implementations" -ForegroundColor Gray
        Write-Host "   - Called dynamically" -ForegroundColor Gray
    }
    'JSON' {
        $unusedItems | ConvertTo-Json -Depth 10
    }
    'CSV' {
        $unusedItems | ConvertTo-Csv -NoTypeInformation
    }
    'Summary' {
        $grouped = $unusedItems | Group-Object Type
        Write-Host "Unused code by type:" -ForegroundColor Cyan
        $grouped | ForEach-Object {
            Write-Host "  $($_.Name): $($_.Count)" -ForegroundColor White
        }
    }
}
