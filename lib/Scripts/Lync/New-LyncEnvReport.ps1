<#
.SYNOPSIS  
	Create Microsoft Word based report of Lync environment from XML datafile.
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
	.\New-LyncEnvReport.ps1 -LyncDataFile .\YourLyncDataFile.zip
.INPUTS
	None. You cannot pipe objects to this script.
.PARAMETER LyncDataFile
	The file name of the Lync Data File to be used to create the report.
.PARAMETER Template
	The file name of the Word template to be used to create the report.
#>
param(
	[Parameter(Mandatory = $false)]
	[string]$LyncDataFile = $null,
	[Parameter(Mandatory = $false)]
	$Visible = $true,
	[Parameter(Mandatory = $false)]
	$Template
)

$ErrorActionPreference = "Continue"
$OFS = "`r`n"

# Word document template style setting names.
$script:TableStyleName = "Grid Table 4 - Accent 1"
$script:TitleStyleName = "Title"
$script:NormalStyleName = "Normal"
$script:Heading1StyleName = "Heading 1"
$script:Heading2StyleName = "Heading 2"
$script:Heading3StyleName = "Emphasis"
$script:Heading4StyleName = "Strong"



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
	
	[string]$script:CurrentPath = Get-Location
	$LyncDataFile = Get-ChildItem $LyncDataFileName
	$LyncDataFileName = $LyncDataFile.FullName
	
	# If a Zip archive was selected, extract the contents before moving forward.
	if ($LyncDataFileName.EndsWith(".zip")){Extract-LyncDataFile $LyncDataFile}
	
	$script:LyncDataXmlFileName = $LyncDataFileName.Replace("zip", "xml")
	
	Update-Status "Importing Lync data file to $($LyncDataFile.FileName)" Status
	$script:LyncConfig = New-Object PSObject
	$script:LyncConfig = Import-Clixml "$script:LyncDataXmlFileName"
}

function Extract-LyncDataFile ($LyncDataFile) {
	$ShellApp = New-Object -COMObject Shell.Application
	$LyncDataFileZip = $ShellApp.NameSpace("$LyncDataFile")
	$DestinationFolder = $ShellApp.NameSpace("$script:CurrentPath")
	Update-Status "Extracting Lync data file to $script:CurrentPath" Status
	$DestinationFolder.CopyHere($LyncDataFileZip.Items()) | Out-Null
}

function New-WordReport {
	# Set the Word document filename.
	$script:WordDocFileName = $script:LyncDataXmlFileName.Replace("xml", "docx")
	Update-Status "Creating report: $($script:WordDocFileName)" Status
	
	# Create new instance of Microsoft Word to work with.
	Update-Status "Creating new instance of Word to work with."
	$script:WordApplication = New-Object -ComObject "Word.Application"
	# Create a new blank document to work with or open template if one is specified and make the Word application visible.
	if ($DocumentTemplate){
		$script:WordDocument = $WordApplication.Documents.Open("$($DocumentTemplate.FullName)")
	} else {
		$script:WordDocument = $WordApplication.Documents.Add()
	}
	$WordApplication.Visible = $script:WordVisible
	$WordDocument.SaveAs([ref]$WordDocFileName)
	
	# Word refers to the current cursor location as it's selection.
	$script:Selection = $WordApplication.Selection
	
	# Formatting and document navigation commands. These functions must be defined this way as the selection will not exist until runtime.
	New-Item function:global:New-Line -Value {$Selection.TypeParagraph()} | Out-Null
	New-Item function:global:New-PageBreak -Value {$Selection.InsertNewPage()} | Out-Null
	New-Item function:global:MoveTo-End -Value {$Selection.Start = $Selection.StoryLength - 1} | Out-Null
	
	# Create cover page for report.
	New-WordCoverPage
	
	# Create a blank second page that will hold the Table of Contents. The number specifies how many blank pages we want to insert.
	New-WordBlankPage 1
	
	# Create the Topology section of the report.
	New-WordTopologySection
	
	# Create the sections for Policy configurations.
	New-WordPolicySection ExternalConfig
	New-WordPolicySection Voice
	New-WordPolicySection Conferencing
	New-WordPolicySection RGS
	New-WordPolicySection CAC
	New-WordPolicySection LIS
	New-WordPolicySection Policy
	
	# Create Table of Contents for document. The number specifies which page to place the Table of Contents on.
	New-WordTableOfContents 2
	
	Update-Status "Finished creating report, saving changes to document." Status
	$WordDocument.SaveAs([ref]$WordDocFileName)
    $WordApplication.Quit()
	Update-Status "Done." Status
}

