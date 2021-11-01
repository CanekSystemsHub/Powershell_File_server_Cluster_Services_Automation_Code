
#####################################################################################################################################################################################
# The purpose of this script is to carry out automatically the Windows 2012 R2 FS cluster Deployment and configuration
#
# 13/07/2018  Version 1.0 --> Initial, filtering instructions used by Stuart and added more robust logic, logging and improvements. As well as resolved the Disk allocation issue.
#             Version 1.1 --> Another challenging improvement was to add logic to execute this script remotely since reboots are quired and to have better handling of the process.
#             Version 1.2 --> After 1st individual QA noticed the script needs mor error handling for false positives.
#                             Added logic to validate the nodes are member of the G_WS12R2_Clusters AD group before creating the cluster, otherwise there will get time out error.
#                             Once creted the DNS record make sure the " Update asociated PTR" option is Enabled.
#                             Review the logic on disk labeling @("Q:3","J:4","E:5","F:6","G:7","H:8","I:9")
#
# Author : Victor Jimenez, based initial instructions taken from Stuart Blackmoore's prior script.
#
# IMPORTANT.- The scope of this script starts rigth after the Pre-requisites are completed on Windows FS building proces in Taleo. For datails see following SOP:
#             https://confluence.rightnowtech.com/pages/viewpage.action?spaceKey=PDITCDI&title=File+Cluster  
#           
#             This script is not intended to explain how Windows FS clustering works, the engineer in charge to execute it should have enough expertise on this Role.
#             
#
#####################################################################################################################################################################################


# Set free execution for this script and we start with the path recognition and logging
# On ISE always move manually to the path where the script is located. cd D:\Victor_DontDelete\Cluster_Build_v1

$ORG_Path = $null
$ORG_Path = $pwd.Path
Import-Module $ORG_Path\loginfos.psm1 -ErrorAction SilentlyContinue
open-log

$AppendLog = getLogFilePath

# Credentilas that will be used during Cluster creation
Write-log "Input your Infra credentials as INFRA\<User>" -Type INFO
$Creds = Get-Credential

        # Check credentials are Valid
        $username = $creds.username
        $password = $creds.GetNetworkCredential().password

         # Get your Domain
         $Root = "LDAP://" + ([ADSI]"").distinguishedName
         $domain = New-Object System.DirectoryServices.DirectoryEntry($Root,$UserName,$Password)

        if ($domain.name -ne $null)
        {
            write-log "Authenticated OK your user account:" -Type INFO
            $creds.username
        }else{
            write-log "Not authenticated, Re-run the script and input your correct credentials" -Type ERROR
            $creds.username 
            Exit
        }




#####################################################################################################################################################################################
# Part #1 - INITIAL and NETWORK CONFIGURATION ON NODE 1
#####################################################################################################################################################################################

# Cluster_Settings.txt contect is input in a variable to start with the logic to get each value, thistxt file needs to be feeded in advance.

$path_Settings = $ORG_Path + "\Cluster_Settings.txt"
$clus_settings = gc $path_Settings

#Clear-Variable -Name 1Set,Set_Split,set_sansplit,saniqn,Val_Settings
#Clear
# This is for troubleshooting

$Set_Split = @()
foreach($1Set in $clus_settings)
{
    $Set_Split += $1Set.split(":",2)[1] | ? {$_ -ne " "}
   
}
$Val_Settings = $Set_Split.count

Write-log "Following records will be processed on next steps" -Type INFO
$Set_Split
$Set_Split | Out-File  -Encoding ascii -Append $AppendLog

# Now setting the variable with their corresponding value

    If ($Val_Settings -lt 18)
    {
        write-log "Error missing mandatory value for configuring the cluster process halted" -Type ERROR
        exit 2
    }
    Elseif($Val_Settings -eq 18)
    {
       
        $CLuster_Name = $Set_Split[0].Trim()
        $Node_1 = $Set_Split[1].Trim()
        $Node_2 = $Set_Split[2].Trim()
        $IP_1 = $Set_Split[3].Trim()
        $IP_2 = $Set_Split[4].Trim()
        $IP_3 = $Set_Split[5].Trim()
        $IP_4 = $Set_Split[6].Trim()
        $IP_5 = $Set_Split[7].Trim()
        $IP_6 = $Set_Split[8].Trim()
        $IP_7 = $Set_Split[9].Trim()
        $TargetPortal = $Set_Split[10].Trim()
        $ISCSIIP1 = $Set_Split[11].Trim()
        $ISCSIIP2 = $Set_Split[12].Trim()
        $Priv1 = $Set_Split[13].Trim()
        $Priv2 = $Set_Split[14].Trim()
        $Chap_Scr = $Set_Split[15].Trim()
        $SAN_IQN1 = $Set_Split[16].Trim()
        $SAN_IQN2 = $Set_Split[17].Trim()
        Write-log "The information from the Cluster_settings.txt input file has been processed, Ready to continue" -Type INFO
    }

Start-sleep 5

# Verifying Node 1 is online first

 write-log "Time to continue with $Node_1  Network configuration"  -Type INFO
 Start-Sleep 5
      $TargetPath1 = "\\$Node_1\C$\Windows"
    If ($Status1 = Test-Path -path $TargetPath1)
    {
        Write-log "The Server $Node_1 is OK, ready to continue" -Type INFO
        Start-Sleep 5    
    }
    Else
    {
        do {
        Write-log "$Node_1 is offline please check, this script will continue until it gets online" -Type WARNING        
        $Status1 = Test-Path -path $TargetPath1
        Start-Sleep 10
        } While ($Status1 -ne 'False')      
    }

Write-log "The Remote access is $Node_1 is OK" -Type INFO
Start-Sleep 5
write-log "Time to  Enable and rename the iSCI and cluster vNICs" -Type INFO
        $Enable_Cluster1 = Enable-NetAdapter -InterfaceDescription "*#3*" -CimSession $Node_1
        $Enable_iSCSI1 = Enable-NetAdapter -InterfaceDescription "*#2*" -CimSession $Node_1
        $Ren_Cluster1 = Rename-NetAdapter -InterfaceDescription *#3* -NewName Cluster -CimSession $Node_1
        $Ren_iSCSI1 = Rename-NetAdapter -InterfaceDescription *#2* -NewName iSCSI -CimSession $Node_1

        $Status_Cluster1 = Get-NetAdapter -InterfaceDescription "*#3*"-CimSession $Node_1
        $Status_iSCSI1  = Get-NetAdapter -InterfaceDescription "*#2*"-CimSession $Node_1
        
        If ($Enable_Cluster1, $Enable_iSCSI1, $Ren_Cluster1, $Ren_iSCSI1 -ne $null)
        {
            Write-log "Error missing vNIC or issue on new vNICS, please check a re-execute the script on a new Window" -Type ERROR
            exit 2
        }
        Elseif($Status_Cluster1.Status -and $Status_iSCSI1.Status -eq "Up" )
        {
            write-log "The status of the vNICs is OK, ready to proceeed..." -Type INFO
        }
        Else
        {
            write-log "There is an issue on the vNics which are either Disabled or not exist, please check a re-execute the script on a new Window " -Type ERROR
            exit 2
        }



Write-log "Proceeding with Network IP configuration on  $Node_1" -Type INFO
Start-Sleep 5
New-NetIPAddress –InterfaceAlias iSCSI –IPAddress $ISCSIIP1 –PrefixLength 24 -CimSession $Node_1
New-NetIPAddress –InterfaceAlias Cluster –IPAddress $Priv1 -PrefixLength 24 -CimSession $Node_1

$IP_iSCSI1 = Get-NetIPAddress  –InterfaceAlias iSCSI -CimSession $Node_1
$IP_Cluster1 = Get-NetIPAddress  –InterfaceAlias Cluster -CimSession $Node_1

write-log "Following IP Address for iSCSI vNIC is" -Type INFO
$IP_iSCSI1
Start-Sleep 5
$IP_iSCSI1 | Out-File -Encoding ascii -Append $AppendLog

write-log "Following IP Address for Cluster vNIC is" -Type INFO
$IP_Cluster1
Start-Sleep 5
$IP_Cluster1 | Out-File -Encoding ascii -Append $AppendLog


Write-log "Proceeding with Network Advanced configuration" -Type INFO
Start-Sleep 5

Set-NetAdapterAdvancedProperty -Name Cluster -DisplayName "Large Send Offload" -DisplayValue "Disabled" -CimSession $Node_1
Disable-NetAdapterBinding -Name "Cluster" -ComponentID ms_pacer -CimSession $Node_1
Disable-NetAdapterBinding -Name "Cluster" -ComponentID ms_rspndr -CimSession $Node_1
Disable-NetAdapterBinding -Name "Cluster" -ComponentID ms_lltdio -CimSession $Node_1
Disable-NetAdapterBinding -Name "Cluster" -ComponentID ms_implat -CimSession $Node_1
Disable-NetAdapterBinding -Name "Cluster" -ComponentID ms_msclient -CimSession $Node_1
Disable-NetAdapterBinding -Name "Cluster" -ComponentID ms_server -CimSession $Node_1
Disable-NetAdapterBinding -Name "Cluster" -ComponentID ms_netftflt -CimSession $Node_1
Disable-NetAdapterBinding -Name "Cluster" -ComponentID ms_tcpip6 -CimSession $Node_1


