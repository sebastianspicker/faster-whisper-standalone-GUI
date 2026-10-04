<#
.SYNOPSIS
    Resolves the configured executable to a full path, or returns $null when not found.

.DESCRIPTION
    A bare name is looked up in ApplicationDirectory first, then on PATH (applications only).
    A value containing a path separator must be an existing file (relative values are resolved
    against the current PowerShell location) and is returned as a full path.
#>
function Resolve-FasterWhisperExecutable {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Executable,

        [Parameter()]
        [AllowEmptyString()]
        [string]$ApplicationDirectory = ''
    )

    if ($Executable -match '[/\\]') {
        if (Test-Path -LiteralPath $Executable -PathType Leaf) {
            return (Convert-Path -LiteralPath $Executable)
        }
        return $null
    }

    if (-not [string]::IsNullOrWhiteSpace($ApplicationDirectory)) {
        $candidate = Join-Path -Path $ApplicationDirectory -ChildPath $Executable
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Convert-Path -LiteralPath $candidate)
        }
    }

    $command = Get-Command -Name $Executable -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($command) { return [string]$command.Source }

    return $null
}