function New-WordTableOfContents ($PageNumber) {
	# Go back to the beginning of page two.
	[void]$Selection.GoTo(1, 2, $null, $PageNumber)
	Update-Status "Creating Table of Contents." Status
	New-WordHeading "Table of Contents" $script:Heading1StyleName
	
	# Create Table of Contents for document.
	# Set Range to beginning of document to insert the Table of Contents.
	$TocRange = $Selection.Range
	$useHeadingStyles = $true 
	$upperHeadingLevel = 1 # <-- Heading1 or Title 
	$lowerHeadingLevel = 2 # <-- Heading2 or Subtitle 
	$useFields = $false 
	$tableID = $null 
	$rightAlignPageNumbers = $true 
	$includePageNumbers = $true 
	# to include any other style set in the document add them here 
	$addedStyles = $null 
	$useHyperlinks = $true 
	$hidePageNumbersInWeb = $true 
	$useOutlineLevels = $true 

	# Insert Table of Contents
	$WordTableOfContents = $WordDocument.TablesOfContents.Add($TocRange, $useHeadingStyles, 
	$upperHeadingLevel, $lowerHeadingLevel, $useFields, $tableID, 
	$rightAlignPageNumbers, $includePageNumbers, $addedStyles, 
	$useHyperlinks, $hidePageNumbersInWeb, $useOutlineLevels) 
	$WordTableOfContents.TabLeader = 0	
}

function New-WordPolicySection ($SectionName) {
	Update-Status "Creating $SectionName policy section." Status
	New-WordHeading "$SectionName" $script:Heading1StyleName
	
	$PolicyCmdlets = $script:LyncConfig.($SectionName) | Get-Member -MemberType NoteProperty | Select -Expand Name
	
	foreach ($Policy in $PolicyCmdlets) {
		Update-Status "Creating $Policy policy table." Status
		New-WordHeading "$($Policy -creplace "([a-z])([A-Z])", '$1 $2')" $script:Heading2StyleName
		
		if (($SectionName -match "Voice") -and ($script:LyncConfig.($SectionName).($Policy).Count -gt 10)) {
			$script:Selection.TypeText("Please see detailed Voice documentation in Excel workbook.")
			New-Line
		} else{
			New-WordPolicyTable $script:LyncConfig.($SectionName).($Policy)
		}
	}
	New-PageBreak
}

function New-WordPolicyTable ($Policies) {
	if ($Policies) {
		$PolicyAttributes = $Policies | Get-Member -MemberType Property | Select -Expand Name
		$NumRows = $PolicyAttributes.Count - 1
		$NumCols = ($Policies | measure).Count + 1
		
		$PolicyTable = New-WordTable $NumRows $NumCols $True
		$CurrentColumn = 1
		$CurrentRow = 1
		
		[string]$PolicyTable.Cell($CurrentRow, $CurrentColumn).Range.Text = "Identity"
		$CurrentRow++
		
		foreach ($AttributeName in $PolicyAttributes){
			if (($AttributeName -ne "Identity") -and ($AttributeName -ne "Anchor")){
				[string]$PolicyTable.Cell($CurrentRow, $CurrentColumn).Range.Text = $AttributeName
				$CurrentRow++
			}
		}
	
		# Reset currently selected cell to Row 1, Column 2
		$CurrentRow = 1
		$CurrentColumn = 2
	
		foreach ($Policy in $Policies) {
			# Set first row as Identity value.
			[string]$PolicyTable.Cell($CurrentRow, $CurrentColumn).Range.Text = $Policy.Identity
			$CurrentRow++
			foreach ($AttributeName in $PolicyAttributes){
				if (($AttributeName -ne "Identity") -and ($AttributeName -ne "Anchor")){
					[string]$PolicyTable.Cell($CurrentRow, $CurrentColumn).Range.Text = "$($Policy.($AttributeName))"
					$CurrentRow++
				}
			}
			$CurrentRow = 1
			$CurrentColumn++
		}
	} else {
		$script:Selection.TypeText("No Settings Found")
	}
	$Policies = $null
	MoveTo-End
	New-Line
}

