##############################################################################
# Cleanup_HPE_Syergy.ps1
#
# - Example script for de-configuring the HPE Synergy Appliance
#
#   VERSION 5.40
#
#   AUTHORS
#   Dave Olker - HPE Storage and Big Data
#
# (C) Copyright 2020 Hewlett Packard Enterprise Development LP 
##############################################################################
<#
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
#>

# ------------------ Parameters
Param ( [String]$OVApplianceIP                  = "192.168.62.128",
        [String]$OVAdminName                    = "Administrator",
        [String]$OVAuthDomain                   = "Local",
        [String]$OneViewModule                  = "HPEOneView.540"
)


function Get-TimeStamp {    
    return "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
}


function Remove_Logical_Enclosures
{
    Write-Host "$(Get-TimeStamp) Removing all Logical Enclosures"
    Get-OVLogicalEnclosure | Remove-OVLogicalEnclosure -Force -Confirm:$false | Wait-OVTaskComplete
    Write-Host "$(Get-TimeStamp) All Logical Enclosures Removed"
}    


function Remove_Enclosure_Groups
{
    Write-Host "$(Get-TimeStamp) Removing all Enclosure Groups"
    Get-OVEnclosureGroup | Remove-OVEnclosureGroup -Force -Confirm:$false
    Write-Host "$(Get-TimeStamp) All Enclosure Groups Removed"
}
    

function Remove_Logical_Interconnect_Groups
{
    Write-Host "$(Get-TimeStamp) Removing all Logical Interconnect Groups"
    Get-OVLogicalInterconnectGroup | Remove-OVLogicalInterconnectGroup -Force -Confirm:$false | Wait-OVTaskComplete
    Write-Host "$(Get-TimeStamp) All Logical Interconnect Groups Removed"
}


function Remove_OS_Deployment_Servers
{
    Write-Host "$(Get-TimeStamp) Removing all OS Deployment Servers"
    Get-OVOSDeploymentServer | Remove-OVOSDeploymentServer -Confirm:$false | Wait-OVTaskComplete
    #
    # Sleep for 400 seconds to allow the OS Deployment Cluster to Form
    #
    #Sleep -Seconds 400
    Write-Host "$(Get-TimeStamp) All OS Deployment Servers Removed"
}


function Remove_Server_Profile_Templates
{
    Write-Host "$(Get-TimeStamp) Removing all Server Profile Templates"
    Get-OVServerProfileTemplate | Remove-OVServerProfileTemplate -Force -Confirm:$false | Wait-OVTaskComplete
    Write-Host "$(Get-TimeStamp) All Server Profile Templates Removed"
}


function Remove_Server_Profiles
{
    Write-Host "$(Get-TimeStamp) Removing all Server Profiles"
    Get-OVServerProfile | Remove-OVserverProfile -Force -Confirm:$false | Wait-OVTaskComplete
    Write-Host "$(Get-TimeStamp) All Server Profiles Removed"
}


function Rename_Enclosures
{
    Write-Host "$(Get-TimeStamp) Renaming Enclosures"
    $Enc = Get-OVEnclosure -Name Synergy-Encl-1 -ErrorAction SilentlyContinue
    Set-OVEnclosure -Name "0000A66101" -Enclosure $Enc | Wait-OVTaskComplete

    $Enc = Get-OVEnclosure -Name Synergy-Encl-2 -ErrorAction SilentlyContinue
    Set-OVEnclosure -Name "0000A66102" -Enclosure $Enc | Wait-OVTaskComplete

    $Enc = Get-OVEnclosure -Name Synergy-Encl-3 -ErrorAction SilentlyContinue
    Set-OVEnclosure -Name "0000A66103" -Enclosure $Enc | Wait-OVTaskComplete

    $Enc = Get-OVEnclosure -Name Synergy-Encl-4 -ErrorAction SilentlyContinue
    Set-OVEnclosure -Name "0000A66104" -Enclosure $Enc | Wait-OVTaskComplete

    $Enc = Get-OVEnclosure -Name Synergy-Encl-5 -ErrorAction SilentlyContinue
    Set-OVEnclosure -Name "0000A66105" -Enclosure $Enc | Wait-OVTaskComplete

    Write-Host "$(Get-TimeStamp) All Enclosures Renamed"
}