Set-NetAdapterAdvancedProperty -Name iSCSI -DisplayName "Large Send Offload" -DisplayValue "Disabled" -CimSession $Node_1
Disable-NetAdapterBinding -Name "iSCSI" -ComponentID ms_pacer -CimSession $Node_1
Disable-NetAdapterBinding -Name "iSCSI" -ComponentID ms_rspndr -CimSession $Node_1
Disable-NetAdapterBinding -Name "iSCSI" -ComponentID ms_lltdio -CimSession $Node_1
Disable-NetAdapterBinding -Name "iSCSI" -ComponentID ms_implat -CimSession $Node_1
Disable-NetAdapterBinding -Name "iSCSI" -ComponentID ms_msclient -CimSession $Node_1
Disable-NetAdapterBinding -Name "iSCSI" -ComponentID ms_server -CimSession $Node_1
Disable-NetAdapterBinding -Name "iSCSI" -ComponentID ms_netftflt -CimSession $Node_1
Disable-NetAdapterBinding -Name "iSCSI" -ComponentID ms_tcpip6 -CimSession $Node_1

$Adv_iSCSI1 = Get-NetAdapterAdvancedProperty -Name iSCSI -Verbose -CimSession $Node_1
$Adv_Cluster1 = Get-NetAdapterAdvancedProperty -Name Cluster -Verbose -CimSession $Node_1

write-log "Advanced Configuration for iSCSI vNIC  on $Node_1 is" -Type INFO
$Adv_iSCSI1
Start-Sleep 5
$Adv_iSCSI1 | Out-File  -Encoding ascii -Append $AppendLog

write-log "Advanced Configuration for Cluster vNIC on $Node_1  is" -Type INFO
$Adv_Cluster1
Start-Sleep 5
$Adv_Cluster1 | Out-File -Encoding ascii -Append $AppendLog


Write-log "Completed with Network Advanced configuration on iSCSI and Cluster vNICs, AT THIS POINT YOU SHOULD CHECK THE NETWORK CONFIGURATION IS OK AND THERE IS NOT ANY NETWORK CONFLICT" -Type INFO
Write-log "Ready to continue? If Yes then hit Enter" -Type INFO
pause


#####################################################################################################################################################################################
# Part #2 - NETWORK CONFIGURATION ON NODE 2
#####################################################################################################################################################################################
   write-log "Time to continue with $Node_2  Network configuration"  -Type INFO
      $TargetPath2 = "\\$Node_2\C$\Windows"
    If ($Status2 = Test-Path -path $TargetPath2)
    {
        Write-log "The Server $Node_2 is OK, ready to continue" -Type INFO
        Start-Sleep 10    
    }
    Else
    {
        do {
        Write-log "$Node_2 is offline please check, this script will continue until it gets online" -Type WARNING        
        $Status2 = Test-Path -path $TargetPath2
        Start-Sleep 10
        } While ($Status2 -ne 'False')      
    }

    Write-log "The Remote access is $Node_2 is OK" -Type INFO
    Start-Sleep 5

# Network configuration begins executing the commands now for remote server
    write-log "Time to  Enable and rename the iSCI and cluster vNICs" -Type INFO
    Start-Sleep 5
        $Enable_Cluster2 = Enable-NetAdapter -InterfaceDescription "*#3*" -CimSession $Node_2
        $Enable_iSCSI2 = Enable-NetAdapter -InterfaceDescription "*#2*" -CimSession $Node_2
        $Ren_Cluster2 = Rename-NetAdapter -InterfaceDescription *#3* -NewName Cluster -CimSession $Node_2
        $Ren_iSCSI2 = Rename-NetAdapter -InterfaceDescription *#2* -NewName iSCSI -CimSession $Node_2

        $Status_Cluster2 = Get-NetAdapter -InterfaceDescription "*#3*" -CimSession $Node_2
        $Status_iSCSI2  = Get-NetAdapter -InterfaceDescription "*#2*" -CimSession $Node_2
        
        If ($Enable_Cluster2, $Enable_iSCSI2, $Ren_Cluster2, $Ren_iSCSI2 -ne $null)
        {
            Write-log "Error missing vNIC or issue on new vNICS, please check a re-execute the script on a new Window" -Type ERROR
            exit 2
        }
        Elseif($Status_Cluster2.Status -and $Status_iSCSI2.Status -eq "Up" )
        {
            write-log "The status of the vNICs is OK, ready to proceeed..." -Type INFO
        }
        Else
        {
            write-log "There is an issue on the vNics which are either Disabled or not exist, please check a re-execute the script on a new Window " -Type ERROR
            exit 2
        }



Write-log "Proceeding with Network IP configuration on $Node_2" -Type INFO
New-NetIPAddress –InterfaceAlias iSCSI –IPAddress $ISCSIIP2 –PrefixLength 24 -CimSession $Node_2
New-NetIPAddress –InterfaceAlias Cluster –IPAddress $Priv2 -PrefixLength 24 -CimSession $Node_2

$IP_iSCSI2 = Get-NetIPAddress  –InterfaceAlias iSCSI -CimSession $Node_2
$IP_Cluster2 = Get-NetIPAddress  –InterfaceAlias Cluster -CimSession $Node_2
Start-Sleep 5

write-log "Following IP Address for iSCSI vNIC is" -Type INFO
$IP_iSCSI2
$IP_iSCSI2 | Out-File  -Encoding ascii -Append $AppendLog
Start-Sleep 5

write-log "Following IP Address for Cluster vNIC is" -Type INFO
$IP_Cluster2
$IP_Cluster2 | Out-File -Encoding ascii -Append $AppendLog
Start-Sleep 5

Write-log "Proceeding with Network Advanced configuration" -Type INFO
Start-Sleep 5
Set-NetAdapterAdvancedProperty -Name Cluster -DisplayName "Large Send Offload" -DisplayValue "Disabled" -CimSession $Node_2
Disable-NetAdapterBinding -Name "Cluster" -ComponentID ms_pacer -CimSession $Node_2
Disable-NetAdapterBinding -Name "Cluster" -ComponentID ms_rspndr -CimSession $Node_2
Disable-NetAdapterBinding -Name "Cluster" -ComponentID ms_lltdio -CimSession $Node_2
Disable-NetAdapterBinding -Name "Cluster" -ComponentID ms_implat -CimSession $Node_2
Disable-NetAdapterBinding -Name "Cluster" -ComponentID ms_msclient -CimSession $Node_2
Disable-NetAdapterBinding -Name "Cluster" -ComponentID ms_server -CimSession $Node_2
Disable-NetAdapterBinding -Name "Cluster" -ComponentID ms_netftflt -CimSession $Node_2
Disable-NetAdapterBinding -Name "Cluster" -ComponentID ms_tcpip6 -CimSession $Node_2


Set-NetAdapterAdvancedProperty -Name iSCSI -DisplayName "Large Send Offload" -DisplayValue "Disabled" -CimSession $Node_2
Disable-NetAdapterBinding -Name "iSCSI" -ComponentID ms_pacer -CimSession $Node_2
Disable-NetAdapterBinding -Name "iSCSI" -ComponentID ms_rspndr -CimSession $Node_2
Disable-NetAdapterBinding -Name "iSCSI" -ComponentID ms_lltdio -CimSession $Node_2
Disable-NetAdapterBinding -Name "iSCSI" -ComponentID ms_implat -CimSession $Node_2
Disable-NetAdapterBinding -Name "iSCSI" -ComponentID ms_msclient -CimSession $Node_2
Disable-NetAdapterBinding -Name "iSCSI" -ComponentID ms_server -CimSession $Node_2
Disable-NetAdapterBinding -Name "iSCSI" -ComponentID ms_netftflt -CimSession $Node_2
Disable-NetAdapterBinding -Name "iSCSI" -ComponentID ms_tcpip6 -CimSession $Node_2


$Adv_iSCSI2 = Get-NetAdapterAdvancedProperty -Name iSCSI -Verbose -CimSession $Node_2
$Adv_Cluster2 = Get-NetAdapterAdvancedProperty -Name Cluster -Verbose -CimSession $Node_2



write-log "Advanced Configuration for iSCSI vNIC  on $Node_2 is" -Type INFO
$Adv_iSCSI2
Start-Sleep 5
$Adv_iSCSI2 | Out-File -Encoding ascii -Append $AppendLog

