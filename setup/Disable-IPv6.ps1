<#
	.SYNOPSIS
		Manage IPv6 activation
		
	.DESCRIPTION
        Enable or disable IPv6
    
    .PARAMETER IPv6State
        Desired State of IPv6, multiple value possible :
            DisableAll          : Disable IPv6 on nontunnel interfaces (except the loopback) and on IPv6 tunnel interface
            DisableAllNonTunnel : Disable IPv6 on all nontunnel interfaces
            DisableAllTunnel    : Disable IPv6 on all tunnel interfaces
            preferIPv4          : Prefer IPv4 over IPv6 in prefix policies
            preferIPv6          : Prefer IPv6 over IPv4 in prefix policies
            EnableAll           : Re-enable IPv6 on nontunnel interfaces and on IPv6 tunnel interfaces
            EnableAllNonTunnel  : Re-enable IPv6 on all nontunnel interfaces
            EnableAllTunnel     : Re-enable IPv6 on all tunnel interfaces

	.EXAMPLE
		.\Set-IPv6.ps1 -IPv6State DisableAll
	
	.NOTES
		Version			: 1.0
		Author 			: Mathieu ALLEGRET
		Date			: 20/02/2017
        Purpose/Change	: Initial script development
        URL             : https://support.microsoft.com/en-us/help/929852/how-to-disable-ipv6-or-its-components-in-windows
		
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet('DisableAll', 'DisableAllNonTunnel', 'DisableAllTunnel', 'preferIPv4', 'preferIPv6', 'EnableAll', 'EnableAllNonTunnel', 'EnableAllTunnel')]
    $IPv6State
)
function Test-Value {
    param(
        [string]$Path = $(throw "A path must be specified"), 
        [string]$ValueName = $(throw "A value name must be specified") 
    )

    if(Test-Path $path)
    {
        [bool]$ValueFound = $false
        $myKey = Get-item -path $path -Force
        $values = $myKey.GetValueNames()
        foreach($name in $values)
        {
            if($name.ToLower() -eq $ValueName.ToLower())
            {
                $ValueFound = $true
                break
            }
        }
        return $ValueFound
    }
    else
    {
        return $false
    }
}

function Get-RegProperty {
    param(
        [string] $Path = $(throw "No registry path is specified"),
        [string] $Name = $(throw "No value name is specified")
    )

    if(Test-Value -Path $Path -ValueName $Name)
    {
        return (Get-Item $Path).GetValue($Name)
    }
}

function Test-RegProperty {
    param(
        [string] $Path          = $(throw "No registry path is specified"),
        [string] $Name          = $(throw "No property name is specified"),
        [string] $PropertyType  = $null,
        $Value         = $null
    )

    if($Value -is "Array" )
    {
        if($Value.count -eq 0)
        {
            return $false
        }
    }
    if(Test-Path $path)
    {
        [bool]$ValueFound = $false
        $myKey = Get-item -path $path -Force
        $values = $myKey.GetValueNames()

        foreach($valueName in $values)
        {
            if([string]::Compare($valueName, $Name, $true) -eq 0)
            {
                $ValueFound = $true
                $propertyValue = $myKey.GetValue($Name, $null, 'DoNotExpandEnvironmentNames')
                break
            }
        }
        if($ValueFound)
        {
            if($PropertyType)
            {
                # If $PropertyType is speicified check if PropertyType matches
                if((Get-Item -Path $Path).GetValueKind($Name) -eq $PropertyType)
                {
                    # If $Value is specified, check if value matches
                    return ($Value -eq $null) -or (@(compare-object $propertyValue $Value -SyncWindow 0).Count -eq 0)
                }
            }
            else
            {
                return ($Value -eq $null) -or ($propertyValue -eq $Value)
            }
        }
    }
    return $false
}

function Add-RegKey {
    param(
        [string] $Path = $(throw "No registry path is specified")
    )

    if(!(Test-Path $Path))
    {
        New-Item $Path -Force
    }
}

function Set-RegProperty {
    param(
        [string] $Path          = $(throw "No registry path is specified"),
        [string] $Name          = $(throw "No registry property name is specified"),
        [string] $PropertyType  = $(throw "No registry property type is specified. One of the following values is allowed: String | ExpandString | Binary | DWord | MultiString | QWord | Unknown"),
        $Value         = $(throw "No registry property value is specified")
    )

    [void](Add-RegKey $Path)
    if(Test-Value $Path $Name)
    {
        if(Test-RegProperty -Path $Path -Name $Name -Value $Value -PropertyType $PropertyType)
        {
            return
        }
        else
        {
            # Check if they contains the same name property with the same type, if not delete old one and create new.
            if(Test-RegProperty -Path $Path -Name $Name -PropertyType $PropertyType)
            {
                Set-ItemProperty -Path $Path -Name $Name -Value $Value
            }
            else
            {
                # The property has different property type, delete old one
                Remove-ItemProperty -Path $Path -Name $Name
                # Add new with the specified type
                New-ItemProperty -Path $Path -Name $Name -PropertyType $PropertyType -Value $Value
            }
        }
    }
    else
    {
        New-ItemProperty -Path $Path -Name $Name -PropertyType $PropertyType -Value $Value
    }
}

function disableIP {
    if(Test-Value $path $name) {
        Remove-ItemProperty $path $name -Force -ErrorAction SilentlyContinue 
    }
}

function enableIP {
    $dwvalue = 0
    if(Test-Value $path $name) {
        $dwvalue = Get-RegProperty $path $name
    }
    return $dwvalue
}

$path = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters"
$name = "DisabledComponents"


switch ($IPv6State) {

    'DisableAll' {
        disableIP
        $dwvalue = 17
        break
    }
    'DisableAllNonTunnel' {
        disableIP
        $dwvalue = 16
        break
    }

    'DisableAllTunnel' {
        disableIP
        $dwvalue = 1
        break
    }

    'preferIPv4' {
        disableIP
        $dwvalue = 32
        break
    }

    'preferIPv6' {
        $dwvalue = enableIP
        $dwvalue = $dwvalue -band (-bnot 0x20)
        break
    }

    'EnableAll' {
        $dwvalue = enableIP
        $dwvalue = $dwvalue -band (-bnot 0x11)
        break
    }

    'EnableAllNonTunnel'    {
        $dwvalue = enableIP
        $dwvalue = $dwvalue -band (-bnot 0x10)
        break
    }

    'EnableAllTunnel'    {
        $dwvalue = enableIP
        $dwvalue = $dwvalue -band (-bnot 0x01)
        break
    }
    default {throw "error in parameters"}
}

Write-Verbose "Setting value '$dwvalue' in property '$name' of path '$path'"
Set-RegProperty $path $name DWord $dwvalue -Force -ErrorAction SilentlyContinue
