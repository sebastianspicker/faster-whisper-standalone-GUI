function Get-FasterWhisperGuiConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath,

        [Parameter()]
        [pscustomobject]$DefaultConfig = (Get-FasterWhisperGuiDefaultConfig)
    )

    $parsed = $null
    if (Test-Path -LiteralPath $ConfigPath) {
        $parsed = Get-JsonObjectFromFile -Path $ConfigPath
    }

    if (-not $parsed) {
        return [pscustomobject]@{
            ExecutablePath = $DefaultConfig.ExecutablePath
            Device = $DefaultConfig.Device
            Language = $DefaultConfig.Language
            Model = $DefaultConfig.Model
            OutputFormat = $DefaultConfig.OutputFormat
            Task = $DefaultConfig.Task
            BestOf = $DefaultConfig.BestOf
            BeamSize = $DefaultConfig.BeamSize
            Patience = $DefaultConfig.Patience
            Temperature = $DefaultConfig.Temperature
            PlayConfirmationSound = $DefaultConfig.PlayConfirmationSound
            ShowCliProgress = $DefaultConfig.ShowCliProgress
            UseInputDirectoryAsOutput = $DefaultConfig.UseInputDirectoryAsOutput
        }
    }

    $allowedValues = Get-FasterWhisperAllowedValueMap

    $executablePath = Get-ConfigStringOrDefault -Object $parsed -PropertyName 'ExecutablePath' -DefaultValue $DefaultConfig.ExecutablePath
    $device = Get-ConfigStringOrDefault -Object $parsed -PropertyName 'Device' -DefaultValue $DefaultConfig.Device
    $language = Get-ConfigStringOrDefault -Object $parsed -PropertyName 'Language' -DefaultValue $DefaultConfig.Language -AllowEmpty
    $model = Get-ConfigStringOrDefault -Object $parsed -PropertyName 'Model' -DefaultValue $DefaultConfig.Model
    $outputFormat = Get-ConfigStringOrDefault -Object $parsed -PropertyName 'OutputFormat' -DefaultValue $DefaultConfig.OutputFormat
    $task = Get-ConfigStringOrDefault -Object $parsed -PropertyName 'Task' -DefaultValue $DefaultConfig.Task

    if (-not [string]::IsNullOrWhiteSpace($device)) { $device = $device.ToLowerInvariant() }
    if (-not [string]::IsNullOrWhiteSpace($model)) { $model = $model.ToLowerInvariant() }
    if (-not [string]::IsNullOrWhiteSpace($outputFormat)) { $outputFormat = $outputFormat.ToLowerInvariant() }
    if (-not [string]::IsNullOrWhiteSpace($task)) { $task = $task.ToLowerInvariant() }

    if (-not ($allowedValues.Devices -contains $device)) { $device = $DefaultConfig.Device }
    if (-not ($allowedValues.Models -contains $model)) { $model = $DefaultConfig.Model }
    if (-not ($allowedValues.Formats -contains $outputFormat)) { $outputFormat = $DefaultConfig.OutputFormat }
    if (-not ($allowedValues.Tasks -contains $task)) { $task = $DefaultConfig.Task }

    return [pscustomobject]@{
        ExecutablePath = $executablePath
        Device = $device
        Language = $language
        Model = $model
        OutputFormat = $outputFormat
        Task = $task
        BestOf = Get-ConfigNumberOrDefault -Object $parsed -PropertyName 'BestOf' -DefaultValue $DefaultConfig.BestOf -CastTo 'int'
        BeamSize = Get-ConfigNumberOrDefault -Object $parsed -PropertyName 'BeamSize' -DefaultValue $DefaultConfig.BeamSize -CastTo 'int'
        Patience = Get-ConfigNumberOrDefault -Object $parsed -PropertyName 'Patience' -DefaultValue $DefaultConfig.Patience -CastTo 'double'
        Temperature = Get-ConfigNumberOrDefault -Object $parsed -PropertyName 'Temperature' -DefaultValue $DefaultConfig.Temperature -CastTo 'double'
        PlayConfirmationSound = Get-ConfigBoolOrDefault -Object $parsed -PropertyName 'PlayConfirmationSound' -DefaultValue $DefaultConfig.PlayConfirmationSound
        ShowCliProgress = Get-ConfigBoolOrDefault -Object $parsed -PropertyName 'ShowCliProgress' -DefaultValue $DefaultConfig.ShowCliProgress
        UseInputDirectoryAsOutput = Get-ConfigBoolOrDefault -Object $parsed -PropertyName 'UseInputDirectoryAsOutput' -DefaultValue $DefaultConfig.UseInputDirectoryAsOutput
    }
}
