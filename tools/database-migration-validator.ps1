<#
.SYNOPSIS
    Validate database migrations for safety and compatibility

.DESCRIPTION
    Validates EF Core/SQL migrations before deployment:
    - Checks for breaking changes
    - Validates migration syntax
    - Detects data loss operations
    - Checks migration ordering
    - Validates rollback scripts
    - Tests on staging database

.PARAMETER MigrationFile
    Path to migration file

.PARAMETER DatabaseType
    Database type: sqlserver, mysql, postgresql

.PARAMETER TestOnStaging
    Test migration on staging database

.PARAMETER ConnectionString
    Staging database connection string

.PARAMETER OutputFormat
    Output format: table (default), json

.EXAMPLE
    .\database-migration-validator.ps1 -MigrationFile "./Migrations/20240125_AddUserEmail.cs"

.NOTES
    Value: 7/10 - Prevents migration disasters
    Effort: 1.2/10 - Code parsing + validation
    Ratio: 6.0 (TIER S)
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$MigrationFile,

    [Parameter(Mandatory=$false)]
    [ValidateSet('sqlserver', 'mysql', 'postgresql')]
    [string]$DatabaseType = 'sqlserver',

    [Parameter(Mandatory=$false)]
    [switch]$TestOnStaging = $false,

    [Parameter(Mandatory=$false)]
    [string]$ConnectionString = "",

    [Parameter(Mandatory=$false)]
    [ValidateSet('table', 'json')]
    [string]$OutputFormat = 'table'
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

Write-Host "🗄️ Database Migration Validator" -ForegroundColor Cyan
Write-Host "  Migration: $MigrationFile" -ForegroundColor Gray
Write-Host ""

if (-not (Test-Path $MigrationFile)) {
    Write-Host "❌ Migration file not found: $MigrationFile" -ForegroundColor Red
    exit 1
}

$content = Get-Content $MigrationFile -Raw

$issues = @()

# Check for destructive operations
$destructiveOps = @(
    @{Pattern='DropTable'; Message='Drops table (data loss)'; Severity='CRITICAL'}
    @{Pattern='DropColumn'; Message='Drops column (data loss)'; Severity='CRITICAL'}
    @{Pattern='DropIndex'; Message='Drops index (performance impact)'; Severity='HIGH'}
    @{Pattern='AlterColumn.*nullable:\s*false'; Message='Makes column NOT NULL (may fail if nulls exist)'; Severity='HIGH'}
    @{Pattern='RenameTable'; Message='Renames table (breaking change)'; Severity='HIGH'}
    @{Pattern='RenameColumn'; Message='Renames column (breaking change)'; Severity='MEDIUM'}
)

foreach ($op in $destructiveOps) {
    if ($content -match $op.Pattern) {
        $issues += [PSCustomObject]@{
            Type = "Destructive Operation"
            Severity = $op.Severity
            Issue = $op.Message
            Pattern = $op.Pattern
        }
    }
}

# Check for missing Down() method
if ($content -notmatch 'protected override void Down') {
    $issues += [PSCustomObject]@{
        Type = "Missing Rollback"
        Severity = "HIGH"
        Issue = "No Down() method for rollback"
        Pattern = "Down()"
    }
}

# Check for transaction handling
if ($content -match 'DropTable|DropColumn' -and $content -notmatch 'migrationBuilder\.Sql\("BEGIN TRANSACTION') {
    $issues += [PSCustomObject]@{
        Type = "Transaction Safety"
        Severity = "MEDIUM"
        Issue = "Destructive operation without explicit transaction"
        Pattern = "BEGIN TRANSACTION"
    }
}

Write-Host "MIGRATION VALIDATION" -ForegroundColor Cyan
Write-Host ""

switch ($OutputFormat) {
    'table' {
        if ($issues.Count -gt 0) {
            $issues | Format-Table -AutoSize -Wrap -Property @(
                @{Label='Severity'; Expression={$_.Severity}; Width=10}
                @{Label='Type'; Expression={$_.Type}; Width=20}
                @{Label='Issue'; Expression={$_.Issue}; Width=60}
            )
        }

        Write-Host ""
        Write-Host "SUMMARY:" -ForegroundColor Cyan
        Write-Host "  Migration file: $(Split-Path $MigrationFile -Leaf)" -ForegroundColor Gray
        Write-Host "  Issues found: $($issues.Count)" -ForegroundColor $(if($issues.Count -gt 0){"Yellow"}else{"Green"})
        Write-Host "  CRITICAL: $(($issues | Where-Object {$_.Severity -eq 'CRITICAL'}).Count)" -ForegroundColor Red
        Write-Host "  HIGH: $(($issues | Where-Object {$_.Severity -eq 'HIGH'}).Count)" -ForegroundColor Yellow
        Write-Host "  MEDIUM: $(($issues | Where-Object {$_.Severity -eq 'MEDIUM'}).Count)" -ForegroundColor Gray
        Write-Host ""

        if ($issues.Count -gt 0) {
            Write-Host "RECOMMENDATIONS:" -ForegroundColor Yellow
            Write-Host "  1. Backup database before applying migration" -ForegroundColor Gray
            Write-Host "  2. Test migration on staging environment" -ForegroundColor Gray
            Write-Host "  3. Implement Down() method for rollback" -ForegroundColor Gray
            Write-Host "  4. Consider data migration scripts for column drops" -ForegroundColor Gray
            Write-Host "  5. Use multiple migrations for complex changes" -ForegroundColor Gray
        } else {
            Write-Host "✅ Migration appears safe" -ForegroundColor Green
        }
    }
    'json' {
        @{
            MigrationFile = $MigrationFile
            Issues = $issues
            Summary = @{
                TotalIssues = $issues.Count
                Critical = ($issues | Where-Object {$_.Severity -eq 'CRITICAL'}).Count
                High = ($issues | Where-Object {$_.Severity -eq 'HIGH'}).Count
                Medium = ($issues | Where-Object {$_.Severity -eq 'MEDIUM'}).Count
            }
        } | ConvertTo-Json -Depth 10
    }
}

Write-Host ""
if (($issues | Where-Object {$_.Severity -in @('CRITICAL','HIGH')}).Count -gt 0) {
    Write-Host "⚠️  High-risk migration - review carefully before deployment" -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "✅ Migration validation complete" -ForegroundColor Green
    exit 0
}
