<#
.SYNOPSIS
    Generates realistic test data for database seeding using Bogus library.

.DESCRIPTION
    Seeds database with realistic test data for development and testing.
    Uses Bogus library for .NET to generate fake but realistic data.

    Features:
    - Multiple entity types (Users, Clients, Projects, Tasks, etc.)
    - Configurable data volume (small, medium, large)
    - Relationship-aware seeding (maintains foreign keys)
    - Clear existing data option
    - Support for development and staging environments
    - Integration with EF Core DbContext
    - Customizable seed scenarios

.PARAMETER ProjectPath
    Path to .NET project with DbContext

.PARAMETER DataVolume
    Data volume: small (10-50 records), medium (100-500), large (1000-5000)

.PARAMETER Environment
    Target environment: development, staging

.PARAMETER Entities
    Comma-separated entity types to seed (default: all)

.PARAMETER ClearExisting
    Clear existing data before seeding

.PARAMETER Scenario
    Predefined scenario: minimal, realistic, stress-test

.PARAMETER ConnectionString
    Override connection string

.EXAMPLE
    .\seed-database.ps1 -ProjectPath "C:\Projects\client-manager" -DataVolume small
    .\seed-database.ps1 -ProjectPath "." -DataVolume medium -ClearExisting
    .\seed-database.ps1 -ProjectPath "." -Scenario realistic -Environment staging
    .\seed-database.ps1 -ProjectPath "." -Entities "Users,Clients,Projects"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectPath,

    [ValidateSet("small", "medium", "large")]
    [string]$DataVolume = "small",

    [ValidateSet("development", "staging")]
    [string]$Environment = "development",

    [string]$Entities,
    [switch]$ClearExisting,

    [ValidateSet("minimal", "realistic", "stress-test")]
    [string]$Scenario,

    [string]$ConnectionString
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$script:EntityCounts = @{}
$script:CreatedIds = @{}

function Get-DataVolumeCounts {
    param([string]$Volume)

    switch ($Volume) {
        "small" {
            return @{
                "Users" = 10
                "Clients" = 5
                "Projects" = 8
                "Tasks" = 20
                "Invoices" = 12
                "TimeEntries" = 30
            }
        }
        "medium" {
            return @{
                "Users" = 50
                "Clients" = 25
                "Projects" = 40
                "Tasks" = 150
                "Invoices" = 60
                "TimeEntries" = 200
            }
        }
        "large" {
            return @{
                "Users" = 200
                "Clients" = 100
                "Projects" = 150
                "Tasks" = 1000
                "Invoices" = 300
                "TimeEntries" = 2000
            }
        }
    }
}

function Get-ScenarioCounts {
    param([string]$Scenario)

    switch ($Scenario) {
        "minimal" {
            return @{
                "Users" = 3
                "Clients" = 2
                "Projects" = 2
                "Tasks" = 5
                "Invoices" = 2
                "TimeEntries" = 10
            }
        }
        "realistic" {
            return @{
                "Users" = 15
                "Clients" = 10
                "Projects" = 12
                "Tasks" = 50
                "Invoices" = 20
                "TimeEntries" = 80
            }
        }
        "stress-test" {
            return @{
                "Users" = 500
                "Clients" = 300
                "Projects" = 400
                "Tasks" = 5000
                "Invoices" = 1000
                "TimeEntries" = 10000
            }
        }
    }
}

function Test-BogusInstalled {
    param([string]$ProjectPath)

    $csprojFiles = Get-ChildItem $ProjectPath -Filter "*.csproj" -Recurse

    foreach ($csproj in $csprojFiles) {
        $content = Get-Content $csproj.FullName -Raw

        if ($content -match 'Bogus') {
            return $true
        }
    }

    return $false
}

function Install-Bogus {
    param([string]$ProjectPath)

    Write-Host ""
    Write-Host "=== Installing Bogus Library ===" -ForegroundColor Cyan
    Write-Host ""

    # Find .csproj file
    $csprojFiles = Get-ChildItem $ProjectPath -Filter "*.csproj" -Recurse | Where-Object { $_.Name -notmatch 'Test' }

    if ($csprojFiles.Count -eq 0) {
        Write-Host "ERROR: No .csproj file found" -ForegroundColor Red
        return $false
    }

    $csproj = $csprojFiles[0]

    Write-Host "Installing Bogus in: $($csproj.Name)" -ForegroundColor White

    Push-Location (Split-Path $csproj.FullName)
    try {
        dotnet add package Bogus

        Write-Host ""
        Write-Host "Bogus installed successfully!" -ForegroundColor Green
        Write-Host ""

        return $true

    } catch {
        Write-Host "ERROR: Failed to install Bogus: $_" -ForegroundColor Red
        return $false

    } finally {
        Pop-Location
    }
}

