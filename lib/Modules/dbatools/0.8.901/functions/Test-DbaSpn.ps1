﻿Function Test-DbaSpn
{
<#
.SYNOPSIS 
Test-DbaSpn will determine what SPNs *should* be set for a given server (and any instances of SQL running on it) and return
whether the SPNs are set or not.

.DESCRIPTION
This function is designed to take in a server name(s) and attempt to determine required SPNs. It was initially written to mimic the (previously)
broken functionality of the Microsoft Kerberos Configuration manager and SQL Server 2016. The functon will connect to a remote server and,
through WMI, discover all running intances of SQL Server. For any instances with TCP/IP enabled, the script will determine which port(s)
the instances are listening on and generate the required SPNs. For named instances NOT using dynamic ports, the script will generate a port-
based SPN for those instances as well.  At a minimum, the script will test a base, port-less SPN for each instance discovered.

Once the required SPNs are generated, the script will connect to Active Directory and search for any of the SPNs (if any) that are already
set.

The function will return a custom object(s) that contains the server name checked, the instance name discovered, the account the service is
running under, and what the "required" SPN should be. It will also return a boolean property indicating if the SPN is set in Active Directory
or not.

.PARAMETER ComputerName
The server name you want to discover any SQL Server instances on. This parameter is required.

.PARAMETER Credential
The credential you want to use to connect to the remote server and active directory. This parameter is required.

.PARAMETER Domain
If your server resides on a different domain than what your current session is authenticated against, you can specify a domain here. This
parameter is optional.

.NOTES
Tags: SQLWMI, SPN
Author: Drew Furgiuele (@pittfurg), http://www.port1433.com

dbatools PowerShell module (https://dbatools.io, clemaire@gmail.com)

Copyright (C) 2016 Chrissy LeMaire
This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.

.LINK
https://dbatools.io/Test-DbaSpn

.EXAMPLE   
Test-DbaSpn -ComputerName SQLSERVERA -Credential (Get-Credential)

Connects to a computer (SQLSERVERA) and queries WMI for all SQL instances and return "required" SPNs. It will then take each SPN it generates
and query Active Directory to make sure the SPNs are set.

.EXAMPLE   
Test-DbaSpn -ComputerName SQLSERVERA,SQLSERVERB -Credential (Get-Credential)

Connects to multiple computers (SQLSERVERA, SQLSERVERB) and queries WMI for all SQL instances and return "required" SPNs. 
It will then take each SPN it generates and query Active Directory to make sure the SPNs are set.

.EXAMPLE
Test-DbaSpn -ComputerName SQLSERVERC -Domain domain.something -Credential (Get-Credential)

Connects to a computer (SQLSERVERC) on a specified and queries WMI for all SQL instances and return "required" SPNs. 
It will then take each SPN it generates and query Active Directory to make sure the SPNs are set. Note that the credential you pass must
have be a valid login with appropriate rights on the domain you specify

#>
	[cmdletbinding()]
	param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[string[]]$ComputerName,
		[Parameter(Mandatory = $false)]
		[PSCredential]$Credential,
		[Parameter(Mandatory = $false)]
		[string]$Domain
	)
	
	process
	{
		foreach ($computer in $computername)
		{
			try
			{
				$resolved = Resolve-DbaNetworkName -ComputerName $computer -Credential $Credential -ErrorAction Stop
			}
			catch
			{
				$resolved = Resolve-DbaNetworkName -ComputerName $computer -Turbo
			}
			
			$ipaddr = $resolved.IPAddress
			$hostentry = $resolved.DNSHostEntry
			
			if (!$domain)
			{
				$domain = $resolved.domain
				if ($computer -notmatch "\.")
				{
					$computer = $resolved.DNSHostEntry
				}
			}
			else
			{
				if ($computer -notmatch "\.")
				{
					if ($computer -match "\\")
					{
						$computer = $computer.Split("\")[0]
						
					}
					$computer = "$computer.$domain"
				}
			}
			
			Write-Verbose "Resolved ComputerName to FQDN: $computer"
			
			$Scriptblock = {
				
				Function Convert-SqlVersion
				{
					param (
						[version]$version
					)
					
					switch ($version.Major)
					{
						9 { "SQL Server 2005" }
						10 {
							if ($version.Minor -eq 0)
							{
								"SQL Server 2008"
							}
							else
							{
								"SQL Server 2008 R2"
							}
						}
						11 { "SQL Server 2012" }
						12 { "SQL Server 2014" }
						13 { "SQL Server 2016" }
						14 { "SQL Server vNext" }
						default { $version }
					}
				}
				
				$spns = @()
				$servername = $args[0]
				$hostentry = $args[1]
				$domain = $args[2]
				$instancecount = $wmi.ServerInstances.Count
				Write-Verbose "Found $instancecount instances"
				
				foreach ($instance in $wmi.ServerInstances)
				{
					$spn = [pscustomobject] @{
						ComputerName = $servername
						InstanceName = $null
						SqlProduct = $null #SKUNAME
						InstanceServiceAccount = $null
						RequiredSPN = $null
						IsSet = $false
						Cluster = $false
						TcpEnabled = $false
						Port = $null
						DynamicPort = $false
						Warning = "None"
						Error = "None"
						Credential = $Credential # for piping
					}
					
					$spn.InstanceName = $instance.name
					$InstanceName = $spn.InstanceName
					
					Write-Verbose "Parsing $InstanceName"
					
					$services = $wmi.services | Where-Object DisplayName -eq "SQL Server ($InstanceName)"
					$spn.InstanceServiceAccount = $services.ServiceAccount
					$spn.Cluster = ($services.advancedproperties | Where-Object Name -eq 'Clustered').Value
					
					if ($spn.Cluster)
					{
						$hostentry = ($services.advancedproperties | Where-Object Name -eq 'VSNAME').Value.ToLower()
						Write-Verbose "Found cluster $hostentry"
						$hostentry = ([System.Net.Dns]::GetHostEntry($hostentry)).HostName
						$spn.ComputerName = $hostentry
					}
					
					$rawversion = [version]($services.advancedproperties | Where-Object Name -eq 'VERSION').Value #13.1.4001.0
					
					$version = Convert-SqlVersion $rawversion
					$skuname = ($services.advancedproperties | Where-Object Name -eq 'SKUNAME').Value
					
					$spn.SqlProduct = "$version $skuname"
					
					#is tcp enabled on this instance? If not, we don't need an spn, son
					if ((($instance.serverprotocols | Where-Object { $_.Displayname -eq "TCP/IP" }).ProtocolProperties | Where-Object { $_.Name -eq "Enabled" }).Value -eq $true)
					{
						Write-Verbose "TCP is enabled, gathering SPN requirements"
						$spn.TcpEnabled = $true
						#Each instance has a default SPN of MSSQLSvc\<fqdn> or MSSSQLSvc\<fqdn>:Instance    
						if ($instance.Name -eq "MSSQLSERVER")
						{
							$spn.RequiredSPN = "MSSQLSvc/$hostentry"
						}
						else
						{
							$spn.RequiredSPN = "MSSQLSvc/" + $hostentry + ":" + $instance.name
						}
					}
					
					$spns += $spn
				}
				# Now, for each spn, do we need a port set? Only if TCP is enabled and NOT DYNAMIC!
				ForEach ($spn in $spns)
				{
					$ports = @()
					
					$ips = (($wmi.ServerInstances | Where-Object { $_.name -eq $spn.InstanceName }).ServerProtocols | Where-Object { $_.DisplayName -eq "TCP/IP" -and $_.IsEnabled -eq "True" }).IpAddresses
					$ipAllPort = $null
					ForEach ($ip in $ips)
					{
						if ($ip.Name -eq "IPAll")
						{
							$ipAllPort = ($ip.IPAddressProperties | Where-Object { $_.Name -eq "TCPPort" }).Value
							if (($ip.IpAddressProperties | Where-Object { $_.Name -eq "TcpDynamicPorts" }).Value -ne "")
							{
								$ipAllPort = ($ip.IPAddressProperties | Where-Object { $_.Name -eq "TcpDynamicPorts" }).Value + "d"
							}
							
						}
						else
						{
							$enabled = ($ip.IPAddressProperties | Where-Object { $_.Name -eq "Enabled" }).Value
							$active = ($ip.IPAddressProperties | Where-Object { $_.Name -eq "Active" }).Value
							$TcpDynamicPorts = ($ip.IPAddressProperties | Where-Object { $_.Name -eq "TcpDynamicPorts" }).Value
							if ($enabled -and $active -and $TcpDynamicPorts -eq "")
							{
								$ports += ($ip.IPAddressProperties | Where-Object { $_.Name -eq "TCPPort" }).Value
							}
							elseif ($enabled -and $active -and $TcpDynamicPorts -ne "")
							{
								$ports += $ipAllPort + "d"
							}
						}
					}
					if ($ipAllPort -ne "")
					{
						#IPAll overrides any set ports. Not sure why that's the way it is?
						$ports = $ipAllPort
					}
					
					$ports = $ports | Select-Object -Unique
					ForEach ($port in $ports)
					{
						$newspn = $spn.PSObject.Copy()
						if ($port -like "*d")
						{
							$newspn.Port = ($port.replace("d", ""))
							$newspn.RequiredSPN = $newspn.RequiredSPN.Replace($newSPN.InstanceName, $newspn.Port)
							$newspn.DynamicPort = $true
							$newspn.Warning = "Dynamic port is enabled"
						}
						else
						{
							#If this is a named instance, replace the instance name with a port number (for non-dynamic ported named instances)
							$newspn.Port = $port
							$newspn.DynamicPort = $false

							if ($newspn.InstanceName -eq "MSSQLSERVER") {
								$newspn.RequiredSPN = $newspn.RequiredSPN + ":" + $port
							} else {
								$newspn.RequiredSPN = $newspn.RequiredSPN.Replace($newSPN.InstanceName, $newspn.Port)
							}

						}
						
						$spns += $newspn
					}
				}
				$spns
			}
			
			Write-Verbose "Attempting to connect to SQL WMI on remote computer"
			if ($Credential)
			{
				try
				{
					$spns = Invoke-ManagedComputerCommand -ComputerName $ipaddr -ScriptBlock $Scriptblock -ArgumentList $computer, $hostentry, $domain -Credential $Credential -ErrorAction Stop
				}
				catch
				{
					Write-Verbose "Couldn't connect to $ipaddr with credential. Using without credentials."
					$spns = Invoke-ManagedComputerCommand -ComputerName $ipaddr -ScriptBlock $Scriptblock -ArgumentList $computer, $hostentry, $domain
				}
			}
			else
			{
				$spns = Invoke-ManagedComputerCommand -ComputerName $ipaddr -ScriptBlock $Scriptblock -ArgumentList $computer, $hostentry, $domain
			}
			
			
			#Now query AD for each required SPN
			ForEach ($spn in $spns)
			{
				$DN = "DC=" + $domain -Replace ("\.", ',DC=')
				$LDAP = "LDAP://$DN"
				$root = [ADSI]$LDAP
				$ADObject = New-Object System.DirectoryServices.DirectorySearcher
				$ADObject.SearchRoot = $root
				
				$serviceAccount = $spn.InstanceServiceAccount
				
				if ($serviceaccount -like "*\*")
				{
					Write-Debug "Account provided in in domain\user format. Stripping domain values."
					$serviceaccount = ($serviceaccount.split("\"))[1]
				}
				if ($serviceaccount -like "*@*")
				{
					Write-Debug "Account provided in in user@domain format. Stripping domain values."
					$serviceaccount = ($serviceaccount.split("@"))[0]
				}
				
				$ADObject.Filter = $("(&(samAccountName={0}))" -f $serviceaccount)
				
				try
				{
					$results = $ADObject.FindAll()
				}
				catch
				{
					Write-Warning "AD lookup failure. This may be because the hostname ($computer) was not resolvable within the domain ($domain) or the SQL Server service account ($serviceaccount) couldn't be found in domain."
					continue
				}
				
				if ($results.Count -gt 0)
				{
					if ($results.Properties.serviceprincipalname -contains $spn.RequiredSPN)
					{
						$spn.IsSet = $true
					}
				}
				
				if (!$spn.IsSet -and $spn.TcpEnabled)
				{
					$spn.Error = "SPN missing"
				}
				
				$spn | Select-DefaultView -ExcludeProperty Credential, DomainName
			}
		}
	}
}
