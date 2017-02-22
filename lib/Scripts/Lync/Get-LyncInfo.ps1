<#
.SYNOPSIS  
	Gather Lync deployment environment and configuration information.
.DESCRIPTION  
	Versions
	1.0 - Initial version created to test information gathering and processing steps.
	1.5 - Re-Write to more efficiently gather data in custom PSObject.
	2.1 - Add Visio Diagram Drawing, and better sorting to Word report with proper sections and sub-sections.
	3.0 - Environment data collection sub-routine has been rewritten to gather additional info and change data storage method.
	3.2 - Added certificate sections.
	4.1 - Updated and cleaned up Text User Interface, fixed duplicate SIP domain listings.
	5.0 - Re-Write to clean up code and separate data gathering and report building functions.
	5.1 - All scripts have been updated to use the en-US culture during runtime, this should resolve most if not all localization issues and is reset when the script completes.
			Excel - Added Excel based report for Voice Configuration parameters
			Visio - Removed reference to THEMEVAL theme colors as this seemed to cause failures for non en-US Visio installs when creating the site backgrounds.
			Word - Corrected some spelling mistakes.
	5.2 - Updates
			Visio - Fixed typo on site name on line 512 that was causing problems.
			Word - Voice sections with more than 5 columns will not be included due to formatting issues, instead there will be a reference to the Excel workbook.
				Clean up some table formatting and empty cells.
	5.3 - Updates
			Visio - Removed automated download of Visio stencils as the path has changed. Update path to use new 2012_Stencil_121412.vss file.
			Word - Updated to add support for Word templates.
	5.4 - Updates
			Collector - Updated to better support Standard Edition servers and Skype for Business.
			Word - Updated to properly parse software version tables for Skype for Business.
.LINK  
	http://www.emptymessage.com
.EMAIL
	ccook@emptymessage.com
.EXAMPLE
	.\Get-LyncInfo.ps1 -EdgeCredentials $Credentials
.INPUTS
	None. You cannot pipe objects to this script.
.PARAMETER EdgeCredentials
	A PowerShell variable containing credentials stored with Get-Credential.
#>
param([Parameter(Mandatory = $false)]
      [System.Management.Automation.PSCredential]
      [System.Management.Automation.Credential()]$EdgeCredentials = [System.Management.Automation.PSCredential]::Empty)

$ErrorActionPreference = "ContinueSilenty"


function New-LyncDataObject {
	$global:LyncConfig = New-Object PSObject
}

function New-TimeStamp {
	Add-Member -InputObject $LyncConfig -MemberType NoteProperty -Name TimeStamp -Value ([string](Get-Date))
	Add-Member -InputObject $LyncConfig -MemberType NoteProperty -Name FileTimeStamp -Value ([string](Get-Date -format MMddyyhhmm))
}

function Get-LyncTopologyConfiguration {
	# Get current topology from the CMS.
	Update-Status "Grabbing Lync topology from current environment."
	$global:Topology = Get-CsTopology
	[xml]$global:XmlTopology = Get-CsTopology -AsXml
	$global:arrExternalDnsRecords = @()
	$global:arrInternalDnsRecords = @()
	$global:Sites = @()

	
	# Add a topology property to the $LyncConfig object to store topology data
	Add-Member -InputObject $LyncConfig -MemberType NoteProperty -Name Topology -Value (New-Object PSObject)
	
	# Enumerate sites in the topology and gather data for them.
	foreach ($Site in $Topology.Sites) { $global:Sites += (Get-SiteInfo $Site) }
	Add-Member -InputObject $LyncConfig.Topology -MemberType NoteProperty -Name Sites -Value $global:Sites
}

function Get-SiteInfo ($Site) {
	Update-Status "Found Site: $($Site.Name)"
	
	# Set / Reset variables for data collection in each site.
	$NewSite = New-Object PSObject
	$global:SiteUserCount = 0
	$global:SitePools = $Null
	$global:SitePools = @()
	$global:SiteMachines = $Null
	$global:SiteMachines = @()
	$global:Pool = $Null
	
	# Enumerate pools in the current site. Single machines are considered pools with a single member. (The Lync topology refers to pools as clusters.)
	foreach ($Pool in $Site.Clusters) {$global:SitePools += (Get-PoolInfo $Pool)}
	
	# Get current site Kerberos Account configuration.
	$SiteKerberosConfiguration = Get-SiteKerberosConfiguration $Site.Name
	
	Add-Member -InputObject $NewSite -MemberType NoteProperty -Name Kind -Value ([string]$Site.Kind)
	Add-Member -InputObject $NewSite -MemberType NoteProperty -Name SiteId -Value ([string]$Site.SiteId)
	Add-Member -InputObject $NewSite -MemberType NoteProperty -Name Name -Value ([string]$Site.Name)
	Add-Member -InputObject $NewSite -MemberType NoteProperty -Name Description -Value ([string]$Site.Description)
	Add-Member -InputObject $NewSite -MemberType NoteProperty -Name Machines -Value $global:SiteMachines
	Add-Member -InputObject $NewSite -MemberType NoteProperty -Name Pools -Value $global:SitePools
	Add-Member -InputObject $NewSite -MemberType NoteProperty -Name UserCount -Value $global:SiteUserCount
	Add-Member -InputObject $NewSite -MemberType NoteProperty -Name KerberosConfiguration -Value $SiteKerberosConfiguration
	return $NewSite
}

function Get-PoolRoles ($Pool) {
	$CurrentPoolRoles = $null
	$CurrentPoolRoles = @()
	foreach ($Service in $Pool.InstalledServices){
		if ($Service.IsDirector -eq $True){$CurrentPoolRoles += "Director"}
		if ($Service.RoleId -match "UserServices:?"){$CurrentPoolRoles += "Front-End"}
		if ($Service.RoleId -match "ConfServices:?"){$CurrentPoolRoles += "AV Conferencing"}
		if ($Service.RoleId -match "CentralMgmt:?"){$CurrentPoolRoles += "CMS"}
		if ($Service.RoleId -match "EdgeServer:?"){$CurrentPoolRoles += "Edge"}
		if ($Service.RoleId -match "MonitoringServer:?"){$CurrentPoolRoles += "Monitoring"}
		if ($Service.RoleId -match "ArchivingServer:?"){$CurrentPoolRoles += "Archiving"}
		if ($Service.RoleId -match "ExternalServer:?"){$CurrentPoolRoles += "External Application"}
		if ($Service.RoleId -match "MediationServer:?"){$CurrentPoolRoles += "Mediation"}
		if ($Service.RoleId -match "FileStore:?"){$CurrentPoolRoles += "File Server"}
		if ($Service.RoleId -match "PstnGateway:?"){$CurrentPoolRoles += "PSTN Gateway"}
		if ($Service.RoleId -match "WacService:?"){$CurrentPoolRoles += "Web Application Server"}
	}

if ($Topology.Services | Where {$_.InstalledOn.Cluster -like $Pool.ClusterId}){$CurrentPoolRoles += "SQL Server"}
	
return $CurrentPoolRoles
}

