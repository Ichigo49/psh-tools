function Get-SystemInfo {
param(
	[string]$computer="."
)	
	Write-Host "System:"
	$sys = Get-System -computer $computer
	$sys | Format-List
    
    Write-Host "Computer System:"
    $csys = Get-ComputerSystem -computer $computer
	$csys | Format-List
 
    Write-Host "Computer Bus:"
    $cbus = Get-Bus -computer $computer
	$cbus | Format-List
       
	Write-Host "CPU:"
	$cpu = Get-CPU -computer $computer
	$cpu 
		
	Write-Host "Operating System:"
	$os = Get-OSInfo -computer $computer
	$os 
	
	Write-Host "BIOS:"
	$bios = Get-BIOSInfo  -computer $computer
	$bios 
	"BIOS Characteristics:"
	$bchars  = Get-BIOSInfo  -computer $computer -bioscharacteristics
	$bchars
	
    ""
    Write-Host "Device, Memory and IRQ"
    $mrq = Get-MemIrq -computer $computer
    $mrq 
    
    ""
    Write-Host "CD Drive:"
    $cd = Get-CDROM
    $cd
    
    ""
	Write-Host "Page File:"
	$pf = Get-PageFile  -computer $computer
	$pf
	
	""
	Write-Host "Time Zone:"
	$tz = Get-TimeZone  -computer $computer
	$tz 
	
}
function Get-System {
param(
	[string]$computer="."
)
Get-WmiObject -Class Win32_ComputerSystemProduct -ComputerName $computer |
	Select Vendor, Name, IdentifyingNumber
}
function Get-ComputerSystem {
param(
	[string]$computer="."
)
Get-WmiObject -Class Win32_ComputerSystem -ComputerName $computer |
	Select Domain, 
    @{Name="Domain Role";Expression={ Get-DomainRole $_.DomainRole }}, 
    Name, 
    @{Name="Total Physical Memory";Expression={[math]::round($($_.TotalPhysicalMemory/1GB), 2)}} 
}
function Get-CPU {
param(
	[string]$computer="."
)
Get-WmiObject -Class Win32_Processor -ComputerName $computer |
	Select Name, Description, MaxClockSpeed, L2CacheSize, NumberOfCores, NumberOfLogicalProcessors, SocketDesignation, ExtClock
}
function Get-OSInfo {
param(
	[string]$computer="."
)
	Get-WmiObject	-Class Win32_OperatingSystem -ComputerName $computer |
	Select Caption, ServicePackMajorVersion, ServicePackMinorVersion, BuildNumber, 
	@{Name="Code Set";Expression={ Get-CodeSet $_.CodeSet }},
	@{Name="Country Code";Expression={ Get-CountryCode $_.CountryCode }}, 
	@{Name="Install Date";Expression={ $_.ConvertToDateTime( $_.InstallDate) }}, 
	@{Name="Locale ";Expression={ Get-Locale $_.Locale }},
	OSArchitecture, 
	@{Name="OS Language";Expression={ Get-Language $_.OSLanguage }},
	@{Name="OS Type";Expression={ Get-OSType $_.OSType }},
	BootDevice, SystemDevice,Version, WindowsDirectory
}
function Get-BIOSInfo {
param(
	[string]$computer=".",
	[switch]$bioscharacteristics
)	
	if ($bioscharacteristics) {
		Get-WmiObject -Class Win32_Bios | Select -ExpandProperty BiosCharacteristics |
		foreach {Get-BIOSCode $_}
	}
	else {
		Get-WmiObject -Class Win32_Bios -ComputerName $computer | 
		Select  BuildNumber, CurrentLanguage, InstallableLanguages, Manufacturer, Name, PrimaryBIOS, 
		@{Name="Release Date";Expression={ $_.ConvertToDateTime( $_.ReleaseDate) }},
		SerialNumber, SMBIOSBIOSVersion, SMBIOSMajorVersion, SMBIOSMinorVersion, SMBIOSPresent, Status, Version 
	}	
}
function Get-CDROM {
param(
	[string]$computer="."
)	
		Get-WmiObject -Class Win32_CDROMdrive -ComputerName $computer | 
		Select  Drive, Manufacturer, Name
}
function Get-PageFile {
param(
	[string]$computer="."
)	
		Get-WmiObject -Class Win32_PageFileUsage  -ComputerName $computer | 
		Select  @{Name="File";Expression={ $_.Name }},
		@{Name="Base Size(MB)"; Expression={$_.AllocatedBaseSize}},
		@{Name="Peak Size(MB)"; Expression={$_.PeakUsage}},
		@{Name="Install Date";Expression={ $_.ConvertToDateTime( $_.InstallDate) }},
		TempPageFile
  }