function Generate-SeedScript {
    param([hashtable]$Counts, [bool]$ClearExisting, [string]$ConnectionString)

    Write-Host ""
    Write-Host "=== Generating Seed Script ===" -ForegroundColor Cyan
    Write-Host ""

    $script = @"
using Bogus;
using Microsoft.EntityFrameworkCore;
using System;
using System.Linq;
using System.Collections.Generic;

namespace DatabaseSeeder
{
    public class DataSeeder
    {
        private readonly DbContext _context;
        private readonly Dictionary<string, List<int>> _createdIds = new();

        public DataSeeder(DbContext context)
        {
            _context = context;
        }

        public async Task SeedAsync()
        {
            Console.WriteLine("Starting database seeding...");
            Console.WriteLine();

"@

    if ($ClearExisting) {
        $script += @"
            // Clear existing data
            Console.WriteLine("Clearing existing data...");
            await ClearExistingDataAsync();
            Console.WriteLine();

"@
    }

    # Seed in order of dependencies
    $seedOrder = @("Users", "Clients", "Projects", "Tasks", "Invoices", "TimeEntries")

    foreach ($entityType in $seedOrder) {
        if ($Counts.ContainsKey($entityType) -and $Counts[$entityType] -gt 0) {
            $count = $Counts[$entityType]
            $script += @"
            // Seed $entityType
            Console.WriteLine("Seeding $count $entityType...");
            await Seed$entityType($count);
            Console.WriteLine();

"@
        }
    }

    $script += @"
            await _context.SaveChangesAsync();
            Console.WriteLine("Database seeding completed successfully!");
        }

        private async Task ClearExistingDataAsync()
        {
            // Clear in reverse order of dependencies
            _context.RemoveRange(_context.Set<TimeEntry>());
            _context.RemoveRange(_context.Set<Invoice>());
            _context.RemoveRange(_context.Set<Task>());
            _context.RemoveRange(_context.Set<Project>());
            _context.RemoveRange(_context.Set<Client>());
            _context.RemoveRange(_context.Set<User>());

            await _context.SaveChangesAsync();
        }

        private async Task SeedUsers(int count)
        {
            var faker = new Faker<User>()
                .RuleFor(u => u.FirstName, f => f.Name.FirstName())
                .RuleFor(u => u.LastName, f => f.Name.LastName())
                .RuleFor(u => u.Email, (f, u) => f.Internet.Email(u.FirstName, u.LastName))
                .RuleFor(u => u.PasswordHash, f => f.Internet.Password(16))
                .RuleFor(u => u.Role, f => f.PickRandom(new[] { "Admin", "Manager", "User" }))
                .RuleFor(u => u.IsActive, f => f.Random.Bool(0.9f))
                .RuleFor(u => u.CreatedAt, f => f.Date.Past(2));

            var users = faker.Generate(count);
            await _context.Set<User>().AddRangeAsync(users);
            await _context.SaveChangesAsync();

            _createdIds["Users"] = users.Select(u => u.Id).ToList();
        }

        private async Task SeedClients(int count)
        {
            var faker = new Faker<Client>()
                .RuleFor(c => c.Name, f => f.Company.CompanyName())
                .RuleFor(c => c.Email, f => f.Internet.Email())
                .RuleFor(c => c.Phone, f => f.Phone.PhoneNumber())
                .RuleFor(c => c.Address, f => f.Address.FullAddress())
                .RuleFor(c => c.City, f => f.Address.City())
                .RuleFor(c => c.Country, f => f.Address.Country())
                .RuleFor(c => c.Website, f => f.Internet.Url())
                .RuleFor(c => c.IsActive, f => f.Random.Bool(0.8f))
                .RuleFor(c => c.CreatedAt, f => f.Date.Past(2));

            var clients = faker.Generate(count);
            await _context.Set<Client>().AddRangeAsync(clients);
            await _context.SaveChangesAsync();

            _createdIds["Clients"] = clients.Select(c => c.Id).ToList();
        }

        private async Task SeedProjects(int count)
        {
            var clientIds = _createdIds["Clients"];
            var userIds = _createdIds["Users"];

            var faker = new Faker<Project>()
                .RuleFor(p => p.Name, f => f.Commerce.ProductName() + " " + f.Hacker.Verb())
                .RuleFor(p => p.Description, f => f.Lorem.Paragraph())
                .RuleFor(p => p.ClientId, f => f.PickRandom(clientIds))
                .RuleFor(p => p.ProjectManagerId, f => f.PickRandom(userIds))
                .RuleFor(p => p.Budget, f => f.Finance.Amount(5000, 100000))
                .RuleFor(p => p.Status, f => f.PickRandom(new[] { "Planning", "In Progress", "On Hold", "Completed" }))
                .RuleFor(p => p.StartDate, f => f.Date.Past(1))
                .RuleFor(p => p.EndDate, (f, p) => f.Date.Future(1, p.StartDate))
                .RuleFor(p => p.CreatedAt, f => f.Date.Past(2));

            var projects = faker.Generate(count);
            await _context.Set<Project>().AddRangeAsync(projects);
            await _context.SaveChangesAsync();

            _createdIds["Projects"] = projects.Select(p => p.Id).ToList();
        }

        private async Task SeedTasks(int count)
        {
            var projectIds = _createdIds["Projects"];
            var userIds = _createdIds["Users"];

            var faker = new Faker<Task>()
                .RuleFor(t => t.Title, f => f.Hacker.Phrase())
                .RuleFor(t => t.Description, f => f.Lorem.Sentences(3))
                .RuleFor(t => t.ProjectId, f => f.PickRandom(projectIds))
                .RuleFor(t => t.AssignedToId, f => f.PickRandom(userIds))
                .RuleFor(t => t.Status, f => f.PickRandom(new[] { "To Do", "In Progress", "Review", "Done" }))
                .RuleFor(t => t.Priority, f => f.PickRandom(new[] { "Low", "Medium", "High", "Critical" }))
                .RuleFor(t => t.EstimatedHours, f => f.Random.Int(1, 40))
                .RuleFor(t => t.ActualHours, (f, t) => f.Random.Int(0, (int)(t.EstimatedHours * 1.5)))
                .RuleFor(t => t.DueDate, f => f.Date.Future(0.5f))
                .RuleFor(t => t.CreatedAt, f => f.Date.Past(1));

            var tasks = faker.Generate(count);
            await _context.Set<Task>().AddRangeAsync(tasks);
            await _context.SaveChangesAsync();

            _createdIds["Tasks"] = tasks.Select(t => t.Id).ToList();
        }

        private async Task SeedInvoices(int count)
        {
            var clientIds = _createdIds["Clients"];
            var projectIds = _createdIds["Projects"];

            var faker = new Faker<Invoice>()
                .RuleFor(i => i.InvoiceNumber, f => "INV-" + f.Random.Number(10000, 99999))
                .RuleFor(i => i.ClientId, f => f.PickRandom(clientIds))
                .RuleFor(i => i.ProjectId, f => f.PickRandom(projectIds))
                .RuleFor(i => i.Amount, f => f.Finance.Amount(1000, 50000))
                .RuleFor(i => i.TaxAmount, (f, i) => i.Amount * 0.21m)
                .RuleFor(i => i.TotalAmount, (f, i) => i.Amount + i.TaxAmount)
                .RuleFor(i => i.Status, f => f.PickRandom(new[] { "Draft", "Sent", "Paid", "Overdue", "Cancelled" }))
                .RuleFor(i => i.IssueDate, f => f.Date.Past(0.5f))
                .RuleFor(i => i.DueDate, (f, i) => f.Date.Future(0.1f, i.IssueDate))
                .RuleFor(i => i.PaidDate, (f, i) => i.Status == "Paid" ? f.Date.Between(i.IssueDate, i.DueDate) : (DateTime?)null)
                .RuleFor(i => i.CreatedAt, f => f.Date.Past(1));

            var invoices = faker.Generate(count);
            await _context.Set<Invoice>().AddRangeAsync(invoices);
            await _context.SaveChangesAsync();

            _createdIds["Invoices"] = invoices.Select(i => i.Id).ToList();
        }

        private async Task SeedTimeEntries(int count)
        {
            var userIds = _createdIds["Users"];
            var projectIds = _createdIds["Projects"];
            var taskIds = _createdIds["Tasks"];

            var faker = new Faker<TimeEntry>()
                .RuleFor(t => t.UserId, f => f.PickRandom(userIds))
                .RuleFor(t => t.ProjectId, f => f.PickRandom(projectIds))
                .RuleFor(t => t.TaskId, f => f.Random.Bool(0.8f) ? f.PickRandom(taskIds) : (int?)null)
                .RuleFor(t => t.Description, f => f.Lorem.Sentence())
                .RuleFor(t => t.Hours, f => f.Random.Float(0.5f, 8.0f))
                .RuleFor(t => t.Date, f => f.Date.Past(0.3f))
                .RuleFor(t => t.IsBillable, f => f.Random.Bool(0.7f))
                .RuleFor(t => t.CreatedAt, f => f.Date.Past(0.5f));

            var timeEntries = faker.Generate(count);
            await _context.Set<TimeEntry>().AddRangeAsync(timeEntries);
            await _context.SaveChangesAsync();

            _createdIds["TimeEntries"] = timeEntries.Select(t => t.Id).ToList();
        }
    }
}
"@

    return $script
}

