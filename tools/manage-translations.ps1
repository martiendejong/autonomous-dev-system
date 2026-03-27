<#
.SYNOPSIS
    Manages localization and translations for frontend applications.

.DESCRIPTION
    Extracts translatable strings from React components, manages i18n files,
    validates missing translations, and syncs with translation services.

    Features:
    - Extracts strings wrapped in t() or useTranslation()
    - Generates translation files (JSON)
    - Validates missing translations across locales
    - Detects unused translation keys
    - Supports i18next format
    - Export/import for translation services

.PARAMETER ProjectPath
    Path to frontend project

.PARAMETER Action
    Action: extract, validate, sync, export, import

.PARAMETER Locale
    Target locale (e.g., en, nl, fr, de)

.PARAMETER InputFile
    Input file for import action (JSON)

.PARAMETER OutputPath
    Output path for extracted/exported translations

.EXAMPLE
    .\manage-translations.ps1 -ProjectPath "C:\Projects\client-manager\ClientManagerFrontend" -Action extract
    .\manage-translations.ps1 -ProjectPath "." -Action validate -Locale nl
    .\manage-translations.ps1 -ProjectPath "." -Action export -OutputPath "translations.json"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectPath,

    [Parameter(Mandatory=$true)]
    [ValidateSet("extract", "validate", "sync", "export", "import")]
    [string]$Action,

    [string]$Locale,
    [string]$InputFile,
    [string]$OutputPath = "locales"
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

function Find-TranslationKeys {
    param([string]$ProjectPath)

    Write-Host ""
    Write-Host "=== Extracting Translation Keys ===" -ForegroundColor Cyan
    Write-Host ""

    $srcPath = Join-Path $ProjectPath "src"

    if (-not (Test-Path $srcPath)) {
        Write-Host "ERROR: src/ directory not found" -ForegroundColor Red
        return @()
    }

    # Find all .tsx/.jsx files
    $files = Get-ChildItem $srcPath -Include "*.tsx","*.jsx" -Recurse -ErrorAction SilentlyContinue

    Write-Host "Scanning $($files.Count) files..." -ForegroundColor DarkGray

    $keys = @{}

    foreach ($file in $files) {
        $content = Get-Content $file.FullName -Raw

        # Extract t('key') patterns
        $matches = [regex]::Matches($content, "t\([`"']([^`"']+)[`"']")

        foreach ($match in $matches) {
            $key = $match.Groups[1].Value

            if (-not $keys.ContainsKey($key)) {
                $keys[$key] = @{
                    "Key" = $key
                    "Files" = @()
                    "DefaultText" = ""
                }
            }

            $keys[$key].Files += $file.FullName
        }

        # Extract t('key', 'default text') patterns
        $matchesWithDefault = [regex]::Matches($content, "t\([`"']([^`"']+)[`"'],\s*[`"']([^`"']+)[`"']")

        foreach ($match in $matchesWithDefault) {
            $key = $match.Groups[1].Value
            $defaultText = $match.Groups[2].Value

            if (-not $keys.ContainsKey($key)) {
                $keys[$key] = @{
                    "Key" = $key
                    "Files" = @()
                    "DefaultText" = $defaultText
                }
            } else {
                $keys[$key].DefaultText = $defaultText
            }

            $keys[$key].Files += $file.FullName
        }
    }

    Write-Host "Found $($keys.Count) translation keys" -ForegroundColor Green
    Write-Host ""

    return $keys.Values
}

function Get-ExistingTranslations {
    param([string]$ProjectPath, [string]$Locale)

    $localesPath = Join-Path $ProjectPath "public/locales/$Locale"

    if (-not (Test-Path $localesPath)) {
        return @{}
    }

    $translationFile = Join-Path $localesPath "translation.json"

    if (-not (Test-Path $translationFile)) {
        return @{}
    }

    try {
        $json = Get-Content $translationFile | ConvertFrom-Json
        return $json
    } catch {
        return @{}
    }
}

function Extract-Translations {
    param([string]$ProjectPath)

    $keys = Find-TranslationKeys -ProjectPath $ProjectPath

    if ($keys.Count -eq 0) {
        Write-Host "No translation keys found" -ForegroundColor Yellow
        return
    }

    # Build translation object
    $translations = @{}

    foreach ($key in $keys) {
        $translations[$key.Key] = if ($key.DefaultText) {
            $key.DefaultText
        } else {
            $key.Key
        }
    }

    # Save to file
    $outputDir = Join-Path $ProjectPath "public/locales/en"

    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    $outputFile = Join-Path $outputDir "translation.json"

    $translations | ConvertTo-Json -Depth 10 | Set-Content $outputFile -Encoding UTF8

    Write-Host "Extracted translations saved to: $outputFile" -ForegroundColor Green
    Write-Host ""

    # Show summary
    Write-Host "=== Extraction Summary ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host ("  Total Keys: {0}" -f $keys.Count) -ForegroundColor White
    Write-Host ("  With Defaults: {0}" -f ($keys | Where-Object { $_.DefaultText }).Count) -ForegroundColor White
    Write-Host ""
}

