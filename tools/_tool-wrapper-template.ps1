# TEMPLATE: Add this snippet to the START of every tool for auto-tracking
# Replace {TOOL_NAME} with actual tool name

<# USAGE TRACKING - DO NOT REMOVE
. "$PSScriptRoot\_usage-logger.ps1" -ToolName "{TOOL_NAME}" -Action "execute" -Metadata @{
    Parameters = $PSBoundParameters.Keys -join ','
}
#>

# Example integration:
<#
param(
    [Parameter(Mandatory=$false)]
    [string]$SomeParam
)

# AUTO-TRACK USAGE
. "$PSScriptRoot\_usage-logger.ps1" -ToolName "my-tool" -Action "execute" -Metadata @{
    Parameters = $PSBoundParameters.Keys -join ','
}

# ... rest of tool code ...
#>
