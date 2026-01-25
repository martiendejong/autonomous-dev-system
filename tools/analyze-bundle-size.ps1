<#
.SYNOPSIS
    Analyzes Vite bundle size and suggests optimizations.

.DESCRIPTION
    Analyzes frontend bundle composition, identifies large dependencies,
    and suggests code-splitting and tree-shaking opportunities.

    Generates visualizations using rollup-plugin-visualizer.

.PARAMETER ProjectPath
    Path to Vite project (should contain vite.config.ts/js)

.PARAMETER Build
    Run build before analysis

.PARAMETER Threshold
    Size threshold in KB for flagging large chunks (default: 500)

.PARAMETER OutputReport
    Generate HTML visualization report

.EXAMPLE
    .\analyze-bundle-size.ps1 -ProjectPath "C:\Projects\client-manager\ClientManagerFrontend"
    .\analyze-bundle-size.ps1 -ProjectPath "." -Build -OutputReport
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectPath,

    [switch]$Build,
    [int]$Threshold = 500,
    [switch]$OutputReport
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

function Get-PackageJson {
    param([string]$Path)

    $pkgPath = Join-Path $Path "package.json"
    if (-not (Test-Path $pkgPath)) {
        return $null
    }

    return Get-Content $pkgPath -Raw | ConvertFrom-Json
}

function Analyze-Dependencies {
    param([PSCustomObject]$PackageJson)

    $dependencies = @()

    if ($PackageJson.dependencies) {
        foreach ($dep in $PackageJson.dependencies.PSObject.Properties) {
            $dependencies += @{
                "Name" = $dep.Name
                "Version" = $dep.Value
                "Type" = "production"
            }
        }
    }

    return $dependencies
}

function Get-LargeDependencies {
    param([array]$Dependencies)

    # Known large packages and their typical sizes
    $knownSizes = @{
        "react" = 6
        "react-dom" = 130
        "moment" = 230
        "lodash" = 70
        "@radix-ui/react-dropdown-menu" = 45
        "axios" = 15
        "chart.js" = 180
        "d3" = 250
        "three" = 600
    }

    $suggestions = @()

    foreach ($dep in $Dependencies) {
        if ($knownSizes.ContainsKey($dep.Name)) {
            $size = $knownSizes[$dep.Name]

            if ($size -gt 50) {
                $suggestion = @{
                    "Package" = $dep.Name
                    "EstimatedSize" = $size
                    "Recommendation" = Get-Recommendation -PackageName $dep.Name
                }

                $suggestions += $suggestion
            }
        }
    }

    return $suggestions
}

function Get-Recommendation {
    param([string]$PackageName)

    $recommendations = @{
        "moment" = "Replace with date-fns or dayjs (90% smaller)"
        "lodash" = "Use lodash-es with tree-shaking or import specific functions"
        "@radix-ui/react-dropdown-menu" = "Code-split: import async or create manual chunk"
        "chart.js" = "Code-split: load only when dashboard is accessed"
        "d3" = "Import only required d3-* submodules, not full d3"
        "three" = "Code-split: load only for 3D features"
        "react-dom" = "Already optimized, ensure proper tree-shaking"
    }

    if ($recommendations.ContainsKey($PackageName)) {
        return $recommendations[$PackageName]
    }

    return "Consider code-splitting or lazy loading"
}

function Create-OptimizedViteConfig {
    param([string]$Path)

    $config = @"
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { visualizer } from 'rollup-plugin-visualizer'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [
    react(),
    visualizer({
      filename: 'dist/stats.html',
      gzipSize: true,
      brotliSize: true,
      open: false
    })
  ],
  build: {
    target: 'es2015',
    minify: 'terser',
    terserOptions: {
      compress: {
        drop_console: true,
        drop_debugger: true
      }
    },
    rollupOptions: {
      output: {
        manualChunks: {
          // Vendor chunks
          'vendor-react': ['react', 'react-dom', 'react-router-dom'],

          // UI library chunks (if using)
          // 'vendor-ui': ['@radix-ui/react-dropdown-menu'],

          // Chart library (code-split for dashboard)
          // 'vendor-charts': ['chart.js'],

          // Utility chunks
          // 'vendor-utils': ['axios', 'date-fns']
        }
      }
    },
    chunkSizeWarningLimit: 500 // KB
  }
})
"@

    $configPath = Join-Path $Path "vite.config.optimized.ts"
    $config | Set-Content $configPath -Encoding UTF8

    Write-Host "Created optimized config template: $configPath" -ForegroundColor Green
    Write-Host "Review and merge into your vite.config.ts" -ForegroundColor Yellow
}

function Install-Visualizer {
    param([string]$Path)

    Push-Location $Path
    try {
        Write-Host "Installing rollup-plugin-visualizer..." -ForegroundColor Cyan
        npm install --save-dev rollup-plugin-visualizer 2>&1 | Out-Null

        if ($LASTEXITCODE -eq 0) {
            Write-Host "Installed rollup-plugin-visualizer" -ForegroundColor Green
        } else {
            Write-Host "WARNING: npm install failed" -ForegroundColor Yellow
        }

    } finally {
        Pop-Location
    }
}

function Run-Build {
    param([string]$Path)

    Write-Host ""
    Write-Host "Running production build..." -ForegroundColor Cyan

    Push-Location $Path
    try {
        $output = npm run build 2>&1
        $success = $LASTEXITCODE -eq 0

        if ($success) {
            Write-Host "Build completed successfully" -ForegroundColor Green
        } else {
            Write-Host "Build failed" -ForegroundColor Red
            Write-Host $output -ForegroundColor DarkGray
        }

        return $success

    } finally {
        Pop-Location
    }
}