function Create-SeederConsoleApp {
    param([string]$ProjectPath, [hashtable]$Counts, [bool]$ClearExisting, [string]$ConnectionString)

    Write-Host ""
    Write-Host "=== Creating Seeder Console App ===" -ForegroundColor Cyan
    Write-Host ""

    $seederPath = Join-Path $ProjectPath "DatabaseSeeder"

    if (-not (Test-Path $seederPath)) {
        New-Item -ItemType Directory -Path $seederPath -Force | Out-Null
    }

    # Create .csproj
    $csproj = @"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net8.0</TargetFramework>
    <Nullable>enable</Nullable>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Bogus" Version="35.0.0" />
    <PackageReference Include="Microsoft.EntityFrameworkCore" Version="8.0.0" />
    <PackageReference Include="Microsoft.EntityFrameworkCore.SqlServer" Version="8.0.0" />
  </ItemGroup>
</Project>
"@

    $csprojPath = Join-Path $seederPath "DatabaseSeeder.csproj"
    $csproj | Set-Content $csprojPath -Encoding UTF8

    Write-Host "Created: $csprojPath" -ForegroundColor Green

    # Generate DataSeeder.cs
    $seederCode = Generate-SeedScript -Counts $Counts -ClearExisting $ClearExisting -ConnectionString $ConnectionString
    $seederCodePath = Join-Path $seederPath "DataSeeder.cs"
    $seederCode | Set-Content $seederCodePath -Encoding UTF8

    Write-Host "Created: $seederCodePath" -ForegroundColor Green

    # Create Program.cs
    $program = @"
using Microsoft.EntityFrameworkCore;
using System;
using System.Threading.Tasks;

namespace DatabaseSeeder
{
    class Program
    {
        static async Task Main(string[] args)
        {
            var connectionString = Environment.GetEnvironmentVariable("CONNECTION_STRING")
                ?? "Server=(localdb)\\mssqllocaldb;Database=ClientManager;Trusted_Connection=True;";

            var optionsBuilder = new DbContextOptionsBuilder<DbContext>();
            optionsBuilder.UseSqlServer(connectionString);

            using var context = new DbContext(optionsBuilder.Options);

            // Ensure database exists
            await context.Database.EnsureCreatedAsync();

            var seeder = new DataSeeder(context);
            await seeder.SeedAsync();

            Console.WriteLine();
            Console.WriteLine("Press any key to exit...");
            Console.ReadKey();
        }
    }
}
"@

    $programPath = Join-Path $seederPath "Program.cs"
    $program | Set-Content $programPath -Encoding UTF8

    Write-Host "Created: $programPath" -ForegroundColor Green
    Write-Host ""

    return $seederPath
}

