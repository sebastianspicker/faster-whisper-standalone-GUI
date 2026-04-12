function Get-ConfigStringOrDefault {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [object]$Object,

        [Parameter(Mandatory)]
        [string]$PropertyName,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$DefaultValue,

        [Parameter()]
        [switch]$AllowEmpty
    )

    $property = $Object.PSObject.Properties[$PropertyName]
    if (-not $property) { return $DefaultValue }

    if ($null -eq $property.Value) { return $DefaultValue }

    $value = [string]$property.Value
    if ($AllowEmpty) { return $value }
    if ([string]::IsNullOrWhiteSpace($value)) { return $DefaultValue }

    return $value
}
