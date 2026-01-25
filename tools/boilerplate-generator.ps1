# Boilerplate Generator - Scaffold React components + tests + docs
# Wave 2 Tool #8 (Ratio: 6.0)

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('component', 'service', 'controller', 'test')]
    [string]$Type,

    [Parameter(Mandatory=$true)]
    [string]$Name,

    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "."
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

function New-ReactComponent {
    param([string]$Name, [string]$Path)

    $component = @"
import React from 'react';

interface ${Name}Props {
  // Add props here
}

export const $Name: React.FC<${Name}Props> = (props) => {
  return (
    <div className="$($Name.ToLower())">
      <h2>$Name</h2>
    </div>
  );
};
"@

    $test = @"
import { render, screen } from '@testing-library/react';
import { $Name } from './$Name';

describe('$Name', () => {
  it('renders without crashing', () => {
    render(<$Name />);
    expect(screen.getByText('$Name')).toBeInTheDocument();
  });
});
"@

    $componentFile = Join-Path $Path "$Name.tsx"
    $testFile = Join-Path $Path "$Name.test.tsx"

    $component | Set-Content $componentFile -Encoding UTF8
    $test | Set-Content $testFile -Encoding UTF8

    Write-Host "Created:" -ForegroundColor Green
    Write-Host "  - $componentFile" -ForegroundColor Gray
    Write-Host "  - $testFile" -ForegroundColor Gray
}

function New-Service {
    param([string]$Name, [string]$Path)

    $service = @"
export class ${Name}Service {
  async get(id: string) {
    // Implementation
  }

  async create(data: any) {
    // Implementation
  }

  async update(id: string, data: any) {
    // Implementation
  }

  async delete(id: string) {
    // Implementation
  }
}

export const $($Name.ToLower())Service = new ${Name}Service();
"@

    $serviceFile = Join-Path $Path "${Name}Service.ts"
    $service | Set-Content $serviceFile -Encoding UTF8

    Write-Host "Created: $serviceFile" -ForegroundColor Green
}

function New-Controller {
    param([string]$Name, [string]$Path)

    $controller = @"
using Microsoft.AspNetCore.Mvc;

namespace YourNamespace.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ${Name}Controller : ControllerBase
    {
        [HttpGet]
        public IActionResult Get()
        {
            return Ok();
        }

        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            return Ok();
        }

        [HttpPost]
        public IActionResult Create([FromBody] object model)
        {
            return Created("", model);
        }

        [HttpPut("{id}")]
        public IActionResult Update(int id, [FromBody] object model)
        {
            return Ok();
        }

        [HttpDelete("{id}")]
        public IActionResult Delete(int id)
        {
            return NoContent();
        }
    }
}
"@

    $controllerFile = Join-Path $Path "${Name}Controller.cs"
    $controller | Set-Content $controllerFile -Encoding UTF8

    Write-Host "Created: $controllerFile" -ForegroundColor Green
}

# Ensure output directory exists
if (-not (Test-Path $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
}

switch ($Type) {
    'component' { New-ReactComponent -Name $Name -Path $OutputPath }
    'service' { New-Service -Name $Name -Path $OutputPath }
    'controller' { New-Controller -Name $Name -Path $OutputPath }
    'test' { Write-Host "Test generation for existing code coming soon..." -ForegroundColor Yellow }
}
