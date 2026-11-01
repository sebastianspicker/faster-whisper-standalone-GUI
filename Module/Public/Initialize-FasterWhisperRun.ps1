<#
.SYNOPSIS
    Validates a run request and prepares the transcription engine process.

.DESCRIPTION
    Runs the validation chain (language, confirmation for a custom executable path, executable
    resolution and .exe check, input file, output directory) and, when everything passes, builds
    the ProcessStartInfo for the engine. The process is not started; call Invoke-FasterWhisperRun.
    Input file and output directory are made absolute once, so the checks, the engine arguments,
    the engine's working directory and the summary all use the same paths.

    Side effects: the output directory is created when missing, and ConfirmExecutable is invoked
    when the configured executable path contains a folder (not a bare name).

    Every failure finalizes the summary (EndTime, DurationSeconds, ExitCode $null, Succeeded
    $false, ErrorMessage) and sets Run.Failure. A Failure with a $null Title is silent (the user
    declined the security warning) and should not be shown in a dialog.

.PARAMETER Request
    Object with the properties InputFile, OutputDirectory, UseInputDirectoryAsOutput, Device,
    Language, Model, OutputFormat, Task, BestOf, BeamSize, Patience (double), Temperature
    (double), PlaySound and ShowCliProgress.

.PARAMETER ExecutablePath
    Configured engine executable (name or path). Blank selects the default engine name.

.PARAMETER ApplicationDirectory
    Directory of the application; a bare executable name is looked up here before PATH.

.PARAMETER ConfirmExecutable
    Scriptblock invoked with the security warning text as its only argument. It returns $true to
    continue; any other result cancels the run.

.OUTPUTS
    System.Management.Automation.PSCustomObject (the run) with the properties Summary, Failure
    ($null or Title, Message, Icon 'Warning' or 'Error'), Language (normalized language code),
    StartInfo (ProcessStartInfo, $null on failure) and Process ($null until started).