function Get-PoolInfo ($Pool) {
	Update-Status "Found Pool: $($Pool.Fqdn)"
	
	# Set / Reset variables for data collection for each pool.
	$global:NewPool = New-Object PSObject
	$global:SqlInstance = $Null
	$global:FileShare = $Null
	$global:PoolServices = $Null
	$global:PoolServices = @()
	$global:PoolRoles = @()
	$global:PoolMembers = $Null
	$global:PoolMembers = @()
	$global:PoolUserCount = 0
	$CurrentPoolHealthMonitoringConfiguration = $Null

	# Enumerate pool services and gather data.
	$PoolServices = (Get-PoolServices $Pool)
	
	# Enumerate pool services and associate them with Lync server role names.
	$PoolRoles = (Get-PoolRoles $Pool)
	
	# Enumerate pool members and gather data.
	$PoolMembers = (Get-PoolMembers $Pool)

	# If this is a FE Pool, then get number of users homed on the pool.
	if ($PoolRoles -contains "Front-End"){
		$global:PoolUserCount = (Get-CsUser | Where {$_.RegistrarPool -like $Pool.Fqdn}).Count
		Add-Member -InputObject $NewPool -MemberType NoteProperty -Name UserCount -Value $global:PoolUserCount
	}

	# Add Pool FQDN to the list of internal DNS records.
	 $global:arrInternalDnsRecords += $Pool.Fqdn
	
	# If this is a Director or Front-End pool, then grab the web services FQDNs and add them to the DNS records lists. Also get synthetic transaction accounts assigned to the current pool.
	if (($PoolRoles -contains "Front-End") -or ($PoolRoles -contains "Director")){
		$PoolWebServices = $Pool.InstalledServices | Where { $_.RoleId -match "WebServices??"}
		if ($PoolWebServices.InternalHost) {$global:arrInternalDnsRecords += $PoolWebServices.InternalHost.ToString()}
		if ($PoolWebServices.ExternalHost) {$global:arrExternalDnsRecords += $PoolWebServices.ExternalHost.ToString()}
		$CurrentPoolHealthMonitoringConfiguration = Get-PoolHealthMonitoringConfiguration $Pool.Fqdn
		Add-Member -InputObject $NewPool -MemberType NoteProperty -Name MonitoringAccounts -Value $CurrentPoolHealthMonitoringConfiguration
		Add-Member -InputObject $NewPool -MemberType NoteProperty -Name InternalWebFQDN -Value ([string]$PoolWebServices.InternalHost)
		Add-Member -InputObject $NewPool -MemberType NoteProperty -Name ExternalWebFQDN -Value ([string]$PoolWebServices.ExternalHost)
	}
	
	# Check for associated SQL Instances and FileShares, if found the data is stored with other pool details.
	$SqlInstance = Get-AssociatedSqlInstance $Pool $PoolRoles
	$FileShare = Get-AssociatedFileShare $Pool $PoolRoles
	if ($SqlInstance){Add-Member -InputObject $NewPool -MemberType NoteProperty -Name SqlInstances -Value $SqlInstance}
	if ($FileShare){Add-Member -InputObject $NewPool -MemberType NoteProperty -Name FileStore -Value $FileShare}
	
	Add-Member -InputObject $NewPool -MemberType NoteProperty -Name InstalledServices -Value $PoolServices
	Add-Member -InputObject $NewPool -MemberType NoteProperty -Name Roles -Value $PoolRoles
	Add-Member -InputObject $NewPool -MemberType NoteProperty -Name Machines -Value $PoolMembers
	Add-Member -InputObject $NewPool -MemberType NoteProperty -Name FQDN -Value ([string]$Pool.Fqdn)
	Add-Member -InputObject $NewPool -MemberType NoteProperty -Name Identity -Value ([string]$Pool.ClusterId)
	$global:SiteUserCount = $global:SiteUserCount + $global:PoolUserCount
	return $NewPool
}

function Get-PoolServices ($Pool) {
    $PoolServicesList = $null
    $PoolServicesList = @()
	foreach ($Service in $Pool.InstalledServices){
		$NewService = New-Object PSObject
		$Service | GM -MemberType Property | foreach { Add-Member -InputObject $NewService -MemberType NoteProperty -Name $_.Name -Value $Service.$($_.Name)}
		$PoolServicesList += $NewService
	}
return $PoolServicesList
}

function Get-PoolMembers ($Pool) {
	$CurrentPoolMachines = $null
	$CurrentPoolMachines = @()
	foreach ($Machine in $Pool.Machines){

		Update-Status "Found Machine: $($Machine.Fqdn)"
		# Set / Reset variables for data collection for each pool.
		$NewMachine = New-Object PSObject
		$MachineCertificates = $Null
		$MachineCores = $Null
		$MachineRAM = $Null
		$MachineSWVersions = $Null
		$MachineRoles = $PoolRoles
		$MachineIP = $null
		
		$MachineIP = Get-MachineIP $Machine.Fqdn $Pool.Fqdn
		
		# Exclude external application servers, PSTN gateways, Monitoring, Archiving, SQL, and Web Application servers from certificate lookups.
		if (($MachineRoles -notcontains "External Application") -and ($MachineRoles -notcontains "PSTN Gateway") -and ($MachineRoles -notcontains "Web Application Server")){
			$MachineCertificates = Get-MachineCertificates $Machine.Fqdn $MachineRoles $Machine.Cluster
			Add-Member -InputObject $NewMachine -MemberType NoteProperty -Name Certificates -Value $MachineCertificates
		}
		
		# Exclude external application servers, PSTN gateways, and SQL Servers from CPU core count, RAM total, and software version lookups.
		if (($MachineRoles -notcontains "External Application") -and ($MachineRoles -notcontains "PSTN Gateway")-and ($MachineRoles -notcontains "Web Application Server")){
			$MachineCPUCoreCount = Get-MachineCPUCoreCount $Machine.Fqdn $MachineRoles
			$MachineRAM = Get-MachineRAMCount $Machine.Fqdn $MachineRoles
			$MachineSWVersions = Get-MachineSWVersions $Machine.Fqdn $MachineRoles
			Add-Member -InputObject $NewMachine -MemberType NoteProperty -Name CPUCores -Value $MachineCPUCoreCount
			Add-Member -InputObject $NewMachine -MemberType NoteProperty -Name RAM -Value $MachineRAM
			Add-Member -InputObject $NewMachine -MemberType NoteProperty -Name Version -Value $MachineSWVersions
		}

		
		Add-Member -InputObject $NewMachine -MemberType NoteProperty -Name MachineId -Value ([string]$Machine.MachineId)
		Add-Member -InputObject $NewMachine -MemberType NoteProperty -Name PoolId -Value ([string]$Machine.Cluster)
		Add-Member -InputObject $NewMachine -MemberType NoteProperty -Name FQDN -Value ([string]$Machine.Fqdn)
		Add-Member -InputObject $NewMachine -MemberType NoteProperty -Name IPAddress -Value $MachineIP
		Add-Member -InputObject $NewMachine -MemberType NoteProperty -Name Pool -Value ([string]$Pool.Fqdn)
		Add-Member -InputObject $NewMachine -MemberType NoteProperty -Name InstalledServices -Value $PoolServices
		Add-Member -InputObject $NewMachine -MemberType NoteProperty -Name Roles -Value $MachineRoles
		
		# Add machine FQDN to the list of internal DNS records.
		 $global:arrInternalDnsRecords += $Machine.Fqdn

		$CurrentPoolMachines += $NewMachine
		$global:SiteMachines += $NewMachine
	}

return $CurrentPoolMachines
}