function Remove_Storage_Volume_Templates
{
    Write-Host "$(Get-TimeStamp) Removing all Storage Volume Templates"
    Get-OVStorageVolumeTemplate | Remove-OVStorageVolumeTemplate -Force -Confirm:$false
    Write-Host "$(Get-TimeStamp) All Storage Volume Templates Removed"
}


function Remove_Storage_Volumes
{
    Write-Host "$(Get-TimeStamp) Removing all Storage Volumes"
    Get-OVStorageVolume | Remove-OVStorageVolume -Confirm:$false | Wait-OVTaskComplete
    Write-Host "$(Get-TimeStamp) All Storage Volumes Removed"
}


function Remove_Storage_Pools
{
    Write-Host "$(Get-TimeStamp) Removing all Storage Pools"
    Get-OVStoragePool | Remove-OVStoragePool -Force -Confirm:$false | Wait-OVTaskComplete
    Write-Host "$(Get-TimeStamp) All Storage Pools Removed"
}


function Remove_Storage_Systems
{
    Write-Host "$(Get-TimeStamp) Removing all Storage Systems"
    Get-OVStorageSystem | Remove-OVStorageSystem -Force -Confirm:$false | Wait-OVTaskComplete
    Write-Host "$(Get-TimeStamp) All Storage Systems Removed"
}


function Remove_Network_Sets
{
    Write-Host "$(Get-TimeStamp) Removing all Network Sets"
    Get-OVNetworkSet | Remove-OVNetworkSet -Confirm:$false | Wait-OVTaskComplete
    Write-Host "$(Get-TimeStamp) All Network Sets Removed"
}


function Remove_Networks
{
    Write-Host "$(Get-TimeStamp) Removing all Networks"
    Get-OVNetwork | Remove-OVNetwork -Force -Confirm:$false | Wait-OVTaskComplete
    Write-Host "$(Get-TimeStamp) All Networks Removed"
}


function Remove_IPv4_Address_Pool_Ranges
{
    Write-Host "$(Get-TimeStamp) Removing all IPv4 Address Pool Ranges"
    Get-OVAddressPoolRange | Remove-OVAddressPoolRange -Confirm:$false
    Write-Host "$(Get-TimeStamp) All IPv4 Address Pools Removed"
}


function Remove_IPv4_Subnets
{
    Write-Host "$(Get-TimeStamp) Removing all IPv4 Subnets"
    Get-OVAddressPoolSubnet | Remove-OVAddressPoolSubnet -Confirm:$false
    Write-Host "$(Get-TimeStamp) All IPv4 Subnets Removed"
}


function Remove_SAN_Managers
{
    Write-Host "$(Get-TimeStamp) Removing all SAN Managers"
    Get-OVSanManager | Remove-OVSanManager -Confirm:$false | Wait-OVTaskComplete
    Write-Host "$(Get-TimeStamp) All SAN Managers Removed"
}


function Remove_Licenses
{
    Write-Host "$(Get-TimeStamp) Removing all Licenses"
    Get-OVLicense | Remove-OVLicense -Confirm:$false
    Write-Host "$(Get-TimeStamp) All Licenses Removed"
}


function Remove_Firmware_Bundles
{
    Write-Host "$(Get-TimeStamp) Removing all Fimrware Bundles"
    Get-OVBaseline | Remove-OVBaseline -Confirm:$false | Wait-OVTaskComplete
    Write-Host "$(Get-TimeStamp) All Firmware Bundles Removed"
}