.EXAMPLE
    $run = Initialize-FasterWhisperRun -Request $request -ExecutablePath $config.ExecutablePath `
        -ApplicationDirectory $PSScriptRoot -ConfirmExecutable { param($Warning) $true }
    if (-not $run.Failure) { Invoke-FasterWhisperRun -Run $run }
#>
function Initialize-FasterWhisperRun {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [psobject]$Request,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$ExecutablePath,

        [Parameter(Mandatory)]
        [string]$ApplicationDirectory,

        [Parameter(Mandatory)]
        [scriptblock]$ConfirmExecutable
    )

    $invCulture = [System.Globalization.CultureInfo]::InvariantCulture
    $patienceText = [string]::Format($invCulture, '{0:0.0}', [double]$Request.Patience)
    $temperatureText = [string]::Format($invCulture, '{0:0.0}', [double]$Request.Temperature)

    $summary = [pscustomobject]@{
        InputFile        = $Request.InputFile
        OutputDirectory  = $null
        Device           = $Request.Device
        Language         = $Request.Language
        Model            = $Request.Model
        OutputFormat     = $Request.OutputFormat
        Task             = $Request.Task
        BestOf           = $Request.BestOf
        BeamSize         = $Request.BeamSize
        Patience         = [double]$patienceText
        Temperature      = [double]$temperatureText
        PlaySound        = $Request.PlaySound
        ShowCliProgress  = $Request.ShowCliProgress
        Executable       = $null
        StartTime        = Get-Date
        EndTime          = $null
        DurationSeconds  = $null
        ExitCode         = $null
        Succeeded        = $false
        ErrorMessage     = $null
    }

    $run = [pscustomobject]@{
        Summary   = $summary
        Failure   = $null
        Language  = $Request.Language
        StartInfo = $null
        Process   = $null
    }

    # Language is optional. Whisper codes are two letters, plus 'haw' (Hawaiian) and 'yue' (Cantonese).
    # \z, not $: '$' also matches before a trailing newline
    $language = ([string]$Request.Language).Trim()
    if ($language -and $language -notmatch '(?i)^([a-z]{2}|haw|yue)\z') {
        return Close-FasterWhisperRunWithFailure -Run $run -Title 'Validation Error' -Icon 'Warning' -Message "Invalid language code: '$($Request.Language)'. Please enter a language code such as 'en' (English), 'de' (German), 'fr' (French) or 'yue' (Cantonese), or leave it empty for auto-detection."
    }
    # Normalized (trimmed, lowercase) code for the executable and the summary
    $run.Language = $language.ToLowerInvariant()
    $summary.Language = $run.Language

    $exe = if (-not [string]::IsNullOrWhiteSpace($ExecutablePath)) {
        $ExecutablePath
    }
    else {
        (Get-FasterWhisperGuiDefaultConfig).ExecutablePath
    }

    $summary.Executable = $exe

    # A configured path with a folder (not a bare name) needs the user's OK before it is touched
    # (looking up a UNC path already connects to its host)
    if ($exe -match '[/\\]' -and -not (& $ConfirmExecutable "The executable path is set to a custom location: '$exe'. Only proceed if you trust this executable.")) {
        return Close-FasterWhisperRunWithFailure -Run $run -Title $null -Icon 'Warning' -Message 'User cancelled due to security warning.'
    }

    $resolvedExe = Resolve-FasterWhisperExecutable -Executable $exe -ApplicationDirectory $ApplicationDirectory
    if (-not $resolvedExe) {
        return Close-FasterWhisperRunWithFailure -Run $run -Title 'Transcription Engine Not Found' -Message "Transcription engine not found: $exe`n`nTo fix this:`n1. Download faster-whisper-xxl.exe and place it in the same folder as this script.`n2. Or add its location to your system PATH.`n3. Or set 'ExecutablePath' in the config JSON file."
    }

    # Only .exe files run. This also catches a .cmd/.bat found via PATHEXT, and names without an
    # extension or with a trailing dot ("x.bat."), which Windows could still start as a batch file.
    $resolvedExtension = [System.IO.Path]::GetExtension($resolvedExe)
    if ($resolvedExtension -ne '.exe') {
        return Close-FasterWhisperRunWithFailure -Run $run -Title 'Security Error' -Message "The configured executable path is not allowed for security reasons: Invalid executable extension '$resolvedExtension'. Only .exe files are allowed.`n`nPlease check the 'ExecutablePath' setting in your config JSON file."
    }

    # Validate input file
    if ([string]::IsNullOrWhiteSpace($Request.InputFile) -or
        -not [System.IO.File]::Exists($Request.InputFile)) {
        return Close-FasterWhisperRunWithFailure -Run $run -Title 'Input File Required' -Icon 'Warning' -Message "No input file selected or file not found.`n`nPlease click Browse to select an audio or video file (MP3, WAV, MP4)."
    }

    # One absolute path for the checks, folder creation, engine arguments and the summary
    # (same base as File.Exists above: the process working directory)
    $inputFile = [System.IO.Path]::GetFullPath($Request.InputFile)
    $summary.InputFile = $inputFile

    try {
        $outputDir = if ([bool]$Request.UseInputDirectoryAsOutput -or [string]::IsNullOrWhiteSpace($Request.OutputDirectory)) {
            [System.IO.Path]::GetDirectoryName($inputFile)
        }
        else {
            [System.IO.Path]::GetFullPath($Request.OutputDirectory)
        }
        $summary.OutputDirectory = $outputDir

        if (-not [System.IO.Directory]::Exists($outputDir)) {
            [System.IO.Directory]::CreateDirectory($outputDir) | Out-Null
        }
    }
    catch {
        return Close-FasterWhisperRunWithFailure -Run $run -Title 'Error' -Message "Could not create or access the output folder:`n$($outputDir ?? $Request.OutputDirectory)`n`nPlease check that you have write permissions to this location, or choose a different output folder.`n`nDetails: $($_.Exception.Message)"
    }

    # Build arguments (passed as array via ArgumentList to handle quoting automatically)
    $argList = Get-FasterWhisperArgumentList `
        -InputFile $inputFile `
        -Device $Request.Device `
        -Language $run.Language `
        -Model $Request.Model `
        -OutputDirectory $outputDir `
        -OutputFormat $Request.OutputFormat `
        -Task $Request.Task `
        -BestOf $Request.BestOf `
        -BeamSize $Request.BeamSize `
        -Patience $patienceText `
        -Temperature $temperatureText `
        -PlayConfirmationSound ([bool]$Request.PlaySound) `
        -ShowCliProgress ([bool]$Request.ShowCliProgress)

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $resolvedExe
    foreach ($arg in $argList) { [void]$startInfo.ArgumentList.Add([string]$arg) }
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $false
    $startInfo.WorkingDirectory = [System.IO.Path]::GetDirectoryName($inputFile)

    $run.StartInfo = $startInfo
    return $run
}
