function Get-VMEvents {
 <#
   .Synopsis
 
    Get events for an entity or for query all events.
 
   .Description
 
    This function returns events for entities. It's very similar to 
    get-vievent cmdlet.Note that get-VMEvent can handle 1 vm at a time.
    You can not send array of vms in this version of the script.
 
    .Example
 
    Get-VMEvents 0All -types "VmCreatedEvent","VmDeployedEvent","VmClonedEvent"
 
    This will receive ALL events of types "VmCreatedEvent","VmDeployedEvent",
    "VmClonedEvent". 
     
   .Example
 
    Get-VMEvents -name 'vm1' -types "VmCreatedEvent"
 
    Will ouput creation events for vm : 'vm1'. This was is faster than piping vms from
    get-vm result. There is no need to use get-vm to pass names to get-vmevents.
    Still, it is ok when you will do it, it will make it just a little bit slower <span class="wp-smiley wp-emoji wp-emoji-wink" title=";)">;)</span>
     
   .Example
 
    Get-VMEvents -name 'vm1' -category 'warning'
 
    Will ouput all events for vm : 'vm1'. This was is faster than piping names from
    get-vm cmdlet. Category will make get-vmevent to search only defined category
    events. 
     
   .Example
 
    get-vm 'vm1' | Get-VMEvents -types "VmCreatedEvent","VmMacAssignedEvent"
 
    Will display events from vm1 which will be regarding creation events,
    and events when when/which mac address was assigned
 
 
    .Parameter VM
 
    This parameter is a single string representing vm name. It expects single vm name that
    exists in virtual center. At this moment in early script version it will handle only a case
    where there is 1 instance of vm of selected name. In future it will handle multiple as 
    well.
     
   .Parameter types
 
    If none specified it will return all events. If specified will return
    only events with selected types. For example : "VmCreatedEvent",
    "VmDeployedEvent", "VmMacAssignedEvent" "VmClonedEvent" , etc...
     
    .Parameter category
 
    Possible categories are : warning, info, error. Please use this parameter if you
    want to filter events.
     
    .Parameter All
 
    If you will set this parameter, as a result command will query all events from
    virtual center server regarding virtual machines. 
 
   .Notes
 
    NAME:  VMEvents
 
    AUTHOR: Grzegorz Kulikowski
 
    LASTEDIT: 11/09/2012
     
    NOT WORKING ? #powercli @ irc.freenode.net 
 
   .Link
 
https://psvmware.wordpress.com
 
 #>
 
param(
[Parameter(ValueFromPipeline=$true)]
[ValidatenotNullOrEmpty()]
$VM,
[String[]]$types,
[string]$category,
[switch]$All
)
    $si=get-view ServiceInstance
    $em= get-view $si.Content.EventManager
    $EventFilterSpec = New-Object VMware.Vim.EventFilterSpec
    $EventFilterSpec.Type = $types
    if($category){
    $EventFilterSpec.Category = $category
    }
     
    if ($VM){
    $EventFilterSpec.Entity = New-Object VMware.Vim.EventFilterSpecByEntity
    switch ($VM) {
    {$_ -is [VMware.Vim.VirtualMachine]} {$VMmoref=$vm.moref}
    {$_ -is [VMware.VimAutomation.ViCore.Impl.V1.Inventory.VirtualMachineImpl]}{$VMmoref=$vm.Extensiondata.moref}
    default {$vmmoref=(get-view -ViewType virtualmachine -Filter @{'name'=$VM}).moref }
    }
    $EventFilterSpec.Entity.Entity = $vmmoref
        $em.QueryEvents($EventFilterSpec) 
    }
    if ($All) {
    $em.QueryEvents($EventFilterSpec)
    }
}

