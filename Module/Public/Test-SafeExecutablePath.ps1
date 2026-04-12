<#
.SYNOPSIS
    Validates that an executable path is safe to execute.

.DESCRIPTION
    This function performs security validation on an executable path to prevent
    command injection attacks. It validates:
    1. The path has a safe extension (.exe only)
    2. For simple names (no path separators), allows execution
    3. For paths with directory separators, returns a warning for user confirmation

.PARAMETER ExecutablePath
    The executable path to validate.

.OUTPUTS
    System.Management.Automation.PSCustomObject with properties:
    - IsValid: Boolean indicating if the path passes basic validation
    - Warning: String warning message if user confirmation is needed (null if none)
    - Message: String error message if validation failed (null if valid)

.EXAMPLE
    $result = Test-SafeExecutablePath -ExecutablePath 'faster-whisper-xxl.exe'
    # Returns IsValid=$true, Warning=$null, Message=$null

.EXAMPLE
    $result = Test-SafeExecutablePath -ExecutablePath 'C:\Tools\my-tool.exe'
    # Returns IsValid=$true, Warning='Custom executable path detected...', Message=$null

.EXAMPLE
    $result = Test-SafeExecutablePath -ExecutablePath 'C:\Tools\malicious.bat'
    # Returns IsValid=$false, Warning=$null, Message='Invalid executable extension...'
#>
function Test-SafeExecutablePath {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$ExecutablePath
    )

    # Handle empty/null path - will fall back to default
    if ([string]::IsNullOrWhiteSpace($ExecutablePath)) {
        return [PSCustomObject]@{
            IsValid = $true
            Warning = $null
            Message = $null
        }
    }

    # Check for safe extension (.exe only)
    $extension = [System.IO.Path]::GetExtension($ExecutablePath)
    if ($extension -and $extension -ne '.exe') {
        return [PSCustomObject]@{
            IsValid = $false
            Warning = $null
            Message = "Invalid executable extension '$extension'. Only .exe files are allowed."
        }
    }

    # Check if it's a simple name (no path separators) - these are safe as they must be in PATH
    if ($ExecutablePath -notmatch '[/\\]') {
        return [PSCustomObject]@{
            IsValid = $true
            Warning = $null
            Message = $null
        }
    }

    # It's a path with directory separators - require user confirmation
    # Check for potentially dangerous patterns
    $dangerousPatterns = @('..', '~', '|', '&', ';', '$', '`', '$(')
    foreach ($pattern in $dangerousPatterns) {
        if ($ExecutablePath -match [regex]::Escape($pattern)) {
            return [PSCustomObject]@{
                IsValid = $false
                Warning = $null
                Message = "Potentially dangerous pattern '$pattern' detected in executable path."
            }
        }
    }

    # Path looks valid but is custom - warn user
    return [PSCustomObject]@{
        IsValid = $true
        Warning = "The executable path is set to a custom location: '$ExecutablePath'. Only proceed if you trust this executable."
        Message = $null
    }
}