function New-WordHeading ($Label, $Style){
	$Selection.Style = $Style
	$Selection.TypeText($Label)
	$Selection.TypeParagraph()
	$Selection.Style = $script:NormalStyleName
}

function New-WordCoverPage {
	Update-Status "Creating report cover page." Status
	New-Line
	New-Line
	New-Line
	New-Line
	New-Line
	$Selection.Style = $script:TitleStyleName
	$Selection.ParagraphFormat.Alignment = 1
	$Selection.TypeText("Lync Environment Report")
	
	New-Line
	$Selection.ParagraphFormat.Alignment = 1
	$Selection.Font.Size = 24
	$Selection.TypeText($script:LyncConfig.Topology.AdDomain)
	
	New-Line
	$Selection.ParagraphFormat.Alignment = 1
	$Selection.Font.Size = 18
	$Selection.TypeText("Data Gathered: $($LyncConfig.TimeStamp)")
	New-PageBreak
	Update-Status "Done."
}

function New-WordBlankPage ($NumberOfPages) {
	Update-Status "Inserting $NumberOfPages blank pages." Status
	for ($i = 0; $i -lt $NumberOfPages; $i++){
		$Selection.Font.Size = 11
		$Selection.ParagraphFormat.Alignment = 0
		New-PageBreak
	}
	Update-Status "Done."
}

function New-WordTopologySection {
	Update-Status "Creating Topology report section." Status
	New-WordHeading "Topology and Architecture" $script:Heading1StyleName
	New-WordHeading "Deployment Summary" $script:Heading2StyleName
	
	# Create a new table for the deployment summary.
	New-DeploymentSummaryTable
	
	New-WordHeading "Sites" $script:Heading2StyleName
	
	# Enumerate Lync sites and create the report section for each, this includes their pools and machines.
	foreach ($Site in $LyncConfig.Topology.Sites){
		New-WordSiteSection $Site
	}
	
	New-WordDnsTable $script:LyncConfig.Topology.InternalDNSRecords "Internal DNS Records"
	New-WordDnsTable $script:LyncConfig.Topology.ExternalDNSRecords "External DNS Records"
	
	New-WordSipDomainTable
	New-WordSimpleUrlTable
	New-WordCmsConfigTable	
	
	Update-Status "Done creating Topology report section."
}

function New-WordCmsConfigTable {
	Update-Status "Creating CMS configuration table." Status
	New-WordHeading "CMS configuration" $script:Heading2StyleName
	$CmsConfigTable = New-WordTable 2 2 $false
	
	[string]$CmsConfigTable.Cell(1, 1).Range.Text = "CMS Location"
	[string]$CmsConfigTable.Cell(1, 2).Range.Text = $LyncConfig.Topology.CmsConfiguration.BackEndServer
	[string]$CmsConfigTable.Cell(2, 1).Range.Text = "CMS Mirror Location"
	[string]$CmsConfigTable.Cell(2, 2).Range.Text = $LyncConfig.Topology.CmsConfiguration.MirrorBackEndServer

	MoveTo-End
	New-Line
}

