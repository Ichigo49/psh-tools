Function Get-LocalUser 
{
	<#
		.SYNOPSIS
		   This script can list all local user account.
		.DESCRIPTION
		   This script can list all local user account.
		.PARAMETER  <AccountName>
			Specifies the local user account you want to search.
		.PARAMETER	<ComputerName <string[]>
			Specifies the computers on which the command runs. The default is the local computer. 
		.PARAMETER  <Credential>
			Specifies a user account that has permission to perform this action. 
		.EXAMPLE
			C:\PS> C:\Script\GetLocalAccount.ps1
			
			This example shows how to list all of local users on local computer.	
		.EXAMPLE
			C:\PS> C:\Script\GetLocalAccount.ps1 | Export-Csv -Path "D:\LocalUserAccountInfo.csv" -NoTypeInformation
			
			This example will export report to csv file. If you attach the <NoTypeInformation> parameter with command, it will omit the type information 
			from the CSV file. By default, the first line of the CSV file contains "#TYPE " followed by the fully-qualified name of the object type.
		.EXAMPLE
			C:\PS> C:\Script\GetLocalAccount.ps1 -AccountName "Administrator","Guest"
			
			This example shows how to list local Administrator and Guest account information on local computer.
		.EXAMPLE
			C:\PS> $Cre=Get-Credential
			C:\PS> C:\Script\GetLocalAccount.ps1 -Credential $Cre -Computername "WINSERVER" 
			
			This example lists all of local user accounts on the WINSERVER remote computer.
	#>

	Param
	(
		[Parameter(Position=0,Mandatory=$false)]
		[ValidateNotNullorEmpty()]
		[Alias('cn')][String[]]$ComputerName=$Env:COMPUTERNAME,
		[Parameter(Position=1,Mandatory=$false)]
		[Alias('un')][String[]]$AccountName,
		[Parameter(Position=2,Mandatory=$false)]
		[Alias('cred')][System.Management.Automation.PsCredential]$Credential
	)
		
	$Obj = @()

	Foreach($Computer in $ComputerName)
	{
		If($Credential)
		{
			$AllLocalAccounts = Get-WmiObject -Class Win32_UserAccount -Namespace "root\cimv2" `
			-Filter "LocalAccount='$True'" -ComputerName $Computer -Credential $Credential -ErrorAction Stop
		}
		else
		{
			$AllLocalAccounts = Get-WmiObject -Class Win32_UserAccount -Namespace "root\cimv2" `
			-Filter "LocalAccount='$True'" -ComputerName $Computer -ErrorAction Stop
		}
		
		Foreach($LocalAccount in $AllLocalAccounts)
		{
			$Object = New-Object -TypeName PSObject
			
			$Object | Add-Member -MemberType NoteProperty -Name "Name" -Value $LocalAccount.Name
			$Object | Add-Member -MemberType NoteProperty -Name "Full Name" -Value $LocalAccount.FullName
			$Object | Add-Member -MemberType NoteProperty -Name "Caption" -Value $LocalAccount.Caption
			$Object | Add-Member -MemberType NoteProperty -Name "Disabled" -Value $LocalAccount.Disabled
			$Object | Add-Member -MemberType NoteProperty -Name "Status" -Value $LocalAccount.Status
			$Object | Add-Member -MemberType NoteProperty -Name "LockOut" -Value $LocalAccount.LockOut
			$Object | Add-Member -MemberType NoteProperty -Name "Password Changeable" -Value $LocalAccount.PasswordChangeable
			$Object | Add-Member -MemberType NoteProperty -Name "Password Expires" -Value $LocalAccount.PasswordExpires
			$Object | Add-Member -MemberType NoteProperty -Name "Password Required" -Value $LocalAccount.PasswordRequired
			$Object | Add-Member -MemberType NoteProperty -Name "SID" -Value $LocalAccount.SID
			$Object | Add-Member -MemberType NoteProperty -Name "SID Type" -Value $LocalAccount.SIDType
			$Object | Add-Member -MemberType NoteProperty -Name "Account Type" -Value $LocalAccount.AccountType
			$Object | Add-Member -MemberType NoteProperty -Name "Domain" -Value $LocalAccount.Domain
			$Object | Add-Member -MemberType NoteProperty -Name "Description" -Value $LocalAccount.Description
			
			$Obj+=$Object
		}
		
		If($AccountName)
		{
			Foreach($Account in $AccountName)
			{
				$Obj|Where-Object{$_.Name -like "$Account"}
			}
		}
		else
		{
			$Obj
		}
	}
}

