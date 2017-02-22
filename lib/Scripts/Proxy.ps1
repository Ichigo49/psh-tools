# Requires -Version 3.0            
            
Function Clear-WinHTTPproxy {            
[CmdletBinding()]            
Param()            
Begin {            
    # Make sure we run as admin                        
    $usercontext = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()                        
    $IsAdmin = $usercontext.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")                                           
    if (-not($IsAdmin))                        
    {                        
        Write-Warning "Must run powerShell as Administrator to perform these actions"                        
        break            
    }            
    $head = 40,0,0,0,0,0,0,0,1,0,0,0            
    $none = 0,0,0,0,0,0,0,0            
}            
Process {            
    $HT = @{            
        Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Connections";            
        Name = "WinHttpSettings";            
        PropertyType = "Binary";            
        Value = ($head+$none);            
        Force = $true;            
        ErrorAction = "Stop";            
    }            
    try{             
        New-ItemProperty @HT | Out-Null            
    } catch {            
        Write-Warning -Message "Failed to set proxy because $($_.Exception.Message)"            
    }            
    Get-WinHttpProxy            
}             
End {}            
}            
            
Function Get-WinHttpProxy {            
[CmdletBinding()]            
Param()            
Begin{}            
Process {            
   $binval = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Connections" -Name WinHttpSettings).WinHttPSettings            
   $proxylength = $binval[12]            
   if ($proxylength -gt 0) {            
       $proxy = -join ($binval[(12+3+1)..(12+3+1+$proxylength-1)] | % {([char]$_)})            
       $bypasslength = $binval[(12+3+1+$proxylength)]            
       if ($bypasslength -gt 0) {            
            $bypasslist = -join ($binval[(12+3+1+$proxylength+3+1)..(12+3+1+$proxylength+3+1+$bypasslength)] | % {([char]$_)})            
        } else {            
            $bypasslist = '(none)'            
        }            
       "Current WinHTTP proxy settings:`n"            
       '    Proxy Server(s): {0}' -f $proxy            
       '    Bypass List    : {0}' -f $bypasslist            
    } else {            
        @'
Current WinHTTP proxy settings:

    Direct access (no proxy server).
'@            
    }            
}            
End{}            
}            

Function Set-WinHttpProxy {            
[cmdletbinding()]            
Param(            
[Parameter(mandatory)][system.string]$proxyserver=$null,            
[System.String]$bypasslist=$null            
)            
Begin{            
    # Make sure we run as admin                        
    $usercontext = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()                        
    $IsAdmin = $usercontext.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")                                           
    if (-not($IsAdmin))                        
    {                        
        Write-Warning "Must run powerShell as Administrator to perform these actions"                        
        break            
    }            
}            
Process {            
    # Define 3 arrays            
    $proxylength = $proxyserver.Length,0,0,0            
    $bypasslength = $bypasslist.Length,0,0,0            
    $head = 40,0,0,0,0,0,0,0,3,0,0,0            
    $HT = @{            
        Path  = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Connections";            
        Name = "WinHttpSettings";            
        PropertyType = "Binary";            
        Value  = ($head+$proxylength+$proxyserver.ToCharArray()+$bypasslength+$bypasslist.ToCharArray())             
        Force = $true;            
        ErrorAction = "Stop";            
    }            
    try {            
        New-ItemProperty @HT | Out-Null            
    } catch {            
        Write-Warning -Message "Failed to set proxy because $($_.Exception.Message)"            
    }            
    Get-WinHttpProxy            
}            
End {}            
}
