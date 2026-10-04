<#
.SYNOPSIS
    Returns the allowed values and numeric ranges for the Faster Whisper options.

.DESCRIPTION
    Single source of truth for the option values offered by the GUI (dropdowns, slider limits)
    and enforced by the config loader. Initialize-FasterWhisperRun does not re-check request
    values against it; callers pass values chosen from these lists.

.OUTPUTS
    System.Collections.Hashtable
    A hashtable with the following keys:
    - Devices: Array of allowed device values ('cpu', 'cuda')
    - Models: Array of allowed model values ('base', 'medium', 'large-v2', 'xxl')
    - Formats: Array of allowed output format values ('txt', 'srt', 'vtt')
    - Tasks: Array of allowed task values ('transcribe', 'translate')
    - BestOf, BeamSize: Hashtable with Minimum and Maximum (1 to 10)
    - Patience, Temperature: Hashtable with Minimum and Maximum (0.0 to 2.0)

.EXAMPLE
    $catalog = Get-FasterWhisperOptionCatalog
    $catalog.Devices         # Returns @('cpu', 'cuda')
    $catalog.BestOf.Maximum  # Returns 10
#>
function Get-FasterWhisperOptionCatalog {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    return @{
        Devices     = @('cpu', 'cuda')
        Models      = @('base', 'medium', 'large-v2', 'xxl')
        Formats     = @('txt', 'srt', 'vtt')
        Tasks       = @('transcribe', 'translate')
        BestOf      = @{ Minimum = 1; Maximum = 10 }
        BeamSize    = @{ Minimum = 1; Maximum = 10 }
        Patience    = @{ Minimum = 0.0; Maximum = 2.0 }
        Temperature = @{ Minimum = 0.0; Maximum = 2.0 }
    }
}