Function Get-LocalGroup 
{
	[Cmdletbinding()] 
	Param( 
		[Parameter(ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)] 
		[String[]]$Computername =  $Env:COMPUTERNAME,
		[parameter()]
		[string[]]$Group
	)
	
	Begin {
		Function  ConvertTo-SID {
			Param([byte[]]$BinarySID)
			(New-Object  System.Security.Principal.SecurityIdentifier($BinarySID,0)).Value
		}
		Function  Get-LocalGroupMember {
			Param  ($Group)
			$group.Invoke('members')  | ForEach {
				$_.GetType().InvokeMember("Name",  'GetProperty',  $null,  $_, $null)
			}
		}
	}
	
	Process  {
		ForEach  ($Computer in  $Computername) {
			Try  {
				Write-Verbose  "Connecting to $($Computer)"
				$adsi  = [ADSI]"WinNT://$Computer"
				If  ($PSBoundParameters.ContainsKey('Group')) {
					Write-Verbose  "Scanning for groups: $($Group -join ',')"
					$Groups  = ForEach  ($item in  $group) {                        
						$adsi.Children.Find($Item, 'Group')
					}
				} Else  {
					Write-Verbose  "Scanning all groups"
					$groups  = $adsi.Children | where {$_.SchemaClassName -eq  'group'}
				}
				If  ($groups) {
					$groups  | ForEach {
						[pscustomobject]@{
							Computername = $Computer
							Name = $_.Name[0]
							Members = ((Get-LocalGroupMember  -Group $_))  -join ', '
							SID = (ConvertTo-SID -BinarySID $_.ObjectSID[0])
						}
					}
				} Else  {
					Throw  "No groups found!"
				}
			} Catch  {
				Write-Warning  "$($Computer): $_"
			}
		}
	}
}

