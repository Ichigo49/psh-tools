function Test-OnlineFast {
	<#
        .SYNOPSIS
            Quickly Ping computers
            
        .DESCRIPTION
            This function use WMI to ping computers
            
        .PARAMETER ComputerName
            One or more computers to query
            
        .PARAMETER TimeoutMillisec
            Specify the time out in Millisecond (that is what it makes the ping fast)
            
        .EXAMPLE
            Test-OnlineFast -ComputerName microsoft.com, google.de
    
            Address       StatusCode
            -------       ----------
            google.de              0
            microsoft.com      11010  

            Description
            -----------
            A status code of “0” indicates a response: the system is online. Any other status code indicates failure.

        .EXAMPLE 
            $ComputerName = 1..255 | ForEach-Object { "10.62.13.$_" }
    
            PS> Test-OnlineFast -ComputerName $ComputerName

            Address      StatusCode
            -------      ----------
            10.62.13.1        11010
            10.62.13.10           0
            10.62.13.100          0
            10.62.13.101      11010
            10.62.13.102      11010 
            (...)
            
            Description
            -----------
            Here is an example that pings 200 IP addresses and takes just a few seconds:

        .NOTES
            Version			: 1.0
            Author 			: Mathieu ALLEGRET
            Date			: 20/02/2017
            Purpose/Change	: Codes comes from Idera Community
            URL             : http://community.idera.com/powershell/powertips/b/tips/posts/creating-highspeed-ping-part-4

	#>
    param
    (
        [Parameter(Mandatory)]
        [string[]]
        $ComputerName,
 
        $TimeoutMillisec = 1000
    )
    
    # convert list of computers into a WMI query string
    $query = $ComputerName -join "' or Address='"
 
    Get-WmiObject -Class Win32_PingStatus -Filter "(Address='$query') and timeout=$TimeoutMillisec" | Select-Object -Property Address, StatusCode
}