function Get-TimeZone {
param(
	[string]$computer="."
)	
  Get-WmiObject -Class Win32_TimeZone  -ComputerName $computer | 
  Select Caption, StandardName, DayLightName, DayLightBias
} 

$bustype = DATA {
ConvertFrom-StringData -StringData @'
-1 = Undefined 
0 = Internal 
1 = ISA 
2 = EISA 
3 = MicroChannel 
4 = TurboChannel 
5 = PCI Bus 
6 =  VME Bus 
7 = NuBus 
8 = PCMCIA Bus 
9 = C Bus 
10 = MPI Bus 
11 = MPSA Bus 
12 = Internal Processor 
13 =  Internal Power Bus 
14 =  PNP ISA Bus 
15 =  PNP Bus 
16 =  Maximum Interface Type
'@
} 

function Get-Bus {
param(
	[string]$computer="."
)
Get-WmiObject -class Win32_Bus -ComputerName $computer | 
sort BusType, Busnum | select BusNum, 
@{Name="Bus type"; Expression={$bustype["$($_.BusType)"]}},
DeviceID, PNPDeviceID
}

function Get-MemIrq {
param(
	[string]$computer="."
)
$source = @"
public class sysirqram  {
public string Memory { get; set;}
public string Device { get; set;}
public string Status { get; set;}
public long IRQ { get; set;}
}
"@
Add-Type $source -Language CSharpVersion3

$data = @()
Get-WmiObject Win32_DeviceMemoryAddress -ComputerName $computer | 
foreach {

$name = $_.Name

 $query = "ASSOCIATORS OF {Win32_DeviceMemoryAddress.StartingAddress='$($_.StartingAddress)'} WHERE RESULTCLASS = Win32_PnPEntity"
 Get-WmiObject -ComputerName $computer -Query $query  | foreach {

  $qirq = "ASSOCIATORS OF {Win32_PnPEntity.DeviceID='$($_.PNPDeviceID)'} WHERE RESULTCLASS = Win32_IRQResource"
  $irqs  = Get-WmiObject -ComputerName $computer -Query $qirq | select IRQNumber -Unique
  
  $myobject = New-Object -TypeName sysirqram -Property @{ 
   Memory= $name;
   Device = $_.Name;
   Status = $_.Status;
   IRQ = $irqs.IRQNumber
  }  
  $data += $myobject
 }
}
$data 
}
 
