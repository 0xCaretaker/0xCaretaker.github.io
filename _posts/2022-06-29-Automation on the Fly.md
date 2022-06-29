---
title: "Apocalyst"
date: 2021-07-23 17:10:00 +0530
categories: [HackTheBox, Linux Machines]
tags: [linux, wordpress, ctf, john, passwd, lxd, hackthebox]
image: /assets/img/Posts/Apocalyst/Apocalyst.png
---

Recently, I stumbled on an initiative called "The Auror Project" by [Sudarshan Pisupati](https://www.linkedin.com/in/sudarshan-pisupati-607b0ab/) which was starting a course called "[3 Machine Labs](https://www.linkedin.com/feed/update/urn:li:activity:6919205808157155328/)". 
"3 Machine Labs" is a challenge based learning approach to solidify fundamentals of Active Directory over a series of 9 sessions. 

The first session came with a [challenge](https://docs.google.com/document/d/1Zk_O_JpFQk5JQRGF9CAC0plml3ua3hCQ5VBDLxE2GQI/edit#heading=h.1vlpfqvcrv4) to automate the process of building an Active Directory Lab with some specifications.

Automation should:
- Setup two Virtual Machines; Windows Server & Windows 10 
- Install Active Directory Domain Services(ADDS) on the Windows Server and promote the server to Domain controller through a process called DC Promo
- Add Windows 10 machine to Windows Server domain, through a process called Domain join

Some specifications for the machines were:

For Windows Server (Domain controller):
- Domain name should be "auror.local"
- Has DNS role
- Contains a Domain user called "Adam" with password "Pass@123"

For Windows 10:
- Should've Google Chrome installed
- User "Adam" should be configured as a local administrator
- Firewall should be disabled

I gave a lot of time to this task, for which I'm not sure on how should I feel like.. 

But, Here's me running packer builds on my flight to Mumbai, which gave me the Title for the blog **"Automation on the Fly"**.
![auror-task1-1.jpeg1](/assets/img/Posts/auror-task1-automation-on-the-fly/auror-task1-1.jpeg1)
# # Mindmap
This session was already a catch for me. I'm a huge fan of automation but to my surprise I'd never given a thought of automating installations of virtual machines and lab environments, even though it was tedious, specially with AD environments. 

Rebuilding an AD Lab manually means setup VMs , DC Promo, user and computer accounts and Domain join again, that too for a clean simplistic AD. 
Sudarshan spoke about Clicks vs Time and How this automation needs to minimize clicks to bare minimum.

While snapshots and VM exports may seem like an easy way out for standalone machines, things get complicated in an Active Directory environment. 

Snapshots break for AD because of "Time". 
- Domain Members (includes computers) have a maximum password age of 30 days. If reverted, password in AD and the computer may not match
- In AD, authentication works using Kerberos and Kerberos authentication uses time stamps as part of its protocol. Out of sync timestamps can result in missing tickets and even no authentication at all.
 
## # How to automate?
Question arises on how we can automate the whole process of VM installation from ISO files and configure those VMs according to our need.

There are a lot of alternatives and I've documented the automation using **Packer** and **Vagrant** with VirtualBox as my preferred choice of hypervisor, needless to say configuration files can be easily modified to any hypervisor of your choice.

- [Packer](https://www.packer.io/intro) is the first step which will create a base VM from the ISO.
- [Vagrant](https://www.vagrantup.com/intro) will then further on build the whole virtual machine environment from the output of Packer by cloning and modifying/managing it.
## # What you'll need?
- [Packer](https://www.packer.io/downloads)  or `choco install packer -y` using [Chocolatey](https://adamrushuk.github.io/cheatsheets/chocolatey/)
- [Vagrant](https://www.vagrantup.com/downloads)
- [ISO file for Windows Server 2019](https://software-static.download.prss.microsoft.com/pr/download/17763.737.190906-2324.rs5_release_svc_refresh_SERVER_EVAL_x64FRE_en-us_1.iso) 
- [ISO file for Windows 10](https://software-static.download.prss.microsoft.com/sg/download/444969d5-f34g-4e03-ac9d-1f9786c69161/19044.1288.211006-0501.21h2_release_svc_refresh_CLIENTENTERPRISEEVAL_OEMRET_x64FRE_en-us.iso)
- [Cloned Github repo](https://github.com/0xCaretaker/Auror-Project)

> Note: You can even download the latest Windows Server 2019 and Windows 10 image from [here](https://www.microsoft.com/en-us/evalcenter/download-windows-server-2019) and [here](https://www.microsoft.com/en-us/evalcenter/download-windows-10-enterprise) but remember to modify `iso_url` and `iso_checksum` variable in json files for Packer accordingly.

## # Packer
Packer needs a JSON file or HCL file as a template to configure the build here I've the files named `server-2019.json` and `win10.json` for both the machines.

This is the hierarchy for all the packer files needed for server-2019 and is similar for Windows 10 machine:
```bash
server-2019/
├── files
│   ├── autounattend.xml
│   ├── scripts
│   │   ├── fixnetwork.ps1
│   │   ├── sysprep.bat
│   │   └── winrmConfig.bat
│   └── unattend.xml
├── server-2019.json
└── server-2019-vagrantfile.template
```

I've used JSON template files which contains all the necessary configuration like Type of installation(ISO here), Disk size, No. of CPUs, Memory size, OS type, ISO url/path, communicator type for vagrant(WinRM here) with it's credentials, files which need to be mounted for use and finally the post processors(vagrant) for it's output.

### # External scripts in packer
As you can see there are 3 common external scripts I have used with packer in [my git repo](https://github.com/0xCaretaker/Auror-Project), namely `fixnetwork.ps1`, `winrmConfig.bat` and `sysprep.bat`.

- `winrmConfig.bat`
  Communicators are used by Packer to upload files, execute scripts, etc. with the machine being created. `winrmConfig.bat` is a pre-run script that configures and enables WinRM on the guest machine. 
  All the configuration and code for the script has been given in Packer docs:[www.packer.io/docs/communicators/winrm](https://www.packer.io/docs/communicators/winrm)

- `fixnetwork.ps1`
  If you try to run the above `winrmConfig.bat` in windows10, it'll not work because on a Server OS, like Windows Server 2019, the firewall rule for Public networks allows on remote connections from other devices on the same network. On a client OS, like Windows 10, you will receive an error stating that you are a public network.
  Here's an article which goes in detail for WinRM configuration and how networks should be managed: [adamtheautomator.com/enable-psremoting](https://adamtheautomator.com/enable-psremoting/)

- `sysprep.bat`
  Before you can deploy a Windows image to new PCs, you have to first generalize the image. Generalizing the image removes computer-specific information such as installed drivers and the computer security identifier (SID). 
  The `sysprep /generalize` command removes unique information from your Windows installation so that you can safely reuse that image on a different computer. The next time that you boot the Windows image, the specialize configuration pass runs.
  I've used `unattend.xml` answer file with sysprep to generalize my image. 
  > You can see the GUI execution of SysPrep [here](https://mivilisnet.wordpress.com/2017/06/29/changing-sid-of-cloned-vms/) to get more context.


References: [SysPrep using unattend](https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/sysprep--generalize--a-windows-installation?view=windows-11#generalize-using-unattend), [SysPrep Command line options](https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/sysprep-command-line-options?view=windows-11)

There are two more scripts: `cleanup.ps1` and `setup.ps1` used with Windows 10 machine to fiddle with thing like: Windows Updates, Temporary files, password expiration for administrator, Disabling sleep, hibernation and configuring Powershell prompt to show time. 
## # Vagrant
Vagrant uses `Vagrantfile` containing the configuration to make the environment for the virtual machine.
Here's the hierarchy of the vagrant files needed for building the whole lab from the output of Packer which is `server-2019.box` and `win10.box`.
```bash
Vagrant/
├── files
│   ├── add-adam.ps1
│   ├── add-localadmin.ps1
│   ├── install-active-directory.ps1
│   ├── install-chrome.ps1
│   ├── join-domain.ps1
│   └── set-timezone.ps1
├── server-2019.box
├── Vagrantfile
└── win10.box
```

- `Vagrantfile` provides hostname for the machines, their network configuration and uses the WinRM credentials(configured in Packer) to communicate with the guest and run scripts. It even handles VirtualBox configuration for the name, memory(including video memory), guest additions like shared clipboard etc.
> Note: Be careful on the network adapter configuration, I've kept 10.1.1.0/24 as subnet, which shouldn't collide with the other having 10.0.2.0/24
> (I was trying to keep the original network given to us: 10.0.0.0/24, where DC01 had the IP 10.0.0.9. But, If I mention the gateway as 10.0.0.0, it would collide with the first adapter, by giving the second adapter the subnet of 10.0.0.0/8)

Scripts used:
For DC01:
- `set-timezone.ps1` - Sets timezone for DC01
- `install-active-directory.ps1` - Install ADDS and perform DCPromo, create a new forest which contains a domain named `auror.local`
- `add-adam.ps1` - Adds a user named `Adam`
For PC01:
- `install-chrome.ps1` - Installs chrome, disables firewall and enables RDP for PC01
- `join-domain.ps1` - Performs Domain Join process using `Add-Computer`, by first setting the DNS as DC01
- `add-localadmin.ps1` - Sets `Adam` as local administrator for PC01, Runs windows update and disables windows defender automatic submissions 

These are all the scripts needed.
# # What a waste of time...
Since, I'd no clue what Packer and Vagrant is before this project, this section will go in an in-depth explanation on how everything works using Packer and Vagrant.
You don't necessarily have to read this and can go to [TL;DR Build the lab?](https://0xcaretaker.github.io/Automation on the Fly - The Auror Project)
First, Packer will be used to build the base VM from the ISOs.

## # Explaining Packer files
I discussed about the template JSON file, but what about others?
- `server-2019-vagrantfile.template` is used in the `post_processors` section as this template file will be needed to output the build in `.box` format for Vagrant.
- `autounattend.xml` is the core answer file for automating the whole windows installation process
- `unattend.xml` is another answer file which is used to modify windows settings after the first user is created and assigned a default language(We'll need that with SysPrep)
- Scripts folder contains various scripts already discussed

### # What is autounattend.xml?
The most important file for Packer is `autounattend.xml`, it acts as an answer file to Windows Setup installation since all the UI pages needs to be automated. Unattended installation settings can be applied in one or more configuration passes. 

But **What are Windows setup configuration passes?**
> Windows Setup Configuration Passes are used to specify different phases of Windows Setup. 
Source: [Windows-Setup-Configuration-Passes](https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/windows-setup-configuration-passes?view=windows-11)

The following diagram shows the relationship between the configuration passes relative to the different deployment tools.
![auror-task1-2.png1](/assets/img/Posts/auror-task1-automation-on-the-fly/auror-task1-2.png1)

Not all configuration passes run in a particular installation of Windows. Some configuration passes, such as `auditSystem` and `auditUser`, run only if you boot the computer to audit mode. 
Most Windows Setup `unattend` settings can be added to either the `specialize` or the `oobeSystem` configuration pass. The other configuration passes can also be useful in certain situations.

#### # windowsPE Configuration pass
The windowsPE configuration pass is used to configure settings specific to Windows Preinstallation Environment (Windows PE) in addition to settings that apply to installation.
This configuration pass runs when booting the Windows Setup media.

For more info: [Microsoft-WindowsPE](https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/windowspe?view=windows-11)

As already stated, windowsPE configures settings related to the installation environment and then the setup as well. So, it usually has 2 components `Microsoft-Windows-International-Core-WinPE` and `Microsoft-Windows-Setup`.  

##### # Component `Microsoft-Windows-International-Core-WinPE`
It specifies the default language, locale, and other international settings to use during Windows Setup or Windows Deployment Services installations.

So, The first screen, which is the language selection screen is now automated.  
![auror-task1-3.png1](/assets/img/Posts/auror-task1-automation-on-the-fly/auror-task1-3.png1)

The code snippet looks something like this:
```xml
        <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <SetupUILanguage>
                <UILanguage>en-US</UILanguage>
            </SetupUILanguage>
            <InputLocale>en-US</InputLocale>
            <SystemLocale>en-US</SystemLocale>
            <UILanguage>en-US</UILanguage>
            <UILanguageFallback>en-US</UILanguageFallback>
            <UserLocale>en-US</UserLocale>
        </component>
```

##### # Component `Microsoft-Windows-Setup`
This component contains settings that enable you to select the Windows image that you install, configure the disk that you install Windows to, and configure the Windows PE operating system.

1. Imageinstall
```xml
            <ImageInstall>
                <OSImage>
                    <InstallFrom>
                        <MetaData wcm:action="add">
                            <Key>/IMAGE/NAME</Key>
                            <Value>Windows Server 2019 SERVERSTANDARD</Value>
                        </MetaData>
                    </InstallFrom>
                    <InstallTo>
                        <DiskID>0</DiskID>
                        <PartitionID>2</PartitionID>
                    </InstallTo>
                </OSImage>
            </ImageInstall>
```
![auror-task1-4.png1](/assets/img/Posts/auror-task1-automation-on-the-fly/auror-task1-4.png1)

2. Now we're greeted with EULA agreement message:
![auror-task1-5.png1](/assets/img/Posts/auror-task1-automation-on-the-fly/auror-task1-5.png1)
and that is handled by:
```xml
            <UserData>
                <AcceptEula>true</AcceptEula>
                <FullName>Packer</FullName>
                <Organization>Packer</Organization>
            </UserData>
```
3. Disk configuration:
This configuration creates 2 partitions:
- boot partition of 350MB in size
- Rest size extended for C Drive
```xml
            <DiskConfiguration>
                <Disk wcm:action="add">
                    <CreatePartitions>
                        <CreatePartition wcm:action="add">
                            <Type>Primary</Type>
                            <Order>1</Order>
                            <Size>350</Size>
                        </CreatePartition>
                        <CreatePartition wcm:action="add">
                            <Order>2</Order>
                            <Type>Primary</Type>
                            <Extend>true</Extend>
                        </CreatePartition>
                    </CreatePartitions>
                    <ModifyPartitions>
                        <ModifyPartition wcm:action="add">
                            <Active>true</Active>
                            <Format>NTFS</Format>
                            <Label>boot</Label>
                            <Order>1</Order>
                            <PartitionID>1</PartitionID>
                        </ModifyPartition>
                        <ModifyPartition wcm:action="add">
                            <Format>NTFS</Format>
                            <Label>Local Disk</Label>
                            <Letter>C</Letter>
                            <Order>2</Order>
                            <PartitionID>2</PartitionID>
                        </ModifyPartition>
                    </ModifyPartitions>
                    <DiskID>0</DiskID>
                    <WillWipeDisk>true</WillWipeDisk>
                </Disk>
            </DiskConfiguration>
```
![auror-task1-6.png1](/assets/img/Posts/auror-task1-automation-on-the-fly/auror-task1-6.png1)

#### # offlineServicing Configuration pass
`offlineServicing` configuration pass to apply unattended Setup settings to an offline Microsoft Windows image. During this configuration pass, you can add language packs, update package, device drivers, or other packages to the offline image.

The Microsoft-Windows-LUA-Settings component includes settings related to the Windows User Account Controls (UAC), formerly known as Limited User Account (LUA).

```xml
    <settings pass="offlineServicing">
        <component name="Microsoft-Windows-LUA-Settings" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <EnableLUA>false</EnableLUA>
        </component>
    </settings>
```

EnableLUA specifies whether the windows User Account Controls (UAC) should notify the user when programs try to make changes to the computer.

We set that to false, so that UAC prompts aren't popped up.
#### # specialize Configuration pass
During the `specialize` configuration pass of Windows Setup, computer-specific information for the image is applied. 

For example you can:
- configure network settings, timezone settings, and domain information.
```xml
    <settings pass="specialize">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <OEMInformation>
                <HelpCustomized>false</HelpCustomized>
            </OEMInformation>
            <ComputerName>Server-2019</ComputerName>
            <TimeZone>India Standard Time</TimeZone>
            <RegisteredOwner/>
        </component>
```

- Computer specific configuration like not opening Server Manager whenever a user logs on 
```xml
        <component name="Microsoft-Windows-ServerManager-SvrMgrNc" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <DoNotOpenServerManagerAtLogon>true</DoNotOpenServerManagerAtLogon>
        </component>
```

- and Setting Global execution policy of 64/32-Bit to be Remotely signed using `RunSynchronousCommand`
```xml
        <component name="Microsoft-Windows-Deployment" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <RunSynchronous>
                <RunSynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <Description>Set Execution Policy 64 Bit</Description>
                    <Path>cmd.exe /c powershell -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force"</Path>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add">
                    <Order>2</Order>
                    <Description>Set Execution Policy 32 Bit</Description>
                    <Path>cmd.exe /c powershell -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force"</Path>
                </RunSynchronousCommand>
            </RunSynchronous>
        </component>
    </settings>
```
#### # oobSystem Configuration pass
The `oobeSystem` configuration pass, also known as Windows Welcome, can be used to preconfigure user interface pages for an end user.

Like this built-in administrator account can be automated by `oobsystem` as:
![auror-task1-7.png1](/assets/img/Posts/auror-task1-automation-on-the-fly/auror-task1-7.png1)
```xml
            <UserAccounts>
                <AdministratorPassword>
                    <Value>vagrant</Value>
                    <PlainText>true</PlainText>
                </AdministratorPassword>
                <LocalAccounts>
                    <LocalAccount wcm:action="add">
                        <Password>
                            <Value>vagrant</Value>
                            <PlainText>true</PlainText>
                        </Password>
                        <Group>administrators</Group>
                        <DisplayName>Vagrant</DisplayName>
                        <Name>vagrant</Name>
                        <Description>Vagrant User</Description>
                    </LocalAccount>
                </LocalAccounts>
            </UserAccounts>
```


Then using these credentials we can even configure the user-specific configurations as:
- Autologon
Specifies credentials for an account that is used to automatically log on to the computer.
```xml
            <AutoLogon>
                <Password>
                    <Value>vagrant</Value>
                    <PlainText>true</PlainText>
                </Password>
                <Enabled>true</Enabled>
                <Username>vagrant</Username>
            </AutoLogon>
```
- FirstLogonCommands
Specifies commands to run the first time that an end user logs on to the computer.
```xml
            <FirstLogonCommands>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>cmd.exe /c powershell -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force"</CommandLine>
                    <Description>Set Execution Policy 64 Bit</Description>
                    <Order>1</Order>
                    <RequiresUserInput>true</RequiresUserInput>
                </SynchronousCommand>
```
- OOBE 
OOBE specifies the behavior of some of the Windows Out of Box Experience (OOBE) screens.
```xml
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideLocalAccountScreen>true</HideLocalAccountScreen>
                <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
                <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <NetworkLocation>Home</NetworkLocation>
                <ProtectYourPC>1</ProtectYourPC>
            </OOBE>
```










## # Click, Click .. Windows ADK
So, I spent so long in understanding what all the components and functions do, that I accidently stumbled onto Windows ADK and felt like a complete loser.

Now, talking about how you don't have to write answer xml files yourselves, rather generate it using Windows Assessment and Deployment Kit(ADK).

Install [Windows ADK](https://docs.microsoft.com/en-us/windows-hardware/get-started/adk-install) and.. 
1. Click on File -> Create answer file -> Click yes, to open Windows image
![auror-task1-8.png1](/assets/img/Posts/auror-task1-automation-on-the-fly/auror-task1-8.png1)
2. Mount the ISO -> copy all the files to a directory, select image
![auror-task1-9.png1](/assets/img/Posts/auror-task1-automation-on-the-fly/auror-task1-9.png1)
![auror-task1-10.png1](/assets/img/Posts/auror-task1-automation-on-the-fly/auror-task1-10.png1)

3. Select the OS image name/type

![auror-task1-11.png1](/assets/img/Posts/auror-task1-automation-on-the-fly/auror-task1-11.png1)
4. Create a catalog file

![auror-task1-12.png1](/assets/img/Posts/auror-task1-automation-on-the-fly/auror-task1-12.png1)
![auror-task1-13.png1](/assets/img/Posts/auror-task1-automation-on-the-fly/auror-task1-13.png1)

> Note: If you don't see the above message and it's spitting out errors. 
> 1. Try installing a different version of ADK. (Windows 10, version 1809 worked for me)
> 2. Even after that if you're getting errors like: `This application requires version 6.3.9600.16384 of the Windows ADK. Install this version to correct the problem`. Try copying that `install.wim` file to another location.


Now, let's suppose, I want to add some configuration related to Internet Explorer. I can just Right-Click and add to specific pass.

![auror-task1-14.png1](/assets/img/Posts/auror-task1-automation-on-the-fly/auror-task1-14.png1)

Each component has a lot of properties which you can configure, like IE has:
![auror-task1-15.png1](/assets/img/Posts/auror-task1-automation-on-the-fly/auror-task1-15.png1)
I've made some changes so that:
- Popups are blocked
- DevTools is disabled
- No frustrating first run wizard 
- Homepage is Google and I'm not slammed with some MSN news
- A Custom User-Agent 

Do all you want and then export the answer file as `autounattend.xml` ;)
