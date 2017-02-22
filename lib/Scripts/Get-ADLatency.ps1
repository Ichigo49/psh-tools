function Get-ADLatency
{
	Param ($target = (([ADSI]"LDAP://rootDSE").dnshostname),
		$fqdn = (([ADSI]"").distinguishedname -replace "DC=", "" -replace ",", "."),
		$ou = ("cn=users," + ([ADSI]"").distinguishedname),
		$remove = $true,
		[switch]$table
	)
	$context = new-object System.DirectoryServices.ActiveDirectory.DirectoryContext("Domain", $fqdn)
	$dclist = [System.DirectoryServices.ActiveDirectory.DomainController]::findall($context)
	if ($table)
	{
		$DCTable = @()
		$myobj = "" | select Name, Time
		$myobj.Name = ("$target [SOURCE]").ToUpper()
		$myobj.Time = 0.00
		$DCTable += $myobj
	}

	$name = "rTest" + (Get-Date -f MMddyyHHmmss)
	Write-Host "`n  Creating Temp Contact Object [$name] on [$target]"
	$contact = ([ADSI]"LDAP://$target/$ou").Create("contact", "cn=$Name")
	$contact.SetInfo()
	$dn = $contact.distinguishedname
	Write-Host "  Temp Contact Object [$dn] Created! `n"

	$start = Get-Date

	$i = 0

	Write-Host "  Found [$($dclist.count)] Domain Controllers"
	$cont = $true

	While ($cont)
	{
		$i++
		$oldpos = $host.UI.RawUI.CursorPosition
		Write-Host "  =========== Check $i ===========" -fore white
		start-Sleep 1
		$replicated = $true
		foreach ($dc in $dclist)
		{
			if ($target -match $dc.Name) { continue }
			$object = [ADSI]"LDAP://$($dc.Name)/$dn"
			if ($object.name)
			{
				Write-Host "  - $($dc.Name.ToUpper()) Has Object [$dn]" (" " * 5) -fore Green
				if ($table -and !($dctable | ?{ $_.Name -match $dc.Name }))
				{
					$myobj = "" | Select-Object Name, Time
					$myobj.Name = ($dc.Name).ToUpper()
					$myobj.Time = ("{0:n2}" -f ((Get-Date) - $start).TotalSeconds)
					$dctable += $myobj
				}
			}
			else { Write-Host "  ! $($dc.Name.ToUpper()) Missing Object [$dn]" -fore Red; $replicated = $false }
		}
		if ($replicated) { $cont = $false }
		else { $host.UI.RawUI.CursorPosition = $oldpos }
	}

	$end = Get-Date
	$duration = "{0:n2}" -f ($end.Subtract($start).TotalSeconds)
	Write-Host "`n    Took $duration Seconds `n" -fore Yellow

	if ($remove)
	{
		Write-Host "  Removing Test Object `n"
		([ADSI]"LDAP://$target/$ou").Delete("contact", "cn=$Name")
	}
	if ($table)
	{
		$dctable | Sort-Object Time | Format-Table -auto
	}
}
