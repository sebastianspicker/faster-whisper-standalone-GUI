function Get-FasterWhisperGuiDefaultConfig {
    [CmdletBinding()]
    param()

    [pscustomobject]@{
        ExecutablePath = 'faster-whisper-xxl.exe'
        Device = 'cpu'
        Language = ''
        Model = 'base'
        OutputFormat = 'txt'
        Task = 'transcribe'
        BestOf = 3
        BeamSize = 5
        Patience = 1.0
        Temperature = 0.0
        PlayConfirmationSound = $false
        ShowCliProgress = $false
        UseInputDirectoryAsOutput = $true
    }
}