function New-WordSimpleUrlTable {
	Update-Status "Creating Simple Url table." Status
	New-WordHeading "Simple Urls" $script:Heading2StyleName
	$SimpleUrlTable = New-WordTable $script:LyncConfig.Topology.SimpleUrls.Count 2 $false
	
	$i = 1
	foreach ($Record in $script:LyncConfig.Topology.SimpleUrls.GetEnumerator()){
		[string]$SimpleUrlTable.Cell($i, 1).Range.Text = $Record.Name
		[string]$SimpleUrlTable.Cell($i, 2).Range.Text = $Record.Value
		$i++
	}
	MoveTo-End
	New-Line
}

function New-WordDnsTable ($DnsRecords, $TableName) {
	Update-Status "Creating $TableName table." Status
	New-WordHeading $TableName $script:Heading2StyleName
	$DnsTable = New-WordTable $DnsRecords.Count 2 $false
	
	$i = 1
	foreach ($Record in $DnsRecords.GetEnumerator()){
		[string]$DnsTable.Cell($i, 1).Range.Text = $Record.Name
		[string]$DnsTable.Cell($i, 2).Range.Text = $Record.Value
		$i++
	}
	MoveTo-End
	New-Line
}

function New-WordSipDomainTable {
	Update-Status "Creating SIP Domain(s) table." Status
	New-WordHeading "SIP Domains" $script:Heading2StyleName
	$SipDomainTable = New-WordTable $LyncConfig.Topology.SipDomains.Count 1 $false
	
	$i = 1
	foreach ($SipDomain in $LyncConfig.Topology.SipDomains){
		[string]$SipDomainTable.Cell($i, 1).Range.Text = "$SipDomain"
		$i++
	}
	MoveTo-End
	New-Line
}

function New-DeploymentSummaryTable {
	# The first number specifys how many rows while the second specifies how many columns are in the table.
	$DeploymentSummaryTable = New-WordTable 5 2 $true
	
	[string]$DeploymentSummaryTable.Cell(1, 1).Range.Text = "Total Sites"
	[string]$DeploymentSummaryTable.Cell(1, 2).Range.Text = $LyncConfig.Topology.Sites.Count
	
	[string]$DeploymentSummaryTable.Cell(2, 1).Range.Text = "Total Pools"
	foreach ($Site in $LyncConfig.Topology.Sites){[int]$PoolCount = $PoolCount + ($Site.Pools | Where {$_.Machines.Count -gt 1} | Measure).Count}
	[string]$DeploymentSummaryTable.Cell(2, 2).Range.Text = $PoolCount
	
	[string]$DeploymentSummaryTable.Cell(3, 1).Range.Text = "Total Machines"
	foreach ($Site in $LyncConfig.Topology.Sites){$MachineCount = $MachineCount + ($Site.Machines).Count}
	[string]$DeploymentSummaryTable.Cell(3, 2).Range.Text = $MachineCount
	
	[string]$DeploymentSummaryTable.Cell(4, 1).Range.Text = "Total User Count"
	[string]$DeploymentSummaryTable.Cell(4, 2).Range.Text = $LyncConfig.Topology.TotalUserCount
	
	[string]$DeploymentSummaryTable.Cell(5, 1).Range.Text = "Total SIP Domains"
	[string]$DeploymentSummaryTable.Cell(5, 2).Range.Text = ($LyncConfig.Topology.SipDomains | Measure).Count
	
	MoveTo-End
	New-Line
}

function New-WordTable ($NumRows, $NumCols, $HeaderRow = $true) {
	$NewTable = $WordDocument.Tables.Add($script:Selection.Range, $NumRows, $NumCols)
	$NewTable.AllowAutofit = $true
	$NewTable.AutoFitBehavior(2)
	$NewTable.AllowPageBreaks = $false
	$NewTable.Style = $script:TableStyleName
	$NewTable.ApplyStyleHeadingRows = $HeaderRow
	return $NewTable
}

function New-WordBookmark ($BookmarkName) {
	$script:WordDocument.Bookmarks.Add($BookmarkName,$Selection)
}

function New-WordSiteSection ($Site) {
	Update-Status "Site: $($Site.Name)" Status
	New-WordHeading "Site: $($Site.Name)" $script:Heading3StyleName
	New-WordSiteTable $Site
	#New-WordBookmark "$($Site.Name.Replace(".","_"))"
	New-WordPoolSection $Site
	New-WordMachineSection $Site
}

