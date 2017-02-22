function Remove-UserProxy { 
	<# 
		.Synopsis 
            Remove Proxy Configuration 
		.DESCRIPTION 

		.NOTES 
            Version: 1.0
            Author: Mathieu ALLEGRET
            Creation Date: 02/06/2016
            Purpose/Change: Initial script development

		.EXAMPLE 
            Get-Proxy
        
	#>

    [CmdletBinding()] 
    Param () 
 
    Begin {

        # Set VerbosePreference to Continue so that verbose messages are displayed. 
        $VerbosePreference = 'Continue'
        $regKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    } 
    
    Process {
        
        $ProxyInfo = Get-ItemProperty -Path $regkey
        
        if ($ProxyInfo.AutoConfigURL) {
            Write-Verbose "PROXY CONFIG : $($ProxyInfo.AutoConfigURL)"
            Remove-ItemProperty -Path $regkey -Name AutoConfigURL -force
             if ($ProxyInfo.ProxyServer) {
                Remove-ItemProperty -Path $regkey -Name ProxyServer -force -EA 0
                Set-ItemProperty -Path $regkey -Name ProxyEnable -Value 0
            }
        }
        elseif ($ProxyInfo.ProxyEnable -eq 1) {
             Write-Verbose "PROXY CONFIG : $($ProxyInfo.ProxyServer)"
             Remove-ItemProperty -Path $regkey -Name ProxyServer -force -EA 0
             Set-ItemProperty -Path $regkey -Name ProxyEnable -Value 0
             Set-ItemProperty -Path $regkey -Name ProxyOverride -Value $(($ProxyInfo.ProxyOverride).replace(";<local>",""))
        }
        else {
            Write-host "Proxy Not enable"
       }
    } 
    
    End {} 
    
}
