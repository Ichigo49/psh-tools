function Start-ADReplication {
	<# 
		.Synopsis 
            Force an ActiveDirectory replication on all Domain Controller
		.DESCRIPTION 

		.NOTES 
		   Created by: Mathieu ALLEGRET
		   Creation Initial : 23/11/2017

		.PARAMETER Mode
			Replication mode : Normal or Extra
				Normal (default) : /syncall = Synchronizes a specified domain controller with all replication partners.
					/A = Synchronizes domain controllers across all sites in the enterprise.
					/e = By default, this command does not synchronize domain controllers in other sites.
					/q = Runs in quiet mode, which suppresses call back messages.
				Extra : /kcc = Forces the Knowledge Consistency Checker (KCC) on targeted domain controllers to immediately recalculate the inbound replication topology.

		.EXAMPLE 
            Start-ADReplication

		.EXAMPLE 
            Start-ADReplication -Mode Extra

	#>

	[CmdletBinding(SupportsShouldProcess)]
	param(
	    [ValidateSet("Extra","Normal")]
	    [string]$Mode = 'Normal'
	)
	
	Begin {
		
		if (-not $PSBoundParameters.ContainsKey('Confirm')) {
            $ConfirmPreference = $PSCmdlet.SessionState.PSVariable.GetValue('ConfirmPreference')
        }
        if (-not $PSBoundParameters.ContainsKey('WhatIf')) {
            $WhatIfPreference = $PSCmdlet.SessionState.PSVariable.GetValue('WhatIfPreference')
        }
	
		Import-Module activedirectory
	}
	
	Process {
		
		ForEach ($DC in (Get-ADDomainController -Filter *).Name) {
			if ($pscmdlet.ShouldProcess($Mode)) {
				If ($Mode -eq "Extra") { 
					REPADMIN /kcc $DC
				}
				REPADMIN /syncall /A /e /q $DC
			}
		}
	}
	
	End {}
}