#######################################################################################################
## helper functions
#######################################################################################################
function Get-OSType {
param(
	[int]$type
)
$ostype = DATA {
ConvertFrom-StringData -StringData @'
14 = MSDOS
15 = WIN3X
16 = WIN95
17 = WIN98
18 = WINNT
19 = WINCE
'@
}
$ostype["$($type)"]
}
##
## for language and locale settings see
## http://msdn.microsoft.com/en-us/goglobal/bb964664.aspx
##
function Get-Language {
param(
	[int]$type
)
$lang = DATA {
ConvertFrom-StringData -StringData @'
1078 = Afrikaans - South Africa
1052 = Albanian - Albania
1118 = Amharic - Ethiopia
1025 = Arabic - Saudi Arabia
5121 = Arabic - Algeria
15361 = Arabic - Bahrain
3073 = Arabic - Egypt
2049 = Arabic - Iraq
11265 = Arabic - Jordan
13313 = Arabic - Kuwait
12289 =	Arabic - Lebanon
4097 = Arabic - Libya
6145 = Arabic - Morocco
8193 = Arabic - Oman
16385 = Arabic - Qatar
10241 = Arabic - Syria
7169 = Arabic - Tunisia
14337 = Arabic - U.A.E.
9217 = Arabic - Yemen
1067 = Armenian - Armenia
1101 = Assamese
2092 = Azeri (Cyrillic)
1068 = Azeri (Latin)
1069 = Basque
1059 = Belarusian
1093 = Bengali (India)
2117 = Bengali (Bangladesh)
5146 = Bosnian (Bosnia/Herzegovina)
1026 = Bulgarian
1109 = Burmese
1027 = Catalan
1116 = Cherokee - United States
2052 = Chinese - People's Republic of China
4100 = Chinese - Singapore
1028 = Chinese - Taiwan
3076 = Chinese - Hong Kong SAR
5124 = Chinese - Macao SAR
1050 = Croatian
4122 = Croatian (Bosnia/Herzegovina)
1029 = Czech
1030 = Danish
1125 = Divehi
1043 = Dutch - Netherlands
2067 = Dutch - Belgium
1126 = Edo
1033 = English - United States
2057 = English - United Kingdom
3081 = English - Australia
10249 = English - Belize
4105 = English - Canada
9225 = English - Caribbean
15369 = English - Hong Kong SAR
16393 = English - India
14345 = English - Indonesia
6153 = English - Ireland
8201 = English - Jamaica
17417 = English - Malaysia
5129 = English - New Zealand
13321 = English - Philippines
18441 = English - Singapore
7177 = English - South Africa
11273 = English - Trinidad
12297 = English - Zimbabwe
1061 = Estonian
1080 = Faroese
1065 = Farsi
1124 = Filipino
1035 = Finnish
1036 = French - France
2060 = French - Belgium
11276 = French - Cameroon
3084 = French - Canada
9228 = French - Democratic Rep. of Congo
12300 = French - Cote d'Ivoire
15372 = French - Haiti
5132 = French - Luxembourg
13324 = French - Mali
6156 = French - Monaco
14348 = French - Morocco
58380 = French - North Africa
8204 = French - Reunion
10252 = French - Senegal
4108 = French - Switzerland
7180 = French - West Indies
1122 = Frisian - Netherlands
1127 = Fulfulde - Nigeria
1071 = FYRO Macedonian
2108 = Gaelic (Ireland)
1084 = Gaelic (Scotland)
1110 = Galician
1079 = Georgian
1031 = German - Germany
3079 = German - Austria
5127 = German - Liechtenstein
4103 = German - Luxembourg
2055 = German - Switzerland
1032 = Greek
1140 = Guarani - Paraguay
1095 = Gujarati
1128 = Hausa - Nigeria
1141 = Hawaiian - United States
1037 = Hebrew
1081 = Hindi
1038 = Hungarian
1129 = Ibibio - Nigeria
1039 = Icelandic
1136 = Igbo - Nigeria
1057 = Indonesian
1117 = Inuktitut
1040 = Italian - Italy
2064 = Italian - Switzerland
1041 = Japanese
1099 = Kannada
1137 = Kanuri - Nigeria
2144 = Kashmiri
1120 = Kashmiri (Arabic)
1087 = Kazakh
1107 = Khmer
1111 = Konkani
1042 = Korean
1088 = Kyrgyz (Cyrillic)
1108 = Lao
1142 = Latin
1062 = Latvian
1063 = Lithuanian
1086 = Malay - Malaysia
2110 = Malay - Brunei Darussalam
1100 = Malayalam
1082 = Maltese
1112 = Manipuri
1153 = Maori - New Zealand
1102 = Marathi
1104 = Mongolian (Cyrillic)
2128 = Mongolian (Mongolian)
1121 = Nepali
2145 = Nepali - India
1044 = Norwegian (Bokmål)
2068 = Norwegian (Nynorsk)
1096 = Oriya
1138 = Oromo
1145 = Papiamentu
1123 = Pashto
1045 = Polish
1046 = Portuguese - Brazil
2070 = Portuguese - Portugal
1094 = Punjabi
2118 = Punjabi (Pakistan)
1131 = Quecha - Bolivia
2155 = Quecha - Ecuador
3179 = Quecha - Peru
1047 = Rhaeto-Romanic
1048 = Romanian
2072 = Romanian - Moldava
1049 = Russian
2073 = Russian - Moldava
1083 = Sami (Lappish)
1103 = Sanskrit
1132 = Sepedi
3098 = Serbian (Cyrillic)
2074 = Serbian (Latin)
1113 = Sindhi - India
2137 = Sindhi - Pakistan
1115 = Sinhalese - Sri Lanka
1051 = Slovak
1060 = Slovenian
1143 = Somali
1070 = Sorbian
3082 = Spanish - Spain (Modern Sort)
1034 = Spanish - Spain (Traditional Sort)
11274 = Spanish - Argentina
16394 = Spanish - Bolivia
13322 = Spanish - Chile
9226 = Spanish - Colombia
5130 = Spanish - Costa Rica
7178 = Spanish - Dominican Republic
12298 = Spanish - Ecuador
17418 = Spanish - El Salvador
4106 = Spanish - Guatemala
18442 = Spanish - Honduras
22538 = Spanish - Latin America
2058 = Spanish - Mexico
19466 = Spanish - Nicaragua
6154 = Spanish - Panama
15370 = Spanish - Paraguay
10250 = Spanish - Peru
20490 = Spanish - Puerto Rico
21514 = Spanish - United States
14346 = Spanish - Uruguay
8202 = Spanish - Venezuela
1072 = Sutu
1089 = Swahili
1053 = Swedish
2077 = Swedish - Finland
1114 = Syriac
1064 = Tajik
1119 = Tamazight (Arabic)
2143 = Tamazight (Latin)
1097 = Tamil
1092 = Tatar
1098 = Telugu
1054 = Thai
2129 = Tibetan - Bhutan
1105 = Tibetan - People's Republic of China
2163 = Tigrigna - Eritrea
1139 = Tigrigna - Ethiopia
1073 = Tsonga
1074 = Tswana
1055 = Turkish
1090 = Turkmen
1152 = Uighur - China
1058 = Ukrainian
1056 = Urdu
2080 = Urdu - India
2115 = Uzbek (Cyrillic)
1091 = Uzbek (Latin)
1075 = Venda
1066 = Vietnamese
1106 = Welsh
1076 = Xhosa
1144 = Yi
1085 = Yiddish
1130 = Yoruba
1077 = Zulu
1279 = HID (Human Interface Device)
'@
}
$lang["$($type)"]
}
function Get-Locale {
param(
	[string]$type
)
$loc = DATA {
ConvertFrom-StringData -StringData @'
0436 = Afrikaans - South Africa
041c = Albanian - Albania
045e = Amharic - Ethiopia
0401 = Arabic - Saudi Arabia
1401 = Arabic - Algeria
3c01 = Arabic - Bahrain
0c01 = Arabic - Egypt
0801 = Arabic - Iraq
2c01 = Arabic - Jordan
3401 = Arabic - Kuwait
3001 = Arabic - Lebanon
1001 = Arabic - Libya
1801 = Arabic - Morocco
2001 = Arabic - Oman
4001 = Arabic - Qatar
2801 = Arabic - Syria
1c01 = Arabic - Tunisia
3801 = Arabic - U.A.E.
2401 = Arabic - Yemen
042b = Armenian - Armenia
044d = Assamese
082c = Azeri (Cyrillic)
042c = Azeri (Latin)
042d = Basque
0423 = Belarusian
0445 = Bengali (India)
0845 = Bengali (Bangladesh)
141A = Bosnian (Bosnia/Herzegovina)
0402 = Bulgarian
0455 = Burmese
0403 = Catalan
045c = Cherokee - United States
0804 = Chinese - People's Republic of China
1004 = Chinese - Singapore
0404 = Chinese - Taiwan
0c04 = Chinese - Hong Kong SAR
1404 = Chinese - Macao SAR
041a = Croatian
101a = Croatian (Bosnia/Herzegovina)
0405 = Czech
0406 = Danish
0465 = Divehi
0413 = Dutch - Netherlands
0813 = Dutch - Belgium
0466 = Edo
0409 = English - United States
0809 = English - United Kingdom
0c09 = English - Australia
2809 = English - Belize
1009 = English - Canada
2409 = English - Caribbean
3c09 = English - Hong Kong SAR
4009 = English - India
3809 = English - Indonesia
1809 = English - Ireland
2009 = English - Jamaica
4409 = English - Malaysia
1409 = English - New Zealand
3409 = English - Philippines
4809 = English - Singapore
1c09 = English - South Africa
2c09 = English - Trinidad
3009 = English - Zimbabwe
0425 = Estonian
0438 = Faroese
0429 = Farsi
0464 = Filipino
040b = Finnish
040c = French - France
080c = French - Belgium
2c0c = French - Cameroon
0c0c = French - Canada
240c = French - Democratic Rep. of Congo
300c = French - Cote d'Ivoire
3c0c = French - Haiti
140c = French - Luxembourg
340c = French - Mali
180c = French - Monaco
380c = French - Morocco
e40c = French - North Africa
200c = French - Reunion
280c = French - Senegal
100c = French - Switzerland
1c0c = French - West Indies
0462 = Frisian - Netherlands
0467 = Fulfulde - Nigeria
042f = FYRO Macedonian
083c = Gaelic (Ireland)
043c = Gaelic (Scotland)
0456 = Galician
0437 = Georgian
0407 = German - Germany
0c07 = German - Austria
1407 = German - Liechtenstein
1007 = German - Luxembourg
0807 = German - Switzerland
0408 = Greek
0474 = Guarani - Paraguay
0447 = Gujarati
0468 = Hausa - Nigeria
0475 = Hawaiian - United States
040d = Hebrew
0439 = Hindi
040e = Hungarian
0469 = Ibibio - Nigeria
040f = Icelandic
0470 = Igbo - Nigeria
0421 = Indonesian
045d = Inuktitut
0410 = Italian - Italy
0810 = Italian - Switzerland
0411 = Japanese
044b = Kannada
0471 = Kanuri - Nigeria
0860 = Kashmiri
0460 = Kashmiri (Arabic)
043f = Kazakh
0453 = Khmer
0457 = Konkani
0412 = Korean
0440 = Kyrgyz (Cyrillic)
0454 = Lao
0476 = Latin
0426 = Latvian
0427 = Lithuanian
043e = Malay - Malaysia
083e = Malay - Brunei Darussalam
044c = Malayalam
043a = Maltese
0458 = Manipuri
0481 = Maori - New Zealand
044e = Marathi
0450 = Mongolian (Cyrillic)
0850 = Mongolian (Mongolian)
0461 = Nepali
0861 = Nepali - India
0414 = Norwegian (Bokmål)
0814 = Norwegian (Nynorsk)
0448 = Oriya
0472 = Oromo
0479 = Papiamentu
0463 = Pashto
0415 = Polish
0416 = Portuguese - Brazil
0816 = Portuguese - Portugal
0446 = Punjabi
0846 = Punjabi (Pakistan)
046B = Quecha - Bolivia
086B = Quecha - Ecuador
0C6B = Quecha - Peru
0417 = Rhaeto-Romanic
0418 = Romanian
0818 = Romanian - Moldava
0419 = Russian
0819 = Russian - Moldava
043b = Sami (Lappish)
044f = Sanskrit
046c = Sepedi
0c1a = Serbian (Cyrillic)
081a = Serbian (Latin)
0459 = Sindhi - India
0859 = Sindhi - Pakistan
045b = Sinhalese - Sri Lanka
041b = Slovak
0424 = Slovenian
0477 = Somali
042e = Sorbian
0c0a = Spanish - Spain (Modern Sort)
040a = Spanish - Spain (Traditional Sort)
2c0a = Spanish - Argentina
400a = Spanish - Bolivia
340a = Spanish - Chile
240a = Spanish - Colombia
140a = Spanish - Costa Rica
1c0a = Spanish - Dominican Republic
300a = Spanish - Ecuador
440a = Spanish - El Salvador
100a = Spanish - Guatemala
480a = Spanish - Honduras
580a = Spanish - Latin America
080a = Spanish - Mexico
4c0a = Spanish - Nicaragua
180a = Spanish - Panama
3c0a = Spanish - Paraguay
280a = Spanish - Peru
500a = Spanish - Puerto Rico
540a = Spanish - United States
380a = Spanish - Uruguay
200a = Spanish - Venezuela
0430 = Sutu
0441 = Swahili
041d = Swedish
081d = Swedish - Finland
045a = Syriac
0428 = Tajik
045f = Tamazight (Arabic)
085f = Tamazight (Latin)
0449 = Tamil
0444 = Tatar
044a = Telugu
041e = Thai
0851 = Tibetan - Bhutan
0451 = Tibetan - People's Republic of China
0873 = Tigrigna - Eritrea
0473 = Tigrigna - Ethiopia
0431 = Tsonga
0432 = Tswana
041f = Turkish
0442 = Turkmen
0480 = Uighur - China
0422 = Ukrainian
0420 = Urdu
0820 = Urdu - India
0843 = Uzbek (Cyrillic)
0443 = Uzbek (Latin)
0433 = Venda
042a = Vietnamese
0452 = Welsh
0434 = Xhosa
0478 = Yi
043d = Yiddish
046a = Yoruba
0435 = Zulu
04ff = HID (Human Interface Device)
'@
}
$loc["$($type)"]
}
function Get-CodeSet {
param(
	[int]$type
)
## codeset info
## http://msdn.microsoft.com/en-us/goglobal/bb964654.aspx
$code = DATA {
ConvertFrom-StringData -StringData @'
437 = US
720 = Arabic
737 = Greek
775 = Baltic
850 = MultiLingual Latin I
852 = Latin II
855 = Cyrillic
857 = Turkish
858 = Multilingual Latin I + Euro
862 = Hebrew
866 = Russian
874 = Thai
932 = Japanese Shift-JIS
936 = Simplified Chinese GBK
949 = Korean
950 = Traditional Chinese Big5
1250 = Central Europe
1251 = Cyrillic
1252 = Latin I
1253 = Greek
1254 = Turkish
1255 = Hebrew
1256 = Arabic
1257 = Baltic
1258 = Vietnam
'@
}
$code["$($type)"]
}
function Get-CountryCode {
param(
	[int]$type
)
## country codes
##http://msdn.microsoft.com/en-us/library/dd387951(VS.85).aspx
$country = DATA {
ConvertFrom-StringData -StringData @'
1 = USA
2 = Canada
20 = Egypt
212 = Morocco
213 = Algeria
216 = Tunisia
218 = Libya
220 = Gambia
221 = Senegal Republic
222 = Mauritania
223 = Mali
224 = Guinea
225 = Cote D'Ivoire
226 = Burkina Faso
227 = Niger
228 = Togo
229 = Benin
230 = Mauritius
231 = Liberia
232 = Sierra Leone
233 = Ghana
234 = Nigeria
235 = Chad
236 = Central African Republic
237 = Cameroon
238 = Cape Verde Islands
239 = Sao Tome and Principe
240 = Equatorial Guinea
241 = Gabon
242 = Congo
243 = Congo(DRC)
244 = Angola
245 = Guinea-Bissau
246 = Diego Garcia
247 = Ascension Island
248 = Seychelle Islands
249 = Sudan
250 = Rwanda
251 = Ethiopia
252 = Somalia
253 = Djibouti
254 = Kenya
255 = Tanzania
256 = Uganda
257 = Burundi
258 = Mozambique
260 = Zambia
261 = Madagascar
262 = Reunion Island
263 = Zimbabwe
264 = Namibia
265 = Malawi
266 = Lesotho
267 = Botswana
268 = Swaziland
269 = Comoros
27 = South Africa
290 = St. Helena
291 = Eritrea
297 = Aruba
298 = Faroe Islands
299 = Greenland
30 = Greece
31 = Netherlands
32 = Belgium
33 = France
34 = Spain
350 = Gibraltar
351 = Portugal
352 = Luxembourg
353 = Ireland
354 = Iceland
355 = Albania
356 = Malta
357 = Cyprus
358 = Finland
359 = Bulgaria
36 = Hungary
370 = Lithuania
371 = Latvia
372 = Estonia
373 = Moldova
374 = Armenia
375 = Belarus
376 = Andorra
377 = Monaco
378 = San Marino
380 = Ukraine
381 = Serbia
385 = Croatia
386 = Slovenia
387 = Bosnia and Herzegovina
389 = F.Y.R.O.M. (Former Yugoslav Republic of Macedonia)
39 = Italy
40 = Romania
41 = Switzerland
420 = Czech Republic
421 = Slovak Republic
43 = Austria
44 = United Kingdom
45 = Denmark
46 = Sweden
47 = Norway
48 = Poland
49 = Germany
500 = Falkland Islands (Islas Malvinas)
501 = Belize
502 = Guatemala
503 = El Salvador
504 = Honduras
505 = Nicaragua
506 = Costa Rica
507 = Panama
508 = St. Pierre and Miquelon
509 = Haiti
51 = Peru
52 = Mexico
53 = Cuba
54 = Argentina
55 = Brazil
56 = Chile
57 = Colombia
58 = Bolivarian Republic of Venezuela
590 = Guadeloupe
591 = Bolivia
592 = Guyana
593 = Ecuador
594 = French Guiana
595 = Paraguay
596 = Martinique
597 = Suriname
598 = Uruguay
599 = Netherlands Antilles
60 = Malaysia
61 = Australia
62 = Indonesia
63 = Philippines
64 = New Zealand
65 = Singapore
66 = Thailand
670 = Saipan Island
671 = Guam
672 = Australian Antarctic Territory
673 = Brunei
674 = Nauru
675 = Papua New Guinea
676 = Tonga
677 = Solomon Islands
678 = Vanuatu
679 = Fiji Islands
680 = Palau
681 = Wallis and Futuna Islands
682 = Cook Islands
683 = Niue
684 = Territory of American Samoa
685 = Samoa
686 = Kiribati Republic
687 = New Caledonia
688 = Tuvalu
689 = French Polynesia
690 = Tokelau
691 = Micronesia
692 = Marshall Islands
7 = Russia
81 = Japan
82 = Korea (South)
84 = Vietnam
850 = Korea (North)
852 = Hong Kong SAR
853 = Macao SAR
855 = Cambodia
856 = Laos
86 = China
880 = Bangladesh
886 = Taiwan
90 = Turkey
91 = India
92 = Pakistan
93 = Afghanistan
94 = Sri Lanka
95 = Myanmar
960 = Maldives
961 = Lebanon
962 = Jordan
963 = Syria
964 = Iraq
965 = Kuwait
966 = Saudi Arabia
967 = Yemen
968 = Oman
971 = United Arab Emirates
972 = Israel
973 = Bahrain
974 = Qatar
975 = Bhutan
976 = Mongolia
977 = Nepal
98 = Iran
994 = Azerbaijan
995 = Georgia
'@
}
$country["$($type)"]
}
function Get-BIOSCode {
param(
	[int]$type
)
$bioschar = DATA {
ConvertFrom-StringData -StringData @'
3 = BIOS Characteristics Not Supported
4 = ISA is supported
5 = MCA is supported
6 = EISA is supported
7 = PCI is supported
8 = PC Card (PCMCIA) is supported
9 = Plug and Play is supported
10 = APM is supported
11 = BIOS is Upgradable (Flash)
12 = BIOS shadowing is allowed
13 = VL-VESA is supported
14 = ESCD support is available
15 = Boot from CD is supported
16 = Selectable Boot is supported
17 = BIOS ROM is socketed
18 = Boot From PC Card (PCMCIA) is supported
19 = EDD (Enhanced Disk Drive) Specification is supported
20 = Int 13h - Japanese Floppy for NEC 9800 1.2mb (3.5, 1k Bytes/Sector, 360 RPM) is supported
21 = Int 13h - Japanese Floppy for Toshiba 1.2mb (3.5, 360 RPM) is supported
22 = Int 13h - 5.25 / 360 KB Floppy Services are supported
23 = Int 13h - 5.25 /1.2MB Floppy Services are supported
24 = Int 13h - 3.5 / 720 KB Floppy Services are supported
25 = Int 13h - 3.5 / 2.88 MB Floppy Services are supported
26 = Int 5h, Print Screen Service is supported
27 = Int 9h, 8042 Keyboard services are supported
28 = Int 14h, Serial Services are supported
29 = Int 17h, printer services are supported
30 = Int 10h, CGA/Mono Video Services are supported
31 = NEC PC-98
32 = ACPI is supported
33 = USB Legacy is supported
34 = AGP is supported
35 = I2O boot is supported
36 = LS-120 boot is supported
37 = ATAPI ZIP Drive boot is supported
38 = 1394 boot is supported
39 = Smart Battery is supported
'@
}
$bioschar["$($type)"]
}
function Get-DomainRole {
param(
	[int]$type
)
$role = DATA {
ConvertFrom-StringData -StringData @'
0 = Standalone Workstation
1 = Member Workstation
2 = Standalone Server
3 = Member Server
4 = Backup Domain Controller
5 = Primary Domain Controller
'@
}
$role["$($type)"]
}

Export-ModuleMember -Function Get-SystemInfo
Export-ModuleMember -Function Get-System, Get-ComputerSystem,  Get-CPU, Get-OSInfo, Get-BIOSInfo
Export-ModuleMember -Function Get-CDROM,  Get-PageFile,  Get-TimeZone, Get-Bus, Get-MemIrq