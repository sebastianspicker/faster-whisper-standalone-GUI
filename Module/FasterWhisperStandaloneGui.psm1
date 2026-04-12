$ErrorActionPreference = 'Stop'

$publicFunctions = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' -File -ErrorAction SilentlyContinue)
$privateFunctions = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -File -ErrorAction SilentlyContinue)

foreach ($file in @($privateFunctions + $publicFunctions)) {
    . $file.FullName
}

Export-ModuleMember -Function @(
    'Get-FasterWhisperArgumentList',
    'Get-FasterWhisperOutputDirectory',
    'Get-FasterWhisperGuiConfig',
    'Get-FasterWhisperGuiDefaultConfig',
    'Get-FasterWhisperAllowedValueMap',
    'Test-SafeExecutablePath',
    'Test-PathTraversalSafe'
) -Alias @(
    'Get-FasterWhisperAllowedValues'
)
