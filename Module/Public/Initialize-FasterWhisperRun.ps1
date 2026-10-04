<#
.SYNOPSIS
    Validates a run request and prepares the transcription engine process.

.DESCRIPTION
    Runs the validation chain (language, executable safety, executable resolution, input file,
    input and output path safety, output directory) and, when everything passes, builds the
    ProcessStartInfo for the engine. The process is not started; call Invoke-FasterWhisperRun.

    Side effects: the output directory is created when missing, and ConfirmExecutable is invoked
    when the configured executable path needs user confirmation.

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

    # Validate Language (optional, but if provided should be ISO-639-1)
    if (-not [string]::IsNullOrWhiteSpace($Request.Language)) {
        if ($Request.Language -notmatch '(?i)^[a-z]{2}$') {
            return Close-FasterWhisperRunWithFailure -Run $run -Title 'Validation Error' -Icon 'Warning' -Message "Invalid language code: '$($Request.Language)'. Please enter a 2-letter language code (e.g. 'en' for English, 'de' for German, 'fr' for French) or leave it empty for auto-detection."
        }
        # Normalize language to lowercase for the executable
        $run.Language = $Request.Language.ToLowerInvariant()
    }

    # Resolve executable path (configurable) with security validation
    $exe = if (-not [string]::IsNullOrWhiteSpace($ExecutablePath)) {
        $ExecutablePath
    }
    else {
        (Get-FasterWhisperGuiDefaultConfig).ExecutablePath
    }

    $exeValidationResult = Test-SafeExecutablePath -ExecutablePath $exe
    if (-not $exeValidationResult.IsValid) {
        return Close-FasterWhisperRunWithFailure -Run $run -Title 'Security Error' -Message "The configured executable path is not allowed for security reasons: $($exeValidationResult.Message)`n`nPlease check the 'ExecutablePath' setting in your config JSON file."
    }
    if ($exeValidationResult.Warning) {
        if (-not (& $ConfirmExecutable $exeValidationResult.Warning)) {
            return Close-FasterWhisperRunWithFailure -Run $run -Title $null -Icon 'Warning' -Message 'User cancelled due to security warning.'
        }
    }

    $summary.Executable = $exe

    $resolvedExe = Resolve-FasterWhisperExecutable -Executable $exe -ApplicationDirectory $ApplicationDirectory
    if (-not $resolvedExe) {
        return Close-FasterWhisperRunWithFailure -Run $run -Title 'Transcription Engine Not Found' -Message "Transcription engine not found: $exe`n`nTo fix this:`n1. Download faster-whisper-xxl.exe and place it in the same folder as this script.`n2. Or add its location to your system PATH.`n3. Or set 'ExecutablePath' in the config JSON file."
    }

    # The resolved file (e.g. via PATHEXT) must be an .exe as well
    $resolvedExtension = [System.IO.Path]::GetExtension($resolvedExe)
    if ($resolvedExtension -and $resolvedExtension -ne '.exe') {
        return Close-FasterWhisperRunWithFailure -Run $run -Title 'Security Error' -Message "The configured executable path is not allowed for security reasons: Invalid executable extension '$resolvedExtension'. Only .exe files are allowed.`n`nPlease check the 'ExecutablePath' setting in your config JSON file."
    }

    # Validate input file
    if ([string]::IsNullOrWhiteSpace($Request.InputFile) -or
        -not [System.IO.File]::Exists($Request.InputFile)) {
        return Close-FasterWhisperRunWithFailure -Run $run -Title 'Input File Required' -Icon 'Warning' -Message "No input file selected or file not found.`n`nPlease click Browse to select an audio or video file (MP3, WAV, MP4)."
    }

    if (-not (Test-PathTraversalSafe -Path $Request.InputFile)) {
        return Close-FasterWhisperRunWithFailure -Run $run -Title 'Error' -Message "The input file path appears unsafe.`nPlease select a file using the Browse button instead of typing the path manually."
    }

    # Determine output directory
    $outputDir = Get-FasterWhisperOutputDirectory `
        -InputFile $Request.InputFile `
        -OutputDirectory $Request.OutputDirectory `
        -UseInputDirectoryAsOutput ([bool]$Request.UseInputDirectoryAsOutput)

    $summary.OutputDirectory = $outputDir

    if (-not (Test-PathTraversalSafe -Path $outputDir)) {
        return Close-FasterWhisperRunWithFailure -Run $run -Title 'Error' -Message "The output directory path appears unsafe.`nPlease select a folder using the Browse button instead of typing the path manually."
    }

    try {
        if (-not [System.IO.Directory]::Exists($outputDir)) {
            [System.IO.Directory]::CreateDirectory($outputDir) | Out-Null
        }
    }
    catch {
        return Close-FasterWhisperRunWithFailure -Run $run -Title 'Error' -Message "Could not create or access the output folder:`n$outputDir`n`nPlease check that you have write permissions to this location, or choose a different output folder.`n`nDetails: $($_.Exception.Message)"
    }

    # Build arguments (passed as array via ArgumentList to handle quoting automatically)
    $argList = Get-FasterWhisperArgumentList `
        -InputFile $Request.InputFile `
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
    $workingDir = Split-Path -Path $Request.InputFile -Parent
    if ([string]::IsNullOrWhiteSpace($workingDir)) {
        $workingDir = [System.Environment]::CurrentDirectory
    }
    $startInfo.WorkingDirectory = $workingDir

    $run.StartInfo = $startInfo
    return $run
}
