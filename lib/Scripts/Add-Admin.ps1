function Log {
<# 
 .Synopsis
  Function to log input string to file and display it to screen

 .Description
  Function to log input string to file and display it to screen. Log entries in the log file are time stamped. Function allows for displaying text to screen in different colors.

 .Parameter String
  The string to be displayed to the screen and saved to the log file

 .Parameter Color
  The color in which to display the input string on the screen
  Default is White
  Valid options are
    Black
    Blue
    Cyan
    DarkBlue
    DarkCyan
    DarkGray
    DarkGreen
    DarkMagenta
    DarkRed
    DarkYellow
    Gray
    Green
    Magenta
    Red
    White
    Yellow

 .Parameter LogFile
  Path to the file where the input string should be saved.
  Example: c:\log.txt
  If absent, the input string will be displayed to the screen only and not saved to log file

 .Example
  Log -String "Hello World" -Color Yellow -LogFile c:\log.txt
  This example displays the "Hello World" string to the console in yellow, and adds it as a new line to the file c:\log.txt
  If c:\log.txt does not exist it will be created.
  Log entries in the log file are time stamped. Sample output:
    2014.08.06 06:52:17 AM: Hello World

 .Example
  Log "$((Get-Location).Path)" Cyan
  This example displays current path in Cyan, and does not log the displayed text to log file.

 .Example 
  "Java process ID is $((Get-Process -Name java).id )" | log -color Yellow
  Sample output of this example:
    "Java process ID is 4492" in yellow

 .Example
  "Drive 'd' on VM 'CM01' is on VHDX file '$((Get-SBVHD CM01 d).VHDPath)'" | log -color Green -LogFile D:\Sandbox\Serverlog.txt
  Sample output of this example:
    Drive 'd' on VM 'CM01' is on VHDX file 'D:\VMs\Virtual Hard Disks\CM01_D1.VHDX'
  and the same is logged to file D:\Sandbox\Serverlog.txt as in:
    2014.08.06 07:28:59 AM: Drive 'd' on VM 'CM01' is on VHDX file 'D:\VMs\Virtual Hard Disks\CM01_D1.VHDX'

 .Link
  https://superwidgets.wordpress.com/category/powershell/

 .Notes
  Function by Sam Boutros
  v1.0 - 08/06/2014

#>

    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='Low')] 
    Param(
        [Parameter(Mandatory=$true,
                   ValueFromPipeLine=$true,
                   ValueFromPipeLineByPropertyName=$true,
                   Position=0)]
            [String]$String, 
        [Parameter(Mandatory=$false,
                   Position=1)]
            [ValidateSet("Black","Blue","Cyan","DarkBlue","DarkCyan","DarkGray","DarkGreen","DarkMagenta","DarkRed","DarkYellow","Gray","Green","Magenta","Red","White","Yellow")]
            [String]$Color = "White", 
        [Parameter(Mandatory=$false,
                   Position=2)]
            [String]$LogFile
    )

    write-host $String -foregroundcolor $Color 
    if ($LogFile.Length -gt 2) {
        ((Get-Date -format "yyyy.MM.dd hh:mm:ss tt") + ": " + $String) | out-file -Filepath $Logfile -append
    } else {
        Write-Verbose "Log: Missing -LogFile parameter. Will not save input string to log file.."
    }
}