write-log "Advanced Configuration for Cluster vNIC on $Node_2 is" -Type INFO
$Adv_Cluster2
Start-Sleep 5
$Adv_Cluster2 | Out-File -Encoding ascii -Append $AppendLog

####################################################################################################################################################################################################
# Now setting the proper metric order in the network Bindings
# This is pending
#$BindClus2 = Get-NetIPInterface -InterfaceAlias Cluster -CimSession $Node_2
#$BindiSCSI2 = Get-NetIPInterface -InterfaceAlias iSCSI -CimSession $Node_2

#Set-NetIPInterface -InterfaceIndex $BindClus2.ifIndex -InterfaceMetric 5 -CimSession $Node_2
#Set-NetIPInterface -InterfaceIndex $BindiSCSI2.ifIndex -InterfaceMetric 5 -CimSession $Node_2
####################################################################################################################################################################################################

Write-log "Completed with Network Advanced configuration on iSCSI and Cluster vNICs, AT THIS POINT YOU SHOULD CHECK THE NETWORK CONFIGURATION IS OK AND THERE IS NOT ANY NETWORK CONFLICT" -Type INFO
Write-log "Ready to continue? If Yes then hit Enter" -Type INFO
pause



####################################################################################################################################################################################################
#Part 3 - iSCSI configuration
####################################################################################################################################################################################################

        
# Add iSCSI connection on Node 1
# iSCSI service verification - Required to make sure for the Second Session to work.


$iSCSI_SVC1 = $null
$iSCSI_SVC1 = get-service MSiSCSI -ComputerName $Node_1

Write-log "iSCSI service status is:" -type INFO
write-log $iSCSI_SVC1.Status -Type INFO

If ($iSCSI_SVC1.Status -ne "Running")
    {
        Set-Service -Name MSiSCSI -StartupType Automatic -ComputerName $Node_1
        Write-log "Setting iSCSI service to Auto" -Type INFO
        Start-Sleep 2
        $Start_Status = Start-Service $iSCSI_SVC1
        Write-log "iSCSI SERVICE PROCESSING `n $Start_Status" -type INFO
        Write-log "Current iSCSI service Status:"
        Start-Sleep 5
        Write-log  $iSCSI_SVC1.Status -type INFO
    }Else
    {
        Write-log "iSCSI SERVICE is already started no Action Taken, ready to configure 2nd iSCSI Session" -type INFO
        
    }

# Starting with the iSCSI connection to the Storage Device
Write-log "Starting with the iSCSI connection to the Storage Device" -Type INFO
Start-Sleep 5

#$NewiSCSI = New-IscsiTargetPortal -TargetPortalAddress $TargetPortal -InitiatorPortalAddress $ISCSIIP1 -InitiatorInstanceName "ROOT\ISCSIPRT\0000_0" -CimSession $Node_1
$NewiSCSI1 = New-IscsiTargetPortal -TargetPortalAddress $TargetPortal -CimSession $Node_1
$GetiSCSI1 = Get-IscsiTarget -CimSession $Node_1

    If ($GetiSCSI1 -ne $null)
    {
        write-log "iSCSI connection to the $Targetportal Portal (Storage device) is successful " -Type INFO
        $GetiSCSI1
        $GetiSCSI1 | Out-File  -Encoding ascii -Append $AppendLog
        Start-Sleep 5

    }Else
    {
        do {
        write-log "iSCSI connection to the $Targetportal Portal (Storage device) is NOT successful " -Type WARNING
        $GetiSCSI1
        $GetiSCSI1 | Out-File  -Encoding ascii -Append $AppendLog   
        write-log "The script will be paused so you can double check" -Type WARNING  
        pause  
        $GetiSCSI1 = Get-IscsiTarget -CimSession $Node_1
        $NewiSCSI2 = New-IscsiTargetPortal -TargetPortalAddress $TargetPortal -CimSession $Node_2
        } While ($GetiSCSI1 -ne $null)  
    }

# Proceeding to connect to the Storage Target
Write-log "Proceeding to connect to the Storage Target" -Type INFO

#$ISCSIIP1 = $null      #For Testing purposes
#$ISCSIIP1 = "10.111.7.54"
$Conn_iSCSI1 = Connect-iSCSITarget -NodeAddress $SAN_IQN1 -InitiatorPortalAddress $ISCSIIP1 –AuthenticationType ONEWAYCHAP –ChapUserName $Node_1 -ChapSecret $Chap_Scr –IsPersistent $True -TargetPortalPortNumber 3260 -InitiatorInstanceName "ROOT\ISCSIPRT\0000_0"  -CimSession $Node_1 
$Conn_iSCSI1
Start-Sleep 5
$Conn_iSCSI | Out-File -Encoding ascii -Append $AppendLog

 If ($Conn_iSCSI1 -ne $null)
    {        
     Write-log "Server iSCSI connection to the Target $Conn_iSCSI1 has been successful, see details below " -Type INFO
     $Conn_iSCSI1
     Start-Sleep 5
     $Conn_iSCSI1 | Out-File  -Encoding ascii -Append $AppendLog   
     write-log "Ready to continue" -Type Info 
    }
    Else{
    do {
        write-log "Server iSCSI connection to the Target $Conn_iSCSI1 is NOT successful" -Type WARNING
        $Conn_iSCSI1
        $Conn_iSCSI1 | Out-File  -Encoding ascii -Append $AppendLog   
        write-log "The script will be paused so you can double check" -Type WARNING  
        pause  
        $Conn_iSCSI1 = "connection checked"      # Need to double check this logic ot make sure always there is a whole validation. At this moment the user should've already checked.
        } While ($GetiSCSI1 -ne $null)  
    }

# Validating the connectivity is OK
write-log "Validating the connectivity is OK" -Type INFO
Start-Sleep 5

$Get_conn1 = Get-IscsiConnection -CimSession $Node_1

    If ($Get_conn1.InitiatorAddress -eq $ISCSIIP1)
    {
        write-log "Iscsi IP address was set OK `n $ISCSIIP1" -Type INFO
    }if($Get_conn1.TargetAddress -eq $TargetPortal)
    {
        write-log "Target IP address was set OK `n $TargetPortal" -Type INFO
    }Else
    {
        write-log "Something went wrong with the information you input, please review and re-execute this script" -Type ERROR
        pause
    }

    #########
 If (($Get_conn1.InitiatorAddress -eq $ISCSIIP1) -and ($Get_conn1.TargetAddress -eq $TargetPortal))
    {
        write-log "The Iscsi IP address was set OK `n $ISCSIIP1 and `n  The Target device was set too `n $TargetPortal" -Type INFO
    }
 Else
    {
        write-log "Something went wrong with the information you input, please review and re-execute this script" -Type ERROR
        pause
    }
Start-sleep 5


#>
# Add iSCSI connection on Node 2
# iSCSI service verification - Required to make sure for the Second Session to work.


$iSCSI_SVC2 = $null
$iSCSI_SVC2 = get-service MSiSCSI -ComputerName $Node_2

Write-log "iSCSI service status is:" -type INFO
write-log $iSCSI_SVC2.Status -Type INFO

If ($iSCSI_SVC2.Status -ne "Running")
    {
        Set-Service -Name MSiSCSI -StartupType Automatic -ComputerName $Node_2
        Write-log "Setting iSCSI service to Auto" -Type INFO
        Start-Sleep 2
        $Start_Status = Start-Service $iSCSI_SVC2
        Write-log "iSCSI SERVICE PROCESSING `n $Start_Status" -type INFO
        Write-log "Current iSCSI service Status:"
        Start-Sleep 5
        Write-log  $iSCSI_SVC2.Status -type INFO
    }Else
    {
        Write-log "iSCSI SERVICE is already started no Action Taken, ready to configure 2nd iSCSI Session" -type INFO
        
    }

# Starting with the iSCSI connection to the Storage Device
Write-log "Starting with the iSCSI connection to the Storage Device" -Type INFO
Start-Sleep 5

#$NewiSCSI = New-IscsiTargetPortal -TargetPortalAddress $TargetPortal -InitiatorPortalAddress $ISCSIIP1 -InitiatorInstanceName "ROOT\ISCSIPRT\0000_0" -CimSession $Node_1
$NewiSCSI2 = New-IscsiTargetPortal -TargetPortalAddress $TargetPortal -CimSession $Node_2
$GetiSCSI2 = Get-IscsiTarget -CimSession $Node_2

  

    If ($GetiSCSI2 -ne $null)
    {
        write-log "iSCSI connection to the $Targetportal Portal (Storage device) is successful " -Type INFO
        $GetiSCSI2
        $GetiSCSI2 | Out-File  -Encoding ascii -Append $AppendLog
        Start-Sleep 5

    }Else
    {
        do {
        write-log "iSCSI connection to the $Targetportal Portal (Storage device) is NOT successful " -Type WARNING
        $GetiSCSI2
        $GetiSCSI2 | Out-File  -Encoding ascii -Append $AppendLog   
        write-log "The script will be paused so you can double check" -Type WARNING  
        pause  
        $NewiSCSI2 = New-IscsiTargetPortal -TargetPortalAddress $TargetPortal -CimSession $Node_2
        $GetiSCSI2 = Get-IscsiTarget -CimSession $Node_2
        } While ($GetiSCSI2 -ne $null)  
    }

