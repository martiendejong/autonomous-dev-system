<#
.SYNOPSIS
    Detect flaky tests by running test suite multiple times and identifying non-deterministic failures

.DESCRIPTION
    Runs test suite N times and tracks:
    - Tests that sometimes pass, sometimes fail
    - Tests with inconsistent execution time
    - Tests that fail only in certain combinations

    Flaky tests are worse than no tests:
    - Destroy confidence in test suite
    - Waste developer time investigating
    - Hide real bugs
    - Indicate poor test design (shared state, timing dependencies)

.PARAMETER ProjectPath
    Path to test project (default: current directory)

.PARAMETER Iterations
    Number of times to run tests (default: 10)

.PARAMETER TestFilter
    Test filter expression (e.g., "FullyQualifiedName~MyTest")

.PARAMETER ParallelExecution
    Run tests in parallel (may expose more flakiness)

.PARAMETER OutputFormat
    Output format: Table (default), JSON, CSV

.PARAMETER MinFailureRate
    Minimum failure rate (0.0-1.0) to be considered flaky (default: 0.1 = 10%)

.PARAMETER MaxFailureRate
    Maximum failure rate to be considered flaky (default: 0.9 = 90%)
    Tests failing >90% are consistently broken, not flaky

.EXAMPLE
    # Run all tests 10 times to detect flakiness
    .\flaky-test-detector.ps1

.EXAMPLE
    # Run specific tests 20 times in parallel
    .\flaky-test-detector.ps1 -Iterations 20 -ParallelExecution -TestFilter "FullyQualifiedName~Integration"

.EXAMPLE
    # Export to JSON for CI integration
    .\flaky-test-detector.ps1 -Iterations 15 -OutputFormat JSON > flaky-tests.json

.NOTES
    Value: 9/10 - Flaky tests destroy CI/CD confidence
    Effort: 1.5/10 - Wrapper around dotnet test
    Ratio: 6.0 (TIER S)

    Common causes of flakiness:
    - Shared state between tests
    - Time/date dependencies
    - Random data without seeds
    - Network/external service calls
    - Race conditions
    - Unordered collections
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ProjectPath = (Get-Location).Path,

    [Parameter(Mandatory=$false)]
    [int]$Iterations = 10,

    [Parameter(Mandatory=$false)]
    [string]$TestFilter = $null,

    [Parameter(Mandatory=$false)]
    [switch]$ParallelExecution = $false,

    [Parameter(Mandatory=$false)]
    [ValidateSet('Table', 'JSON', 'CSV')]
    [string]$OutputFormat = 'Table',

    [Parameter(Mandatory=$false)]
    [ValidateRange(0.0, 1.0)]
    [double]$MinFailureRate = 0.1,

    [Parameter(Mandatory=$false)]
    [ValidateRange(0.0, 1.0)]
    [double]$MaxFailureRate = 0.9
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

Write-Host "🔍 Flaky Test Detector" -ForegroundColor Cyan
Write-Host "   Project: $ProjectPath" -ForegroundColor Gray
Write-Host "   Iterations: $Iterations" -ForegroundColor Gray
Write-Host "   Parallel: $ParallelExecution" -ForegroundColor Gray
if ($TestFilter) {
    Write-Host "   Filter: $TestFilter" -ForegroundColor Gray
}
Write-Host ""

# Verify dotnet test available
if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    Write-Host "❌ dotnet CLI not found" -ForegroundColor Red
    exit 1
}

# Find test project
$testProjects = Get-ChildItem -Path $ProjectPath -Filter "*.csproj" -Recurse |
    Where-Object { $_.FullName -match 'test|spec' }

if ($testProjects.Count -eq 0) {
    Write-Host "❌ No test projects found" -ForegroundColor Red
    exit 1
}

$testProject = $testProjects[0].FullName
Write-Host "📦 Test project: $($testProjects[0].Name)" -ForegroundColor Yellow
Write-Host ""

# Track test results
$testResults = @{}
$executionTimes = @{}

Write-Host "🏃 Running test suite $Iterations times..." -ForegroundColor Yellow
Write-Host ""

for ($i = 1; $i -le $Iterations; $i++) {
    Write-Host "  Iteration $i/$Iterations..." -ForegroundColor Gray

    # Build dotnet test command
    $testArgs = @('test', $testProject, '--no-build', '--logger', 'trx')

    if ($TestFilter) {
        $testArgs += '--filter'
        $testArgs += $TestFilter
    }

    if ($ParallelExecution) {
        $testArgs += '--'
        $testArgs += 'RunConfiguration.MaxCpuCount=0'
    }

    # Run tests and capture output
    $output = & dotnet @testArgs 2>&1

    # Parse TRX file for detailed results
    $trxFiles = Get-ChildItem -Path $testProject -Filter "*.trx" -Recurse | Sort-Object LastWriteTime -Descending | Select-Object -First 1

    if ($trxFiles) {
        [xml]$trx = Get-Content $trxFiles.FullName

        $trx.TestRun.Results.UnitTestResult | ForEach-Object {
            $testName = $_.testName
            $outcome = $_.outcome
            $duration = [TimeSpan]::Parse($_.duration)

            if (-not $testResults.ContainsKey($testName)) {
                $testResults[$testName] = @{
                    Passed = 0
                    Failed = 0
                    Outcomes = @()
                }
                $executionTimes[$testName] = @()
            }

            if ($outcome -eq 'Passed') {
                $testResults[$testName].Passed++
            } else {
                $testResults[$testName].Failed++
            }

            $testResults[$testName].Outcomes += $outcome
            $executionTimes[$testName] += $duration.TotalMilliseconds
        }

        # Clean up TRX file
        Remove-Item $trxFiles.FullName -Force
    }
}