function Remove_New_Users
{
    Write-Host "$(Get-TimeStamp) Removing all non-default Users"
    Get-OVUser -Name BackupAdmin | Remove-OVUser -Confirm:$false
    Get-OVUser -Name NetworkAdmin | Remove-OVUser -Confirm:$false
    Get-OVUser -Name ServerAdmin | Remove-OVUser -Confirm:$false
    Get-OVUser -Name StorageAdmin | Remove-OVUser -Confirm:$false
    Get-OVUser -Name SoftwareAdmin | Remove-OVUser -Confirm:$false
    Write-Host "$(Get-TimeStamp) All non-default Users Removed"
}


function Remove_Scopes
{
    Write-Host "$(Get-TimeStamp) Removing all Scopes"
    Get-OVScope -Name FinanceScope | Remove-OVScope -Confirm:$false
    Write-Host "$(Get-TimeStamp) All Scopes Removed"
}


##############################################################################
#
# Main Program
#
##############################################################################

#
# Unload any earlier versions of the HPOneView POSH modules
#
Remove-Module -ErrorAction SilentlyContinue HPOneView.120
Remove-Module -ErrorAction SilentlyContinue HPOneView.200
Remove-Module -ErrorAction SilentlyContinue HPOneView.300
Remove-Module -ErrorAction SilentlyContinue HPOneView.310
Remove-Module -ErrorAction SilentlyContinue HPOneView.400
Remove-Module -ErrorAction SilentlyContinue HPOneView.410
Remove-Module -ErrorAction SilentlyContinue HPOneView.420
Remove-Module -ErrorAction SilentlyContinue HPOneView.500
Remove-Module -ErrorAction SilentlyContinue HPOneView.520
Remove-Module -ErrorAction SilentlyContinue HPEOneView.530

if (-not (Get-Module HPEOneview.540))
{
    Import-Module -Name HPEOneView.540
}

if (-not $ConnectedSessions)
{
    $ApplianceIP     = Read-Host -Prompt "Synergy Composer IP Address [$OVApplianceIP]"
    if ([string]::IsNullOrWhiteSpace($ApplianceIP))
    {
        $ApplianceIP = $OVApplianceIP
    }

    $AdminName       = Read-Host -Prompt "Administrator Username [$OVAdminName]"
    if ([string]::IsNullOrWhiteSpace($AdminName))
    {
        $AdminName   = $OVAdminName
    }

    $AdminCred       = Get-Credential -UserName $AdminName -Message "Password required for the user '$AdminName'"
    if ([string]::IsNullOrWhiteSpace($AdminCred))
    {
        Write-Host "$(Get-TimeStamp) Blank Credential is not permitted.  Exiting."
        Exit
    }

    Connect-OVMgmt -Hostname $ApplianceIP -Credential $AdminCred -AuthLoginDomain $OVAuthDomain -ErrorAction Stop

    if (-not $ConnectedSessions)
    {
        Write-Host "$(Get-TimeStamp) Login to Synergy System failed.  Exiting."
        Exit
    }
}


Write-Host "$(Get-TimeStamp) De-Configuring HPE Synergy Appliance"

Remove_Server_Profiles
Remove_Server_Profile_Templates
Remove_Logical_Enclosures
Remove_Enclosure_Groups
Remove_Logical_Interconnect_Groups
Rename_Enclosures
Remove_Storage_Volume_Templates
Remove_Storage_Volumes
Remove_Storage_Pools
Remove_Storage_Systems

#
#    Disabled the removal of OS Deployment Server since
#    it causes the OS Deployment appliance to stop working
#
#Remove_OS_Deployment_Servers

Remove_Network_Sets
Remove_Networks
Remove_IPv4_Address_Pool_Ranges
Remove_IPv4_Subnets
Remove_SAN_Managers
Remove_Licenses
Remove_New_Users
Remove_Scopes
Remove_Firmware_Bundles

Write-Host "$(Get-TimeStamp) HPE Synergy Appliance De-configuration Complete"

Disconnect-OVMgmt