# Proceeding to connect to the Storage Target
Write-log "Proceeding to connect to the Storage Target" -Type INFO

#$ISCSIIP2 = $null      #For Testing purposes
#$ISCSIIP2 = "10.111.7.55"
$Conn_iSCSI2 = Connect-iSCSITarget -NodeAddress $SAN_IQN2 -InitiatorPortalAddress $ISCSIIP2 –AuthenticationType ONEWAYCHAP –ChapUserName $Node_2 -ChapSecret $Chap_Scr –IsPersistent $True -TargetPortalPortNumber 3260 -InitiatorInstanceName "ROOT\ISCSIPRT\0000_0"  -CimSession $Node_2 
$Conn_iSCSI2
Start-Sleep 5
$Conn_iSCSI2 | Out-File -Encoding ascii -Append $AppendLog

 If ($Conn_iSCSI2 -ne $null)
    {        
     Write-log "Server iSCSI connection to the Target $Conn_iSCSI2 has been successful, see details below " -Type INFO
     $Conn_iSCSI2
     Start-Sleep 5
     $Conn_iSCSI2 | Out-File  -Encoding ascii -Append $AppendLog   
     write-log "Ready to continue" -Type Info 
    }
    Else{
    do {
        write-log "Server iSCSI connection to the Target $Conn_iSCSI2 is NOT successful" -Type WARNING
        $Conn_iSCSI2
        $Conn_iSCSI2 | Out-File  -Encoding ascii -Append $AppendLog   
        write-log "The script will be paused so you can double check" -Type WARNING  
        pause  
        $Conn_iSCSI2 = "connection checked"      # Need to double check this logic ot make sure always there is a whole validation. At this moment the user should've already checked.
        } While ($GetiSCSI2 -ne $null)  
    }

# Validating the connectivity is OK
write-log "Validating the connectivity is OK" -Type INFO
Start-Sleep 5

$Get_conn2 = Get-IscsiConnection -CimSession $Node_2

    If ($Get_conn2.InitiatorAddress -eq $ISCSIIP2)
    {
        write-log "Iscsi IP address was set OK `n $ISCSIIP2" -Type INFO
    }if($Get_conn2.TargetAddress -eq $TargetPortal)
    {
        write-log "Target IP address was set OK `n $TargetPortal" -Type INFO
    }Else
    {
        write-log "Something went wrong with the information you input, please review and re-execute this script" -Type ERROR
        pause
    }

    #########
 If (($Get_conn2.InitiatorAddress -eq $ISCSIIP2) -and ($Get_conn2.TargetAddress -eq $TargetPortal))
    {
        write-log "The Iscsi IP address was set OK `n $ISCSIIP2 and `n  The Target device was set too `n $TargetPortal" -Type INFO
    }
 Else
    {
        write-log "Something went wrong with the information you input, please review and re-execute this script" -Type ERROR
        pause
    }
Start-sleep 5


####################################################################################################################################################################################################
#Part 4 - Disk Format and Labeling
####################################################################################################################################################################################################

    ############################################################################################################
    # First is required to Disable the D: drive to avoid to have conflicts during the Cluster setup. This is to be cerfified
    ############################################################################################################


$PartD1 = Get-Partition -CimSession $Node_1 -DriveLetter D -ErrorAction SilentlyContinue
$PartD1.DiskNumber 
$PartD2 = Get-Partition -CimSession $Node_2 -DriveLetter D -ErrorAction SilentlyContinue
$PartD2.DiskNumber 

write-log "On $Node_1 D: drive is the disk number:" -Type INFO
$PartD1.DiskNumber
Start-Sleep 5
$PartD1.DiskNumber | Out-File -Encoding ascii -Append $AppendLog

write-log "On $Node_2 D: drive is the disk number:" -Type INFO
$PartD2.DiskNumber
Start-Sleep 5
$PartD2.DiskNumber | Out-File -Encoding ascii -Append $AppendLog


# To list local disk identified as SAS type
$LocalDisks1 = Get-Disk -CimSession $Node_1 | ?{$_.bustype -eq "SAS"} 
$LocalDisks2 = Get-Disk -CimSession $Node_2 | ?{$_.bustype -eq "SAS"} 

write-log "The physical disks are configured as follows:" -Type INFO
$LocalDisks1
$LocalDisks2
Start-Sleep 5
$LocalDisks1 | Out-File -Encoding ascii -Append $AppendLog
$LocalDisks2 | Out-File -Encoding ascii -Append $AppendLog

write-log "Looking for the D disk " -Type INFO
# Now to fetch the Disk Number that matches with the one found in Partition D: command #% Re-evauluating this part

    If ($PartD1 -ne $null)
    {
        Foreach ($Number in $LocalDisks1.Number)
        {
          If ($PartD1.DiskNumber.Equals($Number))
            {
                Write-host "Found the disk # $Number needs to be offline"
                Set-Disk -CimSession $Node_1 -Number $Number -IsOffline $True -ErrorAction SilentlyContinue
                $DiskStatus1 = Get-disk -CimSession $Node_1 -Number $Number
                $DiskStatus1            
            }              
        }
    }
    Else
    {
     Write-log "Disk D on $Node_1 is already disabled " -Type INFO
    }

    If ($PartD2 -ne $null)
    {
        Foreach ($Number in $LocalDisks2.Number)
        {
          If ($PartD2.DiskNumber.Equals($Number))
            {
                Write-host "Found the disk # $Number needs to be offline"
                Set-Disk -CimSession $Node_2 -Number $Number -IsOffline $True -ErrorAction SilentlyContinue
                $DiskStatus2 = Get-disk -CimSession $Node_1 -Number $Number
                $DiskStatus2            
            }              
        }
    }
    Else
    {
     Write-log "Disk D on $Node_2 is already disabled " -Type INFO
    }

 # Final Status
Write-host "Listing Status of D: drive on $Node_1 is:" -ForegroundColor DarkYellow
Get-Disk -CimSession $Node_1 -Number $PartD1.DiskNumber 
$PartD1.DiskNumber | Out-File -Encoding ascii -Append $AppendLog

Write-host "Listing Status of D: drive on $Node_2 is:" -ForegroundColor DarkYellow
Get-Disk -CimSession $Node_2 -Number $PartD2.DiskNumber 
$PartD2.DiskNumber | Out-File -Encoding ascii -Append $AppendLog



    ################################################################################################################################################
    # Second, is required to disable the iSCSI Service on Node 2 in order to make sure the disks get owned by one single node.
    ################################################################################################################################################
    $iSCSI_SVC = $null
    $iSCSI_SVC = get-service MSiSCSI -ComputerName $Node_2

    Write-log "iSCSI service status on Node 2  is:" -type INFO
    write-log $iSCSI_SVC.Status -Type INFO

    If ($iSCSI_SVC.Status -eq "Running")
        {
            $Stop_Status = Stop-Service $iSCSI_SVC
            Write-log "iSCSI SERVICE PROCESSING `n $Stop_Status" -type INFO
            Write-log "Current Status is below, ready to configure and label Disks" -Type INFO
            Write-log  $iSCSI_SVC.Status -type INFO
        }Else
        {
            Write-log "iSCSI SERVICE is already STOP so no Action Taken, ready to configure and label Disks" -type INFO
        
        }
     ###############################################################################################################################################



    ########################################################################
    # Now Starting with the Disk labeling on Node 1.
    ########################################################################

