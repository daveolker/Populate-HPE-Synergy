##############################################################################
# Cleanup_HPE_Syergy.ps1
#
# - Example script for de-configuring the HPE Synergy Appliance
#
#   VERSION 5.20
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
        [String]$OneViewModule                  = "HPOneView.520"
)


function Remove_Logical_Enclosures
{
    Write-Output "Removing all Logical Enclosures" | Timestamp
    Get-HPOVLogicalEnclosure | Remove-HPOVLogicalEnclosure -Force -Confirm:$false | Wait-HPOVTaskComplete
    Write-Output "All Logical Enclosures Removed" | Timestamp
}    


function Remove_Enclosure_Groups
{
    Write-Output "Removing all Enclosure Groups" | Timestamp
    Get-HPOVEnclosureGroup | Remove-HPOVEnclosureGroup -Force -Confirm:$false
    Write-Output "All Enclosure Groups Removed" | Timestamp
}
    

function Remove_Logical_Interconnect_Groups
{
    Write-Output "Removing all Logical Interconnect Groups" | Timestamp
    Get-HPOVLogicalInterconnectGroup | Remove-HPOVLogicalInterconnectGroup -Force -Confirm:$false | Wait-HPOVTaskComplete
    Write-Output "All Logical Interconnect Groups Removed" | Timestamp
}


function Remove_OS_Deployment_Servers
{
    Write-Output "Removing all OS Deployment Servers" | Timestamp
    Get-HPOVOSDeploymentServer | Remove-HPOVOSDeploymentServer -Confirm:$false | Wait-HPOVTaskComplete
    #
    # Sleep for 400 seconds to allow the OS Deployment Cluster to Form
    #
    #Sleep -Seconds 400
    Write-Output "All OS Deployment Servers Removed" | Timestamp
}


function Remove_Server_Profile_Templates
{
    Write-Output "Removing all Server Profile Templates" | Timestamp
    Get-HPOVServerProfileTemplate | Remove-HPOVServerProfileTemplate -Force -Confirm:$false | Wait-HPOVTaskComplete
    Write-Output "All Server Profile Templates Removed" | Timestamp
}


function Remove_Server_Profiles
{
    Write-Output "Removing all Server Profiles" | Timestamp
    Get-HPOVServerProfile | Remove-HPOVserverProfile -Force -Confirm:$false | Wait-HPOVTaskComplete
    Write-Output "All Server Profiles Removed" | Timestamp
}


function Rename_Enclosures
{
    Write-Output "Renaming Enclosures" | Timestamp
    $Enc = Get-HPOVEnclosure -Name Synergy-Encl-1 -ErrorAction SilentlyContinue
    Set-HPOVEnclosure -Name "0000A66101" -Enclosure $Enc | Wait-HPOVTaskComplete

    $Enc = Get-HPOVEnclosure -Name Synergy-Encl-2 -ErrorAction SilentlyContinue
    Set-HPOVEnclosure -Name "0000A66102" -Enclosure $Enc | Wait-HPOVTaskComplete

    $Enc = Get-HPOVEnclosure -Name Synergy-Encl-3 -ErrorAction SilentlyContinue
    Set-HPOVEnclosure -Name "0000A66103" -Enclosure $Enc | Wait-HPOVTaskComplete

    $Enc = Get-HPOVEnclosure -Name Synergy-Encl-4 -ErrorAction SilentlyContinue
    Set-HPOVEnclosure -Name "0000A66104" -Enclosure $Enc | Wait-HPOVTaskComplete

    $Enc = Get-HPOVEnclosure -Name Synergy-Encl-5 -ErrorAction SilentlyContinue
    Set-HPOVEnclosure -Name "0000A66105" -Enclosure $Enc | Wait-HPOVTaskComplete

    Write-Output "All Enclosures Renamed" | Timestamp
}


function Remove_Storage_Volume_Templates
{
    Write-Output "Removing all Storage Volume Templates" | Timestamp
    Get-HPOVStorageVolumeTemplate | Remove-HPOVStorageVolumeTemplate -Force -Confirm:$false
    Write-Output "All Storage Volume Templates Removed" | Timestamp
}


function Remove_Storage_Volumes
{
    Write-Output "Removing all Storage Volumes" | Timestamp
    Get-HPOVStorageVolume | Remove-HPOVStorageVolume -Confirm:$false | Wait-HPOVTaskComplete
    Write-Output "All Storage Volumes Removed" | Timestamp
}