Function Get-LocalGroupMembership 
{
	[Cmdletbinding()]
	Param (
		[Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
		[string]$ComputerName = $env:COMPUTERNAME,
		
		[string]$GroupName = "Administrators"
		)
	
	# Create the array that will contains all the output of this function
	$Output = @()
	
	# Get the members for the group and computer specified
	$Group = [ADSI]"WinNT://$ComputerName/$GroupName" 
	$Members = @($group.psbase.Invoke("Members"))

	# Format the Output
	$Members | foreach {
		$name = $_.GetType().InvokeMember("Name", 'GetProperty', $null, $_, $null)
		$class = $_.GetType().InvokeMember("Class", 'GetProperty', $null, $_, $null)
		$path = $_.GetType().InvokeMember("ADsPath", 'GetProperty', $null, $_, $null)
		
		# Find out if this is a local or domain object
		if ($path -like "*/$ComputerName/*"){
			$Type = "Local"
			}
		else {$Type = "Domain"
		}
		
		$Details = "" | Select ComputerName,Account,Class,Group,Path,Type
		$Details.ComputerName = $ComputerName
		$Details.Account = $name
		$Details.Class = $class
        $Details.Group = $GroupName
		$details.Path = $path
		$details.Type = $type
		
		# Send the current result to the $output variable
		$output = $output + $Details
	}
	# Finally show the Output to the user.
	$output
}

# Function to get DOMAIN Group Member(s)
#	This function allow to dig into Active Directory to get all the members (direct or nested)
#	Members can only be from the Domain.
function Get-DomainGroupMembership 
{
	param ($GroupName,$ComputerName)
	#$ComputerName parameter here is only used for information purpose, to show in the output
	
	# Create the array that will contains all the output of this function
	$Output = @()
	
	# Check the current members of $GroupName
	$Members = $GroupName | Get-QADGroupMember
	
	# Check the Count of $members
	$MembersCount = $Members.count

	# If there is at least 1 member, do the following
	if ($MembersCount -gt 0){
		foreach ($member in $Members){
			switch ($Member.type){
				"user"{
					# Return the user information
					$Details = "" | Select ComputerName,Account,Class,Group,Domain,type,path
					$Details.ComputerName = $ComputerName
					$Details.Account = $member.name
					$Details.Class = $Member.type
					$Details.Group = $GroupName
					$details.domain = $member.domain.name
					$details.type = "Domain"
					$Details.path = $Member.CanonicalName
					$output = $output + $Details
                }#Switch user
				"group"{
					# Return the group object information
					$Details = "" | Select ComputerName,Account,Class,Group,Domain,type,path
					$Details.ComputerName = $ComputerName
					$Details.Account = $member.name
					$Details.Class = $Member.type
					$Details.Group = $GroupName
					$details.domain = $member.domain.name
					$details.type = "Domain"
					$Details.path = $Member.CanonicalName
					$output = $output + $Details
					# Return the members of the current group
					Get-DomainGroupMembership -GroupName $Member.name -ComputerName $ComputerName
				}#Switch group
			}#switch ($Member.type)
		}#foreach ($member in $Members)
	}#if ($MembersCount -gt 0)
	#Finally show the output
	$Output
}#end function Get-DomainGroupMembership

# Function to Get LOCAL and DOMAIN member(s) information
#	LOCAL Group Membership information is handled by the function Get-LocalGroupMembership
#	DOMAIN Group Membership information is handled by the function Get-DomainGroupMembership
function Get-LocalGroupAllMembers 
{
	param (
        [parameter(ValueFromPipeline=$true)]
	    [string]$ComputerName = "$env:computername",
        [string]$GroupName = "Administrators"
	)
# Create the array that will contains all the output of this function
$Output = @()

# Get the local administrators for the current ComputerName using the function declared 
#	earlier: Get-LocalGroupMembership
$LocalAdministrators = Get-LocalGroupMembership -ComputerName $ComputerName -GroupName $GroupName

# Let's now get information about each members, and members of members, etc...
foreach ($admin in $LocalAdministrators){

    # L O C A L #
    #	Local User
    if (($admin.Type -like "Local") -and ($admin.class -like "User")){
        $Details = "" | Select ComputerName,Account,Class,Group,Type,Path
        $Details.ComputerName = $admin.ComputerName
        $Details.Account = $admin.account
        $Details.Class = $admin.class
        $Details.Group = $admin.group
        $Details.Type = $admin.type
        $Details.Path = $admin.path
        $output = $output + $Details

    }
    #	Local Group
    if (($admin.type -like "Local") -and ($admin.class -like "group")){
        # Return the local group information before checking its members
        $Details = "" | Select ComputerName,Account,Group,Domain                        
        $Details.ComputerName = $admin.ComputerName
        $Details.Account = $admin.account
        $Details.Class = $admin.class
        $Details.Group = $admin.group
        $Details.type = $admin.type
        $Details.path = $admin.path
        $output = $output + $Details
		# Return the members of the current Local Group
        $localgroup = Get-LocalGroupMembership -GroupName $admin.account -ComputerName $ComputerName
        
        # If There is at least 1 member, do the following
        if ($localgroup.count -gt 0) {
            foreach ($localMember in $localgroup){
                $Details = "" | Select ComputerName,Account,Class,Group,Type,Path                       
                $Details.Account = $localMember.account
                $Details.Group = $admin.account # Here we are taking the name of the parent group
                $Details.ComputerName = $localMember.ComputerName
                $Details.Class = $localMember.class
                $Details.type = $localMember.type
                $Details.path = $localMember.path
                $output = $output + $Details
                }#foreach
            }#if
    }#if (Get-LocalGroupMember -group $admin.account -ComputerName $ComputerName)

    # D O M A I N #
    if ($admin.type -like "Domain"){
        # Get information about this object in the domain
        #	Here we just want to know if it is an User or Group.
        $ADObject = Get-QADObject $admin.account
        
        Switch ($ADObject.type) {
        
        	#	Domain User
            "user" {
                # Return the User information
                $Details = "" | Select ComputerName,Account,Class,Group,Domain,type,path
                $Details.ComputerName = $ComputerName
                $Details.Account = $ADObject.name
                $Details.Class = $ADObject.type
                $Details.Group = $admin.group
                $Details.domain = $ADObject.domain.name
                $Details.Type = $admin.type
                $Details.path = $ADObject.CanonicalName
                $output = $output + $Details

                }#user (switch)
                
            #	Domain Group
            "group"{
                # Return the Group information
                $Details = "" | Select ComputerName,Account,Class,Group,Domain,type,path
                $Details.ComputerName = $ComputerName
                $Details.Account = $ADObject.name
                $details.Class = $ADObject.type
                $Details.Group = $admin.group
                $Details.domain = $ADObject.domain.name
                $Details.Type = $admin.type
                $Details.path = $ADObject.CanonicalName
                $output = $output + $Details
                # Checking if the group has members, call the function declared ealier
                # Get-DomainGroupMembership
                Get-DomainGroupMembership -GroupName $ADObject.name -ComputerName $ComputerName
            }#group (switch)
        }#switch
    }#if ($admin.domain -notlike "$ComputerName"){
}#foreach ($admin in $LocalAdministrators){
$output
}#function Get-LocalGroupAllMembers

Function New-LocalUser 
{ 
  <# 
   .Synopsis 
    This function creates a local user  
   .Description 
    This function creates a local user 
   .Example 
    New-LocalUser -userName "ed" -description "cool Scripting Guy" ` 
        -password "password" 
    Creates a new local user named ed with a description of cool scripting guy 
    and a password of password.  
   .Parameter ComputerName 
    The name of the computer upon which to create the user 
   .Parameter UserName 
    The name of the user to create 
   .Parameter password 
    The password for the newly created user 
   .Parameter description 
    The description for the newly created user 
   .Notes 
    NAME:  New-LocalUser 
    AUTHOR: ed wilson, msft 
    LASTEDIT: 06/29/2011 10:07:42 
    KEYWORDS: Local Account Management, Users 
    HSG: HSG-06-30-11 
   .Link 
     Http://www.ScriptingGuys.com/blog 
 #Requires -Version 2.0 
 #> 
 [CmdletBinding()] 
 Param( 
  [Parameter(Position=0, 
      Mandatory=$True, 
      ValueFromPipeline=$True)] 
  [string]$userName, 
  [Parameter(Position=1, 
      Mandatory=$True, 
      ValueFromPipeline=$True)] 
  [string]$password, 
  [string]$computerName = $env:ComputerName, 
  [string]$description = "Created by PowerShell" 
 ) 
 $computer = [ADSI]"WinNT://$computerName" 
 $user = $computer.Create("User", $userName) 
 $user.setpassword($password) 
 $user.put("description",$description)  
 $user.SetInfo() 
} #end function New-LocalUser 
 
Function New-LocalGroup 
{ 
 <# 
   .Synopsis 
    This function creates a local group  
   .Description 
    This function creates a local group 
   .Example 
    New-LocalGroup -GroupName "mygroup" -description "cool local users" 
    Creates a new local group named mygroup with a description of cool local users.  
   .Parameter ComputerName 
    The name of the computer upon which to create the group 
   .Parameter GroupName 
    The name of the Group to create 
   .Parameter description 
    The description for the newly created group 
   .Notes 
    NAME:  New-LocalGroup 
    AUTHOR: ed wilson, msft 
    LASTEDIT: 06/29/2011 10:07:42 
    KEYWORDS: Local Account Management, Groups 
    HSG: HSG-06-30-11 
   .Link 
     Http://www.ScriptingGuys.com/blog 
 #Requires -Version 2.0 
 #> 
 [CmdletBinding()] 
 Param( 
  [Parameter(Position=0, 
      Mandatory=$True, 
      ValueFromPipeline=$True)] 
  [string]$GroupName, 
  [string]$computerName = $env:ComputerName, 
  [string]$description = "Created by PowerShell" 
 ) 
  
  $adsi = [ADSI]"WinNT://$computerName" 
  $objgroup = $adsi.Create("Group", $groupName) 
  $objgroup.SetInfo() 
  $objgroup.description = $description 
  $objgroup.SetInfo() 
  
} #end function New-LocalGroup 
 
Function Set-LocalGroup 
{ 
  <# 
   .Synopsis 
    This function adds or removes a local user to a local group  
   .Description 
    This function adds or removes a local user to a local group 
   .Example 
    Set-LocalGroup -username "ed" -groupname "administrators" -add 
    Assigns the local user ed to the local administrators group 
   .Example 
    Set-LocalGroup -username "ed" -groupname "administrators" -remove 
    Removes the local user ed to the local administrators group 
   .Parameter username 
    The name of the local user 
   .Parameter groupname 
    The name of the local group 
   .Parameter ComputerName 
    The name of the computer 
   .Parameter add 
    causes function to add the user 
   .Parameter remove 
    causes the function to remove the user 
   .Notes 
    NAME:  Set-LocalGroup 
    AUTHOR: ed wilson, msft 
    LASTEDIT: 06/29/2011 10:23:53 
    KEYWORDS: Local Account Management, Users, Groups 
    HSG: HSG-06-30-11 
   .Link 
     Http://www.ScriptingGuys.com/blog 
 #Requires -Version 2.0 
 #> 
 [CmdletBinding()] 
 Param( 
  [Parameter(Position=0, 
      Mandatory=$True, 
      ValueFromPipeline=$True)] 
  [string]$userName, 
  [Parameter(Position=1, 
      Mandatory=$True, 
      ValueFromPipeline=$True)] 
  [string]$GroupName, 
  [string]$computerName = $env:ComputerName, 
  [Parameter(ParameterSetName='addUser')] 
  [switch]$add, 
  [Parameter(ParameterSetName='removeuser')] 
  [switch]$remove 
 ) 
 $group = [ADSI]"WinNT://$ComputerName/$GroupName,group" 
 if($add) 
  { 
   $group.add("WinNT://$ComputerName/$UserName") 
  } 
  if($remove) 
   { 
   $group.remove("WinNT://$ComputerName/$UserName") 
   } 
} #end function Set-LocalGroup 
 
Function Set-LocalUserPassword 
{ 
 <# 
   .Synopsis 
    This function changes a local user password  
   .Description 
    This function changes a local user password 
   .Example 
    Set-LocalUserPassword -userName "ed" -password "newpassword" 
    Changes a local user named ed password to newpassword. 
   .Parameter ComputerName 
    The name of the computer upon which to change the user's password 
   .Parameter UserName 
    The name of the user for which to change the password 
   .Parameter password 
    The new password for the user 
   .Notes 
    NAME:  Set-LocalUserPassword 
    AUTHOR: ed wilson, msft 
    LASTEDIT: 06/29/2011 10:07:42 
    KEYWORDS: Local Account Management, Users 
    HSG: HSG-06-30-11 
   .Link 
     Http://www.ScriptingGuys.com/blog 
 #Requires -Version 2.0 
 #> 
 [CmdletBinding()] 
 Param( 
  [Parameter(Position=0, 
      Mandatory=$True, 
      ValueFromPipeline=$True)] 
  [string]$userName, 
  [Parameter(Position=1, 
      Mandatory=$True, 
      ValueFromPipeline=$True)] 
  [string]$password, 
  [string]$computerName = $env:ComputerName 
 ) 
 $user = [ADSI]"WinNT://$computerName/$username,user" 
 $user.setpassword($password)  
 $user.SetInfo() 
} #end function Set-LocalUserPassword 

function Set-LocalUser 
{ 
  <# 
   .Synopsis 
    Enables or disables a local user  
   .Description 
    This function enables or disables a local user 
   .Example 
    Set-LocalUser -userName ed -disable 
    Disables a local user account named ed 
   .Example 
    Set-LocalUser -userName ed -password Password 
    Enables a local user account named ed and gives it the password password  
   .Parameter UserName 
    The name of the user to either enable or disable 
   .Parameter Password 
    The password of the user once it is enabled 
   .Parameter Description 
    A description to associate with the user account 
   .Parameter Enable 
    Enables the user account 
   .Parameter Disable 
    Disables the user account 
   .Parameter ComputerName 
    The name of the computer on which to perform the action 
   .Notes 
    NAME:  Set-LocalUser 
    AUTHOR: ed wilson, msft 
    LASTEDIT: 06/29/2011 12:40:43 
    KEYWORDS: Local Account Management, Users 
    HSG: HSG-6-30-2011 
   .Link 
     Http://www.ScriptingGuys.com/blog 
 #Requires -Version 2.0 
 #> 
 [CmdletBinding()] 
 Param( 
  [Parameter(Position=0, 
      Mandatory=$True, 
      ValueFromPipeline=$True)] 
  [string]$userName, 
  [Parameter(Position=1, 
      Mandatory=$True, 
      ValueFromPipeline=$True, 
      ParameterSetName='EnableUser')] 
  [string]$password, 
  [Parameter(ParameterSetName='EnableUser')] 
  [switch]$enable, 
  [Parameter(ParameterSetName='DisableUser')] 
  [switch]$disable, 
  [string]$computerName = $env:ComputerName, 
  [string]$description = "modified via powershell" 
 ) 
 $EnableUser = 512 # ADS_USER_FLAG_ENUM enumeration value from SDK 
 $DisableUser = 2  # ADS_USER_FLAG_ENUM enumeration value from SDK 
 $User = [ADSI]"WinNT://$computerName/$userName,User" 
  
 if($enable) 
  { 
      $User.setpassword($password) 
      $User.description = $description 
      $User.userflags = $EnableUser 
      $User.setinfo() 
  } #end if enable 
 if($disable) 
  { 
      $User.description = $description 
      $User.userflags = $DisableUser 
      $User.setinfo() 
  } #end if disable 
} #end function Set-LocalUser 
 
Function Remove-LocalUser 
{ 
 <# 
   .Synopsis 
    This function deletes a local user  
   .Description 
    This function deletes a local user 
   .Example 
    Remove-LocalUser -userName "ed"  
    Removes a new local user named ed.  
   .Parameter ComputerName 
    The name of the computer upon which to delete the user 
   .Parameter UserName 
    The name of the user to delete 
   .Notes 
    NAME:  Remove-LocalUser 
    AUTHOR: ed wilson, msft 
    LASTEDIT: 06/29/2011 10:07:42 
    KEYWORDS: Local Account Management, Users 
    HSG: HSG-06-30-11 
   .Link 
     Http://www.ScriptingGuys.com/blog 
 #Requires -Version 2.0 
 #> 
 [CmdletBinding()] 
 Param( 
  [Parameter(Position=0, 
      Mandatory=$True, 
      ValueFromPipeline=$True)] 
  [string]$userName, 
  [string]$computerName = $env:ComputerName 
 ) 
 $User = [ADSI]"WinNT://$computerName" 
 $user.Delete("User",$userName) 
} #end function Remove-LocalUser 
 
Function Remove-LocalGroup 
{ 
 <# 
   .Synopsis 
    This function deletes a local group  
   .Description 
    This function deletes a local group 
   .Example 
    Remove-LocalGroup -GroupName "mygroup"  
    Creates a new local group named mygroup.  
   .Parameter ComputerName 
    The name of the computer upon which to delete the group 
   .Parameter GroupName 
    The name of the Group to delete 
   .Notes 
    NAME:  Remove-LocalGroup 
    AUTHOR: ed wilson, msft 
    LASTEDIT: 06/29/2011 10:07:42 
    KEYWORDS: Local Account Management, Groups 
    HSG: HSG-06-30-11 
   .Link 
     Http://www.ScriptingGuys.com/blog 
 #Requires -Version 2.0 
 #> 
 [CmdletBinding()] 
 Param( 
  [Parameter(Position=0, 
      Mandatory=$True, 
      ValueFromPipeline=$True)] 
  [string]$GroupName, 
  [string]$computerName = $env:ComputerName 
 ) 
 $Group = [ADSI]"WinNT://$computerName" 
 $Group.Delete("Group",$GroupName) 
} #end function Remove-LocalGroup 
 
function Test-IsAdministrator 
{ 
    <# 
    .Synopsis 
        Tests if the user is an administrator 
    .Description 
        Returns true if a user is an administrator, false if the user is not an administrator         
    .Example 
        Test-IsAdministrator 
    #>    
    param()  
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent() 
    (New-Object Security.Principal.WindowsPrincipal $currentUser).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator) 
} #end function Test-IsAdministrator


Export-ModuleMember -function Get-LocalUser
Export-ModuleMember -function Get-LocalGroup
Export-ModuleMember -function Get-LocalGroupMembership
Export-ModuleMember -function Get-DomainGroupMembership
Export-ModuleMember -function Get-LocalGroupAllMembers 
Export-ModuleMember -function New-LocalUser 
Export-ModuleMember -function New-LocalGroup
Export-ModuleMember -function Set-LocalUser 
Export-ModuleMember -function Set-LocalUserPassword
Export-ModuleMember -function Set-LocalGroup
Export-ModuleMember -function Remove-LocalUser
Export-ModuleMember -function Remove-LocalGroup
Export-ModuleMember -function Test-IsAdministrator