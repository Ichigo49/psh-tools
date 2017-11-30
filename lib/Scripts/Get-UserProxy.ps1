function Get-UserProxy { 
	<# 
		.Synopsis 
            Get Proxy Information 
		.DESCRIPTION 

		.NOTES 
            Version: 1.0
            Author: Mathieu ALLEGRET
            Creation Date: 02/06/2016
            Purpose/Change: Initial script development

		.EXAMPLE 
            Get-UserProxy
        
	#>

    [CmdletBinding()] 
    Param () 
 
    Begin { 

        # Set VerbosePreference to Continue so that verbose messages are displayed. 
        $VerbosePreference = 'Continue'
        $regKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    } 
    
    Process { 
        
        $ProxyInfo = Get-ItemProperty $regkey
        
        if ($ProxyInfo.AutoConfigURL) {
			[PSCustomObject]@{
                AutoConfig = $ProxyInfo.AutoConfigURL
			}
        }
        elseif ($ProxyInfo.ProxyEnable -eq 1) {
			[PSCustomObject]@{
                ProxyName = ($ProxyInfo.ProxyServer).split(":")[0]
                ProxyPort = ($ProxyInfo.ProxyServer).split(":")[1]
                ProxyEnable = "Yes"
                ByPassList = $ProxyInfo.ProxyOverride
			}
        }
        else {
			[PSCustomObject]@{
                ProxyEnable = "No"
			}
        }
    } 
    
    End {} 
    
}