function Analyze-BuildOutput {
    param([string]$Path, [int]$SizeThreshold)

    $distPath = Join-Path $Path "dist\assets"
    if (-not (Test-Path $distPath)) {
        Write-Host "WARNING: dist/assets not found, run build first" -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "=== Bundle Analysis ===" -ForegroundColor Cyan
    Write-Host ""

    $files = Get-ChildItem $distPath -File

    $jsFiles = $files | Where-Object { $_.Extension -eq ".js" }
    $cssFiles = $files | Where-Object { $_.Extension -eq ".css" }

    # JavaScript bundles
    Write-Host "JavaScript Bundles:" -ForegroundColor White
    Write-Host ""

    $totalJsSize = 0
    $largeChunks = @()

    foreach ($file in $jsFiles | Sort-Object Length -Descending) {
        $sizeKB = [math]::Round($file.Length / 1KB, 2)
        $totalJsSize += $sizeKB

        $color = if ($sizeKB -gt $SizeThreshold) { "Red"; $largeChunks += $file } `
                 elseif ($sizeKB -gt ($SizeThreshold / 2)) { "Yellow" } `
                 else { "Green" }

        Write-Host ("  {0,-50} {1,8} KB" -f $file.Name, $sizeKB) -ForegroundColor $color
    }

    Write-Host ""
    Write-Host ("  Total JS: {0:N2} KB" -f $totalJsSize) -ForegroundColor Cyan
    Write-Host ""

    # CSS bundles
    if ($cssFiles.Count -gt 0) {
        Write-Host "CSS Bundles:" -ForegroundColor White
        Write-Host ""

        $totalCssSize = 0
        foreach ($file in $cssFiles | Sort-Object Length -Descending) {
            $sizeKB = [math]::Round($file.Length / 1KB, 2)
            $totalCssSize += $sizeKB

            Write-Host ("  {0,-50} {1,8} KB" -f $file.Name, $sizeKB) -ForegroundColor Green
        }

        Write-Host ""
        Write-Host ("  Total CSS: {0:N2} KB" -f $totalCssSize) -ForegroundColor Cyan
        Write-Host ""
    }

    # Total
    Write-Host ("Total Bundle Size: {0:N2} KB" -f ($totalJsSize + $totalCssSize)) -ForegroundColor Cyan
    Write-Host ""

    # Warnings
    if ($largeChunks.Count -gt 0) {
        Write-Host "=== Large Chunks Detected ===" -ForegroundColor Red
        Write-Host ""
        Write-Host "The following chunks exceed ${SizeThreshold}KB threshold:" -ForegroundColor Yellow
        foreach ($chunk in $largeChunks) {
            $sizeKB = [math]::Round($chunk.Length / 1KB, 2)
            Write-Host "  - $($chunk.Name): $sizeKB KB" -ForegroundColor Yellow
        }
        Write-Host ""
        Write-Host "Consider code-splitting these chunks." -ForegroundColor Yellow
        Write-Host ""
    }
}

# Main execution
Write-Host ""
Write-Host "=== Bundle Size Analyzer ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $ProjectPath)) {
    Write-Host "ERROR: Project path not found: $ProjectPath" -ForegroundColor Red
    exit 1
}

# Check for package.json
$packageJson = Get-PackageJson -Path $ProjectPath
if (-not $packageJson) {
    Write-Host "ERROR: package.json not found in $ProjectPath" -ForegroundColor Red
    exit 1
}

Write-Host "Analyzing: $ProjectPath" -ForegroundColor White
Write-Host ""

# Analyze dependencies
$dependencies = Analyze-Dependencies -PackageJson $packageJson
$largeDeps = Get-LargeDependencies -Dependencies $dependencies

if ($largeDeps.Count -gt 0) {
    Write-Host "=== Large Dependencies Detected ===" -ForegroundColor Yellow
    Write-Host ""

    foreach ($dep in $largeDeps | Sort-Object EstimatedSize -Descending) {
        Write-Host "  $($dep.Package): ~$($dep.EstimatedSize) KB" -ForegroundColor Yellow
        Write-Host "    → $($dep.Recommendation)" -ForegroundColor DarkGray
        Write-Host ""
    }
}

# Install visualizer if output report requested
if ($OutputReport) {
    Install-Visualizer -Path $ProjectPath
}

# Run build if requested
if ($Build) {
    $buildSuccess = Run-Build -Path $ProjectPath

    if (-not $buildSuccess) {
        Write-Host "Skipping bundle analysis due to build failure" -ForegroundColor Red
        exit 1
    }
}

# Analyze build output
Analyze-BuildOutput -Path $ProjectPath -SizeThreshold $Threshold

# Create optimized config template
Create-OptimizedViteConfig -Path $ProjectPath

Write-Host "=== Recommendations ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Review vite.config.optimized.ts and merge into your config" -ForegroundColor White
Write-Host "2. Use manualChunks to split vendor code" -ForegroundColor White
Write-Host "3. Implement lazy loading for routes:" -ForegroundColor White
Write-Host "   const Dashboard = lazy(() => import('./pages/Dashboard'))" -ForegroundColor DarkGray
Write-Host "4. Run 'npm run build' to see updated bundle sizes" -ForegroundColor White

if ($OutputReport) {
    $reportPath = Join-Path $ProjectPath "dist\stats.html"
    if (Test-Path $reportPath) {
        Write-Host "5. Open dist/stats.html to visualize bundle composition" -ForegroundColor White
    }
}

Write-Host ""

exit 0