$C_Letters = @()
$C_Letters = @("Q:3","J:4","E:5","F:6","G:7","H:8","I:9")


    Foreach($let in $C_Letters)
    {
        #$let = "E:5"
        [int]$Disk_Size = 8192
        $Disk_Type = "GPT"
        $A_Letter_Order  = $let.split(":")[1]
        $A_Letter = $let.split(":")[0]

        $A_DC = $Node_1.ToUpper().subString(0,2)
        $A_POD = $Node_1.ToUpper().subString(6,1)
        $A_Num = $Node_1.subString(7)
        $Label = $A_DC + $A_POD + $A_Num + "_"+ $A_Letter

        If($A_Letter -eq "Q")
        {
        $Disk_Type = "MBR"
        $Label = "Quorum"
        }
        elseif(($A_Letter -eq "E") -or ($A_Letter -eq "J"))
        {
        [int]$Disk_Size = 32768
        }
        #elseif(($A_Letter -eq "F") -or ($A_Letter -eq "G"))
        {
        $Label = "DataFiles"
        }

    Start-Sleep 5
    $Init_Disk = Initialize-Disk -CimSession $Node_1 -Number $A_Letter_Order -PartitionStyle $Disk_Type -ErrorAction SilentlyContinue
    write-log "Disk $let has been initialized " -Type INFO
    $Init_Disk
    $Init_Disk | Out-File -Encoding ascii -Append $AppendLog
    Start-Sleep 5
    $GetDisk = Get-Disk -CimSession $Node_1 -Number $A_Letter_Order
    write-log "Getting Disk details" -Type INFO
    $GetDisk
    $GetDisk | Out-File -Encoding ascii -Append $AppendLog
    Start-Sleep 5
    $SetDisk = Set-Disk -CimSession $Node_1 -InputObject $GetDisk -IsReadonly $false
    write-log "Set disk to read only" -Type INFO
    $SetDisk
    $SetDisk | Out-File -Encoding ascii -Append $AppendLog
    Start-Sleep 5
    
    #Here we're making sure the disk is completely released for new use.
    #Clear-ClusterDiskReservation -Node $Node_1 –Disk $GetDisk.Number -Force

    $NewPart = New-Partition $GetDisk.Number -UseMaximumSize -DriveLetter $A_Letter  -CimSession $Node_1 -ErrorAction SilentlyContinue 
    write-log "Creting partition and Assigning letter" -Type INFO
    $NewPart
    $NewPart | Out-File -Encoding ascii -Append $AppendLog
    Start-Sleep 5
    $FormatVol = Format-Volume -CimSession $Node_1 -DriveLetter $A_Letter -FileSystem NTFS -AllocationUnitSize $Disk_Size -NewFileSystemLabel $Label -Confirm:$false -ErrorAction SilentlyContinue
    write-log "Formating $A_Letter volume with the standards" -Type INFO
    $FormatVol
    $FormatVol | Out-File -Encoding ascii -Append $AppendLog
    Start-Sleep 10

    }


    ################################################################################################################################################
    # Now is time is required to start again the iSCSI Service on Node 2 
    ################################################################################################################################################
    $iSCSI_SVC = $null
    $iSCSI_SVC = get-service MSiSCSI

    Write-log "iSCSI service status is:" -type INFO
    write-log $iSCSI_SVC.Status -Type INFO

    If ($iSCSI_SVC.Status -ne "Running")
    {
        $Start_Status = Start-Service $iSCSI_SVC
        Write-log "iSCSI SERVICE PROCESSING `n $Start_Status" -type INFO
        Write-log "Current Status is below, ready to continue" -Type INFO
        Write-log  $iSCSI_SVC.Status -type INFO
    }Else
    {
        Write-log "iSCSI SERVICE is already started no Action Taken, ready to continue" -type INFO
        
    }
  
      # Re-Enable Partition D on both nodes
      write-log "Re-enabling Partition D" -Type INFO
      Set-Disk -CimSession $Node_1 -Number $PartD1.DiskNumber -IsOffline $False -ErrorAction SilentlyContinue
      Set-Disk -CimSession $Node_2 -Number $PartD2.DiskNumber -IsOffline $False -ErrorAction SilentlyContinue
      Start-Sleep 5

       # Final Status
        Write-host "Listing Status of D: drive on $Node_1 is:" -ForegroundColor DarkYellow
        Get-Disk -CimSession $Node_1 -Number $PartD1.DiskNumber 
        $PartD1.DiskNumber | Out-File -Encoding ascii -Append $AppendLog

        Write-host "Listing Status of D: drive on $Node_2 is:" -ForegroundColor DarkYellow
        Get-Disk -CimSession $Node_2 -Number $PartD2.DiskNumber 
        $PartD2.DiskNumber | Out-File -Encoding ascii -Append $AppendLog

####################################################################################################################################################################################################
#Part 5 - Cluster creation 
####################################################################################################################################################################################################

# Validate the Cluster Roles is installed on the target nodes.
$ClusterFeature1 = Get-WindowsFeature -Name Failover-Clustering -ComputerName $Node_1 -ErrorAction SilentlyContinue
$ClusterFeature2 = Get-WindowsFeature -Name Failover-Clustering -ComputerName $Node_2 -ErrorAction SilentlyContinue

    If ($ClusterFeature1.Installed -and $ClusterFeature2.Installed)
    {
        write-log "Verified Cluster feature is installed on both nodes that are online" -Type INFO
    }
    Else
    {
        Write-log "Cluster Role is either not installed on one of the nodes or theres is a a connetivity issue, check, script will be paused" -Type INFO
        Write-log "Ready to continue? If Yes then hit Enter" -Type INFO
        pause 
    }

   
    
#Preparation Cluster 4 FS Resources
$FS_PREP_Site = [string]$CLuster_Name.tolower() | % {$_.substring(0,2)}
$FS_PREP_NODE1 = $Node_1 | % {$_.substring($_.length-6)}
$FS_PREP_NODE2 = $Node_2 | % {$_.substring($_.length-6)}
$FS_1_Final = $FS_PREP_Site + $FS_PREP_NODE1 + "-fs"
$FS_2_Final = $FS_PREP_Site + $FS_PREP_NODE2 + "-fs"
$FS_3_Final = $FS_PREP_Site + $FS_PREP_NODE1.Substring(0,5) + "3-fs"
$FS_4_Final = $FS_PREP_Site + $FS_PREP_NODE2.Substring(0,5) + "4-fs"

# New Cluster creation

    # Pre-Requisite, verifying the cluster nodes are member of G_WS12R2_Clusters AD group
    Write-log "Pre-Requisite, verifying the cluster nodes are member of G_WS12R2_Clusters AD group" -Type INFO
    $ADClusterGroup = @()
    $ADClusterGroup = Get-ADGroupMember -Identity G_WS12R2_Clusters

    # $ADClusterGroup += $Node_1, $Node_2 # Testing purposes
    
    $ClusterGroupFalse = $True
    Foreach ($ADcomputer in $ADClusterGroup)
    {
            If ($ADcomputer -contains $Node_1)
            {
                write-log "Found the Cluster node below as member of the G_WS12R2_Clusters AD group so these can receive the proper GPOs " -Type INFO
                $ADcomputer
                $ADcomputer | Out-File -Encoding ascii -Append $AppendLog
            }
               ElseIf ($ADcomputer -contains $Node_2)
                {
                    write-log "Found the Cluster node below as member of the G_WS12R2_Clusters AD group so these can receive the proper GPOs " -Type INFO
                    $ADcomputer
                    $ADcomputer | Out-File -Encoding ascii -Append $AppendLog
                }
            Else
            {
               $ClusterGroupFalse = $False
            }
    }

            If ($ClusterGroupFalse -eq $False)
            {
                write-log "Did NOT found one or both of the Cluster nodes below as member of the G_WS12R2_Clusters AD group so these can NOT receive the proper GPOs " -Type INFO
                write-log "Contact a Domain Administrator to add both computer AD nodes to G_WS12R2_Clusters AD group. Script will be paused until you get this fixed" -Type INFO
                write-log "Just hit ENTER once you're done to continue" -Type INFO
                Pause
             }


# Setting the New-Cluster parameters in a temporal txt file to take these in the Workflow/inlines next commands
$CLuster_Name | Out-File C:\Windows\Temp\cluster.txt -Encoding ascii -Force
$Node_1 |  Out-File C:\Windows\Temp\Node1.txt -Encoding ascii -Force
$IP_1 |  Out-File C:\Windows\Temp\ClusterIP.txt -Encoding ascii -Force
$creds | Out-File C:\Windows\Temp\Creds.txt -Encoding ascii -Force

workflow CrearCluster
{     
    "Starting with the Cluster creation"
    [String]$Cluster = Get-Content "C:\Windows\Temp\cluster.txt"
    [String]$Nodo1 = Get-Content "C:\Windows\Temp\Node1.txt"
    [String]$ClusterIP = Get-Content "C:\Windows\Temp\ClusterIP.txt"
    
    Inlinescript 
    {
       "The value of Cluster Name is - $Using:Cluster"
       "The value of Node # 1 is - $Using:Nodo1"
       "The value of the IP address is - $Using:ClusterIP"
       $Resultado = New-Cluster -Name $using:Cluster -Node  $using:Nodo1 -StaticAddress $using:ClusterIP -NoStorage -Force
       $Resultado | out-file C:\Windows\Temp\Resultado.txt
    } -PSComputerName $Node_1 -PSCredential $Creds
}
# Execute this command in the the server where the script is been executed
#Get-NetAdapter –name LAN -CimSession $Node_1 | disable-NetAdapterChecksumOffload -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

# Executing the Workflow Function
CrearCluster

# Query the recent created cluster and report. $CLuster_Name = "CHSMCNS00991"

