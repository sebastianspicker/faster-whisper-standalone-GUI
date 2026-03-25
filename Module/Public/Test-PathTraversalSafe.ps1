<#
.SYNOPSIS
    Returns whether a path is safe from path traversal (e.g. .. segments).

.DESCRIPTION
    Validates that the path does not contain ".." as a path component,
    which could be used to escape intended directories. Does not resolve
    the path; only checks for suspicious patterns.

.PARAMETER Path
    The file or directory path to check.

.OUTPUTS
    Boolean. $true if the path appears safe (no .. segments), $false otherwise.

.EXAMPLE
    Test-PathTraversalSafe -Path 'C:\Users\me\file.mp3'
    # Returns $true

.EXAMPLE
    Test-PathTraversalSafe -Path 'C:\Users\..\etc\passwd'
    # Returns $false
#>
function Test-PathTraversalSafe {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    # Match ".." as a path segment: at start (..\ or ../), between separators (\..\ /../), or at end
    if ($Path -match '(^|[/\\])\.\.([/\\]|$)') {
        return $false
    }

    return $true
}
