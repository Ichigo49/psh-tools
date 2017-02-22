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
        
        $ProxyInfo = Get-ItemProperty $regkey
        
        if ($ProxyInfo.AutoConfigURL) {
            $AutoConf = $ProxyInfo.AutoConfigURL
            $obj = "" | Select AutoConfig
            $obj.AutoConfig = $AutoConf
        }
        elseif ($ProxyInfo.ProxyEnable -eq 1) {
                $obj = "" | Select ProxyName,ProxyPort,ProxyEnable,ByPassList
                $obj.ProxyName = ($ProxyInfo.ProxyServer).split(":")[0]
                $obj.ProxyPort = ($ProxyInfo.ProxyServer).split(":")[1]
                $obj.ProxyEnable = "Yes"
                $obj.ByPassList = $ProxyInfo.ProxyOverride
        }
        else {
                $obj = "" | Select ProxyEnable
                $obj.ProxyEnable = "No"
        }
    } 
    
    End {
        return $obj
    } 
    
}
