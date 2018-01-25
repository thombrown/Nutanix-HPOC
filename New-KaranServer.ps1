#https://portal.nutanix.com/#/page/docs/details?targetId=Nutanix-Calm-Admin-Operations-Guide-v10:nuc-installing-karan-service-t.html
#Powershell 3.0 or onwards should be installed on the Karan server.
#.Net framework 4.0 or 4.5 should be installed on the Karan server.

enable-psremoting
set-executionpolicy remotesigned
set-Item wsman:\localhost\Client\TrustedHosts -Value *

#Download Karan executable
$KaranVersion = "1.6.0"
$KaranEXE = "Karan-1.6.0.0.exe"
    $url = "http://download.nutanix.com/calm/Karan/$KaranVersion/$KaranEXE"
    $output = "C:\$KaranEXE"

    (New-Object System.Net.WebClient).DownloadFile($url, $output)

    Write-Output "Karan executable downloaded to C:\"

Start-Process -FilePath "C:\$KaranEXE" -Wait

Start-Service -Name "Karan"





