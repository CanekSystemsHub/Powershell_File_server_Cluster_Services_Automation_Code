
# This code is only for migrated clusters to setthe proper Failover values.
# Set free execution for this script and we start with the path recognition and logging
# On ISE always move manually to the path where the script is located. cd C:\cs_pkgs\FS_Deploy_Script

$ORG_Path = $null
$ORG_Path = $pwd.Path
Import-Module $ORG_Path\loginfos.psm1 -ErrorAction SilentlyContinue
Import-Module NetTCPIP
Import-Module NetAdapter
Import-Module ActiveDirectory
Import-Module Storage

open-log

$AppendLog = getLogFilePath


# Validation of Cluster_Settings.txt file
# Cluster_Settings.txt contect is input in a variable to start with the logic to get each value, this txt file needs to be feeded in advance.

        $path_Settings = $ORG_Path + "\Cluster_Settings.txt"
        $clus_settings = gc $path_Settings


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
       
                $CLuster_Name = $Set_Split[0].Trim() + ".$FQDN"
                $Node_1 = $Set_Split[1].Trim() + ".$FQDN"
                $Node_2 = $Set_Split[2].Trim() + ".$FQDN"
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




# Trying to get all the cluster resources filtering the "restartperiod" and "RetryPeriodOnFailure" parameters to adjust them to the standard
Write-log "Time to set the standard values for restart period and RetryPeriodOnFailure parameters, below are the current ones as set by default " -Type INFO
$ResourceValues = @()
$ResourceValues = Get-ClusterResource -Cluster $CLuster_Name.Substring(0,12) | Select Name, restartperiod, RetryPeriodOnFailure
$ResourceValues
$ResourceValues | Out-File  -Encoding ascii -Append $AppendLog 

# Once we saved all the resources in a array we proceed to set the values on nested foreach, We don't care the name as all must be the same
Write-log "Starting to change those values to 2 Minutes" -Type INFO

            Foreach ($value in $ResourceValues)
            {
                Get-ClusterResource -Cluster $CLuster_Name.Substring(0,12) -Name $value.Name | % {$_.restartperiod = "120000"}
                Get-ClusterResource -Cluster $CLuster_Name.Substring(0,12) -Name $value.Name | % {$_.RetryPeriodOnFailure = "120000"}
            }

Write-log "values have been set as the standard" -Type INFO
$NewResourceValues = @()
$NewResourceValues = Get-ClusterResource -Cluster $CLuster_Name.Substring(0,12) | Select Name, restartperiod, RetryPeriodOnFailure
$NewResourceValues
$NewResourceValues | Out-File  -Encoding ascii -Append $AppendLog 


# Time to set the new values for the Cluster FS groups on FailoverThreshold and FailoverPeriod, here we filter by Onlie group not only the FS role groups but also the Core group which is the QUORUM

Write-log "Time to set the new values for the Cluster FS groups on FailoverThreshold and FailoverPeriod parameters, below are the current ones as set by default " -Type INFO
$FSGroupValues = @()
$FSGroupValues = Get-ClusterGroup -Cluster $CLuster_Name.Substring(0,12) | where State -eq "Online" | Select Name, FailoverThreshold, FailoverPeriod
$FSGroupValues
$FSGroupValues | Out-File  -Encoding ascii -Append $AppendLog 

# Once we saved all the resources in a array we proceed to set the values on nested foreach, We don't care the name as all must be the same
Write-log "Starting to change those values on FailoverThreshold=3 and FailoverPeriod=2" -Type INFO

            Foreach ($FSvalue in $FSGroupValues)
            {
                 Get-ClusterGroup -Cluster $CLuster_Name.Substring(0,12) -Name $FSvalue.Name | % {$_.FailoverThreshold = "3"}
                 Get-ClusterGroup -Cluster $CLuster_Name.Substring(0,12) -Name $FSvalue.Name | % {$_.FailoverPeriod = "2"}
            }

Write-log "FS group values have been set as the standard" -Type INFO
$NewFSGroupValues = @()
$NewFSGroupValues = Get-ClusterGroup -Cluster $CLuster_Name | where State -eq "Online" | Select Name, FailoverThreshold, FailoverPeriod
$NewFSGroupValues
$NewFSGroupValues | Out-File  -Encoding ascii -Append $AppendLog 
Start-Sleep 5
