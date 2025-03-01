# Cloud Gaming Made Easy

## Update 02/28/2025
We are now using Parsec for 

## About

Effortlessly stream the latest games on Azure. This project automates the set-up process for cloud gaming on a Nvidia M60 GPU on Azure.
The development of this project is heavily inspired by this [excellent guide](https://lg.io/2016/10/12/cloudy-gamer-playing-overwatch-on-azures-new-monster-gpu-instances.html).

The automated setup first deploys an Azure NC4as_T4_v3 virtual machine (VM) with a single Nvidia Tesla GPU, configures the official Nvidia Driver Extension that installs the Nvidia driver on the VM, and finally deploys a Custom Script Extension to run the setup script. The setup script configures everything that's needed to run Steam games on the VM, such as installing the Parsec remote desktop, installing Steam platform etc...

## Disclaimer

**This software comes with no warranty of any kind**. USE AT YOUR OWN RISK! This a personal project and is NOT endorsed by Microsoft. If you encounter an issue, please submit it on GitHub.

## How Do I Stream Games?

Your Azure VM and your local machine are connected through Steam. You can stream games after login into you parsec software using the same username and password both for your local machine and remote virtual desktop.

## How Much Bandwidth Does It Take?

The bandwidth needed can vary drastically depending on your streaming host/client, game, and resolution. The default set up is 30 Mb/sec.

## Pricing



## Usage

### I. Setup your local machine

1. Sign up for a [Paid Azure subscription](https://azure.microsoft.com/en-us/pricing/purchase-options/). You need a paid subscription as the free account does not grant you access to GPU VMs.
2. Have Steam ready and logged in. You can specify client streaming options in Steam's Settings > Remote Play > Advanced Client Options. Make sure to limit the bandwidth of your local steam client to 15 or 30 Mbits (50 if you don't mind the extra data cost).

You can also use Steam Link on a mobile device !

#### I.B (Optional) Setup ZeroTier VPN

For some scenarios other than Steam Remote Play

3. Sign up for an account on [zero tier VPN](https://www.zerotier.com/) and create a network. Make sure the network is set to **public**.
Note down the network id.
4.  Download and install zero tier VPN on your local machine. Join the network using the network ID noted in the previous step. **Make sure your local machine connect to the network BEFORE the VM does!**

### II. Automatically Deploy Your Azure VM

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fecalder6%2Fazure-gaming%2Fmaster%2FStandard.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>

Click on the button above and fill out the form. You'll need to fill in:

* Subscription: your paid subscription.
* Resource group: create a new one and name it anything you like.
* Location: pick the location closest to you. Note that not every location has the VM with M60 graphics card. Check [this website](https://azure.microsoft.com/en-us/global-infrastructure/services/) for whether a region supports NV6 VM.
* Vm Name: the name for the VM.
* Admin username and password: the login credentials for the local user.
* Vm Type: Use Standard_NV6_Promo if possible to save money. Use Standard_NV12s_v3 if you want Premium SSD.
* Platform : The OS of the VM to deploy. Note that Windows 10 VMs requires you to own a volume license for it.
* Vm Storage Type: The type of storage for the VM. Standard_LRS for "Standard HDD", StandardSSD_LRS for "Standard SSD" or Premium_LRS for "Premium SSD".
* Vm Ip Type: The Public IP allocation method for the VM. Check [here](https://azure.microsoft.com/en-us/pricing/details/ip-addresses/) for Public IP Address pricing.
* Spot VM: Set to true if you want to deploy a Spot VM. Note that it is not compatible with the *Promo* series VMs.
* Script location: the location of the setup script. Use the default value.
* Windows Update: whether to update windows, which takes around an hour. Recommended to leave as false.
* Network ID: network ID of your zero tier VPN, or empty if you don't need ZeroTier.

For Standard VM, you could specify a time when the VM would automatically shut down and deallocate. Once it's deallocated, you do not have to pay for the VM. See [Q & A](#q--a) for more.
A list of timezones understood by Azure is available [here](https://jackstromberg.com/2017/01/list-of-time-zones-consumed-by-azure/)

**Note: your admin credentials will be stored in plain-text in the VM. See [Q & A](#q--a) for more.**

After filling these in, check on I agree the terms and click on purchase. A VM with a M60 GPU will be automatically deployed and configured for you. Note that the setup process will take around 15 minutes (1 hour + if you choose to update Windows).

You can monitor the progress of the deployment using the notification button (bell icon) on the top right. You can also check the status under Virtual Machine -> The VM Name -> Extensions -> one of the entries in the list. If you see an error or failure, submit an issue on GitHub along with what's in detailed status.

Wait until the deployment is successful and both extensions are finished before logging in.

### III. Log into your VM

You can log into your VM using Remote Desktop Connection.

    1. Go to Virtual machines in [Azure Portal](https://portal.azure.com/) and click on the VM name
    2. Click on Connect and then Download RDP File (leave everything as default)
    3. Open your RDP file. Click on "Don't ask me again" and Connect for RDP popup.
    4. Enter the username and password you provided. Click on more choices -> "Use a different account" if you can't modify the username.
    5. Click on "Don't ask me again" and "Yes" for certificate verification popup.

### IV. Setup Steam

Steam is automatically installed on your VM. Launch it and log-in with your steam credentials. Once logged in, install your games through Steam on the VM. Unfortunately, Steam no longer allows interaction-free installation from local machine, requring you to do a bit of setup in the VM.

You could either install a game to your system drive (managed disk) or a temporary drive. The temporary drive has faster speeds, but you lose all your data after deallocating a VM. You will have to re-install your games every time you stop and start your VM if you choose to install on the temporary drive. See [Q & A](#q--a) for more.

If you want to stream from the Steam Link mobile app, don't forget to pair your phone and the VM from the VM's Remote Play settings !


### V. Game!

Close the remote desktop connection using the disconnect.lnk shortcut on the desktop and enjoy some cloud gaming!

If you don't use this shortcut, the VM gets locked and Steam Remote Play can not capture the game.

In Steam Remote Play, you can toggle streaming stats display with F6.

#### I Want to Manually Deploy My VM

You could manually deploy your VM through Azure portal, PowerShell, or Azure CLI.

1. Deploy a NV6 size VM through the azure portal(see [this guide](https://lg.io/2016/10/12/cloudy-gamer-playing-overwatch-on-azures-new-monster-gpu-instances.html) for instructions). Do not forget to add the Nvidia Driver Extension to the VM!
2. Remote desktop into your Azure VM instance.

3. Launch PowerShell (click on the Windows key in the bottom-left corner, type "powershell", and click on the app PowerShell).
4. Download https://github.com/ecalder6/azure-gaming/blob/master/setup.ps1. You could download this onto your local machine and paste it through remote desktop.
5. Navigate to the directory containing setup.ps1 in PowerShell and execute

6. After some time, the script will restart your VM, at which point your remote desktop session will end.
7. You can then remote desktop into your VM again a few minutes later. (1+ hour if you want to update Windows)
8. Follow [Setup Steam](#setup-steam) from above.

## Stopping a VM
After you are done with a gaming session, I recommend you stop (deallocate) the VM **using the Azure portal**. When it's stopped (deallocated), you don't have to pay for the VM. If you shut it down from Windows, you will still have to pay. Below are the steps for stopping a VM in portal:
1. Login to [Azure portal](https://portal.azure.com)
2. On the left-hand side, click on All resources
3. Click on the VM you've created.
4. Click on Stop on the top.

To start the VM, follow the steps above except that you click on start.

## Removing a VM

If you no longer wish to game on Azure, you could remove everything by:

1. Login to [Azure portal](https://portal.azure.com)
2. On the left-hand side, click on Resource Groups.
3. Click on the resource group you've created.
4. Click on delete resource group on the top.

## Contribution

Contributions are welcome! Please submit an issue and a PR for your change.

## Future work items