function Show-SeedPlan {
    param([hashtable]$Counts)

    Write-Host ""
    Write-Host "=== Seed Plan ===" -ForegroundColor Cyan
    Write-Host ""

    $total = 0

    foreach ($entity in $Counts.Keys | Sort-Object) {
        $count = $Counts[$entity]
        $total += $count

        Write-Host ("  {0,-20} {1,6} records" -f $entity, $count) -ForegroundColor White
    }

    Write-Host ""
    Write-Host ("  Total:              {0,6} records" -f $total) -ForegroundColor Green
    Write-Host ""
}

function Run-Seeder {
    param([string]$SeederPath, [string]$ConnectionString)

    Write-Host ""
    Write-Host "=== Running Database Seeder ===" -ForegroundColor Cyan
    Write-Host ""

    Push-Location $SeederPath
    try {
        # Restore packages
        Write-Host "Restoring packages..." -ForegroundColor White
        dotnet restore

        Write-Host ""

        # Set connection string if provided
        if ($ConnectionString) {
            $env:CONNECTION_STRING = $ConnectionString
        }

        # Run seeder
        Write-Host "Running seeder..." -ForegroundColor White
        dotnet run

        Write-Host ""
        Write-Host "Seeding completed!" -ForegroundColor Green
        Write-Host ""

    } catch {
        Write-Host "ERROR: Seeding failed: $_" -ForegroundColor Red
        return $false

    } finally {
        Pop-Location
    }

    return $true
}

