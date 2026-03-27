<#
.SYNOPSIS
    Automated E2E testing with Playwright and visual regression.

.DESCRIPTION
    Runs end-to-end tests using Playwright, captures screenshots for visual
    regression testing, and generates HTML test reports.

    Features:
    - Playwright test execution
    - Screenshot comparison (baseline vs current)
    - HTML test report generation
    - Parallel test execution
    - CI/CD integration
    - Video recording on failure
    - Test retry on failure

.PARAMETER ProjectPath
    Path to frontend project with E2E tests

.PARAMETER Browser
    Browser to test: chromium, firefox, webkit, all (default: chromium)

.PARAMETER Headed
    Run tests in headed mode (visible browser)

.PARAMETER UpdateSnapshots
    Update baseline screenshots

.PARAMETER Parallel
    Run tests in parallel (default: true)

.PARAMETER Retries
    Number of retries on failure (default: 2)

.PARAMETER CI
    CI mode (headless, no interactive prompts)

.EXAMPLE
    .\run-e2e-tests.ps1 -ProjectPath "C:\Projects\client-manager\ClientManagerFrontend"
    .\run-e2e-tests.ps1 -ProjectPath "." -Browser all -Headed
    .\run-e2e-tests.ps1 -ProjectPath "." -UpdateSnapshots
    .\run-e2e-tests.ps1 -ProjectPath "." -CI
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectPath,

    [ValidateSet("chromium", "firefox", "webkit", "all")]
    [string]$Browser = "chromium",

    [switch]$Headed,
    [switch]$UpdateSnapshots,
    [switch]$Parallel = $true,
    [int]$Retries = 2,
    [switch]$CI
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

function Test-PlaywrightInstalled {
    param([string]$ProjectPath)

    $packageJson = Join-Path $ProjectPath "package.json"

    if (-not (Test-Path $packageJson)) {
        return $false
    }

    try {
        $pkg = Get-Content $packageJson | ConvertFrom-Json

        $hasPlaywright = $pkg.devDependencies.PSObject.Properties.Name -contains "@playwright/test"

        return $hasPlaywright

    } catch {
        return $false
    }
}

function Install-Playwright {
    param([string]$ProjectPath)

    Write-Host ""
    Write-Host "=== Installing Playwright ===" -ForegroundColor Cyan
    Write-Host ""

    Push-Location $ProjectPath
    try {
        Write-Host "Installing @playwright/test..." -ForegroundColor White
        npm install --save-dev @playwright/test

        Write-Host "Installing Playwright browsers..." -ForegroundColor White
        npx playwright install

        Write-Host ""
        Write-Host "Playwright installed successfully!" -ForegroundColor Green
        Write-Host ""

    } finally {
        Pop-Location
    }
}

function Initialize-PlaywrightConfig {
    param([string]$ProjectPath)

    $configPath = Join-Path $ProjectPath "playwright.config.ts"

    if (Test-Path $configPath) {
        Write-Host "Playwright config already exists" -ForegroundColor Green
        return
    }

    Write-Host "Creating playwright.config.ts..." -ForegroundColor Cyan

    $config = @"
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [
    ['html', { outputFolder: 'playwright-report' }],
    ['json', { outputFile: 'test-results.json' }]
  ],
  use: {
    baseURL: 'http://localhost:5173',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
    },
    {
      name: 'webkit',
      use: { ...devices['Desktop Safari'] },
    },
  ],

  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:5173',
    reuseExistingServer: !process.env.CI,
  },
});
"@

    $config | Set-Content $configPath -Encoding UTF8

    Write-Host "Created: $configPath" -ForegroundColor Green
    Write-Host ""
}

function Create-SampleTest {
    param([string]$ProjectPath)

    $e2eDir = Join-Path $ProjectPath "e2e"

    if (-not (Test-Path $e2eDir)) {
        New-Item -ItemType Directory -Path $e2eDir -Force | Out-Null
    }

    $testFile = Join-Path $e2eDir "example.spec.ts"

    if (Test-Path $testFile) {
        Write-Host "Sample test already exists" -ForegroundColor Green
        return
    }

    Write-Host "Creating sample E2E test..." -ForegroundColor Cyan

    $test = @"
import { test, expect } from '@playwright/test';

test.describe('Homepage', () => {
  test('should load successfully', async ({ page }) => {
    await page.goto('/');

    // Check title
    await expect(page).toHaveTitle(/Client Manager/);

    // Take screenshot
    await page.screenshot({ path: 'screenshots/homepage.png' });
  });

  test('should navigate to login', async ({ page }) => {
    await page.goto('/');

    // Click login button
    await page.click('text=Login');

    // Wait for navigation
    await page.waitForURL('**/login');

    // Check we're on login page
    await expect(page.locator('h1')).toContainText('Login');
  });
});

test.describe('Visual Regression', () => {
  test('homepage snapshot', async ({ page }) => {
    await page.goto('/');

    // Visual regression test
    await expect(page).toHaveScreenshot('homepage.png');
  });
});
"@

    $test | Set-Content $testFile -Encoding UTF8

    Write-Host "Created: $testFile" -ForegroundColor Green
    Write-Host ""
}

