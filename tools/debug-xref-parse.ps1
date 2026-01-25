$content = Get-Content 'C:\scripts\logs\cross-reference-validation.md' -Raw
$sections = ($content -split '### Source:') | Select-Object -Skip 1

Write-Host "Total sections: $($sections.Count)"
Write-Host ""

# Check first few sections
for ($i = 0; $i -lt [Math]::Min(5, $sections.Count); $i++) {
    $section = $sections[$i]
    $lines = $section -split "`n"

    $source = ($lines[0] -replace '`', '').Trim()
    $target = ""

    foreach ($line in $lines) {
        Write-Host "    Line: $line"
        if ($line -match '\*\*Target:\*\*\s+`([^`]+)`') {
            $target = $matches[1].Trim()
            Write-Host "    MATCHED!"
            break
        }
    }

    Write-Host "Section ${i}:"
    Write-Host "  Source: $source"
    Write-Host "  Target: [$target]"
    Write-Host "  Is 'url'? $($target -eq 'url')"
    Write-Host "  Is 'link'? $($target -eq 'link')"
    Write-Host "  Matches placeholder? $($target -match '^(url|link)$')"
    Write-Host ""
}
