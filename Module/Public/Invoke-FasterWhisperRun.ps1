<#
.SYNOPSIS
    Starts the transcription engine process of an initialized run.

.DESCRIPTION
    Starts a process from Run.StartInfo and stores it in Run.Process. When the process cannot be
    started, Run.Failure is set (Title 'Error', Icon 'Error') and the summary is finalized as
    failed. The caller owns waiting for the process and then calls Complete-FasterWhisperRun.

.PARAMETER Run
    The run object returned by Initialize-FasterWhisperRun (without a Failure).

.OUTPUTS
    System.Boolean. $true when the process was started, $false otherwise.

.EXAMPLE
    if (Invoke-FasterWhisperRun -Run $run) { $run.Process.WaitForExit() }
#>
function Invoke-FasterWhisperRun {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Run
    )

    if ($null -eq $Run.StartInfo) { return $false }

    $process = [System.Diagnostics.Process]::new()
    try {
        $process.StartInfo = $Run.StartInfo
        $null = $process.Start()
        $Run.Process = $process
        return $true
    }
    catch {
        $process.Dispose()
        $exe = $Run.Summary.Executable
        $null = Close-FasterWhisperRunWithFailure -Run $Run -Title 'Error' -Message "Failed to start the transcription engine.`n`nPlease verify that '$exe' is a valid executable and try again.`n`nDetails: $($_.Exception.Message)"
        return $false
    }
}