function Get-VMCreationDate {
<#
   .Synopsis
 
    Gets where possible vm creation date.
 
   .Description
 
    This function will return object with information about  creation time, method, month,
    creator for particular vm. 
    VMname         : SomeVM12
    CreatedTime    : 8/10/2012 11:48:18 AM
    CreatedMonth   : August
    CreationMethod : Cloned
    Creator         : office\greg
     
    This function will display NoEvent value in properties in case when your VC does no
    longer have information about those particular events, or your vm events no longer have
    entries about being created. If your VC database has longer retension date it is more possible
    that you will find this event. 
 
    .Example
 
    Get-VMCreationdate -VMnames "my_vm1","My_otherVM"
 
    This will return objects that contain creation date information for vms with names
    myvm1 and myvm2
     
   .Example
 
    Get-VM -Location 'Cluster1' |Get-VMCreationdate
 
    This will return objects that contain creation date information for vms that are
    located in Cluster1
     
   .Example
 
    Get-view -viewtype virtualmachine -SearchRoot (get-datacenter 'mydc').id|Get-VMCreationDate
 
    This will return objects that contain creation date information for vms that are
    located in datacenter container 'mydc'. If you are using this function within existing loop where you
    have vms from get-view cmdlet, you can pass them via pipe or as VMnames parameter.
 
    .Example
 
    $report=get-cluster 'cl-01'|Get-VMCreationdate
    $report | export-csv c:\myreport.csv
    Will store all reported creationtimes object in $report array variable and export report to csv file.
    You can also filter the report before writing it to csv file using select
    $report | Where-Object {$_.CreatedMonth -eq "October"} | Select VMName,CreatedMonth
    So that you will see only vms that were created in October.
 
 
    .Example
    get-vmcreationdate -VMnames "my_vm1",testvm55
    WARNING: my_vm1 could not be found, typo?
    VMname         : testvm55
    CreatedTime    : 10/5/2012 2:24:03 PM
    CreatedMonth   : October
    CreationMethod : NewVM
    Creator        : home\greg
    In case when you privided vm that does not exists in yor infrastructure, a warning will be displayed.
    You can still store the whole report in $report variable, but it will not include any information about
    missing vm creation dates. A warning will be still displayed only for your information that there was
    probably a typo in the vm name.
     
    .Parameter VMnames
 
    This parameter should contain virtual machine objects or strings that represents vm
    names. It is possible to feed this function wiith VM objects that come from get-vm or
    from get-view. 
 
 
   .Notes
 
    NAME:  Get-VMCreationdate
 
    AUTHOR: Grzegorz Kulikowski
 
    LASTEDIT: 27/11/2012
     
    NOT WORKING ? #powercli @ irc.freenode.net 
 
   .Link
 
https://psvmware.wordpress.com
 
 #>
  
param(
[Parameter(ValueFromPipeline=$true,Mandatory = $true)]
[ValidateNotNullOrEmpty()] 
[Object[]]$VMnames
)
process {
foreach ($vm in $VMnames){
$ReportedVM = ""|Select VMname,CreatedTime,CreatedMonth,CreationMethod,Creator
if ($CollectedEvent=$vm|Get-VMEvents -types 'VmBeingDeployedEvent','VmRegisteredEvent','VmClonedEvent','VmBeingCreatedEvent' -ErrorAction SilentlyContinue)
    {
    if($CollectedEvent.gettype().isArray){$CollectedEvent=$CollectedEvent|?{$_ -is [vmware.vim.VmRegisteredEvent]}}
    $CollectedEventType=$CollectedEvent.gettype().name
    $CollectedEventMonth = "{0:MMMM}" -f $CollectedEvent.CreatedTime
    $CollectedEventCreationDate=$CollectedEvent.CreatedTime
    $CollectedEventCreator=$CollectedEvent.Username
        switch ($CollectedEventType)
        {
        'VmClonedEvent' {$CreationMethod = 'Cloned'} 
        'VmRegisteredEvent' {$CreationMethod = 'RegisteredFromVMX'} 
        'VmBeingDeployedEvent' {$CreationMethod = 'VmFromTemplate'}
        'VmBeingCreatedEvent'  {$CreationMethod = 'NewVM'}
        default {$CreationMethod='Error'}
        }
    $ReportedVM.VMname=$CollectedEvent.vm.Name
    $ReportedVM.CreatedTime=$CollectedEventCreationDate
    $ReportedVM.CreatedMonth=$CollectedEventMonth
    $ReportedVM.CreationMethod=$CreationMethod
    $ReportedVM.Creator=$CollectedEventCreator
    }else {
        if ($?) {
            if($vm -is [VMware.Vim.VirtualMachine]){$ReportedVM.VMname=$vm.name} else {$ReportedVM.VMname=$vm.ToString()}
            $ReportedVM.CreatedTime = 'NoEvent'
            $ReportedVM.CreatedMonth = 'NoEvent'
            $ReportedVM.CreationMethod = 'NoEvent'
            $ReportedVM.Creator = 'NoEvent'
             
        } else {
            $ReportedVM = $null
            Write-Warning "$VM could not be found, typo?"
        }
    }
    $ReportedVM
}
}
}