$Cluster_Status = Get-Cluster -Name $Cluster_Name -ErrorAction SilentlyContinue

$Cluster_Online = Test-Connection $Cluster_Name -ErrorAction SilentlyContinue

    If($Cluster_Status -and $Cluster_Online)
    {
        write-log "Cluster is online good to proceed" -Type INFO
        $Cluster_Status.Name
        $Cluster_Status | Out-File  -Encoding ascii -Append $AppendLog
        $Cluster_Online
        $Cluster_Online | Out-File  -Encoding ascii -Append $AppendLog
    }
    Else
    {
        Write-log "Server is not responding, you need to check the vms" -Type ERROR
        Start-Sleep 10
        Write-log "Ready to continue? If Yes then hit Enter" -Type INFO
        pause      
    }


# Starting with the cluster network configuration 
Write-log "Time to rename cluster network NICs and configure according the the role" -Type INFO
$ClusterNetworks = Get-Cluster -Name $Cluster_Name | Get-ClusterNetwork
$ClusterNetworks
$ClusterNetworks | Out-File  -Encoding ascii -Append $AppendLog

    If ($ClusterNetworks.Count)
    {
        write-log "Checked the 3 Cluster NICs are OK, ready to continue with the next reconfiguration" -Type INFO
    }
    Else
    {
        Write-log "There's one Nic missing or misconfigured, please check manually and once fixed continue" -Type ERROR
        Start-Sleep 10
        Write-log "Ready to continue? If Yes then hit Enter" -Type INFO
        pause  
    }    


#Networks change Nic's
#1: Allow cluster network communication on this network
#3: Allow clients to connect through this network
#0: Do not allow cluster network communication on this network



try
    {
    $ClusterNet1 = Get-Cluster -Name $Cluster_Name | Get-ClusterNetwork -Name "Cluster Network 1"
    $ClusterNet1.NAme = "LAN"
    $ClusterNet1.Role = 3

    $ClusterNet2 = Get-Cluster -Name $Cluster_Name | Get-ClusterNetwork -Name "Cluster Network 2"
    $ClusterNet2.NAme = "Storage"
    $ClusterNet2.Role = 0

    $ClusterNet3 = Get-Cluster -Name $Cluster_Name | Get-ClusterNetwork -Name "Cluster Network 3"
    $ClusterNet3.NAme = "Cluster"
    $ClusterNet3.Role = 1

    }
catch
    {
    $ErrorActionPreference = "Continue"
    write-log "There is an error setting the Cluster network settings, check logs in the Cluster node " -Type ERROR
    Write-log "Ready to continue? If Yes then hit Enter" -Type INFO
    pause   
    }
finally
    {
    Write-log "Cluster network Rename and Role/Scope changes are completed, ready to proceed" -Type INFO
    $ClusterNet1
    $ClusterNet1 | Out-File  -Encoding ascii -Append $AppendLog
    $ClusterNet2
    $ClusterNet2 | Out-File  -Encoding ascii -Append $AppendLog
    $ClusterNet3
    $ClusterNet3 | Out-File  -Encoding ascii -Append $AppendLog
    }



####################################################################################################################################################################################################
#Part 6 - Cluster Build / Setup 
####################################################################################################################################################################################################


    #############################################################################################
    # Begins the logic to find the Q disk that matches withthe Diskpart vs. Failover cluster role
    #############################################################################################
    # To get the partition Q 
    $PartQ = Get-Partition -CimSession $Node_1 -DriveLetter Q 
 
    If ($PartQ)
    {
        write-log "Found the Quorum Disk successfully with the NUMBER:" -Type INFO
        $PartQ.DiskNumber 
        $PartQ.DiskNumber | Out-File  -Encoding ascii -Append $AppendLog
        $PartQ.DriveLetter
        $PartQ.DriveLetter | Out-File  -Encoding ascii -Append $AppendLog
    }
    Else
    {
        write-log "There is an error fetching the Q: drive check logs in the Cluster and continue once fixed " -Type ERROR
        Write-log "Ready to continue? If Yes then hit Enter" -Type INFO
        pause
        $PartQ = Get-Partition -CimSession $Node_1 -DriveLetter Q 
    }

    # Get the Disk with Q letter assigned basing the query from $PartQ
    # Get-Disk -CimSession $Node_1 | where Number -eq $PartQ.DiskNumber | ft * -AutoSize
    $DiskQ = Get-Disk  -CimSession $Node_1 | where Number -eq $PartQ.DiskNumber

    
    # Since Q: is the only with MBR Format and should be a iSCSI type we can validate to be certain is the one we're looking for
    If (($DiskQ.PartitionStyle -eq 'MBR') -and ($DiskQ.Bustype -eq 'iSCSI'))
    {
        Write-log "This is the Quorum and should be the one to add in the cluster" -Type INFO
        $DiskQ
        $DiskQ  | Out-File  -Encoding ascii -Append $AppendLog
    }
    Else
    {
        Write-log "This is NOT the Quorum" -Type ERROR
        write-log "There is an error fetching the Q: drive check logs in the Cluster and continue once fixed " -Type ERROR
        Write-log "Ready to continue? If Yes then hit Enter" -Type INFO
        pause
        $DiskQ = Get-Disk  -CimSession $Node_1 | where Number -eq $PartQ.DiskNumber
    }



# Get the Cluster Q disk that matches with the Number in Diskpart $PartQ.DiskNumber
write-log "Time to get the Q Disk from the available list in Cluster side" -Type INFO
$ClusterDisks = Get-ClusterAvailableDisk -Cluster $Cluster_Name | where Number -eq $DiskQ.Number 
$ClusterDisks
$ClusterDisks | Out-File  -Encoding ascii -Append $AppendLog 

    # Making sure the Disk Number in the Cluster properties is the same than the Number in Diskpart $PartQ.DiskNumber
    If ($DiskQ.Number -eq $ClusterDisks.Number)
    {
        Write-log "Compared the Cluster Q disk that matches with the Number in Diskpart is TRUE, ready to proceed to add it in the Cluster available list" -Type INFO
    }
    Else
    {
        write-log "There is an error fetching the Q: drive check logs in the Cluster and continue once fixed " -Type ERROR
        Write-log "Ready to continue? If Yes then hit Enter" -Type INFO
        pause
        $ClusterDisks = Get-ClusterAvailableDisk -Cluster $Cluster_Name | where Number -eq $DiskQ.Number
    }

Start-Sleep 10
# Add the Quorum Disk and set the majority disk
write-log "Starting with the Quorum configuration - Adding the Q: disk" -Type INFO
Get-ClusterAvailableDisk -Cluster $Cluster_Name | ?{ $_.Number -eq $ClusterDisks.Number } | Add-ClusterDisk | Set-ClusterOwnerNode -Owners $Node_1 -ErrorAction SilentlyContinue
$QuorumDisk = Get-ClusterQuorum -Cluster $Node_1 | Format-Table * -AutoSize

        If (!(Get-ClusterAvailableDisk -Cluster $Cluster_Name | where Number -eq $DiskQ.Number) -and ($QuorumDisk))
        {
            write-log "Quorum Disk was set successfully" -Type INFO
            $QuorumDisk
            $QuorumDisk | Out-File  -Encoding ascii -Append $AppendLog 
        }
        Else
        {
        write-log "There is an error fetching the Quorum check logs in the Cluster and continue once fixed " -Type ERROR
        Write-log "Ready to continue? If Yes then hit Enter" -Type INFO
        pause
        $QuorumDisk = Get-ClusterQuorum -Cluster $Node_1 | Format-Table * -AutoSize
        }

Start-Sleep 10

# Here Node and Disk Majority is selected for Quorom settings
write-log "Node and Disk Majority is selected for Quorum settings" -Type INFO
Set-ClusterQuorum -Cluster $CLuster_Name -NodeAndDiskMajority $ClusterDisks.Name
Clear-Variable -Name QuorumDisk

    $QuorumDisk = Get-ClusterQuorum -Cluster $Node_1 
    If ($QuorumDisk.QuorumResource -eq $ClusterDisks.Name)
    {
        write-log "Now the Quorum resource is set to Node and Disk Majority" -Type INFO
        $QuorumDisk = Get-ClusterQuorum -Cluster $Node_1 | Format-Table * -AutoSize
        $QuorumDisk
        $QuorumDisk | Out-File  -Encoding ascii -Append $AppendLog 
    }
    Else
    {
        write-log "There is an error fetching the Quorum check logs in the Cluster and continue once fixed " -Type ERROR
        Write-log "Ready to continue? If Yes then hit Enter" -Type INFO
        pause
        $QuorumDisk = Get-ClusterQuorum -Cluster $Node_1 | Format-Table * -AutoSize  
    }
Start-Sleep 10

