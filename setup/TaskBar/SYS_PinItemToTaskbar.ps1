#######################################################################
#
#   NOM DU FICHIER : SYS_PinItemToTaskbar.ps1 	UTILISATION : Webcenter
#
#   AUTEUR : Mathieu Allegret
#	DATE : 08/07/2014
#	VERSION : 1.0
#
#   BUT DE LA PROCEDURE :
#  	Attaché des raccourcis dans la barre des tâches
#
#   FONCTIONNEMENT :
#   lancer le script via powershell :
#	.\PinItemtoTaskbar.ps1 -PinItems "C:\y900x00\util\setup\TaskBar\Task Scheduler.lnk"
#   
# #######################################################################

Param
(
    [Parameter(Mandatory=$true)]
    [Alias('pin')]
    [String[]]$PinItems
)

$Shell = New-Object -ComObject Shell.Application
$Desktop = $Shell.NameSpace(0X0)
$oslang = (Get-WmiObject Win32_OperatingSystem).oslanguage

Foreach($item in $PinItems)
{
    #Verify the shortcut whether exists
    If(Test-Path -Path $item)
    {
        $itemLnk = $Desktop.ParseName($item)
        $Flag=0
	
        #pin application to windows Tasbar
        $itemVerbs = $itemLnk.Verbs()
        Foreach($itemVerb in $itemVerbs)
        {
			if ($oslang -eq "1036") 
			{
				If($itemVerb.Name.Replace("&","") -match "Épingler à la barre des tâches")
				{
					$itemVerb.DoIt()
					$Flag=1
				}
			}
			else
			{
				If($itemVerb.Name.Replace("&","") -match "Pin to Taskbar")
				{
					$itemVerb.DoIt()
					$Flag=1
				}
			}
        }
		#get the name of item
        $itemName = (Get-Item -Path $item).Name
		
		If($Flag -eq 1)
        {
            Write-Host "Pin '$itemName' file to taskbar successfully." -ForegroundColor Green
        }
        Else
        {
            Write-Host "Failed to pin '$itemName' file to taskbar." -ForegroundColor Red
        }
    }
    Else
    {
        Write-Warning "Cannot find path '$item' because it does not exist."
    }
}