function New-WordSiteTable ($Site) {
	New-WordHeading "$($Site.Name) Details" $script:Heading4StyleName
	$CurrentSiteTable = New-WordTable 6 2 $true
	
	[string]$CurrentSiteTable.Cell(1, 1).Range.Text = "$($Site.Name)"
	[string]$CurrentSiteTable.Cell(1, 2).Range.Text = ""
	[string]$CurrentSiteTable.Cell(2, 1).Range.Text = "Description"
	[string]$CurrentSiteTable.Cell(2, 2).Range.Text = $Site.Description
	[string]$CurrentSiteTable.Cell(3, 1).Range.Text = "Kind"
	[string]$CurrentSiteTable.Cell(3, 2).Range.Text = $Site.Kind
	[string]$CurrentSiteTable.Cell(4, 1).Range.Text = "Site ID"
	[string]$CurrentSiteTable.Cell(4, 2).Range.Text = $Site.SiteId
	[string]$CurrentSiteTable.Cell(5, 1).Range.Text = "User Count"
	[string]$CurrentSiteTable.Cell(5, 2).Range.Text = $Site.UserCount
	[string]$CurrentSiteTable.Cell(6, 1).Range.Text = "Kerberos Account"
	[string]$CurrentSiteTable.Cell(6, 2).Range.Text = $Site.KerberosConfiguration
	
	MoveTo-End
	New-Line
}

function New-WordMachineSection ($Site) {
	New-WordHeading "Machines" $script:Heading4StyleName
		foreach ($Machine in $Site.Machines){
			Update-Status "Machine: $($Machine.Fqdn)" Status
			New-WordMachineTable $Machine
			# If there is certificate information for this machine build the table a populate the data.
			if ($Machine.Certificates) {
				Update-Status "Certificates: $($Machine.Fqdn)" Status
				New-WordMachineCertificateTable $Machine
			}
	}
}

function New-WordMachineTable ($Machine) {
	$NumRows = 4
	if ($Machine.CPUCores){$NumRows++}
	if (($Machine.RAM) -and ($Machine.RAM -ne "0MB")){$NumRows++}
	if ($Machine.Version -eq $null){$NumRows++}
	if ($Machine.IPAddress){$NumRows++}
	
	$CurrentMachineTable = New-WordTable $NumRows 2 $true
	
	[string]$CurrentMachineTable.Cell(1, 1).Range.Text = $Machine.FQDN
	#New-WordBookMark "$($Machine.FQDN.Replace(".","_"))"
	[string]$CurrentMachineTable.Cell(1, 2).Range.Text = ""
	[string]$CurrentMachineTable.Cell(2, 1).Range.Text = "Machine ID"
	[string]$CurrentMachineTable.Cell(2, 2).Range.Text = $Machine.MachineId
	[string]$CurrentMachineTable.Cell(3, 1).Range.Text = "Parent Pool"
	[string]$CurrentMachineTable.Cell(3, 2).Range.Text = $Machine.Pool
	[string]$CurrentMachineTable.Cell(4, 1).Range.Text = "Roles"
	[string]$CurrentMachineTable.Cell(4, 2).Range.Text = $Machine.Roles
	
	$CurrentRow = 5
	if ($Machine.IPAddress){
		$IpAddressTable = $null
		$IpAddressTable = @()
		foreach ($Key in $Machine.IPAddress.Keys) {$IpAddressTable += "$($Machine.IPAddress.$Key)" }
		[string]$CurrentMachineTable.Cell($CurrentRow, 1).Range.Text = "IP Addresses"
		[string]$CurrentMachineTable.Cell($CurrentRow, 2).Range.Text = $IpAddressTable
		$CurrentRow++
	}

	if ($Machine.CPUCores){
		[string]$CurrentMachineTable.Cell($CurrentRow, 1).Range.Text = "CPU Cores"
		[string]$CurrentMachineTable.Cell($CurrentRow, 2).Range.Text = $Machine.CPUCores
		$CurrentRow++
	}

	if (($Machine.RAM) -and ($Machine.RAM -ne "0MB")){
		[string]$CurrentMachineTable.Cell($CurrentRow, 1).Range.Text = "RAM"
		[string]$CurrentMachineTable.Cell($CurrentRow, 2).Range.Text = $Machine.RAM
		$CurrentRow++
	}

	if ($Machine.Version){
		$VersionTable = $null
		$VersionTable = @()
		foreach ($Key in $Machine.Version.Keys) {
			$SwKey = $($Key.Replace('Microsoft Lync Server ', ''))
			$SwKey = $SwKey.Replace('Skype for Business Server ', '')
			$VersionTable += "$($SwKey) $($Machine.Version.$Key)"
		}

		[string]$CurrentMachineTable.Cell($CurrentRow, 1).Range.Text = "Software Versions"
		[string]$CurrentMachineTable.Cell($CurrentRow, 2).Range.Text = $VersionTable
		$CurrentRow++
	}

	MoveTo-End
	New-Line
}

