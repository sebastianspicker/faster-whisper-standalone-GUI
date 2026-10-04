<#
.SYNOPSIS
    Finalizes a run summary record in place (keeps the property order unchanged).

.DESCRIPTION
    Sets EndTime, DurationSeconds (rounded to 0.1), ExitCode and Succeeded. ErrorMessage is only
    set when the run did not succeed and the summary has no message yet.
#>
function Close-FasterWhisperRunSummary {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Summary,

        [Parameter()]
        [AllowNull()]
        [object]$ExitCode = $null,

        [Parameter()]
        [AllowEmptyString()]
        [string]$ErrorMessage = ''
    )

    $Summary.EndTime = Get-Date
    $Summary.DurationSeconds = [Math]::Round(($Summary.EndTime - $Summary.StartTime).TotalSeconds, 1)
    $Summary.ExitCode = $ExitCode
    $Summary.Succeeded = ($null -ne $ExitCode -and $ExitCode -eq 0)

    if (-not $Summary.Succeeded -and [string]::IsNullOrEmpty($Summary.ErrorMessage)) {
        $Summary.ErrorMessage = $ErrorMessage
    }

    return $Summary
}
