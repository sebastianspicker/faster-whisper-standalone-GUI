<#
.SYNOPSIS
    Returns a hashtable containing the allowed values for various Faster Whisper configuration options.

.DESCRIPTION
    This function centralizes the definition of allowed values for devices, models, output formats,
    and tasks to avoid duplication across multiple files. This ensures consistency and makes
    future updates easier.

.OUTPUTS
    System.Collections.Hashtable
    A hashtable with the following keys:
    - Devices: Array of allowed device values ('cpu', 'cuda')
    - Models: Array of allowed model values ('base', 'medium', 'large-v2', 'xxl')
    - Formats: Array of allowed output format values ('txt', 'srt', 'vtt')
    - Tasks: Array of allowed task values ('transcribe', 'translate')

.EXAMPLE
    $allowed = Get-FasterWhisperAllowedValueMap
    $allowed.Devices    # Returns @('cpu', 'cuda')
    $allowed.Models     # Returns @('base', 'medium', 'large-v2', 'xxl')
    $allowed.Formats    # Returns @('txt', 'srt', 'vtt')
    $allowed.Tasks      # Returns @('transcribe', 'translate')

.EXAMPLE
    if ($allowed.Devices -contains $device) { Write-Output "Valid device" }
#>
function Get-FasterWhisperAllowedValueMap {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    return @{
        Devices = @('cpu', 'cuda')
        Models  = @('base', 'medium', 'large-v2', 'xxl')
        Formats = @('txt', 'srt', 'vtt')
        Tasks   = @('transcribe', 'translate')
    }
}

# Backward-compatibility alias for earlier public API name.
Set-Alias -Name Get-FasterWhisperAllowedValues -Value Get-FasterWhisperAllowedValueMap
