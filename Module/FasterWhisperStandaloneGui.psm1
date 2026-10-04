$ErrorActionPreference = 'Stop'

$publicFunctions = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' -File -ErrorAction SilentlyContinue)
$privateFunctions = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -File -ErrorAction SilentlyContinue)

# The manifest (FunctionsToExport) is the single export list.
foreach ($file in @($privateFunctions + $publicFunctions)) {
    . $file.FullName
}
