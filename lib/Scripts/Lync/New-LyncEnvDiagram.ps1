<#
.SYNOPSIS  
	Create Microsoft Visio based diagram of Lync environment from XML datafile.
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
.EXAMPLE
	.\New-LyncEnvDiagram.ps1 -LyncDataFile .\YourLyncDataFile.zip
.INPUTS
	None. You cannot pipe objects to this script.
.PARAMETER LyncDataFile
	The file name of the Lync Data File to be used to create the diagram.
#>
param([Parameter(Mandatory = $false)]
      [string]$LyncDataFile = $null)

$ErrorActionPreference = "Continue"
$OFS = "`r`n"
$OFS = ", "

function Update-Status ($Status, $MessageType){
	switch ($MessageType) 
    { 
        "Update" {Write-Host -BackgroundColor Black -ForegroundColor Gray "$Status"} 
		"Warning" {Write-Host -BackgroundColor Black -ForegroundColor Yellow "$Status"} 
        "Error" {Write-Host -BackgroundColor Black -ForegroundColor Red "$Status"} 
        default {Write-Host -BackgroundColor Black -ForegroundColor Gray "$Status"}
    }
}

function Open-LyncDataFile ($LyncDataFileName) {
	# Check if data file was passed as a commandline option and if it exists; if it does not show the GUI file picker dialog for user to select the Lync Data File.
	Try
		{Test-Path -path "$LyncDataFileName"}
	Catch
		{
		# Notify user that the specified file could not be found and that the "Open File Dialog" will be presented.
		Update-Status "**Unable to locate specified file.**" Error
		Update-Status "Opening file picker for data file selection" Warning
		# Load Windows forms from .Net.
		[void] [Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')
		# Create a new "Open File Dialog" form object.
		$OpenFileDialog = New-Object Windows.Forms.OpenFileDialog
		# Set the file dialog initial directory to the directory where the script was run from.
		$OpenFileDialog.InitialDirectory = Get-Location | Select Path
		# Define filter to only show Zip files.
		$OpenFileDialog.Filter = "Lync Data files (*.zip, *.xml)| *.zip; *.xml"
		# The next line is only used to make sure the "Open File Dialog" does not get hidden behind another window.
		$OpenFileDialog.ShowHelp = $True
		# Show the Dialog window to the user.
		$OpenFileDialog.ShowDialog()
		# Grab the file name for the selected file.
		$LyncDataFileName = [string]$OpenFileDialog.FileName
	}
	
	Try
		{Test-Path -path "$LyncDataFileName" | Out-Null}
	Catch
		{Exit}
	
	[string]$global:CurrentPath = Get-Location
	$LyncDataFile = Get-ChildItem $LyncDataFileName
	$LyncDataFileName = $LyncDataFile.FullName
	
	# If a Zip archive was selected, extract the contents before moving forward.
	if ($LyncDataFileName.EndsWith(".zip")){Extract-LyncDataFile $LyncDataFile}
	
	$global:LyncDataXmlFileName = $LyncDataFileName.Replace("zip", "xml")
	
	Update-Status "Importing Lync data file to $($LyncDataFile.FileName)" Status
	$global:LyncConfig = New-Object PSObject
	$global:LyncConfig = Import-Clixml "$global:LyncDataXmlFileName"
}

function Extract-LyncDataFile ($LyncDataFile) {
	$ShellApp = New-Object -COMObject Shell.Application
	$LyncDataFileZip = $ShellApp.NameSpace("$LyncDataFile")
	$DestinationFolder = $ShellApp.NameSpace("$global:CurrentPath")
	Update-Status "Extracting Lync data file to $global:CurrentPath" Status
	$DestinationFolder.CopyHere($LyncDataFileZip.Items()) | Out-Null
}

function New-VisioDiagram {
	# Set the Visio document filename.
	$global:VisioDocFileName = $global:LyncDataXmlFileName.Replace("xml", "vsd")
	Update-Status "Creating diagram: $($global:VisioDocFileName)" Status
	
	# Create new instance of Microsoft Visio to work with.
	Update-Status "Creating new instance of Visio to work with." Status
	$global:VisioApplication = New-Object -ComObject "Visio.Application"
	
	# Create a new blank document to work with and make the Visio application visible.
	Update-Status "Creating new Visio document." Status
	$global:VisioDocuments = $VisioApplication.Documents
	$global:VisioDocument = $VisioApplication.Documents.Add("NETW_U.VST")
	$global:VisioPages = $VisioApplication.ActiveDocument.Pages
	Update-Status "Adding pages to work with." Status
	$global:VisioPage = $VisioPages.Item(1)
	$global:VisioDocument.PrintLandscape = $true
	$global:VisioPage.AutoSize = $true
	$global:VisioApplication.Visible = $True
	
	Update-Status "Importing stencils." Status
	Import-VisioStencils
	$global:CurrentPage = $global:VisioPages.Item(1)
	
	$CurrentSiteNumber = 0
	$global:CurrentPage = $VisioPages.Item(1)
	foreach ($Site in $global:LyncConfig.Topology.Sites) {
		$CurrentSiteNumber++
		if ($VisioPages.Count -lt $CurrentSiteNumber){$global:CurrentPage = $VisioPages.Add()}
		$CurrentPage.Name = $Site.Name
		New-VisioLyncSite $Site
		Add-VisioLegend
	}
	
	Update-Status "Done creating diagram." Status
	Update-Status "Saving changes." Status
	$global:VisioDocument.SaveAs($VisioDocFileName) | Out-Null
	Update-Status "Done!" Status
}

function Import-VisioStencils {
	[string]$VisioStencilPath = [System.Environment]::GetFolderPath('MyDocuments') + "\My Shapes"
	[string]$LyncStencil = "2012_Stencil_121412.vss"
	$global:colLyncStencils = $VisioApplication.Documents.Add("$VisioStencilPath\$LyncStencil")
	$global:colBasicStencils = $VisioApplication.Documents.Add("BASIC_U.VSS")

	$global:VisioStencils = @{
		'ApplicationServer' = $colLyncStencils.Masters.Item("Application Server")
		'ArchivingServer' = $colLyncStencils.Masters.Item("Lync Server")
		'AVServer' = $colLyncStencils.Masters.Item("Lync Server")
		'DatabaseServer' = $colLyncStencils.Masters.Item("Database Server")
		'Director' = $colLyncStencils.Masters.Item("Lync Director")
		'EdgeServer' = $colLyncStencils.Masters.Item("Lync Edge Server")
		'FEPool' = $colLyncStencils.Masters.Item("Lync Front-End Pool")
		'FEServer' = $colLyncStencils.Masters.Item("Lync Front-End Server")
		'FileStore' = $colLyncStencils.Masters.Item("Folder, Shared")
		'Firewall' = $colLyncStencils.Masters.Item("Firewall")
		'PBX' = $colLyncStencils.Masters.Item("IP-PBX")
		'LoadBalancer' = $colLyncStencils.Masters.Item("Load Balancer")
		'MediationServer' = $colLyncStencils.Masters.Item("Lync Mediation Server")
		'MonitoringServer' = $colLyncStencils.Masters.Item("Lync Monitoring Server")
		'ReverseProxy' = $colLyncStencils.Masters.Item("Reverse Proxy")
		'SBASBS' = $colLyncStencils.Masters.Item("Survivable Branch Server")
		'Server' = $colLyncStencils.Masters.Item("Server, Generic")
		'VoIPGateway' = $colLyncStencils.Masters.Item("VoIP Gateway")
		'RoundRectangle' = $colBasicStencils.Masters.Item("Rounded Rectangle")
		'Rectangle' = $colBasicStencils.Masters.Item("Rectangle")
	}
	
}

function New-VisioLyncSite ($Site) {
	$SiteBgWidth = $null
	
	# Create selection of internal machines.
	$InternalMachines = $Site.Machines | Where {$_.Roles -notcontains "Edge"}
	
	# Create selection of internal pools.
	$InternalPools = $Site.Pools | Where {($_.Machines.Count -gt 1) -and ($_.Roles -notcontains "Edge")}
	
	# Create selection of DMZ machines.
	$DMZMachines = $Site.Machines | Where {$_.Roles -contains "Edge"}

	$SiteBgWidth = $InternalMachines.Count
	$SiteDescription = $null
	$SiteDescription = "$($Site.Name)`r`n$($Site.Description)`r`nUser Count: $($Site.UserCount)"
	
	Add-SiteBG $SiteBgWidth $SiteDescription
	Add-SiteDmzBG $SiteBgWidth
	
	# Set current machine number and add internal machines to the diagram.
	$CurrentMachineNumber = 0
	foreach ($Machine in $InternalMachines){
		Update-Status "Adding internal machine: $($Machine.FQDN)." Status
		$CurrentMachineNumber++
		
		$shpServerType = Get-StencilType $Machine.Roles
		$StencilX = ($global:SiteX + 3.6608) + (($CurrentMachineNumber - 1) * -0.8539)
		$StencilY = ($global:SiteY + 2.7677) + (($CurrentMachineNumber - 1) * 0.4945)

		Add-MachineStencil $Machine $shpServerType $StencilX $StencilY
	}
	
	# Add internal pools to the diagram.
	foreach ($Pool in $InternalPools){
		Update-Status "Adding internal pool: $($Pool.FQDN)." Status
		$shpServerType = Get-StencilType $Pool.Roles
		$PoolMachines = $Pool.Machines | Select -ExpandProperty FQDN
		$PoolX = 0
		$PoolY = 0
		foreach ($MachineName in $PoolMachines){
			$PoolMemberShape = $null
			$PoolMemberShape = $CurrentPage.Shapes | Where {$_.Name -match $MachineName}
			$PoolX = $PoolX + $PoolMemberShape.Cells("PinX").ResultIU
			$PoolY = $PoolY + $PoolMemberShape.Cells("PinY").ResultIU
		}
		
		$PoolX = ($PoolX / $PoolMachines.Count) - 3.2608
		$PoolY = ($PoolY / $PoolMachines.Count) - 2.3677
		
		Add-PoolStencil $Pool $shpServerType $PoolX $PoolY
		
		foreach ($MachineName in $PoolMachines){
			$PoolMemberShape = $CurrentPage.Shapes | Where {$_.Name -match $MachineName}
			$PoolShape = $CurrentPage.Shapes | Where {$_.Name -match $Pool.FQDN}
			#$PoolShape.AutoConnect($PoolMemberShape, 0)
		}
	}


	# Set current machine number and add DMZ machines to the diagram.
	$CurrentDMZMachineNumber = 0
	foreach ($Machine in $DMZMachines){
		Update-Status "Adding DMZ machine: $($Machine.FQDN)." Status
		$CurrentDMZMachineNumber++
		# Set stencil shape to Edge Server
		$shpServerType = $VisioStencils.EdgeServer
		$StencilX = $global:DmzX + (($CurrentDMZMachineNumber - 1) * -0.8539)
		$StencilY = ($global:DmzY + 0.6661) + (($CurrentDMZMachineNumber - 1) * 0.4945)
		Add-MachineStencil $Machine $shpServerType $StencilX $StencilY
	}
	
	# Add Reverse Proxy to the DMZ for each Front-End and Director pool in the site.
	$ReverseProxies = $Site.Pools | Where {$_.Roles -contains "Front-End" -or $_.Roles -contains "Director"}
	foreach ($ReverseProxy in $ReverseProxies){
		Update-Status "Adding Reverse Proxy for Pool: $($ReverseProxy.FQDN)." Status
		$CurrentDMZMachineNumber++
		$StencilX = $global:DmzX + (($CurrentDMZMachineNumber - 1) * -0.8539)
		$StencilY = ($global:DmzY + 0.6661) + (($CurrentDMZMachineNumber - 1) * 0.4945)
		Add-RPStencil $ReverseProxy $StencilX $StencilY
	}
	
	# Connector styling cleanup.
	$Connectors = $CurrentPage.Shapes | Where {$_.Name -match "onnector"}
	foreach ($LineConnector in $Connectors){
		$LineConnector.CellsU("EndArrow") = 5
		$LineConnector.CellsU("LineColorTrans") = .50
		$LineConnector.CellsU("LineWeight").Formula = "2 pt"
		$LineConnector.CellsU("LineColor").Formula = "THEMEGUARD(MSOTINT(THEME(""LineColor""),-25))"
		$LineConnector.CellsU("ShapeRouteStyle").Formula = 14
	}
}

function Get-StencilType ($Roles) {
	# Set default stencil shape to "Server, Generic" and then modify it to fit the role(s) of the server or pool.
	$shpServerType = $VisioStencils.Server
	if (($Roles -contains "File Server") -and ($Roles -notcontains "Front-End")){$ServerRole = "File-Store" ; $shpServerType = $VisioStencils.FileStore}
	if ($Roles -contains "Archiving"){$ServerRole = "Archiving" ; $shpServerType = $VisioStencils.ArchivingServer}
	if (($Roles -contains "AV Conferencing") -and ($Roles -notcontains "Front-End")){$ServerRole = "AV-Conferencing" ; $shpServerType = $VisioStencils.AVServer}
	if ($Roles -contains "Director"){$ServerRole = "Director" ; $shpServerType = $VisioStencils.Director}
	if (($Roles -contains "Mediation") -and ($Roles -notcontains "Front-End")){$ServerRole = "Mediation" ; $shpServerType = $VisioStencils.MediationServer}
	if ($Roles -contains "External Application"){$ServerRole = "External-App Server" ; $shpServerType = $VisioStencils.ApplicationServer}
	if ($Roles -contains "PSTN Gateway"){$ServerRole = "PSTN Gateway" ; $shpServerType = $VisioStencils.VoIPGateway}
	if ($Roles -contains "SQL Server"){$ServerRole = "SQL Server" ; $shpServerType = $VisioStencils.DatabaseServer}
	if ($Roles -contains "Monitoring"){$ServerRole = "Monitoring" ; $shpServerType = $VisioStencils.MonitoringServer}
	if ($Roles -contains "Front-End"){$ServerRole = "Front-End" ; $shpServerType = $VisioStencils.FEServer}
	return $shpServerType
}

function Add-VisioLegend {
	# Build shape for diagram legend and populate with data.
	$EnvironmentName = $global:LyncConfig.Topology.AdDomain
	$TimeStamp = $LyncConfig.TimeStamp

	$LegendText = "Environment: $EnvironmentName`r`nData Gathered: $($LyncConfig.TimeStamp)`r`n`r`nSIP Domains: $($LyncConfig.Topology.SipDomains -join ", ")"
	$shpLegendBG = $CurrentPage.Drop($VisioStencils.RoundRectangle, ($global:SiteX - 7), ($global:SiteY - 1.5))
	$shpLegendBG.Cells("Height").ResultIU = 2
	$shpLegendBG.Cells("Width").ResultIU = 5
	$shpLegendBG.Cells("FillForeGnd").Formula = "RGB(230,230,230)"
	$shpLegendBG.Cells("FillForeGndTrans").ResultIU = 1.0
	$shpLegendBG.Cells("Char.Size").Formula = "16 pt"
	$shpLegendBG.Cells("TextDirection").Formula = 0
	$shpLegendBG.Text = $LegendText
}

function Add-RPStencil ($ReverseProxy, $StencilX, $StencilY) {
	$MachineIPs = $null
	$MachineIPs = @()

	$CurrentStencil = $global:CurrentPage.Drop($VisioStencils.ReverseProxy, $StencilX, $StencilY)
	$CurrentStencil.Name = [string]$ReverseProxy.ExternalWebFQDN
	$CurrentStencil.CellsU("LeftMargin").Formula = "0.1 in."
	$CurrentStencil.CellsU("TxtWidth").ResultIU = "3"
	$CurrentStencil.CellsU("TxtHeight").ResultIU = "1.5"
	$CurrentStencil.CellsU("TxtPinX").ResultIU = "1.1021"
	$CurrentStencil.CellsU("TxtPinY").ResultIU = "0.8361"
	$CurrentStencil.CellsU("TxtLocPinX").ResultIU = "0.6062"
	$CurrentStencil.CellsU("TxtLocPinY").ResultIU = "0.6898"
	$CurrentStencil.CellsU("TxtAngle").Formula = "0 deg"
	$CurrentStencil.CellsU("Char.Size").Formula = "10 pt."
	
	$RPOtherURLS = $null
	$RPOtherURLS = Foreach ($Key in ($LyncConfig.Topology.ExternalDNSRecords.GetEnumerator() | Where-Object {$_.Value -eq $RPIP})){$Key.name}
	$RPIP = $null
	$RPIP = $LyncConfig.Topology.ExternalDNSRecords.Item($($ReverseProxy.ExternalWebFQDN))
	
	$CurrentStencil.AddSection(243) | Out-Null
	$CurrentStencil.AddNamedRow(243,"FQDN",0) | Out-Null
	$CurrentStencil.Cells("Prop.FQDN").Formula = """$([string]$ReverseProxy.ExternalWebFQDN)"""
	$CurrentStencil.AddNamedRow(243,"Pool",0) | Out-Null
	$CurrentStencil.Cells("Prop.Pool").Formula = """$($ReverseProxy.FQDN)"""
	$CurrentStencil.AddNamedRow(243,"IPAddress",0) | Out-Null
	$CurrentStencil.Cells("Prop.IPAddress").Formula = """$($RPIP)"""
	$CurrentStencil.AddNamedRow(243,"OtherURLS",0) | Out-Null
	$CurrentStencil.Cells("Prop.OtherURLS").Formula = """$($RPOtherURLS)"""

	$CurrentStencil.Text = "Reverse Proxy: $($ReverseProxy.ExternalWebFQDN)"
	$CurrentStencil.Cells("Char.Size").Formula = "10 pt"
	$CurrentStencil.Cells("Para.IndLeft").Formula = "0.25 in."
	$CurrentStencil.Cells("Para.HorzAlign").Formula = 0
}

function Add-MachineStencil ($Machine, $Stencil, $StencilX, $StencilY) {
	$MachineIPs = $null
	$MachineIPs = @()

	$CurrentStencil = $global:CurrentPage.Drop($Stencil, $StencilX, $StencilY)
	$CurrentStencil.Name = [string]$Machine.Fqdn
	$CurrentStencil.CellsU("LeftMargin").Formula = "0.1 in."
	$CurrentStencil.CellsU("TxtWidth").ResultIU = "3"
	$CurrentStencil.CellsU("TxtHeight").ResultIU = "1.5"
	$CurrentStencil.CellsU("TxtPinX").ResultIU = "1.1021"
	$CurrentStencil.CellsU("TxtPinY").ResultIU = "0.8361"
	$CurrentStencil.CellsU("TxtLocPinX").ResultIU = "0.6062"
	$CurrentStencil.CellsU("TxtLocPinY").ResultIU = "0.6898"
	$CurrentStencil.CellsU("TxtAngle").Formula = "0 deg"
	$CurrentStencil.CellsU("Char.Size").Formula = "10 pt."
	
	
	$CurrentStencil.AddSection(243) | Out-Null
	$CurrentStencil.AddNamedRow(243,"FQDN",0) | Out-Null
	$CurrentStencil.Cells("Prop.FQDN").Formula = """$([string]$Machine.Fqdn)"""
	$CurrentStencil.AddNamedRow(243,"MachineID",0) | Out-Null
	$CurrentStencil.Cells("Prop.MachineID").Formula = """$($Machine.MachineId)"""
	$CurrentStencil.AddNamedRow(243,"Pool",0) | Out-Null
	$CurrentStencil.Cells("Prop.Pool").Formula = """$($Machine.Pool)"""
	$CurrentStencil.AddNamedRow(243,"CPUCores",0) | Out-Null
	$CurrentStencil.Cells("Prop.CPUCores").Formula = """$($Machine.CPUCores)"""
	$CurrentStencil.AddNamedRow(243,"RAM",0) | Out-Null
	$CurrentStencil.Cells("Prop.RAM").Formula = """$($Machine.RAM)"""
	$CurrentStencil.AddNamedRow(243,"Roles",0) | Out-Null
	$CurrentStencil.Cells("Prop.Roles").Formula = """$($Machine.Roles -join ", ")"""
	
	if ($Machine.IPAddress.Count -gt 1){
		foreach ($Key in $Machine.IPAddress.Keys) {
			$CurrentStencil.AddNamedRow(243,"$([string]$Key)",0) | Out-Null
			if ($($Machine.IPAddress.$Key)) {
				$CurrentStencil.Cells("Prop.$([string]$Key)").Formula = """$($Machine.IPAddress.$Key)"""
			}
		}
	}

	$CurrentStencil.Text = "Server: $($Machine.Fqdn)"
	$CurrentStencil.Cells("Char.Size").Formula = "10 pt"
	$CurrentStencil.Cells("Para.IndLeft").Formula = "0.25 in."
	$CurrentStencil.Cells("Para.HorzAlign").Formula = 0
}

function Add-PoolStencil ($Pool, $Stencil, $StencilX, $StencilY) {
	$PoolIPs = $null
	
	$CurrentStencil = $global:CurrentPage.Drop($Stencil, $StencilX, $StencilY)
	$CurrentStencil.Name = [string]$Pool.Fqdn
	$CurrentStencil.CellsU("LeftMargin").Formula = "0.1 in."
	$CurrentStencil.CellsU("TxtWidth").ResultIU = "3"
	$CurrentStencil.CellsU("TxtHeight").ResultIU = "1.5"
	$CurrentStencil.CellsU("TxtPinX").ResultIU = "1.1021"
	$CurrentStencil.CellsU("TxtPinY").ResultIU = "0.8361"
	$CurrentStencil.CellsU("TxtLocPinX").ResultIU = "0.6062"
	$CurrentStencil.CellsU("TxtLocPinY").ResultIU = "0.6898"
	$CurrentStencil.CellsU("TxtAngle").Formula = "0 deg"
	$CurrentStencil.CellsU("Char.Size").Formula = "10 pt."
	
	$CurrentStencil.AddSection(243) | Out-Null
	$CurrentStencil.AddNamedRow(243,"FQDN",0) | Out-Null
	$CurrentStencil.Cells("Prop.FQDN").Formula = """$([string]$Pool.Fqdn)"""
	$CurrentStencil.AddNamedRow(243,"UniqueID",0) | Out-Null
	$CurrentStencil.Cells("Prop.UniqueID").Formula = """$($Pool.Identity)"""
	$CurrentStencil.AddNamedRow(243,"Members",0) | Out-Null
	$CurrentStencil.Cells("Prop.Members").Formula = """$($Pool.Machines.FQDN)"""
	$CurrentStencil.AddNamedRow(243,"Roles",0) | Out-Null
	$CurrentStencil.Cells("Prop.Roles").Formula = """$($Pool.Roles)"""
	
	if ($Pool.InternalWebFQDN){
		$CurrentStencil.AddNamedRow(243,"InternalWebFQDN",0) | Out-Null
		$CurrentStencil.Cells("Prop.InternalWebFQDN").Formula = """$($Pool.InternalWebFQDN)"""
	}
	if ($Pool.ExternalWebFQDN){
		$CurrentStencil.AddNamedRow(243,"ExternalWebFQDN",0) | Out-Null
		$CurrentStencil.Cells("Prop.ExternalWebFQDN").Formula = """$($Pool.ExternalWebFQDN)"""
	}
	if ($Pool.UserCount){
		$CurrentStencil.AddNamedRow(243,"UserCount",0) | Out-Null
		$CurrentStencil.Cells("Prop.UserCount").Formula = """$($Pool.UserCount)"""
	}
	if ($Pool.SqlInstances){
		$CurrentStencil.AddNamedRow(243,"SqlInstances",0) | Out-Null
		$CurrentStencil.Cells("Prop.SqlInstances").Formula = """$($Pool.SqlInstances)"""
	}
	if ($Pool.FileStore){
		$CurrentStencil.AddNamedRow(243,"FileStore",0) | Out-Null
		$CurrentStencil.Cells("Prop.FileStore").Formula = """$($Pool.FileStore)"""
	}

	$CurrentStencil.Text = "Pool: $($Pool.Fqdn)"
	$CurrentStencil.Cells("Char.Size").Formula = "10 pt"
	$CurrentStencil.Cells("Para.IndLeft").Formula = "0.25 in."
	$CurrentStencil.Cells("Para.HorzAlign").Formula = 0
}

function Add-SiteBG ($SiteWidth, $SiteDescription) {
	Update-Status "Adding internal background for site $($Site.Name)." Status
	$SiteBG = $CurrentPage.Drop($VisioStencils.Rectangle, 0, 0)
	$SiteBG.Cells("Width").Formula = "0.1969 in"
	$SiteBG.Cells("Height").Formula = "0.1969 in"
	$SiteBG.Cells("Rounding").Formula = "0.05 in"
	
	if (($SiteBG.SectionExists(242,1)) -eq 0){$SiteBG.AddSection(242) | Out-Null}
	$SiteBG.AddNamedRow(242,"width", 0) | Out-Null
	$SiteBG.AddNamedRow(242,"depth", 0) | Out-Null
	$SiteBG.AddSection(243) | Out-Null
	$SiteBG.AddNamedRow(243,"width",0) | Out-Null
	$SiteBG.AddNamedRow(243,"depth",0) | Out-Null
	
	$SiteBG.Cells("Prop.width.Type").Formula = 2
	$SiteBG.Cells("Prop.depth.Type").Formula = 2
	$SiteBG.Cells("Prop.width").Formula = "$($SiteWidth) in"
	$SiteBG.Cells("Prop.depth").Formula = "6 in"
	$SiteBG.Cells("User.width").Formula = "Prop.width*(Height/5 mm)"
	$SiteBG.Cells("User.depth").Formula = "Prop.depth*(Width/5 mm)"

	$SiteBG.Cells("Geometry1.X1").Formula = "User.width*0"
	$SiteBG.Cells("Geometry1.Y1").Formula = "User.width*0"

	$SiteBG.RowType(10,2) = 140
	$SiteBG.Cells("Geometry1.X2").Formula = "Geometry1.X1-User.width*COS(30 deg)"
	$SiteBG.Cells("Geometry1.Y2").Formula = "Geometry1.Y1+User.width*SIN(30 deg)"

	$SiteBG.RowType(10,3) = 140
	$SiteBG.Cells("Geometry1.X3").Formula = "Geometry1.X2+User.depth*(COS(30 deg))"
	$SiteBG.Cells("Geometry1.Y3").Formula = "Geometry1.Y2+1*User.depth*SIN(30 deg)"

	$SiteBG.RowType(10,4) = 140
	$SiteBG.Cells("Geometry1.X4").Formula = "Geometry1.X3+User.width*COS(30 deg)"
	$SiteBG.Cells("Geometry1.Y4").Formula = "Geometry1.Y3+-User.width*SIN(30 deg)"

	$SiteBG.RowType(10,5) = 140
	$SiteBG.Cells("Geometry1.X5").Formula = "Geometry1.X1"
	$SiteBG.Cells("Geometry1.Y5").Formula = "Geometry1.Y1"

	$SiteBG.Cells("FillForegnd").Formula = "RGB(255,255,255)"
	$SiteBG.Cells("FillForegndTrans").Formula = "0%"
	$SiteBG.Cells("FillBkgnd").Formula = "RGB(183,221,232)"
	$SiteBG.Cells("FillBkgndTrans").Formula = "0%"
	$SiteBG.Cells("FillPattern").Formula = "40"
	$SiteBG.Cells("ShdwForegnd").Formula = "HSL(144,116,125)"
	$SiteBG.Cells("ShdwForegndTrans").Formula = "0%"
	$SiteBG.Cells("ShdwPattern").Formula = "0"
	$SiteBG.Cells("ShapeShdwOffsetX").Formula = "0 in"
	$SiteBG.Cells("ShapeShdwOffsetY").Formula = "0 in"
	$SiteBG.Cells("ShapeShdwType").Formula = "0"
	$SiteBG.Cells("ShapeShdwObliqueAngle").Formula = "0 deg"
	$SiteBG.Cells("ShapeShdwScaleFactor").Formula = "100%"
	#$SiteBG.Cells("ShapeShdwBlur").Formula = "0 pt"
	#$SiteBG.Cells("ShapeShdwShow").Formula = "0"

	$SiteBG.Cells("LineGradientDir").Formula = "0"
	$SiteBG.Cells("FillGradientAngle").Formula = "30 deg"
	$SiteBG.Cells("RotateGradientWithShape").Formula = "TRUE"
	$SiteBG.Cells("LineGradientAngle").Formula = "90 deg"
	$SiteBG.Cells("LineGradientEnabled").Formula = "FALSE"
	$SiteBG.Cells("UseGroupGradient").Formula = "FALSE"
	$SiteBG.Cells("FillGradientDir").Formula = "3"
	$SiteBG.Cells("FillGradientEnabled").Formula = "True"
	
	$SiteBG.Cells("LineColor").Formula = "RGB(183,221,232)"
	$SiteBG.Cells("LineColorTrans").ResultIU = 0.50
	
	$SiteBG.Section(249).Row(0).Cell(0).Formula = "RGB(255,255,255)"
	$SiteBG.Section(249).Row(0).Cell(1).Formula = "0%"
	$SiteBG.Section(249).Row(0).Cell(2).Formula = "0%"
	$SiteBG.Section(249).Row(1).Cell(0).Formula = "RGB(183,221,232)"
	$SiteBG.Section(249).Row(1).Cell(1).Formula = "0%"
	$SiteBG.Section(249).Row(1).Cell(2).Formula = "100%"
	
	$SiteBG.Cells("Width").Formula = "0.1969 in"
	$SiteBG.Cells("Height").Formula = "0.1969 in"
	$SiteBG.Cells("PinX").Formula = "0"
	$SiteBG.Cells("PinY").Formula = "0"
	$SiteBG.CellsU("TxtWidth").Formula = "Prop.depth"
	$SiteBG.CellsU("TxtPinX").Formula = "0.0000 in"
	$SiteBG.CellsU("TxtPinY").Formula = "-1.000 in"
	$SiteBG.CellsU("TxtAngle").Formula = "30 deg"
	$SiteBG.Cells("TextDirection").Formula = 0
	$SiteBG.Cells("VerticalAlign").Formula = 2
	$SiteBG.Cells("Char.Size").Formula = "14 pt"
	$SiteBG.Cells("LeftMargin").Formula = "240 pt."
	$SiteBG.Text = "$($Site.Name)`r`n$SiteDescription"
	
	$global:SiteX = $SiteBG.Cells("PinX").ResultIU
	$global:SiteY = $SiteBG.Cells("PinY").ResultIU
	Update-Status "Done." Status
}

function Add-SiteDmzBG ($SiteWidth) {
	Update-Status "Adding DMZ background for site $($Site.Name)." Status
	$global:DmzX = $SiteX - 2.5985
	$global:DmzY = $SiteY - 1.5
	
	$DmzBG = $CurrentPage.Drop($VisioStencils.Rectangle, $DmzX, $DmzY)
	$DmzBG.Cells("Width").Formula = "0.1969 in"
	$DmzBG.Cells("Height").Formula = "0.1969 in"
	$DmzBG.Cells("Rounding").Formula = "0.05 in"
	
	if (($DmzBG.SectionExists(242,1)) -eq 0){$DmzBG.AddSection(242) | Out-Null}
	$DmzBG.AddNamedRow(242,"width", 0) | Out-Null
	$DmzBG.AddNamedRow(242,"depth", 0) | Out-Null
	$DmzBG.AddSection(243) | Out-Null
	$DmzBG.AddNamedRow(243,"width",0) | Out-Null
	$DmzBG.AddNamedRow(243,"depth",0) | Out-Null
	$DmzBG.Cells("Prop.width.Type").Formula = 2
	$DmzBG.Cells("Prop.depth.Type").Formula = 2
	$DmzBG.Cells("Prop.width").Formula = "$($SiteWidth) in"
	$DmzBG.Cells("Prop.depth").Formula = "3 in"

	$DmzBG.Cells("User.width").Formula = "Prop.width*(Height/5 mm)"
	$DmzBG.Cells("User.depth").Formula = "Prop.depth*(Width/5 mm)"

	$DmzBG.Cells("Geometry1.X1").Formula = "User.width*0"
	$DmzBG.Cells("Geometry1.Y1").Formula = "User.width*0"

	$DmzBG.RowType(10,2) = 140
	$DmzBG.Cells("Geometry1.X2").Formula = "Geometry1.X1-User.width*COS(30 deg)"
	$DmzBG.Cells("Geometry1.Y2").Formula = "Geometry1.Y1+User.width*SIN(30 deg)"

	$DmzBG.RowType(10,3) = 140
	$DmzBG.Cells("Geometry1.X3").Formula = "Geometry1.X2+User.depth*(COS(30 deg))"
	$DmzBG.Cells("Geometry1.Y3").Formula = "Geometry1.Y2+1*User.depth*SIN(30 deg)"

	$DmzBG.RowType(10,4) = 140
	$DmzBG.Cells("Geometry1.X4").Formula = "Geometry1.X3+User.width*COS(30 deg)"
	$DmzBG.Cells("Geometry1.Y4").Formula = "Geometry1.Y3+-User.width*SIN(30 deg)"

	$DmzBG.RowType(10,5) = 140
	$DmzBG.Cells("Geometry1.X5").Formula = "Geometry1.X1"
	$DmzBG.Cells("Geometry1.Y5").Formula = "Geometry1.Y1"

	$DmzBG.Cells("FillForegnd").Formula = "RGB(255,255,255)"
	$DmzBG.Cells("FillForegndTrans").Formula = "0%"
	$DmzBG.Cells("FillBkgnd").Formula = "RGB(251,215,187)"
	$DmzBG.Cells("FillBkgndTrans").Formula = "0%"
	$DmzBG.Cells("FillPattern").Formula = "40"
	$DmzBG.Cells("ShdwForegnd").Formula = "HSL(17,213,206)"
	$DmzBG.Cells("ShdwForegndTrans").Formula = "0%"
	$DmzBG.Cells("ShdwPattern").Formula = "0"
	$DmzBG.Cells("ShapeShdwOffsetX").Formula = "0 in"
	$DmzBG.Cells("ShapeShdwOffsetY").Formula = "0 in"
	$DmzBG.Cells("ShapeShdwType").Formula = "0"
	$DmzBG.Cells("ShapeShdwObliqueAngle").Formula = "0 deg"
	$DmzBG.Cells("ShapeShdwScaleFactor").Formula = "100%"
	#$DmzBG.Cells("ShapeShdwBlur").Formula = "0 pt"
	#$DmzBG.Cells("ShapeShdwShow").Formula = "0"

	$DmzBG.Cells("LineGradientDir").Formula = "0"
	$DmzBG.Cells("FillGradientAngle").Formula = "30 deg"
	$DmzBG.Cells("RotateGradientWithShape").Formula = "TRUE"
	$DmzBG.Cells("LineGradientAngle").Formula = "90 deg"
	$DmzBG.Cells("LineGradientEnabled").Formula = "FALSE"
	$DmzBG.Cells("UseGroupGradient").Formula = "FALSE"
	$DmzBG.Cells("FillGradientDir").Formula = "3"
	$DmzBG.Cells("FillGradientEnabled").Formula = "True"
	
	$DmzBG.Cells("LineColor").Formula = "RGB(251,215,187)"
	$DmzBG.Cells("LineColorTrans").ResultIU = 0.50
	
	$DmzBG.Section(249).Row(0).Cell(0).Formula = "RGB(255,255,255)"
	$DmzBG.Section(249).Row(0).Cell(1).Formula = "0%"
	$DmzBG.Section(249).Row(0).Cell(2).Formula = "0%"
	$DmzBG.Section(249).Row(1).Cell(0).Formula = "RGB(251,215,187)"
	$DmzBG.Section(249).Row(1).Cell(1).Formula = "0%"
	$DmzBG.Section(249).Row(1).Cell(2).Formula = "100%"
	
	$DmzBG.Cells("Width").Formula = "0.1969 in"
	$DmzBG.Cells("Height").Formula = "0.1969 in"
	$DmzBG.Cells("PinX").Formula = "$DmzX in"
	$DmzBG.Cells("PinY").Formula = "$DmzY in"
	$DmzBG.CellsU("TxtWidth").Formula = "5 in"
	$DmzBG.CellsU("TxtPinX").Formula = "Prop.depth/3"
	$DmzBG.CellsU("TxtPinY").Formula = "0"
	$DmzBG.CellsU("TxtAngle").Formula = "30 deg"
	$DmzBG.Cells("TextDirection").Formula = 0
	$DmzBG.Cells("VerticalAlign").Formula = 2
	$DmzBG.Cells("Char.Size").Formula = "14 pt"
	$DmzBG.Cells("LeftMargin").Formula = "240 pt."
	$DmzBG.Text = "DMZ"
	Update-Status "Done." Status
}

function Set-ModuleStatus { 
	[CmdletBinding(SupportsShouldProcess = $True)]
	param	(
		[parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $true, HelpMessage = "No module name specified!")] 
		[string]$name
	)
	if(!(Get-Module -name "$name")) { 
		if(Get-Module -ListAvailable | ? {$_.name -eq "$name"}) { 
			Import-Module -Name "$name" 
			# module was imported
			return $true
		} else {
			# module was not available
			return $false
		}
	}else {
		# module was already imported
		# Write-Host "$name module already imported"
		return $true
	}
} # end function Set-ModuleStatus

$OldCulture = [System.Threading.Thread]::CurrentThread.CurrentCulture
[System.Threading.Thread]::CurrentThread.CurrentCulture = "en-US"

Open-LyncDataFile $LyncDataFile	
# My Documents folder
$MyShapesPath = [environment]::GetFolderPath([environment+SpecialFolder]::MyDocuments)+"\My Shapes"
Update-Status "*** Starting Time: $(Get-Date) ***"
New-VisioDiagram
Update-Status "*** Finishing Time: $(Get-Date) ***"

[System.Threading.Thread]::CurrentThread.CurrentCulture = $OldCulture