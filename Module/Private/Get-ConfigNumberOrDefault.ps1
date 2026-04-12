function Get-ConfigNumberOrDefault {
    [CmdletBinding()]
    [OutputType([int], [double])]
    param(
        [Parameter(Mandatory)]
        [object]$Object,

        [Parameter(Mandatory)]
        [string]$PropertyName,

        [Parameter(Mandatory)]
        [object]$DefaultValue,

        [Parameter(Mandatory)]
        [ValidateSet('int', 'double')]
        [string]$CastTo
    )

    $property = $Object.PSObject.Properties[$PropertyName]
    if (-not $property -or $null -eq $property.Value) { return $DefaultValue }

    try {
        if ($CastTo -eq 'int') { return [int]$property.Value }
        if ($CastTo -eq 'double') { return [double]$property.Value }
        return $DefaultValue
    }
    catch {
        return $DefaultValue
    }
}
