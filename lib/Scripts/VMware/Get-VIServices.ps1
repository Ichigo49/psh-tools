function Get-VIServices {
	param (
		$viserver = "localhost", 
		$credential
	)
   If ($credential){
      $Services = get-wmiobject win32_service -Credential $credential -ComputerName $viserver | Where {$_.DisplayName -like "VMware*" }
   } Else {
      $Services = get-wmiobject win32_service -ComputerName $viserver | Where {$_.DisplayName -like "VMware*" }
   }
 
   $myCol = @()
   Foreach ($service in $Services){
      If ($service.StartMode -eq "Auto") {
         if ($service.State -eq "Stopped") {
            $MyDetails = New-Object -TypeName PSObject -Property @{
               Name = $service.Displayname
               State = $service.State
               StartMode = $service.StartMode
               Health = "Unexpected State"
            }
         }
      }
 
      If ($service.StartMode -eq "Auto") {
         if ($service.State -eq "Running") {
            $MyDetails = New-Object -TypeName PSObject -Property @{
               Name = $service.Displayname
               State = $service.State
               StartMode = $service.StartMode
               Health = "OK"
            }
         }
      }
      If ($service.StartMode -eq "Disabled"){
         If ($service.State -eq "Running"){
            $MyDetails = New-Object -TypeName PSObject -Property @{
               Name = $service.Displayname
               State = $service.State
               StartMode = $service.StartMode
               Health = "Unexpected State"
            }
         }
      }
      If ($service.StartMode -eq "Disabled"){
         if ($service.State -eq "Stopped"){
            $MyDetails = New-Object -TypeName PSObject -Property @{
               Name = $service.Displayname
               State = $service.State
               StartMode = $service.StartMode
               Health = "OK"
            }
         }
      }
      $myCol += $MyDetails
   }
   $myCol
}