# Populate HPE Synergy
Configure and populate an HPE Synergy Data Center Simulator virtual appliance for demonstration, educational, and custom integration purposes.

##
## The HPE Synergy Data Center Simulator is an HPE proprietary tool available for HPE employee and Partner use only. 
#

The HPE Synergy Data Center Simulator (DCS) is a useful tool for learning about the HPE Synergy Composable Infrastructure platform and the HPE OneView management interface. The tool simulates a datacenter comprised of multiple racks of HPE Synergy hardware, 3PAR storage arrays, SAN managers, and other simulated infrastructure. The simulator looks and acts just like a real, physical Synergy environment. It uses the same RESTful interface as real Synergy and OneView instances, making it the perfect environment for learning how to implement and demonstrate Infrastructure-as-Code.

The Populate HPE Synergy scripts work with the Data Center Simulator to instantiate all of the simulated hardware and components availble in the appliance, making it a much more feature-rich environment to demonstrate and learn how to use features such as Server Profile Templates, Server Profiles, etc.

# How to use the scripts
This package contains two primary scripts and one configuration file. These are PowerShell scripts and they require the HPE OneView PowerShell library found here: https://github.com/HewlettPackard/POSH-HPOneView.

## Populate_HPE_Synergy.ps1
This script connects with the Synergy DCS appliance and discovers/configures all the simulated hardware.  When the script is run, it prompts for the hostname or IP address of the Synergy appliance, the Administrator user name (usually Administrator), and the Administrator password.

The script does the following:

* Prompts the user for the location of a Service Pack for ProLiant to upload as a Firmware Bundle
* Prompts the user for OneView Advanced Licenses, if available
* Prompts the user for Synergy 8GB Fibre Channel Licenses, if available
* Configures two additional Synergy Enclosures
* Renames all five Synergy Enclosures
* Powers off all Compute Modules
* Configures the simulated Cisco SAN Managers
* Configures multiple Ethernet, Fibre Channel, and FCoE Networks
* Configures multiple 3PAR Storage Arrays, Volume Templates, and Volumes
* Adds various Users with different permissions
* Deploys an HPE Image Streamer OS Deployment instance
* Creates Logical Interconnect Groups
* Creates multiple Uplink Sets
* Creates an Enclosure Group
* Creates a Logical Enclosure
* Creates multiple sample Server Profile Templates
* Creates multiple sample Server Profiles
* Adds various Scopes


## RHEL
In order to create an OSBP that installs Docker EE on a RHEL7 server, we need save the provided OOTB RedHat 7.2 OSBP into a new OSBP and perform the following changes:

* Add the following custom attributes:
	-	docker_repo (mandatory): docker repository for Docker Enterprise Edition. This can be either the URL provided by Docker (external URL) or an internal URL accesible via http. When using an external URL please note that if your licence cover different Linux systems, you will need 
	-	docker_version (optional): version of Docker Enterprise Edition to be installed (i.e. 17.03). If no version is specified then the latest found will be installed.
	-	nic_teaming (optional): the OSBP has the option to create one or more NIC teams to provide HA networking. This custom attribute defines the list of NIC teams we intend to create. Format is as follows:
	```
		<team name 1>, <MAC1>, <MAC2>
		<team name 2>, <MAC3>, <MAC4>
		<team name 3>, <MAC5>, <MAC6>
		...
	```