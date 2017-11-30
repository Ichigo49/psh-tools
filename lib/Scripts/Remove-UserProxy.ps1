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
            Remove-UserProxy
        
	#>

    [CmdletBinding(SupportsShouldProcess)] 
    Param () 
 
    Begin {

        $regKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
		if (-not $PSBoundParameters.ContainsKey('Confirm')) {
            $ConfirmPreference = $PSCmdlet.SessionState.PSVariable.GetValue('ConfirmPreference')
        }
        if (-not $PSBoundParameters.ContainsKey('WhatIf')) {
            $WhatIfPreference = $PSCmdlet.SessionState.PSVariable.GetValue('WhatIfPreference')
        }
    } 
    
    Process {
        
        $ProxyInfo = Get-ItemProperty -Path $regkey
        
        if ($ProxyInfo.AutoConfigURL) {
            Write-Verbose "PROXY CONFIG : $($ProxyInfo.AutoConfigURL)"
            if ($pscmdlet.shouldprocess("Are you sure?")) {
				Remove-ItemProperty -Path $regkey -Name AutoConfigURL -force
				if ($ProxyInfo.ProxyServer) {
					Remove-ItemProperty -Path $regkey -Name ProxyServer -force -EA 0
					Set-ItemProperty -Path $regkey -Name ProxyEnable -Value 0
				}
				Write-Verbose "PROXY CONFIG : removed"
			}
        }
        elseif ($ProxyInfo.ProxyEnable -eq 1) {
			Write-Verbose "PROXY CONFIG : $($ProxyInfo.ProxyServer)"
			if ($pscmdlet.shouldprocess("Are you sure?")) { 
				Remove-ItemProperty -Path $regkey -Name ProxyServer -force -EA 0
				Set-ItemProperty -Path $regkey -Name ProxyEnable -Value 0
				Set-ItemProperty -Path $regkey -Name ProxyOverride -Value $(($ProxyInfo.ProxyOverride).replace(";<local>",""))
			}
			Write-Verbose "PROXY CONFIG : removed"
        }
        else {
            Write-verbose "Proxy Not enable"
       }
    } 
    
    End {} 

}
