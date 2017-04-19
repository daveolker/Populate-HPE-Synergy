# Populate HPE Synergy
Configure and populate an HPE Synergy Data Center Simulator virtual appliance for demonstration, educational, and custom integration purposes.

##
## The HPE Synergy Data Center Simulator is an HPE proprietary tool available for HPE employee and Partner use only. 
##

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
	-	docker_repo (mandatory): docker repository for Docker Enterprise Edition. This can be either the URL provided by Docker (external URL) or an internal URL accesible via http. When using an external URL please note that if your licence cover different Linux systems, you will need to add the ‘rhel’ folder. For instance if the URL you’ve been provided with is ‘https://storebits.docker.com/ee/linux/sub-36xxxxx3-dcc3-4ae8-b36d-06xxxxxa9/’, the custom attribute needs to be ‘https://storebits.docker.com/ee/linux/sub-36xxxxx3-dcc3-4ae8-b36d-06xxxxxa9/rhel’. If your license only covers RHEL then the provided URL should be enough. In case of doubt, please navigate to the URL through a browser to find out what the right URL is.
	-	docker_version (optional): version of Docker Enterprise Edition to be installed (i.e. 17.03). If no version is specified then the latest found will be installed.
	-	rhn_user (optional): Red Hat Network user (needed to register the system with Red Hat). Required if no internal_rhel_repo is specified.
	-	rhn_password (optional): Red Hat Network password (needed to register the system with Red Hat). Required if no internal_rhel_repo is specified.
	-	internal_rhel_repo (optional): URL pointing to an internal RHEL repository. For systems where the internet access is restricted, an internal repository can be used instead. When this custom attribute is specified, the RHN registration will be skipped. Required if no rhn_user/rhn_password are provided.
	-	proxy_hostname (optional): self-explanatory
	-	proxy_port (optional): self-explanatory
	-	no_proxy (optional): Comma-separated list of IP addresses or server names where the proxy should not be used for
	-	nic_teaming (optional): the OSBP has the option to create one or more NIC teams to provide HA networking. This custom attribute defines the list of NIC teams we intend to create. Format is as follows:
	```
		<team name 1>, <MAC1>, <MAC2>
		<team name 2>, <MAC3>, <MAC4>
		<team name 3>, <MAC5>, <MAC6>
		...
	```
	This custom attribute can have any numbers of NIC pairs, but can also be left empty if NIC teaming is not required in the system. The IP address assigned to the NIC team will be chosen as follows:
	-	The static IP of the first NIC, if available, or
	-	The static IP of the second NIC, if available, or
	-	A DHCP provided IP if both NICs are set on DHCP.

