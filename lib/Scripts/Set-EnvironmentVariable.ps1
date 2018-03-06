function Set-EnvironmentVariable
{
    param
    (
        [string]
        [Parameter(Mandatory)]
        $Name,
 
        [string]
        [AllowEmptyString()]
        [Parameter(Mandatory)]
        $Value,
 
        [System.EnvironmentVariableTarget]
        [Parameter(Mandatory)]
        $Target
    )
 
    [Environment]::SetEnvironmentVariable($Name, $Value, $Target)
}