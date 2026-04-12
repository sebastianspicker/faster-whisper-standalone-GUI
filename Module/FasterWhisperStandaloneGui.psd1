@{
    RootModule = 'FasterWhisperStandaloneGui.psm1'
    ModuleVersion = '0.1.0'
    GUID = 'b3d8b7a7-32d5-4e0e-a4f7-52eaa248a12f'
    Author = 'sebastianspicker'
    CompanyName = ''
    Copyright = ''
    PowerShellVersion = '7.0'

    FunctionsToExport = @(
        'Get-FasterWhisperArgumentList',
        'Get-FasterWhisperOutputDirectory',
        'Get-FasterWhisperGuiConfig',
        'Get-FasterWhisperGuiDefaultConfig',
        'Get-FasterWhisperAllowedValueMap',
        'Test-SafeExecutablePath',
        'Test-PathTraversalSafe'
    )

    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @(
        'Get-FasterWhisperAllowedValues'
    )
}
