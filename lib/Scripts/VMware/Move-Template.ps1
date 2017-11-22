function Move-Template{
    param( [string] $template, [string] $esx, [string] $datastore)

    if($template -eq ""){Write-Host "Enter a Template name"}
    if($esx -eq ""){Write-Host "Enter an ESX hostname"}
    if($esx -ne "" -and $datastore -eq ""){$vmotion = $true}
    if($datastore -ne ""){$svmotion = $true}

    Write-Host "Converting $template to VM"
    $vm = Set-Template -Template (Get-Template $template) -ToVM 

    if($svmotion){
        Write-Host "Migrate $template to $esx and $datastore"
        Move-VM -VM (Get-VM $vm) -Destination (Get-VMHost $esx) `
        -Datastore (Get-Datastore $datastore) -Confirm:$false
        (Get-VM $vm | Get-View).MarkAsTemplate() | Out-Null
    }        

    if($vmotion){
        Write-Host "Migrate $template to $esx"
        Move-VM -VM $vm -Destination (Get-VMHost $esx) -Confirm:$false
        ($vm | Get-View).MarkAsTemplate() | Out-Null
    }
}