function Validate-Translations {
    param([string]$ProjectPath, [string]$Locale)

    Write-Host ""
    Write-Host "=== Validating Translations ===" -ForegroundColor Cyan
    Write-Host ""

    if (-not $Locale) {
        Write-Host "ERROR: -Locale required for validation" -ForegroundColor Red
        return
    }

    # Get all keys from source code
    $sourceKeys = Find-TranslationKeys -ProjectPath $ProjectPath

    if ($sourceKeys.Count -eq 0) {
        Write-Host "No translation keys found in source code" -ForegroundColor Yellow
        return
    }

    # Get existing translations for locale
    $existingTranslations = Get-ExistingTranslations -ProjectPath $ProjectPath -Locale $Locale

    if ($existingTranslations.PSObject.Properties.Count -eq 0) {
        Write-Host "No translations found for locale: $Locale" -ForegroundColor Yellow
        Write-Host "All $($sourceKeys.Count) keys are missing" -ForegroundColor Red
        return
    }

    # Find missing keys
    $missingKeys = @()

    foreach ($sourceKey in $sourceKeys) {
        if (-not $existingTranslations.PSObject.Properties.Name -contains $sourceKey.Key) {
            $missingKeys += $sourceKey.Key
        }
    }

    # Find unused keys
    $unusedKeys = @()
    $sourceKeyNames = $sourceKeys | ForEach-Object { $_.Key }

    foreach ($existingKey in $existingTranslations.PSObject.Properties.Name) {
        if (-not ($sourceKeyNames -contains $existingKey)) {
            $unusedKeys += $existingKey
        }
    }

    # Show results
    Write-Host "Locale: $Locale" -ForegroundColor White
    Write-Host ""

    if ($missingKeys.Count -gt 0) {
        Write-Host "MISSING TRANSLATIONS ($($missingKeys.Count)):" -ForegroundColor Red
        Write-Host ""

        foreach ($key in $missingKeys | Select-Object -First 10) {
            Write-Host "  - $key" -ForegroundColor Yellow
        }

        if ($missingKeys.Count -gt 10) {
            Write-Host "  ... and $($missingKeys.Count - 10) more" -ForegroundColor DarkGray
        }

        Write-Host ""
    }

    if ($unusedKeys.Count -gt 0) {
        Write-Host "UNUSED TRANSLATIONS ($($unusedKeys.Count)):" -ForegroundColor Yellow
        Write-Host ""

        foreach ($key in $unusedKeys | Select-Object -First 10) {
            Write-Host "  - $key" -ForegroundColor DarkGray
        }

        if ($unusedKeys.Count -gt 10) {
            Write-Host "  ... and $($unusedKeys.Count - 10) more" -ForegroundColor DarkGray
        }

        Write-Host ""
    }

    if ($missingKeys.Count -eq 0 -and $unusedKeys.Count -eq 0) {
        Write-Host "All translations are up to date!" -ForegroundColor Green
        Write-Host ""
    }

    # Summary
    $coverage = [math]::Round((($sourceKeys.Count - $missingKeys.Count) / $sourceKeys.Count) * 100, 1)

    Write-Host "=== Summary ===" -ForegroundColor Cyan
    Write-Host ("  Coverage: {0}% ({1}/{2})" -f $coverage, ($sourceKeys.Count - $missingKeys.Count), $sourceKeys.Count) -ForegroundColor White
    Write-Host ("  Missing: {0}" -f $missingKeys.Count) -ForegroundColor Red
    Write-Host ("  Unused: {0}" -f $unusedKeys.Count) -ForegroundColor Yellow
    Write-Host ""
}

