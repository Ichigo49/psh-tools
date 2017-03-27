###########################################################################
#
# NAME: Update-sysinternals.ps1
#
# AUTHOR:  gastone canali
#
# COMMENT: 
#
# VERSION HISTORY:
# 1.0    10/03/2012 - Initial release
# 1.0.1  27/12/2016 - added some comment
###########################################################################

function Update-Sysinternals ($ToolsLocalDir = "c:\temp\sys")  
{ 
	if (Test-Path $ToolsLocalDir){ 
   		cd $ToolsLocalDir
   		$DebugPreference = "SilentlyContinue"
   		$wc = new-object System.Net.WebClient
   		$userAgent = "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.2;)"
   		$wc.Headers.Add("user-agent", $userAgent)
   		$ToolsUrl = "http://live.sysinternals.com/tools"
   		$toolsBlock="<pre>.*</pre>"
   		$WebPageCulture = New-Object System.Globalization.CultureInfo("en-us")
   		$Tools = @{}
   		$ToolsPage = $wc.DownloadString($ToolsUrl)
   		$matches=[string] $ToolsPage |select-string -pattern  "$ToolsBlock" -AllMatches
   		foreach($match in $matches.Matches) {	
		
	    	$txt = ( ($match.Value  -replace "</A><br>", "`r`n") -replace  "<[^>]*?>","")
	    	foreach($lines in $txt.Split("`r`n")){
	        	$line=$lines|select-string  -NotMatch -Pattern "To Parent|^$|&lt;dir&gt;"
	        	if ($line -ne $null){
		        	$date=(([string]$line).substring(0,38)).trimstart(" ") -replace "  "," "
		         	$file=([string]$line).substring(52,(([string]$line).length-52))
                 	#Friday, May 30, 2008  4:55 PM          668 About_This_Site.txt
		         	$Tools["$file"]= [datetime]::ParseExact($date,"f",$WebPageCulture)
	        	}
	    	}
    	}

    	$Tools.keys|
		ForEach-Object {
        	$NeedUpdate=$false
	    	if (Test-Path $_)
	    	{
	        	$SubtractSeconds = New-Object System.TimeSpan 0, 0, 0, ((dir $_).lastWriteTime).second, 0
	    		$LocalFileDate= ( (dir $_).lastWriteTime ).Subtract( $SubtractSeconds )
	    		$needupdate=(($tools[$_]).touniversaltime() -lt $LocalFileDate.touniversaltime())
	    	} else {$NeedUpdate=$true}
	    	if ( $NeedUpdate ) 
	    	{
		    	Try {
	            		$wc.DownloadFile("$ToolsUrl/$_","$ToolsLocalDir\$_" )
	            		$f=dir "$ToolsLocalDir\$_"
	            		$f.lastWriteTime=($tools[$_])
						"Updated $_"
		       		}
		    	catch { Write-debug "An error occurred: $_" }
	    	} 
    	} 
  	}
}