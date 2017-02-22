<#
.SYNOPSIS  
	Create Microsoft Excel based report of Lync environment from XML datafile.
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
#>
param([Parameter(Mandatory = $false)]
      [string]$LyncDataFile = $null)

$ErrorActionPreference = "Continue"
$OFS = "`r`n"

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
	
	Update-Status "Importing Lync data file." Status
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

function New-ExcelReport {
	# Set the Excel document filename.
	$script:ExcelDocFileName = $script:LyncDataXmlFileName.Replace("xml", "xlsx")
	Update-Status "Creating Excel report: $ExcelDocFileName" Status
	
	# Create new instance of Microsoft Excel to work with.
	Update-Status "Creating new instance of Excel to work with."
	$script:ExcelApplication = New-Object -ComObject "Excel.Application"
	$script:ExcelApplication.Visible = $true
	
	# Create a new blank document to work with and make the Excel application visible.
	$script:ExcelWorkbooks = $ExcelApplication.Workbooks
	$script:ExcelWorkbook = $script:ExcelWorkbooks.Add()
	$script:ExcelWorkSheets = $script:ExcelWorkbook.WorkSheets
	$script:CurrentWorkSheet = $script:ExcelWorkSheets.Item(1)
	#$ExcelWorkbook.SaveAs($ExcelDocFileName)
	
	# Set tab starting color.
	$script:TabColor = 20
	
	# Create the sections for Policy configurations.
	# Any section uncommented below will be built in the workbook.
	# Be advised this can dramatically increase generation time.
	
	#New-ExcelPolicySection ExternalConfig
	New-ExcelPolicySection Voice
	#New-ExcelPolicySection Conferencing
	#New-ExcelPolicySection RGS
	#New-ExcelPolicySection CAC
	#New-ExcelPolicySection LIS
	#New-ExcelPolicySection Policy
	
	Update-Status "Finished creating workbook, saving changes to document." Status
	$ExcelWorkbook.SaveAs("$ExcelDocFileName")
	Update-Status "Done." Status
	#$ExcelWorkbook.Close()
	#$ExcelApplication.Quit()

	# Clean up PS COM object so Excel can close properly.
	#[System.Runtime.Interopservices.Marshal]::ReleaseComObject($CurrentWorkSheet)
	#[System.Runtime.Interopservices.Marshal]::ReleaseComObject($ExcelWorkSheets)
	#[System.Runtime.Interopservices.Marshal]::ReleaseComObject($ExcelWorkbook)
	#[System.Runtime.Interopservices.Marshal]::ReleaseComObject($ExcelWorkbooks)
	#[System.Runtime.Interopservices.Marshal]::ReleaseComObject($ExcelApplication)
}

function New-ExcelPolicySection ($SectionName) {
	Update-Status "Creating $SectionName policy section." Status
	$script:PolicyCmdlets = $script:LyncConfig.($SectionName) | Get-Member -MemberType NoteProperty | Select -Expand Name
	
	$CurrentSheetNumber = 1
	
	foreach ($Policy in $PolicyCmdlets) {
		
		if ($CurrentSheetNumber -gt $script:ExcelWorkSheets.Count){
			$script:CurrentWorkSheet = $script:ExcelWorkSheets.Add()
		} else {
			$script:CurrentWorkSheet = $script:ExcelWorkSheets.Item($CurrentSheetNumber)
		}
		
		Update-Status "Creating $Policy policy sheet." Status
		$script:CurrentWorkSheet.Name = "$($Policy -creplace "([a-z])([A-Z])", '$1 $2')"
		New-ExcelPolicySheet $script:LyncConfig.($SectionName).($Policy)
		$CurrentSheetNumber++
	}
}

function New-ExcelPolicySheet ($Policies) {
	if ($Policies) {
		$PolicyAttributes = $Policies | Get-Member -MemberType Property | Select -Expand Name
		$NumRows = $PolicyAttributes.Count - 1
		$NumCols = ($Policies | measure).Count + 1
		
		$CurrentColumn = 1
		$CurrentRow = 1
		
		[string]$script:CurrentWorkSheet.Cells.Item($CurrentRow,$CurrentColumn).value() = "Identity"
		$CurrentRow++
		
		foreach ($AttributeName in $PolicyAttributes){
			if (($AttributeName -ne "Identity") -and ($AttributeName -ne "Anchor")){
				[string]$script:CurrentWorkSheet.Cells.Item($CurrentRow,$CurrentColumn).value() = $AttributeName
				$CurrentRow++
			}
		}
	
		# Reset currently selected cell to Row 1, Column 2
		$CurrentRow = 1
		$CurrentColumn = 2
	
		foreach ($Policy in $Policies) {
			# Set first row as Identity value.
			[string]$script:CurrentWorkSheet.Cells.Item($CurrentRow,$CurrentColumn).value() = $Policy.Identity
			$CurrentRow++
			foreach ($AttributeName in $PolicyAttributes){
				if (($AttributeName -ne "Identity") -and ($AttributeName -ne "Anchor")){
					[string]$script:CurrentWorkSheet.Cells.Item($CurrentRow,$CurrentColumn).value() = "$($Policy.($AttributeName))"
					$CurrentRow++
				}
			}
			$CurrentRow = 1
			$CurrentColumn++
		}
		$script:CurrentWorkSheet.UsedRange.Columns.Autofit() | Out-Null
		$objList = $script:CurrentWorkSheet.ListObjects.Add([Microsoft.Office.Interop.Excel.XlListObjectSourceType]::xlSrcRange, $script:CurrentWorkSheet.UsedRange, $null,[Microsoft.Office.Interop.Excel.XlYesNoGuess]::xlYes,$null)
		$objList.TableStyle = "TableStyleMedium20"
	} else {
		[string]$script:CurrentWorkSheet.Cells.Item(1,1).value() = "No Settings Found"
	}
	$script:CurrentWorkSheet.Tab.ColorIndex = $script:TabColor
	$script:TabColor = $script:TabColor + 1
	if ($script:TabColor -ge 55){$script:TabColor = 1}
	$Policies = $null
}

$OldCulture = [System.Threading.Thread]::CurrentThread.CurrentCulture
[System.Threading.Thread]::CurrentThread.CurrentCulture = "en-US"

Update-Status "*** Starting Time: $(Get-Date) ***"
Open-LyncDataFile $LyncDataFile	
New-ExcelReport
Update-Status "*** Finishing Time: $(Get-Date) ***"

[System.Threading.Thread]::CurrentThread.CurrentCulture = $OldCulture