function Sync-Translations {
    param([string]$ProjectPath)

    Write-Host ""
    Write-Host "=== Syncing Translations ===" -ForegroundColor Cyan
    Write-Host ""

    # Get source keys
    $sourceKeys = Find-TranslationKeys -ProjectPath $ProjectPath

    if ($sourceKeys.Count -eq 0) {
        Write-Host "No translation keys found" -ForegroundColor Yellow
        return
    }

    # Find all locale directories
    $localesPath = Join-Path $ProjectPath "public/locales"

    if (-not (Test-Path $localesPath)) {
        Write-Host "No locales directory found" -ForegroundColor Yellow
        return
    }

    $locales = Get-ChildItem $localesPath -Directory

    foreach ($locale in $locales) {
        Write-Host "Syncing locale: $($locale.Name)" -ForegroundColor White

        $translationFile = Join-Path $locale.FullName "translation.json"

        # Load existing translations
        $existing = if (Test-Path $translationFile) {
            Get-Content $translationFile | ConvertFrom-Json
        } else {
            @{}
        }

        # Add missing keys
        $updated = @{}
        $addedCount = 0

        foreach ($sourceKey in $sourceKeys) {
            if ($existing.PSObject.Properties.Name -contains $sourceKey.Key) {
                # Keep existing translation
                $updated[$sourceKey.Key] = $existing.($sourceKey.Key)
            } else {
                # Add new key with default or key name
                $updated[$sourceKey.Key] = if ($sourceKey.DefaultText) {
                    $sourceKey.DefaultText
                } else {
                    "[TRANSLATE] $($sourceKey.Key)"
                }
                $addedCount++
            }
        }

        # Save updated translations
        $updated | ConvertTo-Json -Depth 10 | Set-Content $translationFile -Encoding UTF8

        Write-Host "  Added $addedCount new keys" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Sync complete!" -ForegroundColor Green
    Write-Host ""
}

function Export-Translations {
    param([string]$ProjectPath, [string]$OutputPath)

    Write-Host ""
    Write-Host "=== Exporting Translations ===" -ForegroundColor Cyan
    Write-Host ""

    # Find all locales
    $localesPath = Join-Path $ProjectPath "public/locales"

    if (-not (Test-Path $localesPath)) {
        Write-Host "ERROR: No locales directory found" -ForegroundColor Red
        return
    }

    $locales = Get-ChildItem $localesPath -Directory

    $export = @{}

    foreach ($locale in $locales) {
        $translationFile = Join-Path $locale.FullName "translation.json"

        if (Test-Path $translationFile) {
            $translations = Get-Content $translationFile | ConvertFrom-Json
            $export[$locale.Name] = $translations
        }
    }

    # Save export
    $exportFile = if ($OutputPath) { $OutputPath } else { "translations-export.json" }

    $export | ConvertTo-Json -Depth 10 | Set-Content $exportFile -Encoding UTF8

    Write-Host "Exported to: $exportFile" -ForegroundColor Green
    Write-Host "Locales: $($export.Keys -join ', ')" -ForegroundColor White
    Write-Host ""
}

function Import-Translations {
    param([string]$ProjectPath, [string]$InputFile)

    Write-Host ""
    Write-Host "=== Importing Translations ===" -ForegroundColor Cyan
    Write-Host ""

    if (-not $InputFile) {
        Write-Host "ERROR: -InputFile required for import" -ForegroundColor Red
        return
    }

    if (-not (Test-Path $InputFile)) {
        Write-Host "ERROR: Input file not found: $InputFile" -ForegroundColor Red
        return
    }

    # Load import file
    try {
        $import = Get-Content $InputFile | ConvertFrom-Json
    } catch {
        Write-Host "ERROR: Failed to parse input file" -ForegroundColor Red
        return
    }

    # Import each locale
    $localesPath = Join-Path $ProjectPath "public/locales"

    foreach ($locale in $import.PSObject.Properties.Name) {
        Write-Host "Importing locale: $locale" -ForegroundColor White

        $localeDir = Join-Path $localesPath $locale

        if (-not (Test-Path $localeDir)) {
            New-Item -ItemType Directory -Path $localeDir -Force | Out-Null
        }

        $translationFile = Join-Path $localeDir "translation.json"

        $import.$locale | ConvertTo-Json -Depth 10 | Set-Content $translationFile -Encoding UTF8

        Write-Host "  Imported $($import.$locale.PSObject.Properties.Count) keys" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Import complete!" -ForegroundColor Green
    Write-Host ""
}

# Main execution
Write-Host ""
Write-Host "=== Translation Manager ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $ProjectPath)) {
    Write-Host "ERROR: Project path not found: $ProjectPath" -ForegroundColor Red
    exit 1
}

# Execute action
switch ($Action) {
    "extract" {
        Extract-Translations -ProjectPath $ProjectPath
    }
    "validate" {
        Validate-Translations -ProjectPath $ProjectPath -Locale $Locale
    }
    "sync" {
        Sync-Translations -ProjectPath $ProjectPath
    }
    "export" {
        Export-Translations -ProjectPath $ProjectPath -OutputPath $OutputPath
    }
    "import" {
        Import-Translations -ProjectPath $ProjectPath -InputFile $InputFile
    }
}

Write-Host "=== Complete ===" -ForegroundColor Green
Write-Host ""

exit 0