function Generate-SeedManifest {
    param([hashtable]$Counts, [string]$OutputPath)

    $manifest = @{
        "timestamp" = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        "environment" = $Environment
        "dataVolume" = $DataVolume
        "scenario" = $Scenario
        "clearExisting" = $ClearExisting.IsPresent
        "entities" = $Counts
    }

    $manifestPath = Join-Path $OutputPath "seed-manifest.json"
    $manifest | ConvertTo-Json -Depth 5 | Set-Content $manifestPath -Encoding UTF8

    Write-Host "Seed manifest created: $manifestPath" -ForegroundColor Green
    Write-Host ""
}

# Main execution
Write-Host ""
Write-Host "=== Database Seeder ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $ProjectPath)) {
    Write-Host "ERROR: Project path not found: $ProjectPath" -ForegroundColor Red
    exit 1
}

# Determine counts
$counts = if ($Scenario) {
    Get-ScenarioCounts -Scenario $Scenario
} else {
    Get-DataVolumeCounts -Volume $DataVolume
}

# Filter entities if specified
if ($Entities) {
    $entityList = $Entities -split ',' | ForEach-Object { $_.Trim() }
    $filteredCounts = @{}

    foreach ($entity in $entityList) {
        if ($counts.ContainsKey($entity)) {
            $filteredCounts[$entity] = $counts[$entity]
        }
    }

    $counts = $filteredCounts
}

# Show plan
Write-Host "Environment: $Environment" -ForegroundColor White
Write-Host "Data Volume: $DataVolume" -ForegroundColor White

if ($Scenario) {
    Write-Host "Scenario: $Scenario" -ForegroundColor White
}

if ($ClearExisting) {
    Write-Host "Clear Existing: YES" -ForegroundColor Yellow
} else {
    Write-Host "Clear Existing: NO" -ForegroundColor White
}

Show-SeedPlan -Counts $counts

# Confirm
if ($Environment -eq "staging") {
    Write-Host "WARNING: You are seeding STAGING environment" -ForegroundColor Yellow
    $confirm = Read-Host "Continue? (yes/no)"

    if ($confirm -ne "yes") {
        Write-Host "Cancelled" -ForegroundColor Yellow
        exit 0
    }

    Write-Host ""
}

# Check Bogus installation
$hasBogus = Test-BogusInstalled -ProjectPath $ProjectPath

if (-not $hasBogus) {
    Write-Host "Bogus library not found" -ForegroundColor Yellow
    $install = Read-Host "Install Bogus? (yes/no)"

    if ($install -eq "yes") {
        $installed = Install-Bogus -ProjectPath $ProjectPath

        if (-not $installed) {
            exit 1
        }
    } else {
        Write-Host "Cancelled" -ForegroundColor Yellow
        exit 1
    }
}

# Create seeder console app
$seederPath = Create-SeederConsoleApp -ProjectPath $ProjectPath -Counts $counts -ClearExisting $ClearExisting -ConnectionString $ConnectionString

# Generate manifest
Generate-SeedManifest -Counts $counts -OutputPath $seederPath

# Run seeder
$success = Run-Seeder -SeederPath $seederPath -ConnectionString $ConnectionString

if ($success) {
    Write-Host "=== Database Seeding Complete ===" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Verify data in database" -ForegroundColor White
    Write-Host "  2. Run application to test with seeded data" -ForegroundColor White
    Write-Host "  3. Adjust seed counts if needed and re-run" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host "Seeding failed" -ForegroundColor Red
    exit 1
}

exit 0
