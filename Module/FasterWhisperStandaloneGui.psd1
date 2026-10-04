@{
    RootModule = 'FasterWhisperStandaloneGui.psm1'
    ModuleVersion = '0.2.0'
    GUID = 'b3d8b7a7-32d5-4e0e-a4f7-52eaa248a12f'
    Author = 'sebastianspicker'
    CompanyName = ''
    Copyright = ''
    PowerShellVersion = '7.0'

    FunctionsToExport = @(
        'Get-FasterWhisperOptionCatalog',
        'Get-FasterWhisperGuiConfig',
        'Initialize-FasterWhisperRun',
        'Invoke-FasterWhisperRun',
        'Complete-FasterWhisperRun'
    )

    CmdletsToExport = @()
    VariablesToExport = @()
}
