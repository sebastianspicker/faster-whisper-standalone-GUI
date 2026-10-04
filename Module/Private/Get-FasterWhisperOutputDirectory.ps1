function Get-FasterWhisperOutputDirectory {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$InputFile,

        [Parameter()]
        [AllowEmptyString()]
        [string]$OutputDirectory,

        [Parameter(Mandatory)]
        [bool]$UseInputDirectoryAsOutput
    )

    $resolved = if ($UseInputDirectoryAsOutput -and [System.IO.File]::Exists($InputFile)) {
        [System.IO.Path]::GetDirectoryName($InputFile)
    }
    else {
        $OutputDirectory
    }

    if ([string]::IsNullOrWhiteSpace($resolved)) {
        $resolved = [System.IO.Path]::GetDirectoryName($InputFile)
    }

    # P0: GetDirectoryName('') returns null; ensure caller never gets null
    if ([string]::IsNullOrWhiteSpace($resolved)) {
        $resolved = [System.Environment]::CurrentDirectory
    }

    return $resolved
}
