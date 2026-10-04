<#
.SYNOPSIS
    Loads the GUI configuration from a JSON file, falling back to defaults.

.DESCRIPTION
    Reads the JSON file at ConfigPath. A missing, empty or invalid file yields the default
    configuration. Enum-like values (Device, Model, OutputFormat, Task) are lower-cased and
    replaced by the default when not in the option catalog. BestOf, BeamSize, Patience and
    Temperature are clamped to the ranges of the option catalog (not quantized). A blank
    ExecutablePath is replaced by the default.

.PARAMETER ConfigPath
    Path of the JSON config file. The file does not have to exist.

.OUTPUTS
    System.Management.Automation.PSCustomObject with the 13 configuration keys.

.EXAMPLE
    $config = Get-FasterWhisperGuiConfig -ConfigPath .\run_faster_whisper_xxl.config.json
#>
function Get-FasterWhisperGuiConfig {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath
    )

    $defaults = Get-FasterWhisperGuiDefaultConfig
    $catalog = Get-FasterWhisperOptionCatalog

    $parsed = $null
    if (Test-Path -LiteralPath $ConfigPath) {
        $parsed = Get-JsonObjectFromFile -Path $ConfigPath
    }

    # Missing or invalid JSON: an empty object makes every key fall back to its default below.
    if (-not $parsed) { $parsed = [pscustomobject]@{} }

    $device = (Get-ConfigStringOrDefault -Object $parsed -PropertyName 'Device' -DefaultValue $defaults.Device).ToLowerInvariant()
    $model = (Get-ConfigStringOrDefault -Object $parsed -PropertyName 'Model' -DefaultValue $defaults.Model).ToLowerInvariant()
    $outputFormat = (Get-ConfigStringOrDefault -Object $parsed -PropertyName 'OutputFormat' -DefaultValue $defaults.OutputFormat).ToLowerInvariant()
    $task = (Get-ConfigStringOrDefault -Object $parsed -PropertyName 'Task' -DefaultValue $defaults.Task).ToLowerInvariant()

    if (-not ($catalog.Devices -contains $device)) { $device = $defaults.Device }
    if (-not ($catalog.Models -contains $model)) { $model = $defaults.Model }
    if (-not ($catalog.Formats -contains $outputFormat)) { $outputFormat = $defaults.OutputFormat }
    if (-not ($catalog.Tasks -contains $task)) { $task = $defaults.Task }

    $bestOf = Get-ConfigNumberOrDefault -Object $parsed -PropertyName 'BestOf' -DefaultValue $defaults.BestOf -CastTo 'int'
    $beamSize = Get-ConfigNumberOrDefault -Object $parsed -PropertyName 'BeamSize' -DefaultValue $defaults.BeamSize -CastTo 'int'
    $patience = Get-ConfigNumberOrDefault -Object $parsed -PropertyName 'Patience' -DefaultValue $defaults.Patience -CastTo 'double'
    $temperature = Get-ConfigNumberOrDefault -Object $parsed -PropertyName 'Temperature' -DefaultValue $defaults.Temperature -CastTo 'double'
    if ([double]::IsNaN($patience)) { $patience = $defaults.Patience }
    if ([double]::IsNaN($temperature)) { $temperature = $defaults.Temperature }

    return [pscustomobject]@{
        ExecutablePath = Get-ConfigStringOrDefault -Object $parsed -PropertyName 'ExecutablePath' -DefaultValue $defaults.ExecutablePath
        Device = $device
        Language = Get-ConfigStringOrDefault -Object $parsed -PropertyName 'Language' -DefaultValue $defaults.Language -AllowEmpty
        Model = $model
        OutputFormat = $outputFormat
        Task = $task
        BestOf = [int][Math]::Clamp($bestOf, [int]$catalog.BestOf.Minimum, [int]$catalog.BestOf.Maximum)
        BeamSize = [int][Math]::Clamp($beamSize, [int]$catalog.BeamSize.Minimum, [int]$catalog.BeamSize.Maximum)
        Patience = [double][Math]::Clamp($patience, [double]$catalog.Patience.Minimum, [double]$catalog.Patience.Maximum)
        Temperature = [double][Math]::Clamp($temperature, [double]$catalog.Temperature.Minimum, [double]$catalog.Temperature.Maximum)
        PlayConfirmationSound = Get-ConfigBoolOrDefault -Object $parsed -PropertyName 'PlayConfirmationSound' -DefaultValue $defaults.PlayConfirmationSound
        ShowCliProgress = Get-ConfigBoolOrDefault -Object $parsed -PropertyName 'ShowCliProgress' -DefaultValue $defaults.ShowCliProgress
        UseInputDirectoryAsOutput = Get-ConfigBoolOrDefault -Object $parsed -PropertyName 'UseInputDirectoryAsOutput' -DefaultValue $defaults.UseInputDirectoryAsOutput
    }
}