function New-WordMachineCertificateTable ($Machine) {
	
	$MachineCertificates = $null
	$MachineCertificates = $Machine.Certificates | Get-Member -MemberType NoteProperty | Select -Expand Name

	# Add an extra row to the number of certificates to account for the table header.
	$NumRows = ($MachineCertificates.Count) + 1
	
	# Create a new table for the certificate(s).
	$CurrentMachineCertificateTable = New-WordTable $NumRows 2 $true
	
	$CurrentRow = 1
	[string]$CurrentMachineCertificateTable.Cell($CurrentRow, 1).Range.Text = "$($Machine.Fqdn) Certificates"
	[string]$CurrentMachineCertificateTable.Cell($CurrentRow, 2).Range.Text = ""
	$CurrentRow++
	
	foreach ($Certificate in $MachineCertificates){
		$CurrentCertificate = $null
		$CertificateTable = $Null
		$FullSubject = $Null
		$SplitSubject = $Null
		$SubjectName = $Null

		$CurrentCertificate = $Machine.Certificates.($Certificate)
		$CertificateTable = @()
		
		$FullSubject = $CurrentCertificate.Subject
		$SplitSubject = $FullSubject.Split(",")
		$ShortSubject = $SplitSubject[0].Substring(3, ($SplitSubject[0].Length - 3))

		$CertificateTable += "Subject : $ShortSubject`r"
		$CertificateTable += "Created : $($CurrentCertificate.NotBefore)`r"
		$CertificateTable += "Expires : $($CurrentCertificate.NotAfter)`r"
		$CertificateTable += "Issuer : $($CurrentCertificate.Issuer)`r"
		$CertificateTable += "Serial Number : $($CurrentCertificate.SerialNumber)`r"
		$CertificateTable += "Thumbprint : $($CurrentCertificate.Thumbprint)`r"
		$CertificateTable += "SAN Names : `r$($CurrentCertificate.AlternativeNames.Replace(" ", "`n"))"
		
		[string]$CurrentMachineCertificateTable.Cell($CurrentRow, 1).Range.Text = "$($CurrentCertificate.Use)"
		[string]$CurrentMachineCertificateTable.Cell($CurrentRow, 2).Range.Text = $CertificateTable
		$CurrentRow++
	}
	
	MoveTo-End
	New-Line
}
		
function New-WordPoolSection ($Site) {
	if (($Site.Pools | Where {$_.Machines.Count -gt 1} | Measure).Count -gt 0) {
		New-WordHeading "Pools" $script:Heading4StyleName
		foreach ($Pool in $Site.Pools | Where {$_.Machines.Count -gt 1}){
			Update-Status "Pool: $($Pool.Fqdn)" Status
			New-WordPoolTable $Pool
		}
	}
}

function New-WordPoolTable ($Pool) {
	$NumRows = 4
	if ($Pool.ExternalWebFQDN){$NumRows++}
	if ($Pool.FileStore){$NumRows++}
	if ($Pool.InternalWebFQDN){$NumRows++}
	if ($Pool.MonitoringAccounts){$NumRows++}
	if ($Pool.SqlInstances){$NumRows++}
	if ($Pool.UserCount){$NumRows++}
	
	$MachineTable = $null
	$MachineTable = $Pool.Machines | Select -Expand FQDN

	
	$CurrentPoolTable = New-WordTable $NumRows 2 $true
	
	[string]$CurrentPoolTable.Cell(1, 1).Range.Text = $Pool.FQDN
	#New-WordBookMark "$($Pool.FQDN.Replace(".","_"))"
	[string]$CurrentPoolTable.Cell(1, 2).Range.Text = ""
	[string]$CurrentPoolTable.Cell(2, 1).Range.Text = "Cluster ID"
	[string]$CurrentPoolTable.Cell(2, 2).Range.Text = $Pool.Identity
	[string]$CurrentPoolTable.Cell(3, 1).Range.Text = "Roles"
	[string]$CurrentPoolTable.Cell(3, 2).Range.Text = $Pool.Roles
	[string]$CurrentPoolTable.Cell(4, 1).Range.Text = "Machines"
	[string]$CurrentPoolTable.Cell(4, 2).Range.Text = $MachineTable
	
	$CurrentRow = 5
	if ($Pool.FileStore){
		[string]$CurrentPoolTable.Cell($CurrentRow, 1).Range.Text = "File Share"
		[string]$CurrentPoolTable.Cell($CurrentRow, 2).Range.Text = $Pool.FileStore
		$CurrentRow++
	}

	if ($Pool.SqlInstances){
		[string]$CurrentPoolTable.Cell($CurrentRow, 1).Range.Text = "SQL Instance"
		[string]$CurrentPoolTable.Cell($CurrentRow, 2).Range.Text = $Pool.SqlInstances
		$CurrentRow++
	}

	if ($Pool.UserCount){
		[string]$CurrentPoolTable.Cell($CurrentRow, 1).Range.Text = "User Count"
		[string]$CurrentPoolTable.Cell($CurrentRow, 2).Range.Text = $Pool.UserCount
		$CurrentRow++
	}
	
	if ($Pool.MonitoringAccounts){
		$MonitoringAccountsTable = $null
		$MonitoringAccountsTable = @()
		foreach ($Key in $Pool.MonitoringAccounts.Keys) {$MonitoringAccountsTable += "$Key $($Pool.MonitoringAccounts.$Key)" }
		[string]$CurrentPoolTable.Cell($CurrentRow, 1).Range.Text = "Testing Accounts"
		[string]$CurrentPoolTable.Cell($CurrentRow, 2).Range.Text = $MonitoringAccountsTable
		$CurrentRow++
	}
	
	if ($Pool.InternalWebFQDN){
		[string]$CurrentPoolTable.Cell($CurrentRow, 1).Range.Text = "Internal Web FQDN"
		[string]$CurrentPoolTable.Cell($CurrentRow, 2).Range.Text = $Pool.InternalWebFQDN
		$CurrentRow++
	}
	
	if ($Pool.ExternalWebFQDN){
		[string]$CurrentPoolTable.Cell($CurrentRow, 1).Range.Text = "External Web FQDN"
		[string]$CurrentPoolTable.Cell($CurrentRow, 2).Range.Text = $Pool.ExternalWebFQDN
		$CurrentRow++
	}
	
	MoveTo-End
	New-Line	
}

$OldCulture = [System.Threading.Thread]::CurrentThread.CurrentCulture
[System.Threading.Thread]::CurrentThread.CurrentCulture = "en-US"

Update-Status "*** Starting Time: $(Get-Date) ***"
Open-LyncDataFile $LyncDataFile	
$script:DocumentTemplate = Get-Item "$Template"
$script:WordVisible = $Visible
New-WordReport
Update-Status "*** Finishing Time: $(Get-Date) ***"

[System.Threading.Thread]::CurrentThread.CurrentCulture = $OldCulture