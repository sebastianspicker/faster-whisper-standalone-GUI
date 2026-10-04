function Get-FasterWhisperArgumentList {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [string]$InputFile,

        [Parameter(Mandatory)]
        [string]$Device,

        [Parameter(Mandatory)]
        [string]$Model,

        [Parameter(Mandatory)]
        [string]$OutputDirectory,

        [Parameter(Mandatory)]
        [string]$OutputFormat,

        [Parameter(Mandatory)]
        [string]$Task,

        [Parameter(Mandatory)]
        [int]$BestOf,

        [Parameter(Mandatory)]
        [int]$BeamSize,

        [Parameter(Mandatory)]
        [string]$Patience,

        [Parameter(Mandatory)]
        [string]$Temperature,

        [Parameter()]
        [AllowEmptyString()]
        [string]$Language = '',

        [Parameter(Mandatory)]
        [bool]$PlayConfirmationSound,

        [Parameter(Mandatory)]
        [bool]$ShowCliProgress
    )

    $argList = @(
        $InputFile
        '--device', $Device
    )

    if (-not [string]::IsNullOrWhiteSpace($Language)) {
        $argList += @('--language', $Language)
    }

    $argList += @(
        '--model', $Model
        '--output_dir', $OutputDirectory
        '--output_format', $OutputFormat
        '--task', $Task
        '--best_of', $BestOf
        '--beam_size', $BeamSize
        '--patience', $Patience
        '--temperature', $Temperature
    )

    if (-not $PlayConfirmationSound) { $argList += '--beep_off' }
    if ($ShowCliProgress) { $argList += '--print_progress' }

    return [string[]]$argList
}