function Run-PlaywrightTests {
    param([string]$ProjectPath, [string]$Browser, [bool]$Headed, [bool]$UpdateSnapshots, [bool]$CI, [int]$Retries)

    Write-Host ""
    Write-Host "=== Running E2E Tests ===" -ForegroundColor Cyan
    Write-Host ""

    Push-Location $ProjectPath
    try {
        $args = @()

        # Browser selection
        if ($Browser -ne "all") {
            $args += "--project=$Browser"
        }

        # Headed mode
        if ($Headed -and -not $CI) {
            $args += "--headed"
        }

        # Update snapshots
        if ($UpdateSnapshots) {
            $args += "--update-snapshots"
        }

        # Retries
        if ($Retries -gt 0) {
            $args += "--retries=$Retries"
        }

        # Reporter
        $args += "--reporter=html,json"

        Write-Host "Running: npx playwright test $($args -join ' ')" -ForegroundColor DarkGray
        Write-Host ""

        npx playwright test @args

        $exitCode = $LASTEXITCODE

        Write-Host ""

        if ($exitCode -eq 0) {
            Write-Host "All tests passed!" -ForegroundColor Green
        } else {
            Write-Host "Some tests failed" -ForegroundColor Red
        }

        Write-Host ""

        return $exitCode

    } finally {
        Pop-Location
    }
}

function Show-TestReport {
    param([string]$ProjectPath)

    $reportPath = Join-Path $ProjectPath "playwright-report/index.html"

    if (Test-Path $reportPath) {
        Write-Host "HTML Report: $reportPath" -ForegroundColor Cyan
        Write-Host "View report: npx playwright show-report" -ForegroundColor White
        Write-Host ""
    }

    # Parse JSON results
    $resultsPath = Join-Path $ProjectPath "test-results.json"

    if (Test-Path $resultsPath) {
        try {
            $results = Get-Content $resultsPath | ConvertFrom-Json

            Write-Host "=== Test Summary ===" -ForegroundColor Cyan
            Write-Host ""

            $stats = $results.stats

            Write-Host ("  Total Tests:  {0}" -f ($stats.expected + $stats.unexpected + $stats.flaky)) -ForegroundColor White
            Write-Host ("  Passed:       {0}" -f $stats.expected) -ForegroundColor Green
            Write-Host ("  Failed:       {0}" -f $stats.unexpected) -ForegroundColor Red

            if ($stats.flaky -gt 0) {
                Write-Host ("  Flaky:        {0}" -f $stats.flaky) -ForegroundColor Yellow
            }

            Write-Host ""
            Write-Host ("  Duration:     {0}ms" -f $results.duration) -ForegroundColor DarkGray
            Write-Host ""

        } catch {
            # Ignore parsing errors
        }
    }
}

# Main execution
Write-Host ""
Write-Host "=== E2E Test Runner ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $ProjectPath)) {
    Write-Host "ERROR: Project path not found: $ProjectPath" -ForegroundColor Red
    exit 1
}

# Check if Playwright is installed
$hasPlaywright = Test-PlaywrightInstalled -ProjectPath $ProjectPath

if (-not $hasPlaywright) {
    Write-Host "Playwright not found in project" -ForegroundColor Yellow

    if (-not $CI) {
        $install = Read-Host "Install Playwright? (yes/no)"

        if ($install -eq "yes") {
            Install-Playwright -ProjectPath $ProjectPath
            Initialize-PlaywrightConfig -ProjectPath $ProjectPath
            Create-SampleTest -ProjectPath $ProjectPath
        } else {
            Write-Host "Cancelled" -ForegroundColor Yellow
            exit 1
        }
    } else {
        Write-Host "ERROR: Playwright not installed (CI mode)" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Playwright detected" -ForegroundColor Green
    Write-Host ""
}

# Initialize config if missing
Initialize-PlaywrightConfig -ProjectPath $ProjectPath

# Run tests
$exitCode = Run-PlaywrightTests -ProjectPath $ProjectPath -Browser $Browser -Headed $Headed -UpdateSnapshots $UpdateSnapshots -CI $CI -Retries $Retries

# Show report
Show-TestReport -ProjectPath $ProjectPath

Write-Host "=== E2E Testing Complete ===" -ForegroundColor Green
Write-Host ""

exit $exitCode
