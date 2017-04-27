###############################################################################
#                                                                             #
#  DSC script to build out two Server 2012 r2 Domain Controllers in Azure     #
#  using a combination of PowerShell and DSC                                  #
#                                                                             #
###############################################################################
configuration BuildADServers
{
    param
    (
  
        [Parameter(Mandatory)]
        [String]$DomainName,

        [Parameter(Mandatory)]
        [String]$DomainNetbiosName,
        
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,

        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30

    ) 
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xStorage,xComputerManagement,xNetworking,xActiveDirectory #check $env:PSModulePath
   
    [System.Management.Automation.PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($Admincreds.UserName)", $Admincreds.Password)
 

 node localhost
 {
 
        LocalConfigurationManager
        {
            ActionAfterReboot = 'ContinueConfiguration'
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
            AllowModuleOverWrite = $true
        }

        xWaitforDisk Disk2
        {
             DiskNumber = 2
             RetryIntervalSec =$RetryIntervalSec
             RetryCount = $RetryCount
        }

        xDisk ADDataDisk2
        {
            DiskNumber = 2
            DriveLetter = 'F'
            FSLabel = 'Data'
            Size = 100GB
			DependsOn = '[xWaitforDisk]Disk2'
         }
		
        xDisk ADDataDisk3
        {
            DiskNumber = 2
            DriveLetter = 'G'
            FSLabel = 'Log'
            Size = 50GB
            DependsOn = '[xDisk]ADDataDisk2'
        }

        WindowsFeature DNS
        {
            Ensure = "Present"
            Name = "DNS"
            DependsOn = '[xDisk]ADDataDisk3'
        }

        WindowsFeature DnsTools
        {
            Ensure = "Present"
            Name = "RSAT-DNS-Server"
            DependsOn = "[WindowsFeature]DNS"
        }

        WindowsFeature ADDSInstall
        {
            Ensure = "Present"
            Name = "AD-Domain-Services"
            DependsOn = "[WindowsFeature]DNS"
        }

        WindowsFeature RSATTools 
        { 
            DependsOn= '[WindowsFeature]ADDSInstall'
            Ensure = 'Present'
            Name = 'RSAT-AD-Tools'
            IncludeAllSubFeature = $true
        }  

        xADDomainController SecondDS
        {
            DomainName = $DomainName
            DomainAdministratorCredential = $DomainCreds
            SafemodeAdministratorPassword = $DomainCreds
            DatabasePath = "F:\NTDS"
            LogPath = "F:\NTDS"
            SysvolPath = "F:\SYSVOL"
            DependsOn = "[WindowsFeature]RSATTools"
        }
   }
}
