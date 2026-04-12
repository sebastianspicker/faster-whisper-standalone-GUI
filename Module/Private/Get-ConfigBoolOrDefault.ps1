function Get-ConfigBoolOrDefault {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [object]$Object,

        [Parameter(Mandatory)]
        [string]$PropertyName,

        [Parameter(Mandatory)]
        [bool]$DefaultValue
    )

    $property = $Object.PSObject.Properties[$PropertyName]
    if (-not $property -or $null -eq $property.Value) { return $DefaultValue }

    try {
        $value = $property.Value
        # JSON may supply string "true"/"false"; [bool]"false" is $true in PowerShell, so parse explicitly
        if ($value -is [string]) {
            $s = $value.Trim().ToLowerInvariant()
            if ($s -eq 'true') { return $true }
            if ($s -eq 'false') { return $false }
        }
        return [bool]$value
    }
    catch {
        return $DefaultValue
    }
}
