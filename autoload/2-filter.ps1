#Convertir bytes en KB / MB / GB / TB / PB
Filter ConvertTo-KMG 
{
	$bytecount = $_
		switch ([math]::truncate([math]::log($bytecount,1024))) 
		{
			0 {"$bytecount Bytes"}
			1 {"{0:n2} KB" -f ($bytecount / 1kb)}
			2 {"{0:n2} MB" -f ($bytecount / 1mb)}
			3 {"{0:n2} GB" -f ($bytecount / 1gb)}
			4 {"{0:n2} TB" -f ($bytecount / 1tb)}
			Default {"{0:n2} PB" -f ($bytecount / 1pb)}
		}
}

#equivalent grep, a utiliser comme suit :
#ll | match "sys_" => list les objets qui contienent "sys_"
filter match( $reg )
{
    if ($_.tostring() -match $reg)
        {
			$_
		}
}

# equivalent grep -v, a utiliser comme suit :
#ll | exclude "sys_" => list les objets qui NE contienent PAS "sys_"
filter exclude( $reg )
{
    if (-not ($_.tostring() -match $reg))
        {
			$_
		}
}
