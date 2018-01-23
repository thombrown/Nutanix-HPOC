#hardev.sanghera@nutanix.com
#Internal Use Only
#Provided as is and unsupported
#15Jan18
#
#Setup Acrive Directory on a freshly installed Windows 2012 R2 VM and
#add a set of AD Groups / Users for use with SSP and/or CALM
#
# This may look complicated but it's simple and requires little input from you - just run it 3 times or twice if you don't want the groups and users!
#
#You need:
#1. ***** A Nutaix Hosted PoC Cluster ===== This script assumes a lot about the datacenter - aimed at easily deploying AD for a POC
#2. A deployed W2K12R2 VM (you can now request deployed VMs via your (AHV) rx reservation booking page)
#3. This script copied to 2. above - copy it to c:\ - there will be 2 re-boots so it's easier to have it there, also it won't matter
#   if you're domain logged or local. Use RDP to copy the file to c:\ but run it from a Prism console - it's easier!
#3.1 On the VM to have AD deployed: You will need to 'Set-Executionpolicy RemoteSigned' (respond with Y) from a powershell window - STARTED IN ADMINISTRATOR MODE, to do this
#    right click on the 'Powershell' icon in the task bar and select 'Run as Administrator' (just the first time to set RemoteSigned and run this script the first time
#    You will run the script THREE times first two times as loca\Administrator and the last time as AD\Administrator - it remembers where it got to each time:
#    - 1st Run (verify POC number, static IP): Changes to a static IP, VM hostname to AD1 (reboots)
#    - 2nd Run (no input from you): Add AD Role and Management Tools, Configures Forest (reboots)
#    - 3rd Run (no input from you): Adds 3 security groups and two users to each group (no reboot)
#4. IP address scheme for your Hosted PoC - I have assumed the standard based on the name of the POC
#   - The last used address in a typical PoC is .37
#   - Will use .40 for the static IP address of the new AD server - you can change it though
#If you don't like any of the parameters go ahead and change them, break at your own risk!
# After running the script 3 times you will end up (assumig defaults):
# 1. A Windows 2012 R2 VM with hostname: AD1 and static IP address of a.b.c.40 (or whatever you chose)
# 2. An AD/DNS called POCnnn.local, eg. if you have POC086 then your AD/DNS would be POC086.local
# 3. AD Group: ntnx-admins with users uadmin1, uadmin2
# 4. AD Group: ntnx-projadmins with users uproj1, uproj2
# 5. AD Group: ntnx-devops with users udevops1, udevops2
# ALL PASSWORDS are nutanix/4u (all AD users, AD Administrator, SafeModeAdministrationPassword for AD) - change if you want.
#
#
# Variables / parameters 
$poc = "POC" #prefix for Hosted POCs
#The following array $adgroupsandusers MUST be symmetrical array, all rows must have the same number of entries.
$adgroupsandusers = ("ntnx-admins","uadmin1","uadmin2"),("ntnx-projadmin","uproj1","uproj2"),("ntnx-devops","udevops1","udevops2")
$plainpw = "nutanix/4u"      #password used throughout
$securepw =  $plainpw | ConvertTo-SecureString -AsPlainText -Force
$ifIndexdefault = 12         #usually the NIC interface is 12
$adhostname ="AD1"           #hostname for the AD server, using the default would mean one less reboot but it's not pretty  
$markerfile = "C:\hardevPoCmarker.txt" #pass information after reboots
$done = "DONE"               #Termination marker
$step1 = "STEP1"             #Next step marker
$step2 = "POC*"              #Next step marker   
$step3 = "*.local"           #Next step marker
$op = "===== "               #Helps with my ocd
$firstpartip = "10.21."      #POC IP Address builder
$defaultstatic = ".40"       #Use this as the static IP for the AD server VM 
$defaultprefix = 25          #netmask for POC networks
$defaultgwayend = ".1"       #Where the default gateway is
$defaultdns = "10.21.253.10" #The default nameserver
$printmask = "255.255.255.128" #default netmask
#
#
#BEGIN
write-host "$op Start Script"
#Have we rebooted this host after running this script before?
if ((test-Path $markerfile) -eq $true) {
   #We're back from a reboot and previous running of this script
   #write-host "$op We're back baby, yeah!"
   #file exists, work out what was the last STEP and go to the next step
   $nextstep = Get-Content $markerfile
   if ($nextstep -eq $done) {
        write-host "$op All steps executed, nothing more to do, quiting"
        exit
   }
}
Else {
      write-host "$op First Run" 
      $nextstep = $step1
}
If ($nextstep -eq $step1) {
   #See if we can determine the POCnnn from the IP address
   $dynamicips = Get-NetIPAddress -InterfaceIndex $ifIndexdefault
   $dynamicipv4 = $dynamicips[1] #2nd value is normally the IPv4 address, 1st is normally the IPv6
   $dynamicpocarray = $dynamicipv4 -split "\." #parse the array
   $dynamicpocno = $dynamicpocarray[2] #eg. the 86 from 10.21.86.51
   #Step 1: Set a Static IP Address
   write-host "$op Step 1: Set Static IP Address for this host"
   write-host "$op Will display network interfaces, tell me which to use, usually it's 12."
   #Display network interface(s) - so you can chose which to apply a static Ip to
   Get-NetAdapter
   $ifIndex = Read-Host "---------- Interfaces listed above, will apply static IP to interface (enter ifIndex or enter to use 12 or q to quit) "
   if ($ifIndex -eq "") {$ifIndex = $ifIndexdefault}
   else {if ($ifIndex -eq "q") {exit}}
   #write-host "$op Interface variables $iptouse $prefix $gw $dns $ifIndex"
   write-host "$op (I think you're POC $dynamicpocno )"
   write-host "$op Enter your poc number without leading zeros, eg. if its POC086, enter 86, POC123 enter 123, POC009 enter 9"
   $pocnumber = Read-Host "or just hit enter and I will use POC number $dynamicpocno"
   if ($pocnumber -eq "") {$pocnumber = $dynamicpocno}
   #$pocnumberstr = $pocnumber.ToString($pocnumber)
   $pocnumberstr = $pocnumber
   if ($pocnumberstr.Length -lt 2) {$pocnumberstr = "00" + $pocnumberstr}
   else { if ($pocnumberstr.Length -lt 3) {$pocnumberstr = "0" + $pocnumberstr}}
   write-host "$op I will use the following defaults to setup your AD server."
   write-host "$op They are usually OK to get you an AD suitable for Calm/SSP." 
   $iptouse = $firstpartip + $pocnumber + $defaultstatic
   $prefix = $defaultprefix
   $gw = $firstpartip + $pocnumber + $defaultgwayend
   $dns = $defaultdns
   write-host "$op Static IP for AD Server: $iptouse"
   write-host "$op Network prefix: $prefix ($printmask)"
   write-host "$op Default gateway: $gw"
   write-host "$op DNS: $dns"
   $go = read-host "--------- If these are OK hit enter, if not hit q and you're on your own!, hit s to enter your choice of static IP for the AD server"
   if ($go -eq "q") {exit}
   elseIf  ($go -eq "s") { 
           $iptouse = Read-Host "---------- Enter Static IP address eg. 10.21.86.40 or q to quit "
           if ($iptouse -eq "q") {exit}
           }
   else { if ($go -eq "") {} }
   $continue = Read-Host "$op Will now change IP address and hostname then reboot, hit enter now to continue"
   write-host "$op Changing IP to $iptouse - if you are RDPng you will lose the session, that's why I said run from console" 
   New-NetIPAddress –InterfaceIndex $ifIndex –IPAddress $iptouse –PrefixLength $prefix -DefaultGateway $gw
   Set-DnsClientServerAddress -InterfaceIndex $ifIndex -ServerAddresses $dns
   #write a marker for when back from a reboot
   $poc + $pocnumberstr | Out-File $markerfile 
   #Restart-Computer -Force
   write-host "$op Step 1.1: Set hostname to $adhostname"
   Rename-Computer -NewName $adhostname -Restart
} 
if ($nextstep -like $step2 -and $nextstep -notlike "*.local" ) {
   #Step 2: Add AD/DNS Role and also the AD Doman and Forest
   $domain = $nextstep + ".local"
   $netbiosname = $nextstep
   write-host "$op Step 2: Add AD/DNS Role to server"
   $continue = Read-Host "$op just hit enter now to continue"
   install-windowsfeature AD-Domain-Services -IncludeManagementTools
   write-host "$op Step 2.1: Add AD Domain and Forest, there will be a reboot!!!!!!"
   #write a marker for when back from a reboot
   "$domain" | Out-File $markerfile
   Install-ADDSForest -SafeModeAdministratorPassword $securepw -CreateDnsDelegation:$false -DatabasePath “C:\Windows\NTDS” -DomainMode “Win2012R2” -DomainName $domain -DomainNetbiosName $netbiosname -ForestMode “Win2012R2” -InstallDns:$true -LogPath “C:\Windows\NTDS” -NoRebootOnCompletion:$false -SysvolPath “C:\Windows\SYSVOL” -Force:$true
}
if ($nextstep -like $step3) {
   $domain = $nextstep
   write-host "$op Step 3: Add Users and Groups"
   $continue = Read-Host "$op just hit enter now to continue"
   #Add Groups and Users to the Groups
   $outer = $adgroupsandusers.GetUpperBound(0)
   $inner = $adgroupsandusers[0].GetUpperBound(0)
   for ($i=0; $i -le $outer; $i++){
       $adgroup = $adgroupsandusers[$i][0]
       write-host "$op Adding Group " $adgroup
       New-ADGroup -Name $adgroup -SamAccountName $adgroup -GroupCategory Security -GroupScope Global -DisplayName $adgroup
       for ($j=1; $j -le $inner; $j++){
         $aduser = $adgroupsandusers[$i][$j]
         write-host "$op Adding User " $aduser
         New-ADUser -Name $aduser -Enabled $true -AccountPassword $securepw -PasswordNeverExpires $true -ChangePasswordAtLogon $false -UserPrincipalName ($aduser + "@" + $domain) -samaccountname $aduser
         Add-ADGroupMember -Identity $adgroup -Members $aduser
       }
   }
   #Write closing marker
   $done | Out-File $markerfile
   write-host "$op Done.  It's been a pleasure."
}