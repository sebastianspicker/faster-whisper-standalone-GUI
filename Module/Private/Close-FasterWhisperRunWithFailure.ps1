<#
.SYNOPSIS
    Records a failure on a run object and finalizes its summary.

.DESCRIPTION
    Sets Run.Failure (Title $null means silent), clears Run.StartInfo and finalizes the summary
    with ExitCode $null. Returns the run.
#>
function Close-FasterWhisperRunWithFailure {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Run,

        [Parameter()]
        [AllowNull()]
        [string]$Title,

        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter()]
        [ValidateSet('Warning', 'Error')]
        [string]$Icon = 'Error'
    )

    $Run.Failure = [pscustomobject]@{
        Title = $Title
        Message = $Message
        Icon = $Icon
    }
    $Run.StartInfo = $null
    $null = Close-FasterWhisperRunSummary -Summary $Run.Summary -ExitCode $null -ErrorMessage $Message

    return $Run
}
