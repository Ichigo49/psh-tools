#add a border around a string of text

Function Add-Border {
<#
.Synopsis
Create a text border around a string.

.Description
This command will create a character or text based border around a line of text. You might use this to create a formatted text report or to improve the display of information to the screen.

.Parameter Text
A single line of text that will be wrapped in a border.

.Parameter Character
The character to use for the border. It must be a single character.

.Parameter InsertBlanks
Insert blank lines before and after the text. The default behavior is to create a border box close to the text. See examples.

.Parameter Tab
Insert the specified number of tab characters before the result.

.Example
PS C:\> add-border "PowerShell Wins!"
********************
* PowerShell Wins! *
********************

.Example
PS C:\> add-border "PowerShell Wins!" -tab 1
    ********************
    * PowerShell Wins! *
    ********************
    
.Example
PS C:\> add-border "PowerShell Wins!" -character "-" -insertBlanks
--------------------
-                  -
- PowerShell Wins! -
-                  -
--------------------

#>
[CmdletBinding()]
Param(
 # The string of text to process
 [Parameter(Position = 0, Mandatory,ValueFromPipeline)]
 [ValidateNotNullOrEmpty()]
 [string]$Text,

 # The character to use for the border. It must be a single character.
 [ValidateNotNullOrEmpty()]
 [validateScript({$_.length -eq 1})]
 [string]$Character = "*",

 # add blank lines before and after text
 [Switch]$InsertBlanks,
 
 # insert X number of tabs
 [int]$Tab = 0
)

Begin {
    Write-Verbose "[$((Get-Date).TimeofDay) BEGIN  ] Starting $($myinvocation.mycommand)"
} #begin

Process {
    Write-Verbose "[$((Get-Date).TimeofDay) PROCESS] Processing '$text'"
    #get length of text
    $len = $text.Length
    
    Write-Verbose "[$((Get-Date).TimeofDay) PROCESS] Using a length of $len"
    #define a horizontal line
    $line = $Character * ($len+4)
	
	$tabs = "`t"*$tab
	
    if ($insertBlanks) {
	    Write-Verbose "[$((Get-Date).TimeofDay) PROCESS] Inserting blank lines"
		
        $body = @"
$tabs$character $((" ")*$len) $character
$tabs$Character $text $Character
$tabs$character $((" ")*$len) $character
"@
    }    
    else {
        $body = "$tabs$Character $text $Character"
    }

$out = @"
$tabs$line
$body
$tabs$line
"@
    #write the result to the pipeline
    $out
} #process

End {
    Write-Verbose "[$((Get-Date).TimeofDay) END    ] Ending $($myinvocation.mycommand)"
} #end

} #close function
