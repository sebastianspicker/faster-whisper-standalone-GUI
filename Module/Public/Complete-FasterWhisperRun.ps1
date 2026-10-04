<#
.SYNOPSIS
    Finalizes the summary of a run whose process has exited.

.DESCRIPTION
    Sets EndTime, DurationSeconds, ExitCode and Succeeded on the summary and, for a failed run
    without an error message, a default ErrorMessage. Disposes Run.Process and sets it to $null.
    Idempotent: when the summary already has an EndTime it is returned unchanged.

.PARAMETER Run
    The run object returned by Initialize-FasterWhisperRun.

.PARAMETER ExitCode
    Exit code of the engine process.

.PARAMETER StoppedByUser
    Marks a non-zero exit as stopped by the user ('Transcription stopped by user.').

.OUTPUTS
    System.Management.Automation.PSCustomObject (the run summary).

.EXAMPLE
    $summary = Complete-FasterWhisperRun -Run $run -ExitCode $run.Process.ExitCode
#>
function Complete-FasterWhisperRun {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Run,

        [Parameter(Mandatory)]
        [int]$ExitCode,

        [Parameter()]
        [switch]$StoppedByUser
    )

    $summary = $Run.Summary
    if ($null -ne $summary.EndTime) { return $summary }

    $errorMessage = if ($StoppedByUser) {
        'Transcription stopped by user.'
    }
    else {
        "Transcription failed (exit code $ExitCode).`nCheck the console window for details, or try a different model size or device setting."
    }
    $null = Close-FasterWhisperRunSummary -Summary $summary -ExitCode $ExitCode -ErrorMessage $errorMessage

    if ($Run.Process -is [System.IDisposable]) { $Run.Process.Dispose() }
    $Run.Process = $null

    return $summary
}