function Add-Admin {
<# 
 .Synopsis
  Function to add local or domain user(s) to local Administrators group on one or many computers

 .Description
  Function to add local or domain user(s) to local Administrators group on one or many computers.
  The script uses ping/ICMP to check if target computer(s) are online. If response to ping/ICMP 
  is disabled on a target computer, the script will skip it.
  The script logs steps taken and results in a log file.

 .Parameter ComputerName
  Computer name(s) where the script will add local admin account

 .Parameter CurrentAdmin
  This can be an existing local admin account on the PCs or domain admin like "MyDomain\MyAdmin"
  This defaults to the account running this script

 .Parameter NewAdmin
  New user name(s) to be made member of the Administrators group on target computer(s)
  This can be a domain user account such as "domain\user", 
  or a local user account like "newadmin"
  If a local user account is specified and it did not exist, the script will create it.
  If a domain user account is specified and it did not exist, the script will NOT create it.
  
 .Parameter NewAdminPassword
  New user password to be setup as local admin on target computer(s)
  Must meet minimum password complexity on each computer in'ComputerName'. 
  This will be saved to the log file (clear text).
  If absent, script assumes "Temp-Pass5"
  If adding a domain user to local Administrators group, this parameter is ignored.

 .Parameter LogFile
  Path to the file where the script will save its progress steps

 .Example
  Add-Admin -ComputerName V-2012r2-vbr1 -NewAdmin Sam7 
  This creates a local user 'Sam7' on computer 'V-2012r2-vbr1', gives it 'Temp-Pass5' password
  and makes it a member of the local Administrators group

 .Example
  Add-Admin -ComputerName V-2012r2-vbr1,NoThere -NewAdmin Sam8 -NewAdminPassword New33One!!  
  This creates a local user 'Sam8' on computers 'V-2012r2-vbr1' and 'NoThere', 
  gives it 'New33One!!' password,
  and makes it a member of the local Administrators group

 .Example
  Add-Admin -ComputerName (Get-Content ".\computerlist.txt") -NewAdmin Sam9 -NewAdminPassword New33One!!  
  This creates a local user 'Sam9' on each of the computers listed in the ".\computerlist.txt" file, 
  gives it 'New33One!!' password,
  and makes it a member of the local Administrators group

 .Example
  Add-Admin -ComputerName V-2012r2-vbr1 -NewAdmin domain\samb
  This adds domain user 'domain\samb' to the local Administrators group on 'V-2012r2-vbr1'

 .Link
  https://superwidgets.wordpress.com/category/powershell/

 .Notes
  Function by Sam Boutros
  v2 - 11/09/2014

#>

    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')] 
    Param(
        [Parameter(Mandatory=$true,
                   ValueFromPipeLine=$true,
                   ValueFromPipeLineByPropertyName=$true,
                   Position=0)]
            [String[]]$ComputerName, 
        [Parameter(Mandatory=$true,
                   Position=1)]
            [String[]]$NewAdmin, 
        [Parameter(Mandatory=$false,
                   Position=2)]
            [String]$NewAdminPassword = "P@ssw0rd!", 
        [Parameter(Mandatory=$false,
                   Position=3)]
            [String]$CurrentAdmin = "$env:USERDOMAIN\$env:USERNAME", 
        [Parameter(Mandatory=$false,
                   Position=4)]
            [String]$LogFile = ".\Add-Admin_$(Get-Date -format yyyyMMdd_hhmmsstt).txt"
    )

    if (-not (Test-Path -Path ".\CurrentCred.txt")) {
        Read-Host ("Enter the pwd for current admin: '$CurrentAdmin' to be encrypted and saved to '.\CurrentCred.txt' for future script use:") -assecurestring | 
            convertfrom-securestring | out-file .\CurrentCred.txt
    }
    $Pwd = Get-Content .\CurrentCred.txt | convertto-securestring
    $CurrentCred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $CurrentAdmin, $Pwd

    foreach ($Computer in $ComputerName) {
        log "Processing computer '$Computer', admin(s) '$($NewAdmin -join ", ")'" Green $LogFile
        if (Test-Connection -ComputerName $Computer -Count 2 -ErrorAction SilentlyContinue) {
            $Group = [ADSI]"WinNT://$Computer/Administrators"
            $AllAdmins = @($Group.Invoke("Members")) |
                % {$_.GetType().InvokeMember("Name", 'GetProperty', $null, $_, $null)}
            $Group = Get-CimInstance -ClassName Win32_Group -ComputerName $Computer -Filter "Name = 'Administrators'"
            $LocalAdmins = (Get-CimAssociatedInstance -InputObject $Group -ComputerName $Computer -ResultClassName Win32_UserAccount).Name 
            $DomainAdmins = $AllAdmins | Where { $LocalAdmins -notcontains $_ } 

            foreach ($AdminName in $NewAdmin) {
                if ($AdminName.Contains("\")) { # Domain account
                    $NewAdminDomain = $AdminName.Split("\")[0]
                    $NewAdminName   = $AdminName.Split("\")[1]
                    if ($NewAdminDomain -eq $env:USERDOMAIN) {
                        if ($NewAdminName -in $DomainAdmins) {
                            log "  Domain user '$AdminName' is already a member of Administrators group on '$Computer', skipping.." Yellow $LogFile
                        } else {
                            if (([adsisearcher]"(samaccountname=$NewAdminName)").findone()) { # Exists in AD
                                try {
                                    ([ADSI]"WinNT://$Computer/Administrators,group").Invoke('Add', "WinNT://$NewAdminDomain/$NewAdminName") 
                                    log "  Added '$AdminName' to Administrators group on '$Computer'" Green $LogFile
                                } catch {
                                    log "  Failed to add '$AdminName' to Administrators group on '$Computer'" Magenta $LogFile
                                }
                            } else {
                                log "  Domain user '$AdminName' not found in current domain '$env:USERDOMAIN', skipping.." Yellow $LogFile
                            }
                        }
                    } else {
                        log "  This script can only process domain users of the current domain '$env:USERDOMAIN', skipping.." Yellow $LogFile
                    }
                } else { # Local account
                    if ($AdminName -in $LocalAdmins) {
                        log "  Local user '$AdminName' is already a member of Administrators group on '$Computer', skipping.." Yellow $LogFile
                    } else {
                        $AdminExists = $False
                        $objComputer = [ADSI]("WinNT://$Computer,computer")
                        $colUsers = ($objComputer.psbase.children | 
                            Where-Object {$_.psBase.schemaClassName -eq "User"} | 
                                Select-Object -expand Name)
                        if ($colUsers -contains $AdminName) { 
                            log "  Local user '$AdminName' already exists on '$Computer'" Green $LogFile
                            $AdminExists = $true
                        } else { 
                            try {
                                $objUser = ([ADSI]"WinNT://$Computer").Create("User", $AdminName)
                                $objUser.SetPassword($NewAdminPassword)
                                $objUser.SetInfo() 
                                log "  Created local user '$AdminName' on '$Computer'" Green $LogFile
                                $AdminExists = $true
                            } catch {
                                log "  Failed to create local user '$AdminName' on '$Computer'," Magenta $LogFile
                                log "    Verify that '$NewAdminPassword' meets minimum password complexity requirements." Magenta $LogFile
                            }
                        }    
                        if ($AdminExists) {
                            try {
                                ([ADSI]"WinNT://$Computer/Administrators,group").Invoke('Add', "WinNT://$Computer/$AdminName") 
                                log "  Added local user '$AdminName' to Administrators group on '$Computer'" Green $LogFile
                            } catch {
                                log "  Failed to Add local user '$AdminName' to Administrators group on '$Computer'" Magenta $LogFile
                            }
                        }
                    }
                }
            }

        } else {
            log "Computer '$Computer' is offline or cannot be contacted, skipping.." Magenta $LogFile
        }
    }
}