function Remove_Storage_Pools
{
    Write-Output "Removing all Storage Pools" | Timestamp
    Get-HPOVStoragePool | Remove-HPOVStoragePool -Force -Confirm:$false | Wait-HPOVTaskComplete
    Write-Output "All Storage Pools Removed" | Timestamp
}


function Remove_Storage_Systems
{
    Write-Output "Removing all Storage Systems" | Timestamp
    Get-HPOVStorageSystem | Remove-HPOVStorageSystem -Force -Confirm:$false | Wait-HPOVTaskComplete
    Write-Output "All Storage Systems Removed" | Timestamp
}


function Remove_Network_Sets
{
    Write-Output "Removing all Network Sets" | Timestamp
    Get-HPOVNetworkSet | Remove-HPOVNetworkSet -Confirm:$false | Wait-HPOVTaskComplete
    Write-Output "All Network Sets Removed" | Timestamp
}


function Remove_Networks
{
    Write-Output "Removing all Networks" | Timestamp
    Get-HPOVNetwork | Remove-HPOVNetwork -Force -Confirm:$false | Wait-HPOVTaskComplete
    Write-Output "All Networks Removed" | Timestamp
}


function Remove_IPv4_Address_Pool_Ranges
{
    Write-Output "Removing all IPv4 Address Pool Ranges" | Timestamp
    Get-HPOVAddressPoolRange | Remove-HPOVAddressPoolRange -Confirm:$false
    Write-Output "All IPv4 Address Pools Removed" | Timestamp
}


function Remove_IPv4_Subnets
{
    Write-Output "Removing all IPv4 Subnets" | Timestamp
    Get-HPOVAddressPoolSubnet | Remove-HPOVAddressPoolSubnet -Confirm:$false
    Write-Output "All IPv4 Subnets Removed" | Timestamp
}


function Remove_SAN_Managers
{
    Write-Output "Removing all SAN Managers" | Timestamp
    Get-HPOVSanManager | Remove-HPOVSanManager -Confirm:$false | Wait-HPOVTaskComplete
    Write-Output "All SAN Managers Removed" | Timestamp
}


function Remove_Licenses
{
    Write-Output "Removing all Licenses" | Timestamp
    Get-HPOVLicense | Remove-HPOVLicense -Confirm:$false
    Write-Output "All Licenses Removed" | Timestamp
}


function Remove_Firmware_Bundles
{
    Write-Output "Removing all Fimrware Bundles" | Timestamp
    Get-HPOVBaseline | Remove-HPOVBaseline -Confirm:$false | Wait-HPOVTaskComplete
    Write-Output "All Firmware Bundles Removed" | Timestamp
}


function Remove_New_Users
{
    Write-Output "Removing all non-default Users" | Timestamp
    Get-HPOVUser -Name BackupAdmin | Remove-HPOVUser -Confirm:$false
    Get-HPOVUser -Name NetworkAdmin | Remove-HPOVUser -Confirm:$false
    Get-HPOVUser -Name ServerAdmin | Remove-HPOVUser -Confirm:$false
    Get-HPOVUser -Name StorageAdmin | Remove-HPOVUser -Confirm:$false
    Get-HPOVUser -Name SoftwareAdmin | Remove-HPOVUser -Confirm:$false
    Write-Output "All non-default Users Removed" | Timestamp
}


function Remove_Scopes
{
    Write-Output "Removing all Scopes" | Timestamp
    Get-HPOVScope -Name FinanceScope | Remove-HPOVScope -Confirm:$false
    Write-Output "All Scopes Removed" | Timestamp
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

if (-not (Get-Module HPOneview.520))
{
    Import-Module -Name HPOneView.520
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
        Write-Output "Blank Credential is not permitted.  Exiting."
        Exit
    }

    Connect-HPOVMgmt -Hostname $ApplianceIP -Credential $AdminCred -AuthLoginDomain $OVAuthDomain -ErrorAction Stop

    if (-not $ConnectedSessions)
    {
        Write-Output "Login to Synergy System failed.  Exiting."
        Exit
    }
}

filter Timestamp {"$(Get-Date -Format G): $_"}

Write-Output "De-Configuring HPE Synergy Appliance" | Timestamp

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

Write-Output "HPE Synergy Appliance De-configuration Complete" | Timestamp

Disconnect-HPOVMgmt