######################################################################################
# Now we continue to add the rest of the disks
# It does not matter the order
######################################################################################
Write-log "Here we start the logic to add all the rest of the Available Disks to the Cluster but D: which is local"

$CluAvaDisks = @()
$CluAvaDisks = @(Get-ClusterAvailableDisk -Cluster $Node_1)

write-log "Collecting the Available Disks" -Type INFO
$CluAvaDisks | Format-Table -AutoSize
Start-Sleep 5

write-log "Excluding D: from the Addition which is the Disk Number:" -Type INFO
$PartD1
$PartD1 | Out-File  -Encoding ascii -Append $AppendLog 
$PartD1.DiskNumber


    Clear-Variable -Name CluDisk
    # Checking each disk one by one exlucing to add the D:
    Foreach ($CluDisk in $CluAvaDisks)
        {
            
            If ($CluDisk.Number -ne $PartD1.DiskNumber)
            {
                Write-log " Adding disk below " -Type INFO
                $CluDisk
                $CluDisk | Out-File  -Encoding ascii -Append $AppendLog 
                Get-ClusterAvailableDisk -Cluster $Cluster_Name | ?{ $_.Number -eq $CluDisk.Number } | Add-ClusterDisk | Set-ClusterOwnerNode -Owners $Node_1 -ErrorAction SilentlyContinue
                $DiskAdded  = Get-ClusterResource -Cluster $CLuster_Name | ?{ ($_.ResourceType -eq "Physical Disk") -and ($_.Name -eq $CluDisk.Name)  } # Review This one
                If ($DiskAdded.Name -eq $CluDisk.Name)
                {
                    Write-log "Disk in turn below was added successfully" -Type INFO
                    $CluDisk
                    $CluDisk | Out-File  -Encoding ascii -Append $AppendLog 
                }
                Else
                {
                    Write-log "Disk in turn below may have an issue, go to check and continue once fixed" -Type INFO
                    $CluDisk.Name
                    $CluDisk | Out-File  -Encoding ascii -Append $AppendLog 
                    pause
                }
            }
            Else
            {
                Write-log "This disk is not intended for clustering as it is local, ignoring it " -Type WARNING
                $CluDisk
                $CluDisk | Out-File  -Encoding ascii -Append $AppendLog 
                $CludiskLocal = @()
                $CludiskLocal  += $CluDisk
            }   
        
        }
# Confirming completion of disk addition in the cluster
Write-log "Completed the to add the clustered iSCSI disks" -Type INFO
Write-log "NOTE: Below disk(s) were not added due are local" -Type INFO
$CludiskLocal
$CludiskLocal | Out-File  -Encoding ascii -Append $AppendLog 



######################################################################################
# Add cluster node 2 to the cluster
######################################################################################
Write-log "Time  to add the 2nd node to the cluster" -Type INFO
    Clear-Variable -Name TargetPath2
    $TargetPath2 = "\\$Node_2\C$\Windows"
    $ClusSvc_SVC2 = $null
    If ($Status2 = Test-Path -path $TargetPath2)
    {
        Write-log "The 2nd Node is OK $Node_2 is OK, ready to proceeed to add it" -Type INFO
        Start-Sleep 5    
    }
    Else
    {
        do {
        Write-log "$Node_2 is offline please check, this script will continue until it gets online" -Type WARNING        
        $Status2 = Test-Path -path $TargetPath2
        Start-Sleep 10
        } While ($Status2 -ne 'False')      
    }


Add-ClusterNode -Cluster $CLuster_Name -name $Node_2 -NoStorage
Start-Sleep 20
$GetNode2 = Get-ClusterNode -Cluster $CLuster_Name -Name $Node_2
    If (($GetNode2.Cluster -eq $CLuster_Name) -and ($GetNode2.State -eq 'Up'))
    {
        Write-log "Node 2 named: $Node_2 has been successfully added to the Cluster: $CLuster_Name" -Type INFO
    }
    Else
    {
        write-log "There is an error fetching Node 2, Check in the Cluster and continue once fixed. For more details go to 'n " -Type ERROR
        write-log "Report file location: C:\windows\cluster\Reports\Add Node Wizard*.mht" -Type ERROR
        Write-log "Ready to continue? If Yes then hit Enter" -Type INFO
        pause
    }

# Setting the Q: disk to the original owner
write-log "Node and Disk Majority is selected for Quorum settings - Double-checking." -Type INFO
Set-ClusterQuorum -Cluster $CLuster_Name -NodeAndDiskMajority $ClusterDisks.Name
#Validating the Quorum type status
$CluAfterNode2 = Get-ClusterQuorum -Cluster $CLuster_Name
$CluAfterNode2.QuorumType
    write-log " The Cluster Quorum type is set as: `n" -Type INFO
    $CluAfterNode2.QuorumType
    $CluAfterNode2.QuorumType | Out-File  -Encoding ascii -Append $AppendLog 


# Code to get the Disk partition inside of the added disk resources in the cluster

$AllCluDisks = @()
$AllCluDisks += Get-CimInstance -Namespace Root\MSCluster -ClassName MSCluster_Resource -ComputerName $CLuster_Name | ?{$_.Type -eq 'Physical Disk'}
$DiskLetter0 = $AllCluDisks[0] | Foreach {Get-CimAssociatedInstance -InputObject $_ -ResultClassName MSCluster_DiskPartition}
$DiskLetter1 = $AllCluDisks[1] | Foreach {Get-CimAssociatedInstance -InputObject $_ -ResultClassName MSCluster_DiskPartition}
$DiskLetter2 = $AllCluDisks[2] | Foreach {Get-CimAssociatedInstance -InputObject $_ -ResultClassName MSCluster_DiskPartition}
$DiskLetter3 = $AllCluDisks[3] | Foreach {Get-CimAssociatedInstance -InputObject $_ -ResultClassName MSCluster_DiskPartition}
$DiskLetter4 = $AllCluDisks[4] | Foreach {Get-CimAssociatedInstance -InputObject $_ -ResultClassName MSCluster_DiskPartition}
$DiskLetter5 = $AllCluDisks[5] | Foreach {Get-CimAssociatedInstance -InputObject $_ -ResultClassName MSCluster_DiskPartition}
$DiskLetter6 = $AllCluDisks[6] | Foreach {Get-CimAssociatedInstance -InputObject $_ -ResultClassName MSCluster_DiskPartition}
$DiskLetter1.Path

write-log "Number of disks found is" -Type INFO
$AllCluDisks.count 
$AllCluDisks.count | Out-File  -Encoding ascii -Append $AppendLog 

############################################################################################################################################################################
# From Above code Create a Hash Table to map the Drive letter with the Disk cluster Name in order for assigning the disk on next Resource creation
############################################################################################################################################################################
$HashCluDisks  =[ordered] @{
                $DiskLetter0.Path.Substring(0,1) = $AllCluDisks[0].Name
                $DiskLetter1.Path.Substring(0,1) = $AllCluDisks[1].Name
                $DiskLetter2.Path.Substring(0,1) = $AllCluDisks[2].Name 
                $DiskLetter3.Path.Substring(0,1) = $AllCluDisks[3].Name 
                $DiskLetter4.Path.Substring(0,1) = $AllCluDisks[4].Name 
                $DiskLetter5.Path.Substring(0,1) = $AllCluDisks[5].Name 
                $DiskLetter6.Path.Substring(0,1) = $AllCluDisks[6].Name 
                }

Write-log "Found below Clustered Disks with their corresponding Partitions" -Type INFO
$HashCluDisks
$HashCluDisks | Out-File  -Encoding ascii -Append $AppendLog 