function Get-MachineIP ($MachineFqdn, $PoolFqdn) {
	$MachineIP = $Null
	$MachineIP = @{}
	
	Update-Status "Searching for IP address for: $MachineFqdn"
	# Locate the server in the topology XML and pull out the interfaces and IP addresses.
	# Note only edge servers have their IP addresses stored in the topology, all other server roles have their IP addresses listed as 0.0.0.0
	$XmlPool = $global:XmlTopology.Topology.Clusters.Cluster | Where {$_.Fqdn -match $PoolFqdn}
	$XmlMachine = $XmlPool.Machine | Where {$_.Fqdn -match $MachineFqdn}
	foreach ($Interface in $XmlMachine.NetInterface){
		$MachineIP.Add("$($Interface.InterfaceSide)$($Interface.InterfaceNumber)", "$($Interface.IPAddress)")
	}
	
	# Do a quick check to see if the Primary1 IP Address was found, if not then perform a DNS lookup and add it.
	if (!$MachineIP.Primary1){
		$MachineIP.Add = ("Primary1",(([System.Net.Dns]::GetHostEntry($MachineFqdn).AddressList | Where { $_.AddressFamily -like "InterNetwork"}).IPAddressToString))
	}

	# Do a quick check to see if the IP address is reported as 0.0.0.0, if so then do a DNS lookup of the servers FQDN to grab it's actual IP Address.
	if (($MachineIP.Primary1) -and ($MachineIP.Primary1 -match "0.0.0.0")){
		$MachineIP.Primary1 = ([System.Net.Dns]::GetHostEntry($MachineFqdn).AddressList | Where { $_.AddressFamily -like "InterNetwork"}).IPAddressToString
	}

	return $MachineIP
}