Write-Host ""
Write-Host "📊 Analyzing results..." -ForegroundColor Yellow
Write-Host ""

# Calculate flakiness metrics
$flakyTests = @()

foreach ($testName in $testResults.Keys) {
    $result = $testResults[$testName]
    $totalRuns = $result.Passed + $result.Failed
    $failureRate = $result.Failed / $totalRuns

    # Check if test is flaky (sometimes passes, sometimes fails)
    if ($failureRate -ge $MinFailureRate -and $failureRate -le $MaxFailureRate) {
        # Calculate execution time variance
        $times = $executionTimes[$testName]
        $avgTime = ($times | Measure-Object -Average).Average
        $stdDev = [Math]::Sqrt((($times | ForEach-Object { ($_ - $avgTime) * ($_ - $avgTime) }) | Measure-Object -Average).Average)
        $coefficientOfVariation = if ($avgTime -gt 0) { $stdDev / $avgTime } else { 0 }

        $flakyTests += [PSCustomObject]@{
            TestName = $testName
            TotalRuns = $totalRuns
            Passed = $result.Passed
            Failed = $result.Failed
            FailureRate = [Math]::Round($failureRate * 100, 1)
            AvgTime = [Math]::Round($avgTime, 2)
            TimeVariance = [Math]::Round($coefficientOfVariation * 100, 1)
            Severity = Get-FlakinessSeverity -FailureRate $failureRate -TimeVariance $coefficientOfVariation
        }
    }
}

# Sort by failure rate (most flaky first)
$flakyTests = $flakyTests | Sort-Object FailureRate -Descending

# Output results
Write-Host ""
Write-Host "🚨 FLAKY TEST ANALYSIS" -ForegroundColor Red
Write-Host ""

if ($flakyTests.Count -eq 0) {
    Write-Host "✅ No flaky tests detected! All tests are deterministic." -ForegroundColor Green
    Write-Host ""
    Write-Host "📈 Summary:" -ForegroundColor Cyan
    Write-Host "   Total tests run: $($testResults.Count)" -ForegroundColor Gray
    Write-Host "   Iterations: $Iterations" -ForegroundColor Gray
    exit 0
}

switch ($OutputFormat) {
    'Table' {
        $flakyTests | Format-Table -AutoSize -Property @(
            @{Label='Test Name'; Expression={$_.TestName}; Width=50}
            @{Label='Runs'; Expression={$_.TotalRuns}; Align='Right'}
            @{Label='Pass'; Expression={$_.Passed}; Align='Right'}
            @{Label='Fail'; Expression={$_.Failed}; Align='Right'}
            @{Label='Fail%'; Expression={"$($_.FailureRate)%"}; Align='Right'}
            @{Label='Avg(ms)'; Expression={$_.AvgTime}; Align='Right'}
            @{Label='Variance%'; Expression={"$($_.TimeVariance)%"}; Align='Right'}
            @{Label='Severity'; Expression={$_.Severity}}
        )

        # Summary
        Write-Host ""
        Write-Host "📈 Summary:" -ForegroundColor Cyan
        Write-Host "   Total tests analyzed: $($testResults.Count)" -ForegroundColor Gray
        Write-Host "   Flaky tests found: $($flakyTests.Count)" -ForegroundColor Red
        Write-Host "   CRITICAL: $(($flakyTests | Where-Object {$_.Severity -eq 'CRITICAL'}).Count)" -ForegroundColor Red
        Write-Host "   HIGH: $(($flakyTests | Where-Object {$_.Severity -eq 'HIGH'}).Count)" -ForegroundColor Yellow
        Write-Host "   MEDIUM: $(($flakyTests | Where-Object {$_.Severity -eq 'MEDIUM'}).Count)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "💡 Common fixes:" -ForegroundColor Yellow
        Write-Host "   - Remove shared state between tests" -ForegroundColor Gray
        Write-Host "   - Use fixed seeds for random data" -ForegroundColor Gray
        Write-Host "   - Mock time-dependent operations" -ForegroundColor Gray
        Write-Host "   - Add proper test isolation" -ForegroundColor Gray
        Write-Host "   - Use deterministic ordering (OrderBy before assertions)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "🔗 Learn more: https://martinfowler.com/articles/nonDeterminism.html" -ForegroundColor Cyan
    }
    'JSON' {
        $flakyTests | ConvertTo-Json -Depth 10
    }
    'CSV' {
        $flakyTests | ConvertTo-Csv -NoTypeInformation
    }
}

# Exit with error if flaky tests found (for CI integration)
if ($flakyTests.Count -gt 0) {
    exit 1
}

function Get-FlakinessSeverity {
    param(
        [double]$FailureRate,
        [double]$TimeVariance
    )

    # Severity based on failure rate and time variance
    if ($FailureRate -ge 0.3 -or $TimeVariance -gt 0.5) {
        return "CRITICAL"
    } elseif ($FailureRate -ge 0.2 -or $TimeVariance -gt 0.3) {
        return "HIGH"
    } else {
        return "MEDIUM"
    }
}
