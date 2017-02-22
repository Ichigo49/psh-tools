Function Get-VMWAREToolsStatus
{
   Param ( [String]$ComputerName, [Switch]$Quiet )

   $VM = Get-View -ViewType VirtualMachine -Property Guest,Name -filter @{"Name"=$ComputerName}
   if ( $VM.Guest.GuestState -ne 'running' )
   {
      Write-Warning "Impossible de continuer car la VM n'est pas démarrée !"
   }
   else
   {
      if ($Quiet -eq $true)
      {
         if ($VM.Guest.ToolsStatus -eq 'toolsOk')
         {
            Write-Output $true
         }
         else
         {
            Write-Output $false
         }
      }
      else 
      {
         Write-Output $VM | Select-object -property Name,@{Name='ToolsStatus'; Expression={$_.Guest.ToolsStatus}},
       @{Name='ToolsVersion'; Expression={$_.Guest.ToolsVersion}}
      }
   }
}