function Get-MachineCertificates ($MachineFqdn, $MachineRoles, $MachineCluster) {
	
	Update-Status "Searching for certificates on: $MachineFqdn"
	$MachineCertificates = $Null
	$MachineCertificates = New-Object PSObject
	
	# Edge and WAC servers do not have remote Lync PowerShell capabilities, so we have to use the .NET method for connecting to the remote machine and collecting certificate data.
	if (($MachineRoles -contains "Web Application Server") -or ($MachineRoles -contains "Edge") -or (($MachineRoles -notcontains "Front-End") -and ($MachineRoles -contains "Mediation")) -or (($MachineRoles -notcontains "Front-End") -and ($MachineRoles -contains "AV Conferencing"))){
		# If this is an Edge server we need to map the C$ network share from it locally to provide implicit credentials for certificate store lookups instead of current domain credentials.
		if (($MachineRoles -contains "Edge") -and ($global:EdgeCredentials)){
			# The first line below only works on PowerShell 3.0 so it's commented out for now.
			#New-PSDrive -name EdgeTMP -PSProvider FileSystem -Root \\$MachineFqdn\c$ -Credential $global:EdgeCredentials | Out-Null
			Try
			{
				Net Use \\$MachineFqdn\c$ "$($global:EdgeCredentials.GetNetworkCredential().Password)" /user:"$($global:EdgeCredentials.GetNetworkCredential().Username)" | Out-Null
			}
			Catch
			{
				Update-Status "Unable to connect to Edge server: $MachineFqdn" Warning
			}
		}
		if (($MachineRoles -contains "Edge") -and (!$global:EdgeCredentials)) {
			return
		}
		
		Try
		{
		# Define the certificate stores and configuration options.
		$Certificates = @{}
		$CertUse = $null
		$CertReadOnly = [System.Security.Cryptography.X509Certificates.OpenFlags]"ReadOnly"
		$CertLmStore = [System.Security.Cryptography.X509Certificates.StoreLocation]"LocalMachine"
		$CertStore = New-Object System.Security.Cryptography.X509Certificates.X509Store("\\$MachineFqdn\my",$CertLmStore)
		$CertStore.Open($CertReadOnly)
		
		$CertResults = $Null
		$CertResults = $CertStore.Certificates
		
		if ($MachineRoles -contains "Edge"){
			$MachineEdgeServices = $null
			$MachineEdgeServices = $MachineCluster.InstalledServices | Where {$_.RoleId -like "EdgeServer??"}
			$InternalEdgeFqdn = $MachineEdgeServices.NetPorts | Where {$_.NetPortId -match "AccessEdge.SipServer.Mtls.Internal"} | Select -Expand EffectiveFqdn
			[array]$ExternalEdgeFqdns = $MachineEdgeServices.NetPorts | Where {$_.NetInterfaceId -match "External:"} | Select -Expand EffectiveFqdn
		}
		
		if (($MachineRoles -notcontains "Front-End") -and ($MachineRoles -contains "AV Conferencing")){
			$MachineAVServices = $null
			$MachineAVServices = $MachineCluster.InstalledServices | Where {$_.RoleId -like "ConfServices??"}
			$AvFqdn = $MachineAVServices.NetPorts | Where {$_.NetPortId -match "AVConf.SipServer.Mtls.Primary"} | Select -Expand EffectiveFqdn
		}
		
		if (($MachineRoles -notcontains "Front-End") -and ($MachineRoles -contains "Mediation")){
			$MachineMediationServices = $null
			$MachineMediationServices = $MachineCluster.InstalledServices | Where {$_.RoleId -like "MediationServer??"}
			$MediationFqdn = $MachineMediationServices.NetPorts | Where {$_.NetPortId -match "Mediation.SipServer.Mtls.Primary"} | Select -Expand EffectiveFqdn
		}
		
		# Enumerate certificates on the remote machine store.
		foreach ($Certificate in $CertResults) {
			$CertificateToStore = $Null
			$CertificateToStore = @{}
			$CertAltNames = $Null
			
			# Subject Alternate Names require extra steps to be properly decoded, and also remove the "DNS Name=" prefix from each line.
			$CertSanExtension = $Certificate.Extensions | Where {$_.Oid.FriendlyName -match "subject alternative name"}
			if ($CertSanExtension){
				$CertAltNames = $CertSanExtension.Format(1)
				$CertAltNames = $CertAltNames.Replace("DNS Name=", "")
				$tmpCertAltNames = $CertAltNames.Replace("`r`n", " ")
				$CertAltNames = $tmpCertAltNames.Split(" ")
			}
			
			# Since we're not pulling directly from Lync we don't get the certificate usages. Here we compare the FQDN in the certificate subject to the Edge internal and external FQDNs to determine usage.
			# If neither match, then we don't gather data on this certificate.
			if (($MachineRoles -contains "Edge") -and ($global:EdgeCredentials)){
				$FullSubject = $null
				$SplitSubject = $null
				$ShortSubject = $null
				$FullSubject = $Certificate.Subject
				$SplitSubject = $FullSubject.Split(",")
				$ShortSubject = $SplitSubject[0].Substring(3, ($SplitSubject[0].Length - 3))
				if ($InternalEdgeFqdn -match $ShortSubject){
					$CertUse = "Edge Internal"
				} elseif (($ExternalEdgeFqdns -match $ShortSubject) -or (Compare-Object $ExternalEdgeFqdns $CertAltNames -IncludeEqual | Where {$_.SideIndicator -eq "=="})){
					$CertUse = "Edge External"
				} else {
					continue
				}
			}
			
			# Since we're not pulling directly from Lync we don't get the certificate usages. Here we compare the FQDN in the certificate subject to the pool FQDN to determine usage.
			# If there iss no match, then we don't gather data on this certificate.
			if (($MachineRoles -notcontains "Front-End") -and ($MachineRoles -contains "AV Conferencing")){
				$FullSubject = $null
				$SplitSubject = $null
				$ShortSubject = $null
				$FullSubject = $Certificate.Subject
				$SplitSubject = $FullSubject.Split(",")
				$ShortSubject = $SplitSubject[0].Substring(3, ($SplitSubject[0].Length - 3))
				if ($AvFqdn -match $ShortSubject){
					$CertUse = "Default"
				} else {
					continue
				}
			}
			
			# Since we're not pulling directly from Lync we don't get the certificate usages. Here we compare the FQDN in the certificate subject to the pool FQDN to determine usage.
			# If there iss no match, then we don't gather data on this certificate.
			if (($MachineRoles -notcontains "Front-End") -and ($MachineRoles -contains "Mediation")){
				$FullSubject = $null
				$SplitSubject = $null
				$ShortSubject = $null
				$FullSubject = $Certificate.Subject
				$SplitSubject = $FullSubject.Split(",")
				$ShortSubject = $SplitSubject[0].Substring(3, ($SplitSubject[0].Length - 3))
				if ($MediationFqdn -match $ShortSubject){
					$CertUse = "Default"
				} else {
					continue
				}
			}

			# Store certificate properties.
			$CertificateToStore.Add("Use", "$CertUse")
			$CertificateToStore.Add("SerialNumber", "$($Certificate.SerialNumber)")
			$CertificateToStore.Add("PSComputerName", "$MachineFqdn")
			$CertificateToStore.Add("Thumbprint", "$($Certificate.Thumbprint)")
			$CertificateToStore.Add("Subject", "$($Certificate.Subject)")
			$CertificateToStore.Add("AlternativeNames", "$CertAltNames")
			$CertificateToStore.Add("Issuer", "$($Certificate.Issuer)")
			$CertificateToStore.Add("NotBefore", "$($Certificate.NotBefore)")
			$CertificateToStore.Add("NotAfter", "$($Certificate.NotAfter)")
			
			Add-Member -InputObject $MachineCertificates -MemberType NoteProperty -Name "$($CertUse)" -Value $CertificateToStore
		}
		}
		Catch
		{
			Update-Status "Unable to retrieve certificates from server: $MachineFqdn" Warning
		}
		Try
		{
			# Remove the mapped drive to the Edge server.
			# if (($MachineRoles -contains "Edge") -and ($global:EdgeCredentials)){Remove-PSDrive -name EdgeTMP | Out-Null}
			if (($MachineRoles -contains "Edge") -and ($global:EdgeCredentials)){Net Use /Delete \\$MachineFqdn\c`$ | Out-Null}
		}
		Catch
		{
		}
		
	} else {
		$CertResults = Invoke-Command -ConnectionUri "https://$MachineFqdn/OcsPowershell" -ScriptBlock {Get-CsCertificate | Select-Object *} -Authentication NegotiateWithImplicitCredential -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck)
		foreach ($Certificate in $CertResults){
			$CertificateToStore = $Null
			$CertificateToStore = @{}
			$CertificateToStore.Add("Use", "$($Certificate.Use)")
			$CertificateToStore.Add("SerialNumber", "$($Certificate.SerialNumber)")
			$CertificateToStore.Add("PSComputerName", "$($Certificate.PSComputerName)")
			$CertificateToStore.Add("Thumbprint", "$($Certificate.Thumbprint)")
			$CertificateToStore.Add("Subject", "$($Certificate.Subject)")
			$CertificateToStore.Add("AlternativeNames", "$($Certificate.AlternativeNames)")
			$CertificateToStore.Add("Issuer", "$($Certificate.Issuer)")
			$CertificateToStore.Add("NotBefore", "$($Certificate.NotBefore)")
			$CertificateToStore.Add("NotAfter", "$($Certificate.NotAfter)")
			
			Add-Member -InputObject $MachineCertificates -MemberType NoteProperty -Name "$($CertificateToStore.Use)" -Value $CertificateToStore
		}
	}
	return $MachineCertificates
}

function Get-MachineCPUCoreCount ($MachineFqdn, $MachineRoles) {
	Update-Status "Determining number of CPU cores on: $MachineFqdn"
	# This is the actual WMI query to get the CPU core count.
	$CPUQuery = "Get-WmiObject -Class ""Win32_Processor"" -ComputerName $($MachineFqdn)"
	# If the target is an Edge server and no Edge credentials were supplied, a message is returned that the connection was unsuccessful.
	if ((!$global:EdgeCredentials) -and ($MachineRoles -contains "Edge")){return "Unable to connect to remote system."}
	# If the target is an Edge server we need to append the credentials for it to the command to be run.
	if (($global:EdgeCredentials) -and ($MachineRoles -contains "Edge")){$CPUQuery = "$CPUQuery -Credential `$global:EdgeCredentials"}
	Try
	{
		$CPUWMI = Invoke-Expression $CPUQuery
	}
	Catch
	{
		Update-Status "CPU Core count WMI query failed for machine: $MachineFqdn" Warning
		
	}
	$MachineCPUCoreCount = $CPUWMI.NumberOfCores
	# The below line is for error checking as CPU core count can be reported two different ways, if the first method fails then $CPUCores will be $null then the second method is used.
	if (!$MachineCPUCoreCount){$MachineCPUCoreCount = $CPUWMI.Count}
	# Failing the second method, a message is returned that the connection was unsuccessful.
	if (!$MachineCPUCoreCount){$CPUCores = "Unable to connect to remote system."}
	
	# Some machines report multiple CPUs with multiple cores which don't show as expected. This next section checks for and corrects that.
	if ($MachineCPUCoreCount.Count -gt 1){
		$Sum = $MachineCPUCoreCount -join "+"
		$MachineCPUCoreCount = Invoke-Expression $Sum
	}
	return $MachineCPUCoreCount
}

function Get-MachineRAMCount ($MachineFqdn, $MachineRoles) {
	Update-Status "Finding RAM totals for: $MachineFqdn"
	# This is the actual WMI query to get the total RAM count.
	$RAMQuery = "Get-WmiObject -Class ""Win32_ComputerSystem"" -ComputerName $($MachineFqdn)"
	# If the target is an Edge server and no Edge credentials were supplied, a message is returned that the connection was unsuccessful.
	if ((!$global:EdgeCredentials) -and ($MachineRoles -contains "Edge")){return "Unable to connect to remote system."}
	# If the target is an Edge server we need to append the credentials for it to the command to be run.
	if (($global:EdgeCredentials) -and ($MachineRoles -contains "Edge")){$RAMQuery = "$RAMQuery -Credential `$global:EdgeCredentials"}
	Try
	{
		$RAMWMI = Invoke-Expression $RAMQuery
	}
	Catch
	{
		Update-Status "RAM count WMI query failed for machine: $MachineFqdn" Warning
		
	}
	# The RAM count is returned in bytes, the following line converts the total to MegaBytes.
	$MachineRAM = [string]([math]::round(($RAMWMI.TotalPhysicalMemory) / 1048576)) + " MB"
	# If the query fails, a message is returned that the connection was unsuccessful.
	if (!$MachineRAM){$MachineRAM = "Unable to connect to remote system."}
	return $MachineRAM
}

function Get-MachineSWVersions ($MachineFqdn, $MachineRoles) {
	Update-Status "Building software version table for: $MachineFqdn"
	$MachineSWVersions = @{}
	# This is the actual WMI query to get the list of installed software on the remote machine.
	$VersionQuery = "Get-WmiObject -query 'Select * from Win32_Product' -ComputerName $($Machine.Fqdn)"
	# If the target is an Edge server and no Edge credentials were supplied, a message is returned that the connection was unsuccessful.
	if ((!$global:EdgeCredentials) -and ($MachineRoles -contains "Edge")){return "Unable to connect to remote system."}
	# If the target is an Edge server we need to append the credentials for it to the command to be run.
	if (($global:EdgeCredentials) -and ($MachineRoles -contains "Edge")){$VersionQuery = "$VersionQuery -Credential `$global:EdgeCredentials"}
	Try
	{
		$VersionWMI = Invoke-Expression $VersionQuery
	}
	Catch
	{
		Update-Status "Software version WMI query failed for machine: $MachineFqdn" Warning
		
	}
	# Select only software packages containing "Microsoft Lync Server" in their title.
	$VersionWMI | Where {($_.Name -like "Microsoft Lync Server*") -or ($_.Name -like "Skype*")} | % {$MachineSWVersions.Add([string]$_.Name,[string]$_.Version)}
	# If the query fails, a message is returned that the connection was unsuccessful.
	if (!$MachineSWVersions){$MachineSWVersions = "Unable to connect to remote system."}
	return $MachineSWVersions
}

function Get-SipDomains {
	Update-Status "Enumerating SIP domains in current deployment."
	$SipDomains = @()
	# Grab all SIP domains from the current deployment and also add the SRV, sip, lyncdiscover, and lyncdiscoverinternal DNS records for each SIP domain to the DNS records lists.
	$Topology.InternalDomains | Select * -Unique | foreach {
		$SipDomains += $_.Name
		$global:arrInternalDnsRecords += "sip.$($_.Name)"
		$global:arrInternalDnsRecords += "lyncdiscoverinternal.$($_.Name)"
		$global:arrInternalDnsRecords += "_sipinternaltls._tcp.$($_.Name)"
		$global:arrExternalDnsRecords += "sip.$($_.Name)"
		$global:arrExternalDnsRecords += "lyncdiscover.$($_.Name)"
		$global:arrExternalDnsRecords += "_sip._tls.$($_.Name)"
		$global:arrExternalDnsRecords += "_sipfederationtls._tcp.$($_.Name)"
	}
	Add-Member -InputObject $LyncConfig.Topology -MemberType NoteProperty -Name SipDomains -Value $SipDomains
}

function Get-EdgeFqdns {
	Update-Status "Determing Edge FQDNs for current deployment."
	# Select all Edge services in the topology.
	$EdgeServices = ($Topology.Services | Where {$_.RoleId -like "EdgeServer??"})
	# Select unique internal Fqdns.
	$InternalEdgeFqdns = $EdgeServices.NetPorts | Where {$_.NetInterfaceId -match "Internal:?"} | Select -Expand EffectiveFQDN -Unique
	# Select unique external Fqdns.
	$ExternalEdgeFqdns = $EdgeServices.NetPorts | Where {$_.NetInterfaceId -match "External:?"} | Select -Expand EffectiveFQDN -Unique
	# The next two lines add the DNS records to the internal and external DNS records list.
	foreach ($Record in $InternalEdgeFqdns) {$global:arrInternalDnsRecords += $Record.EffectiveFqdn}
	foreach ($Record in $ExternalEdgeFqdns) {$global:arrExternalDnsRecords += $Record.EffectiveFqdn}
}

function Get-AssociatedSqlInstance ($PoolFqdn, $PoolRoles) {
	$SqlInstance = $null

	if ($PoolRoles -contains "Front-End") {
		# Locate the "UserServices" service on the pool to find the associated "UserStore" service which is the SQL backend.
		$PoolUserServices = $Pool.InstalledServices | Where {$_.ServiceId -like "*UserServices*"}
		
		# Get the user store service from dependent services.
		$PoolUserStoreService = ($PoolUserServices.DependentServices | Where {$_.Service -like "*UserStore*"}).Service
		
		# Find SQL Instance ID from the service in the topology.
		$SQLInstanceId = $PoolUserStoreService.InstalledOn.SqlInstanceId.ToString()
		
		# The SQL Instance ID references the location with it's unique cluster ID, we need to convert this to it's FQDN so its understandable.
		$SqlInstance = $SqlInstanceId.Replace($PoolUserStoreService.InstalledOn.Cluster.ToString(), $PoolUserStoreService.InstalledOn.Cluster.Fqdn)
	}
	
	if ($PoolRoles -contains "Monitoring") {
		# Locate the "MonitoringServer" service on the pool to find the associated "MonitoringStore" service which is the SQL backend.
		$PoolMonitoringServices = $Pool.InstalledServices | Where {$_.ServiceId -like "*MonitoringServer*"}
		
		# Get the monitoring store service from dependent services.
		$PoolMonitoringStoreService = ($PoolMonitoringServices.DependentServices | Where {$_.Service -like "*MonitoringStore*"}).Service
		
		# Find SQL Instance ID from the service in the topology.
		$SQLInstanceId = $PoolMonitoringStoreService.InstalledOn.SqlInstanceId.ToString()
		
		# The SQL Instance ID references the location with it's unique cluster ID, we need to convert this to it's FQDN so its understandable.
		$SqlInstance = $SqlInstanceId.Replace($PoolMonitoringStoreService.InstalledOn.Cluster.ToString(), $PoolMonitoringStoreService.InstalledOn.Cluster.Fqdn)
	}

	if ($PoolRoles -contains "Archiving") {
		# Locate the "ArchivingServer" service on the pool to find the associated "ArchivingStore" service which is the SQL backend.
		$PoolArchivingServices = $Pool.InstalledServices | Where {$_.ServiceId -like "*ArchivingServer*"}
		
		# Get the archiving store service from dependent services.
		$PoolArchivingStoreService = ($PoolArchivingServices.DependentServices | Where {$_.Service -like "*ArchivingStore*"}).Service
		
		# Find SQL Instance ID from the service in the topology.
		$SQLInstanceId = $PoolArchivingStoreService.InstalledOn.SqlInstanceId.ToString()
		
		# The SQL Instance ID references the location with it's unique cluster ID, we need to convert this to it's FQDN so its understandable.
		$SqlInstance = $SqlInstanceId.Replace($PoolArchivingStoreService.InstalledOn.Cluster.ToString(), $PoolArchivingStoreService.InstalledOn.Cluster.Fqdn)
	}
	
	return $SqlInstance
}

function Get-AssociatedFileShare ($Pool, $PoolRoles) {
	$FileShare = $null
	
	if (($PoolRoles -contains "Front-End") -or ($PoolRoles -contains "Director")) {
		# Locate the "WebServices" service on the pool to find the associated file store.
		$PoolWebServices = $Pool.InstalledServices | Where {$_.ServiceId -like "*WebServices*"}
		
		# Get the file store service from dependent services.
		$PoolFileStoreService = ($PoolWebServices.DependentServices | Where {$_.Service -like "*FileStore*"}).Service
		
		# Get the UNC path from the file store service.
		$FileShare = $PoolFileStoreService.UncPath
	}
	
	if ($PoolRoles -contains "Archiving") {
		# Locate the "ArchivingServer" service on the pool to find the associated file store.
		$PoolArchivingServices = $Pool.InstalledServices | Where {$_.ServiceId -like "*ArchivingServer*"}
		
		# Get the file store service from dependent services.
		$PoolFileStoreService = ($PoolArchivingServices.DependentServices | Where {$_.Service -like "*FileStore*"}).Service
		
		# Get the UNC path from the file store service.
		$FileShare = $PoolFileStoreService.UncPath
	}
	return $FileShare
}

function Resolve-DnsRecords {
	$global:InternalDnsRecords = @{}
	$global:ExternalDnsRecords = @{}

	foreach ($DnsRecord in $global:arrInternalDnsRecords | Select -Unique){
		if ($DnsRecord -match "_"){
			$NslResults = $null
			$NslResults = Invoke-Expression "nslookup -type=srv $DnsRecord"
			$DnsRecordTarget = @()
			for ($i = 4; $i -lt $NslResults.Count; $i++){$DnsRecordTarget += ($NslResults[$i].Replace("  ","")).Trim()}
			$InternalDnsRecords.Add($DnsRecord, $DnsRecordTarget)
		} else {
			$IPAddressList = $null
			Try
			{
				$IPAddressList = [System.Net.Dns]::GetHostEntry($DNSRecord).AddressList |  Where { $_.AddressFamily -like "InterNetwork"}
			}
			Catch [System.Exception]
			{
				$IPAddressList = "Record not found."
			}
			
			$InternalDnsRecords.Add($DnsRecord, $IPAddressList)
		}
	}
	
	foreach ($DnsRecord in $global:arrExternalDnsRecords | Select -Unique){
		if ($DnsRecord -match "_"){
			$NslResults = $null
			$NslResults = Invoke-Expression "nslookup -type=srv $DnsRecord 8.8.8.8"
			$DnsRecordTarget = @()
			for ($i = 4; $i -lt $NslResults.Count; $i++){$DnsRecordTarget += ($NslResults[$i].Replace("  ","")).Trim() + "`n"}
			$ExternalDnsRecords.Add($DnsRecord, $DnsRecordTarget)
		} else {
			$NslResults = $null
			$NslResults = Invoke-Expression "nslookup $DnsRecord 8.8.8.8"
			$DnsRecordTarget = @()
			for ($i = 4; $i -lt ($NslResults.Count - 1); $i++){
				$Address = $NslResults[$i].Replace("Addresses:","")
				$Address = $Address.Replace("Address:","")
				$DnsRecordTarget += $Address.Trim()
			}
			$ExternalDnsRecords.Add($DnsRecord, $DnsRecordTarget)
		}
	}
	
	Add-Member -InputObject $LyncConfig.Topology -MemberType NoteProperty -Name InternalDNSRecords -Value $InternalDnsRecords
	Add-Member -InputObject $LyncConfig.Topology -MemberType NoteProperty -Name ExternalDNSRecords -Value $ExternalDnsRecords
}

function Get-TotalUserCount {
	Add-Member -InputObject $LyncConfig.Topology -MemberType NoteProperty -Name TotalUserCount -Value (Get-CsUser).Count
}

function Get-SimpleUrls {
	Update-Status "Enumerating Simple URLs in current deployment."
	$SimpleUrls = @{}
	$AllSimpleUrls = Get-CsSimpleUrlConfiguration | Select -Expand SimpleUrl
	foreach ($SimpleUrl in $AllSimpleUrls){$SimpleUrls.Add("$($SimpleUrl.Component):$($SimpleUrl.Domain)", "$($SimpleUrl.ActiveUrl)")}
	Add-Member -InputObject $LyncConfig.Topology -MemberType NoteProperty -Name SimpleUrls -Value $SimpleUrls
}

function Get-SiteKerberosConfiguration ($SiteName) {
	Update-Status "Getting Kerberos configuration for Site: $SiteName"
	Try
	{
		$SiteKerberosConfiguration = Get-CsKerberosAccountAssignment -Identity "Site:$SiteName" | Select -Expand UserAccount
	}
	Catch
	{
		Update-Status "Unable to find Kerberos configuration for site: $SiteName" Warning
	}
	return $SiteKerberosConfiguration
}
	
function Get-PoolHealthMonitoringConfiguration ($PoolName) {
	Update-Status "Getting Health Monitoring Configuration for Pool: $PoolName"
	$PoolHealthMonitoringConfiguration = $null
	$PoolHealthMonitoringConfiguration = @{}
	$SyntheticAccounts = Get-CsHealthMonitoringConfiguration  | Where {$_.Identity -match $PoolName}
	if ($SyntheticAccounts.FirstTestUserSipUri){
		$PoolHealthMonitoringConfiguration.Add("$($SyntheticAccounts.FirstTestUserSipUri)", "$($SyntheticAccounts.FirstTestSamAccountName)")
	}
	if ($SyntheticAccounts.SecondTestUserSipUri){
		$PoolHealthMonitoringConfiguration.Add("$($SyntheticAccounts.SecondTestUserSipUri)", "$($SyntheticAccounts.SecondTestSamAccountName)")
	}
	return $PoolHealthMonitoringConfiguration
}

function Get-CmsConfiguration {
	$CmsConfiguration = @{}
	
	Update-Status "Finding CMS location."
	# Lync 2013 reports the primary and mirror location for the CMS, while 2010 will only report the primary location. The commands and formatting are different so we version check against the current Lync PowerShell module.
	$LyncModuleVersion = Get-Module Lync | Select -Expand Version
	
	# This section for Lync 2010.
	if ($LyncModuleVersion.Major -le 4){
		$CmsPrimaryLocation = Get-CsConfigurationStoreLocation
		$CmsConfiguration.Add("BackEndServer", "$CmsPrimaryLocation")
	}
	
	# This section for Lync 2013.
	if ($LyncModuleVersion.Major -gt 4){
		$CmsPrimaryLocation = Get-CsConfigurationStoreLocation | Select -Expand BackEndServer
		$CmsMirrorLocation = Get-CsConfigurationStoreLocation | Select -Expand MirrorBackEndServer
		$CmsConfiguration.Add("BackEndServer", "$CmsPrimaryLocation")
		$CmsConfiguration.Add("MirrorBackEndServer", "$CmsMirrorLocation")
	}
	
	Add-Member -InputObject $LyncConfig.Topology -MemberType NoteProperty -Name CmsConfiguration -Value $CmsConfiguration
}

function Get-LyncPolicyConfiguration {
	Update-Status "Gathering Edge, Mobility, and Federation configuration data..."
	$EdgeCmdlets = @{
		"AccessEdgeConfiguration" = "Get-CsAccessEdgeConfiguration"
		"AllowedDomain" = "Get-CsAllowedDomain"
		"BlockedDomain" = "Get-CsBlockedDomain"
		"ExternalAccessPolicy" = "Get-CsExternalAccessPolicy"
		"MobilityPolicy" = "Get-CsMobilityPolicy"
		"McxConfiguration" = "Get-CsMcxConfiguration"
	}
	$EdgeConfig = New-Object PSObject
	foreach ($PSHCmdlet in $EdgeCmdlets.GetEnumerator() | Sort-Object Key) {Add-Member -InputObject $EdgeConfig -MemberType NoteProperty -Name ($PSHCmdlet.Key) -Value (Invoke-Expression ($PSHCmdlet.Value) -EA SilentlyContinue)}
	Add-Member -InputObject $LyncConfig -MemberType NoteProperty -Name ExternalConfig -Value $EdgeConfig

	Update-Status "Gathering Archiving and Monitoring configuration data..."
	$ArchMonCmdlets = @{
		"ArchivingConfiguration" = "Get-CsArchivingConfiguration"
		"ArchivingPolicy" = "Get-CsArchivingPolicy"
		"QoEConfiguration" = "Get-CsQoEConfiguration"
	}
	$ArchMonConfig = New-Object PSObject
	foreach ($PSHCmdlet in $ArchMonCmdlets.GetEnumerator() | Sort-Object Key) {Add-Member -InputObject $ArchMonConfig -MemberType NoteProperty -Name ($PSHCmdlet.Key) -Value (Invoke-Expression ($PSHCmdlet.Value) -EA SilentlyContinue)}
	Add-Member -InputObject $LyncConfig -MemberType NoteProperty -Name ArchivingConfig -Value $ArchMonConfig

	Update-Status "Gathering Call Admission Control configuration data..."
	$CACCmdlets = @{
		"BandwidthPolicyServiceConfiguration" = "Get-CsBandwidthPolicyServiceConfiguration"
		"NetworkBandwidthPolicyProfile" = "Get-CsNetworkBandwidthPolicyProfile"
		"NetworkConfiguration" = "Get-CsNetworkConfiguration"
		"NetworkInterRegionRoute" = "Get-CsNetworkInterRegionRoute"
		"NetworkInterSitePolicy" = "Get-CsNetworkInterSitePolicy"
		"NetworkRegion" = "Get-CsNetworkRegion"
		"NetworkRegionLink" = "Get-CsNetworkRegionLink"
		"NetworkSite" = "Get-CsNetworkSite"
		"NetworkSubnet" = "Get-CsNetworkSubnet"
	}
	$CACConfig = New-Object PSObject
	foreach ($PSHCmdlet in $CACCmdlets.GetEnumerator() | Sort-Object Key) {Add-Member -InputObject $CACConfig -MemberType NoteProperty -Name ($PSHCmdlet.Key) -Value (Invoke-Expression ($PSHCmdlet.Value) -EA SilentlyContinue)}
	Add-Member -InputObject $LyncConfig -MemberType NoteProperty -Name CAC -Value $CACConfig

	Update-Status "Gathering Location Information Service configuration data..."
	$LISCmdlets = @{
		"LisCivicAddress" = "Get-CsLisCivicAddress"
		"LisLocation" = "Get-CsLisLocation"
		"LisPort" = "Get-CsLisPort"
		"LisServiceProvider" = "Get-CsLisServiceProvider"
		"LisSubnet" = "Get-CsLisSubnet"
		"LisSwitch" = "Get-CsLisSwitch"
		"LisWirelessAccessPoint" = "Get-CsLisWirelessAccessPoint"
	}
	$LISConfig = New-Object PSObject
	foreach ($PSHCmdlet in $LISCmdlets.GetEnumerator() | Sort-Object Key) {Add-Member -InputObject $LISConfig -MemberType NoteProperty -Name ($PSHCmdlet.Key) -Value (Invoke-Expression ($PSHCmdlet.Value) -EA SilentlyContinue)}
	Add-Member -InputObject $LyncConfig -MemberType NoteProperty -Name LIS -Value $LISConfig

	Update-Status "Gathering Conferencing configuration data..."
	$ConferencingCmdlets = @{
		"ConferenceDisclaimer" = "Get-CsConferenceDisclaimer"
		"ConferencingConfiguration" = "Get-CsConferencingConfiguration"
		"ConferencingPolicy" = "Get-CsConferencingPolicy"
		"MeetingConfiguration" = "Get-CsMeetingConfiguration"
		"DialinConferencingAccessNumber" = "Get-CsDialinConferencingAccessNumber"
		"DialinConferencingConfiguration" = "Get-CsDialinConferencingConfiguration"
		"DialinConferencingLanguageList" = "Get-CsDialinConferencingLanguageList"
	}
	$ConferencingConfig = New-Object PSObject
	foreach ($PSHCmdlet in $ConferencingCmdlets.GetEnumerator() | Sort-Object Key) {Add-Member -InputObject $ConferencingConfig -MemberType NoteProperty -Name ($PSHCmdlet.Key) -Value (Invoke-Expression ($PSHCmdlet.Value) -EA SilentlyContinue)}
	Add-Member -InputObject $LyncConfig -MemberType NoteProperty -Name Conferencing -Value $ConferencingConfig

	Update-Status "Gathering Enterprise Voice configuration data..."
	$VoiceCmdlets = @{
		"PstnUsage" = "Get-CsPstnUsage"
		"RoutingConfiguration" = "Get-CsRoutingConfiguration"
		"TrunkConfiguration" = "Get-CsTrunkConfiguration"
		"VoiceConfiguration" = "Get-CsVoiceConfiguration"
		"VoiceNormalizationRule" = "Get-CsVoiceNormalizationRule"
		"VoiceRoute" = "Get-CsVoiceRoute"
		"VoicePolicy" = "Get-CsVoicePolicy"
		"PinPolicy" = "Get-CsPinPolicy"
		"CpsConfiguration" = "Get-CsCpsConfiguration"
		"MediaConfiguration" = "Get-CsMediaConfiguration"
		"DialPlan" = "Get-CsDialPlan"
	}
	$VoiceConfig = New-Object PSObject
	foreach ($PSHCmdlet in $VoiceCmdlets.GetEnumerator() | Sort-Object Key) {Add-Member -InputObject $VoiceConfig -MemberType NoteProperty -Name ($PSHCmdlet.Key) -Value (Invoke-Expression ($PSHCmdlet.Value) -EA SilentlyContinue)}
	Add-Member -InputObject $LyncConfig -MemberType NoteProperty -Name Voice -Value $VoiceConfig

	Update-Status "Gathering Response Group configuration data..."
	$RGSCmdlets = @{
		"RgsAgentGroup" = "Get-CsRgsAgentGroup"
		"RgsConfiguration" = "Get-CsService -ApplicationServer | ForEach-Object {Get-CsRgsConfiguration -Identity `$_.Identity}"
		"RgsHolidaySet" = "Get-CsRgsHolidaySet"
		"RgsHoursOfBusiness" = "Get-CsRgsHoursOfBusiness"
		"RgsQueue" = "Get-CsRgsQueue"
		"RgsWorkflow" = "Get-CsRgsWorkflow"
	}
	$RGSConfig = New-Object PSObject
	foreach ($PSHCmdlet in $RGSCmdlets.GetEnumerator() | Sort-Object Key) {Add-Member -InputObject $RGSConfig -MemberType NoteProperty -Name ($PSHCmdlet.Key) -Value (Invoke-Expression ($PSHCmdlet.Value) -EA SilentlyContinue)}
	Add-Member -InputObject $LyncConfig -MemberType NoteProperty -Name RGS -Value $RGSConfig

	Update-Status "Gathering Lync Policy configuration data..."
	$PolicyCmdlets = @{
		"AddressBookConfiguration" = "Get-CsAddressBookConfiguration"
		"ClientPolicy" = "Get-CsClientPolicy"
		"ClientVersionPolicy" = "Get-CsClientVersionPolicy"
		"FileTransferFilterConfiguration" = "Get-CsFileTransferFilterConfiguration"
		"IMFilterConfiguration" = "Get-CsImFilterConfiguration"
		"PresencePolicy" = "Get-CsPresencePolicy"
		"PrivacyConfiguration" = "Get-CsPrivacyConfiguration"
		"HealthMonitoringConfiguration" = "Get-CsHealthMonitoringConfiguration"
	}
	$PolicyConfig = New-Object PSObject
	foreach ($PSHCmdlet in $PolicyCmdlets.GetEnumerator() | Sort-Object Key) {Add-Member -InputObject $PolicyConfig -MemberType NoteProperty -Name ($PSHCmdlet.Key) -Value (Invoke-Expression ($PSHCmdlet.Value) -EA SilentlyContinue)}
	Add-Member -InputObject $LyncConfig -MemberType NoteProperty -Name Policy -Value $PolicyConfig
}

function Export-LyncConfiguration {
	# Get AD domain name.
	$ADDomainName = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
	[string]$LyncADDomainName = $ADDomainName.Name
	
	# Store AD domain name in the configuration.
	Add-Member -InputObject $LyncConfig.Topology -MemberType NoteProperty -Name AdDomain -Value $LyncADDomainName
	
	# Get current path.
	[string]$CurrentPath = Get-Location
	
	# Contruct filename for zip package.
	[string]$ZipFilename = "$CurrentPath\$($LyncADDomainName)Lync_Env_Data-$($LyncConfig.FileTimeStamp).zip"
	Set-Content $ZipFilename ("PK" + [char]5 + [char]6 + ("$([char]0)" * 18))
		(dir $ZipFilename).IsReadOnly = $false
	$ShellApp = New-Object -COM Shell.Application
	$ZipPackage = $ShellApp.NameSpace($ZipFilename)
	$LyncConfig | Export-Clixml -Path "$CurrentPath\$($LyncADDomainName)Lync_Env_Data-$($LyncConfig.FileTimeStamp).xml"
	$ZipPackage.MoveHere("$CurrentPath\$($LyncADDomainName)Lync_Env_Data-$($LyncConfig.FileTimeStamp).xml")

	Update-Status "Finished gathering Lync configuration and policy data. All information is stored in ""$ZipFilename""."
}

function Update-Status ($Status, $MessageType){
	switch ($MessageType) 
    { 
        "Update" {Write-Host -BackgroundColor Black -ForegroundColor Gray "$Status"} 
		"Warning" {Write-Host -BackgroundColor Black -ForegroundColor Yellow "$Status"} 
        "Error" {Write-Host -BackgroundColor Black -ForegroundColor Red "$Status"} 
        default {Write-Host -BackgroundColor Black -ForegroundColor Gray "$Status"}
    }
}

Import-Module Lync

Update-Status "*** Starting Time: $(Get-Date) ***"

if ($EdgeCredentials.UserName){
	$global:EdgeCredentials = $EdgeCredentials
} else {
	Update-Status "No Edge credentials provided at runtime." Warning
	Update-Status "Prompting for Edge credentials." Warning
	$global:EdgeCredentials = $host.ui.PromptForCredential("Edge Credentials", "Please enter Edge server credentials.", "", "Administrator")
	if (!$global:EdgeCredentials){
		$global:EdgeCredentials = $null
		Update-Status "No Edge credentials provided, Edge server data collection will be limited." Warning
	}
}

# Create data storage PSObject ($LyncConfig) for all collected information.
New-LyncDataObject

# Create timestamp for data collection and reports.
New-TimeStamp

# Grab current Lync topology (sites, servers, pools, etc), and add a topology property to the $LyncConfig object to store topology data.
Get-LyncTopologyConfiguration

# Grab Edge server and pool FQDNS and add them to the lists of DNS records.
Get-EdgeFqdns

# Gather SIP domains from current deployment.
Get-SipDomains

# Resolve internal and external DNS records.
Resolve-DnsRecords

# Get total number of users currently activated for Lync.
Get-TotalUserCount

# Get configured simple URLs from the deployment.
Get-SimpleUrls

# Get the current CMS location.
Get-CmsConfiguration

# Get Lync policy configuration from the current environment.
Get-LyncPolicyConfiguration

# Export XML object to file and compress into a zip archive.
Export-LyncConfiguration

Update-Status "*** Finishing Time: $(Get-Date) ***"