* Add the bash scripts for docker installation (https://github.hpe.com/RA-team/ICsp_Docker_OSBP/blob/master/rhel/install_docker_on_RHEL7.2.sh) and NIC teaming (https://github.hpe.com/RA-team/ICsp_Docker_OSBP/blob/master/rhel/nic_teaming_RHEL7.sh) at the end of the OSBP.
* Replace the default kickstart file in the OSBP with the one provided (https://github.hpe.com/RA-team/ICsp_Docker_OSBP/blob/master/rhel/rhel-kickstart.ks). This new kickstart file includes the changes below:
	-	Creates the Docker volume group to allow the installation of the LVM devicemapper driver
	-	Creates the Docker user belonging to the wheel group (so able to run Docker commands)
	-	Creates /boot and also /boot/efi partitions to support UEFI-based AMD64 and Intel 64 systems (https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/Installation_Guide/sect-kickstart-syntax.html)

## SLES
In order to create an OSBP that installs Docker EE on a SLES 12 server, we need save the provided OOTB SLES 12 SP1 OSBP into a new OSBP and perform the following changes:

* Add the following custom attributes:
	-	docker_repo (mandatory): docker repository for Docker Enterprise Edition. This can be either the URL provided by Docker (external URL) or an internal URL accesible via http. When using an external URL please note that if your licence cover different Linux systems, you will need to add the ‘rhel’ folder. For instance if the URL you’ve been provided with is ‘https://storebits.docker.com/ee/linux/sub-36xxxxx3-dcc3-4ae8-b36d-06xxxxxa9/’, the custom attribute needs to be ‘https://storebits.docker.com/ee/linux/sub-36xxxxx3-dcc3-4ae8-b36d-06xxxxxa9/sles’. If your license only covers RHEL then the provided URL should be enough. In case of doubt, please navigate to the URL through a browser to find out what the right URL is.
	-	docker_version (optional): version of Docker Enterprise Edition to be installed (i.e. 17.03). If no version is specified then the latest found will be installed.
	-	internal_sles_repo (optional): for systems where the internet access is resticted, an internal repository can be used instead
	-	proxy_hostname (optional): self-explanatory
	-	proxy_port (optional): self-explanatory
	-	no_proxy (optional): Comma-separated list of IP addresses or server names where the proxy should not be used for
	-	nic_teaming (optional): the OSBP has the option to create one or more NIC teams to provide HA networking. This custom attribute defines the list of NIC teams we intend to create. Format is as follows:
	```
		<team name 1>, <MAC1>, <MAC2>
		<team name 2>, <MAC3>, <MAC4>
		<team name 3>, <MAC5>, <MAC6>
		...
	```
	This custom attribute can have any numbers of NIC pairs, but can also be left empty if NIC teaming is not required in the system. The IP address assigned to the NIC team will be chosen as follows:
	-	The static IP of the first NIC, if available, or
	-	The static IP of the second NIC, if available, or
	-	A DHCP provided IP if both NICs are set on DHCP.
* Add the bash scripts for docker installation (https://github.hpe.com/RA-team/ICsp_Docker_OSBP/blob/master/sles/install_docker_on_SLES12_SP1.sh) and NIC teaming (https://github.hpe.com/RA-team/ICsp_Docker_OSBP/blob/master/sles/nic_teaming_SLES12.sh) at the end of the OSBP.
* Replace the default autoyast file in the OSBP with the one provided (https://github.hpe.com/RA-team/ICsp_Docker_OSBP/blob/master/sles/autoyast-with-SSH.txt). This new autoyast file includes the changes below:
	-	Enable the SSH service
	-	Create the docker user in the system

## Ubuntu

In order to create an OSBP that installs Docker EE on an Ubuntu 14.04 server, we need save the provided OOTB Ubuntu 14.04 OSBP into a new OSBP and perform the following changes:

* Add the following custom attributes:
	-	docker_repo (mandatory): docker repository for Docker Enterprise Edition. This can be either the URL provided by Docker (external URL) or an internal URL accesible via http. When using an external URL please note that if your licence cover different Linux systems, you will need to add the ‘rhel’ folder. For instance if the URL you’ve been provided with is ‘https://storebits.docker.com/ee/linux/sub-36xxxxx3-dcc3-4ae8-b36d-06xxxxxa9/’, the custom attribute needs to be ‘https://storebits.docker.com/ee/linux/sub-36xxxxx3-dcc3-4ae8-b36d-06xxxxxa9/ubuntu’. If your license only covers RHEL then the provided URL should be enough. In case of doubt, please navigate to the URL through a browser to find out what the right URL is.
	-	docker_version (optional): version of Docker Enterprise Edition to be installed (i.e. 17.03). If no version is specified then the latest found will be installed.
	-	internal_ubuntu_repo (optional): for systems where the internet access is resticted, an internal repository can be used instead of the default server defined in the /etc/apt/sources.list file. When an internal repository is specified, a new file called /etc/apt/sources.list.d/internal.list is created and the old /etc/apt/sources.list is renamed to /etc/apt/sources.list.old.
	-	proxy_hostname (optional): self-explanatory
	-	proxy_port (optional): self-explanatory
	-	no_proxy (optional): Comma-separated list of IP addresses or server names where the proxy should not be used for
	-	nic_bonds (optional): the OSBP has the option to create one or more NIC bonds to provide HA networking. This custom attribute defines the list of bonds we intend to create. Format is as follows:
	```
		<bond name 1>, <MAC1>, <MAC2>
		<bond name 2>, <MAC3>, <MAC4>
		<bond name 3>, <MAC5>, <MAC6>
		...
	```
	This custom attribute can have any number of NIC pairs, but can also be left empty if bonding is not required in the system. The IP address assigned to the bond will be static and will be taken from the first NIC. If the first NIC does not have an assigned IP, then the IP of the second NIC will be used instead.

* Add the bash scripts for docker installation (https://github.hpe.com/RA-team/ICsp_Docker_OSBP/blob/master/ubuntu/install_docker_on_Ubuntu_14.04.sh) and bonding (https://github.hpe.com/RA-team/ICsp_Docker_OSBP/blob/master/ubuntu/NIC_bonding.sh) at the end of the OSBP.
* Replace the default preseed file in the OSBP with the one provided (https://github.hpe.com/RA-team/ICsp_Docker_OSBP/blob/master/ubuntu/ubuntu-preseed-with-route.cfg). This new preseed file includes the changes below:
	-	Disable the default route (this makes the installation stop)
	-	Create the docker user in the system
* Add the sources.list file (https://github.hpe.com/RA-team/ICsp_Docker_OSBP/blob/master/ubuntu/sources.list) as a configuration file in ICsp and add an extra step in the OSBP to replace the original sources.list just before running the Docker script (should be step 25).

## Accessing the systems
You should be able to login via SSH to the brand new system using the 'docker' account and the password 'ChangeMe123!'. You can then switch to root if required using the same password, but you won’t be allowed to connect directly with root via SSH. It is highly recommended that you change both passwords as soon as you log in for the first time.

Note: the docker user is not part of the sudoers by default, so you won’t be able to run privileged commands or to switch to root by using the sudo command. You should instead switch to root by using the su command (with either "su –" or "su - root") and then entering the root password.
