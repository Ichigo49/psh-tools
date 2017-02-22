[CmdletBinding()]
PARAM()
Write-Host "Loading Vmware Snapin..." -NoNewLine
if ( (Get-PSSnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue) -eq $null ){Add-PsSnapin VMware.VimAutomation.Core}
Import-Module ..\modules\SYS_HTMLTable
Write-Host "Done"

$vcenter = @("VIRTADM3","VIRTADM6")
$smtp = "mailhost"
$From = "dsi-exploitation@universcience.fr"
$To = ("mathieu.allegret@atos.net")
$HTML = New-HTMLHead -title "VMWare Snapshots"

foreach ($Server in $vcenter) {
	Write-Host "Connecting To  $Server..." -NoNewLine
	Connect-VIServer $Server -wa 0 | Out-Null
	Write-Host "Done"
	$objColl = @()
	$HTML += "<h3>Listes des Snapshots - $Server :</h3>"
	Write-Host "Gathering Snapshots..." -NoNewLine
	$Snapshot = Get-VM | Get-Snapshot | Select VM,Name,Description,@{Label="SizeMB";Expression={[math]::round($_.SizeMB)}},Created
	if (!$snapshot)
	{
		$HTML += "<p>Pas de Sanpshot sur $Server</p>"
	}
	else
	{
		foreach ($snap in $snapshot)
		{
			$obj = New-Object -TypeName PSObject
			Add-Member -InputObject $obj -MemberType NoteProperty -Name "VM Name" -Value $snap.VM
			Add-Member -InputObject $obj -MemberType NoteProperty -Name "Snapshot Name" -Value $snap.Name
			Add-Member -InputObject $obj -MemberType NoteProperty -Name "Description" -Value $snap.description
			Add-Member -InputObject $obj -MemberType NoteProperty -Name "Created" -Value $snap.created
			Add-Member -InputObject $obj -MemberType NoteProperty -Name "Size Mo" -Value $snap.SizeMB
			$objColl += $obj				
		}
		$HTML += New-HTMLTable -inputObject $objColl
	}
	Write-Host "Done"
	Disconnect-VIServer -confirm:$false
}
$HTML = $HTML | Close-HTML

Send-MailMessage -To $To -From $From -Subject "USC Snapshot Report" -Bodyashtml $HTML -SmtpServer $smtp