write-log " The keys to access the Drive letters Disk label values are as follows:" -Type INFO
$HashCluDisks.Keys
$HashCluDisks.Keys | Out-File  -Encoding ascii -Append $AppendLog 


    ######################################################################################
    # Time to Add the First cluster role + disks to first node
    ######################################################################################
    Write-log "Creating the first FS Resources named $FS_1_Final which will contain disk E:" -Type INFO
    Add-ClusterFileServerRole -Cluster $CLuster_Name -Storage ($HashCluDisks.E) -Name $FS_1_Final -StaticAddress $IP_4 -ErrorAction SilentlyContinue
    Start-Sleep 20
    Set-ClusterOwnerNode -Cluster $CLuster_Name -Group $FS_1_Final -Owners $Node_1
    Start-Sleep 20
    $FS_1_Final_OK = Get-ClusterResource -Cluster $CLuster_Name | Where {$_.ResourceType -eq "File Server"} | Where OwnerGroup -eq $FS_1_Final
    If ($FS_1_Final_OK)
    {
        Write-log "$FS_1_Final Resource group was successfully created" -Type INFO
        $FS_1_Final_OK
        $FS_1_Final_OK |  Out-File  -Encoding ascii -Append $AppendLog 
    }
    Else
    {
        write-log "Something went wrong with the information you input, please review and allow for the next resource to be created" -Type ERROR
        pause
    }
    
   

    ######################################################################################
    # Time to Add the Second cluster role + disks to first node
    ######################################################################################
    Add-ClusterFileServerRole -Cluster $CLuster_Name -Storage ($HashCluDisks.F),($HashCluDisks.G),($HashCluDisks.H) -Name $FS_2_Final -StaticAddress $IP_5
    Start-Sleep 20
    Set-ClusterOwnerNode -Cluster $CLuster_Name -Group $FS_2_Final -Owners $Node_2
    Start-Sleep 20
    $FS_2_Final_OK = Get-ClusterResource -Cluster $CLuster_Name | Where {$_.ResourceType -eq "File Server"} | Where OwnerGroup -eq $FS_2_Final
    If ($FS_2_Final_OK)
    {
        Write-log "$FS_2_Final Resource group was successfully created" -Type INFO
        $FS_2_Final_OK
        $FS_2_Final_OK |  Out-File  -Encoding ascii -Append $AppendLog 
    }
    Else
    {
        write-log "Something went wrong with the information you input, please review and allow for the next resource to be created" -Type ERROR
        pause
    }

    ######################################################################################
    # Time to Add the Third cluster role + disks to first node
    ######################################################################################
    Add-ClusterFileServerRole -Cluster $CLuster_Name -Storage ($HashCluDisks.I) -Name $FS_3_Final -StaticAddress $IP_6
    Start-Sleep 20
    Set-ClusterOwnerNode -Cluster $CLuster_Name -Group $FS_3_Final -Owners $Node_2
    Start-Sleep 20
    $FS_3_Final_OK = Get-ClusterResource -Cluster $CLuster_Name | Where {$_.ResourceType -eq "File Server"} | Where OwnerGroup -eq $FS_3_Final
    If ($FS_3_Final_OK)
    {
        Write-log "$FS_3_Final Resource group was successfully created" -Type INFO
        $FS_3_Final_OK
        $FS_3_Final_OK |  Out-File  -Encoding ascii -Append $AppendLog 
    }
    Else
    {
        write-log "Something went wrong with the information you input, please review and allow for the next resource to be created" -Type ERROR
        pause
    }
######################################################################################
   # Time to Add the Fourth cluster role + disks to first node
######################################################################################
    Add-ClusterFileServerRole -Cluster $CLuster_Name -Storage ($HashCluDisks.J) -Name $FS_4_Final -StaticAddress $IP_7
    Start-Sleep 20
    Set-ClusterOwnerNode -Cluster $CLuster_Name -Group $FS_4_Final -Owners $Node_1
    Start-Sleep 20
    $FS_4_Final_OK = Get-ClusterResource -Cluster $CLuster_Name | Where {$_.ResourceType -eq "File Server"} | Where OwnerGroup -eq $FS_4_Final
    If ($FS_4_Final_OK)
    {
        Write-log "$FS_4_Final Resource group was successfully created" -Type INFO
        $FS_4_Final_OK
        $FS_4_Final_OK |  Out-File  -Encoding ascii -Append $AppendLog 
    }
    Else
    {
        write-log "Something went wrong with the information you input, please review and allow for the next resource to be created" -Type ERROR
        pause
    }
write-log "Waiting for the Cluster resources tasks to be completed"
Start-Sleep 20

######################################################################################
#Time to Reblance Cluster Resources as per he Standard on preferred owners
######################################################################################
Write-log "Reblancing Cluster Group Resources as per the Taleo Standard on preferred owners" -Type INFO
Get-ClusterGroup -Cluster $CLuster_Name
Get-ClusterGroup -Cluster $CLuster_Name |  Out-File  -Encoding ascii -Append $AppendLog 

Move-ClusterGroup -Cluster $CLuster_Name -name "$FS_2_Final" -node $Node_2 -ErrorAction SilentlyContinue
Start-Sleep 30
Move-ClusterGroup -Cluster $CLuster_Name -name "$FS_3_Final" -node $Node_2 -ErrorAction SilentlyContinue
Start-Sleep 30

$GroupREsources = @()
$FSGroupREsources = @()
$GroupREsources = Get-ClusterGroup -Cluster $CLuster_Name 
    Foreach ($Resource in $GroupREsources)
    {
        If ($Resource.Name -like "*-fs") 
         { 
         $FSGroupREsources += $Resource | Format-Table -AutoSize
        }
    }

    Write-log "Resources have been rebalanced as follows:" -Type INFO
    $FSGroupREsources
    $FSGroupREsources | Out-File  -Encoding ascii -Append $AppendLog 


            #####################################################################
            # NEED TO DOUBLE CHECK WHY THE 2 NODES ARE NOT SET AS PREFERED OWNERS
            #####################################################################

# Setting both Owners for the resources
write-log "Now setting the order of the prefered owner node per resource" -Type INFO
Set-ClusterOwnerNode -Cluster $CLuster_Name -Group $FS_1_Final -Owners $Node_1 , $Node_2
Set-ClusterOwnerNode -Cluster $CLuster_Name -Group $FS_2_Final -Owners $Node_2 , $Node_1
Set-ClusterOwnerNode -Cluster $CLuster_Name -Group $FS_3_Final -Owners $Node_2 , $Node_1
Set-ClusterOwnerNode -Cluster $CLuster_Name -Group $FS_4_Final -Owners $Node_1 , $Node_2


$OwnerResources = @()
$FSOwnerREsources = @()
$OwnerREsources = Get-ClusterGroup -Cluster $CLuster_Name | Get-ClusterOwnerNode
    Foreach ($Resource in $OwnerREsources)
    {
        If ($Resource.ClusterObject -like "*-fs") 
         { 
         $FSOwnerREsources += $Resource | Format-Table -AutoSize
        }
    }

    Write-log "Resources Owner Order has been set as follows:" -Type INFO
    $FSOwnerREsources
    $FSOwnerREsources | Out-File  -Encoding ascii -Append $AppendLog 




# Trying to get all the cluster resources filtering the "restartperiod" and "RetryPeriodOnFailure" parameters to adjust them to the standard
Write-log "Time to set the standard vaules for restartperiod and RetryPeriodOnFailure parameters, below are the current ones as set by default " -Type INFO
$ResourceValues = @()
$ResourceValues = Get-ClusterResource -Cluster $CLuster_Name | Select Name, restartperiod, RetryPeriodOnFailure
$ResourceValues
$ResourceValues | Out-File  -Encoding ascii -Append $AppendLog 

# Once we saved all the resources in a array we proceed to set the values on nested foreach, We don't care the name as all must be the same
Write-log "Starting to change those values to 2 Minutes" -Type INFO

            Foreach ($value in $ResourceValues)
            {
                Get-ClusterResource -Cluster $CLuster_Name -Name $value.Name | % {$_.restartperiod = "120000"}
                Get-ClusterResource -Cluster $CLuster_Name -Name $value.Name | % {$_.RetryPeriodOnFailure = "120000"}
            }

Write-log "values have been set as the standard" -Type INFO
$NewResourceValues = @()
$NewResourceValues = Get-ClusterResource -Cluster $CLuster_Name | Select Name, restartperiod, RetryPeriodOnFailure
$NewResourceValues
$NewResourceValues | Out-File  -Encoding ascii -Append $AppendLog 


# Time to set the new values for the Cluster FS groups on FailoverThreshold and FailoverPeriod, here we filter by Onlie group not only the FS role groups but also the Core group which is the QUORUM

Write-log "Time to set the new values for the Cluster FS groups on FailoverThreshold and FailoverPeriod parameters, below are the current ones as set by default " -Type INFO
$FSGroupValues = @()
$FSGroupValues = Get-ClusterGroup -Cluster $CLuster_Name | where State -eq "Online" | Select Name, FailoverThreshold, FailoverPeriod
$FSGroupValues
$FSGroupValues | Out-File  -Encoding ascii -Append $AppendLog 

# Once we saved all the resources in a array we proceed to set the values on nested foreach, We don't care the name as all must be the same
Write-log "Starting to change those values on FailoverThreshold=3 and FailoverPeriod=2" -Type INFO

            Foreach ($FSvalue in $FSGroupValues)
            {
                 Get-ClusterGroup -Cluster $CLuster_Name -Name $FSvalue.Name | % {$_.FailoverThreshold = "3"}
                 Get-ClusterGroup -Cluster $CLuster_Name -Name $FSvalue.Name | % {$_.FailoverPeriod = "2"}
            }

Write-log "FS group values have been set as the standard" -Type INFO
$NewFSGroupValues = @()
$NewFSGroupValues = Get-ClusterGroup -Cluster $CLuster_Name | where State -eq "Online" | Select Name, FailoverThreshold, FailoverPeriod
$NewFSGroupValues
$NewFSGroupValues | Out-File  -Encoding ascii -Append $AppendLog 



