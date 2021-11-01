$scptName = (Get-item (Get-PSCallStack)[1].ScriptName).BaseName

$WarningPreference = 'SilentlyContinue'
$ErrorActionPreference = 'SilentlyContinue'



$serverName = Get-Content Env:COMPUTERNAME
$dataCenter = $serverName.Substring(0,2).toUpper()
$serverPOD = $serverName.Substring(6,1).toUpper()
$FQDN = [System.Net.Dns]::GetHostByName('').HostName
$entity = (($FQDN.Split('.'))[1])
$cloud = (($FQDN.Split('.'))[2])
$env = (($FQDN.Split('.'))[3])
$date = Get-Date -Format 'yyyyMMdd_HHmmssffff'
$folderPath = $PWD.Path + '\'
$logFile = "C:\cs_pkgs\$scptName$date.log"
$logPath = "C:\cs_pkgs\logs"

$usr = [environment]::UserDomainName + '\' + $env:USERNAME

function logInfos(){
    
    param
    (
        [Parameter(Mandatory=$true)]
        [Alias('Message')]
        [String] $logInformations, 
            
        [ValidateSet('YELLOW','RED','GREEN')]
        [String]$color =$null        
    )

    if($logInformations){
        
        $time = Get-Date -UFormat '%y%m%d%H%M%S'
        Add-Content $logFile "$usr::$time::$logInformations"


        Switch ($color){
        
        $null {
                Write-Host $logInformations
                Write-Host ''
            }


        'yellow' {
                    Write-Host $logInformations -ForegroundColor Yellow

            }


        'red' {
                    Write-Host $logInformations -ForegroundColor Red

            }


        'green' {
                    Write-Host $logInformations -ForegroundColor Green
                    Write-Host ''
            }
                
        }
            
    }
    
}

function writeError(){

    Param
    (
        [Parameter(Mandatory ='yes')]
        $jobError        
    
    )


    Write-Host '========================================================'
    Write-Host "$jobError" -ForegroundColor Red
    Write-Host '========================================================'
    logInfos "$usr::$jobError"
    Notepad $logFile
}

function write-log(){
    
    param
    (
        [Parameter(Mandatory=$true)]
        [Alias('logInformations')]
        [String] $Message, 
            
        [ValidateSet('INFO','WARNING','ERROR')]
        [String]$Type = $null        
    )

    
    $logType = @{ 'ERROR' = 'RED'; 'WARNING' = 'YELLOW'; 'INFO' = 'GREEN' }
    $date = Get-Date -UFormat '%d-%m-%y %H:%M:%S'

   
    if(-not $Type){
        Write-Host $Message
        Add-Content $logFile $Message
    }
    else{
        #$msg = 
        Write-Host "$Type:: " $date ':: '  $Message -ForegroundColor $($logType.$Type)
        Add-Content $logFile $("$Type::  $date ::   $Message")
    }

    
    
}

function open-log(){

    if( -not (Test-Path -Path $logPath ) ) {

            New-Item -ItemType  Directory $logPath -Force | Out-Null

        }
    
    if( -not (Test-Path -Path $logFile ) ) {

        New-Item -ItemType file $logFile -Force | Out-Null

    }


    $out =  "#########################################################################`r`n"
    $out += "########################   OPEN LOG    ##################################`r`n"
    $out += "#########################################################################`r`n"
    $out += "####`r`n"
    $out += "####   User:        $usr `r`n"
    $out += "####   ServerName:  $serverName `r`n"
    $out += "####   Data Center: $dataCenter `r`n"
    $out += "####   Server POD:  $serverPOD `r`n"
    $out += "####   FQDN:        $FQDN `r`n"
    $out += "####   Entity:      $entity `r`n"
    $out += "####   Cloud:       $cloud `r`n"
    $out += "####   Date: $(Get-Date -UFormat '%d-%m-%y %H:%M:%S' ) `r`n"
    $out += "#########################################################################`r`n"
    $out += "`r`n"

    

    Add-Content -Path $logFile $out
 }

function close-log(){

    $out =  "#########################################################################`r`n"
    $out += "########################   CLOSE LOG   ##################################`r`n"
    $out += "#########################################################################`r`n"

    Add-Content -Path $logFile $out 
 }

function get-nextFileNumber(){

    $lastLog = $lastFileNo =$null
    $lastLog = $(Get-ChildItem $folderPath | where name -Like "*.log"|sort -Descending)[0].Name
    $lastLog = $lastLog.Split('.')
    $lastFileNo = $lastLog[0].Substring($lastLog[0].Length-4)
    [int]$lastFileNo = [int]$lastFileNo
    $lastFileNo++
    return $lastFileNo.ToString('0000')
}

function getLogFilePath(){
    
    return $logFile
}