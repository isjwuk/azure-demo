#Build an environment to demo Windows Admin Center
#Create a Windows VM with a public IP which has restricted access
#so only the machine running this script has access on port 6516

#Parameters- edit accordingly
$VMLocalAdminUser = "LocalAdminUser"
$VMLocalAdminSecurePassword = ConvertTo-SecureString "P@ssW0rD!" -AsPlainText -Force
$LocationName = "westus"
$ResourceGroupName = "wacdemo-rsg"
$ComputerName = "wacdemo-vms"
$VMName = "wacdemo-vms"
$VMSize = "Standard_B2S"
$NetworkName = "wacdemo-net"
$NICName = "wacdemo-nic"
$SubnetName = "wacdemo-snt"
$SubnetAddressPrefix = "10.0.0.0/24"
$VnetAddressPrefix = "10.0.0.0/16"
$nsgName = "wacdemo-nsg"
$PublicIPAddressName = "wacdemo-pip"

#Get My Public IP for NSG rule
$MyIP=(Invoke-WebRequest -uri "http://ifconfig.me/ip").Content
#If you are running this script from Cloud Shell then assign
# a static value to $MyIP

#Create New Resource Group
New-AzResourceGroup -Name $resourceGroupName -Location $locationName

$nsgRule1 = New-AzNetworkSecurityRuleConfig -Name "wac-rule" -Description "Allow Windows Admin Center" `
    -Access Allow -Protocol Tcp -Direction Inbound -Priority 200 -SourceAddressPrefix `
    $MyIP -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 6516

$nsg = New-AzNetworkSecurityGroup -ResourceGroupName $resourceGroupName -Location $locationName `
            -Name $nsgName -SecurityRules $nsgRule1 

#Build Network config 
$SingleSubnet = New-AzVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix $SubnetAddressPrefix
$Vnet = New-AzVirtualNetwork -Name $NetworkName -ResourceGroupName $ResourceGroupName -Location $LocationName -AddressPrefix $VnetAddressPrefix -Subnet $SingleSubnet
$PIP = New-AzPublicIpAddress -Name $PublicIPAddressName -ResourceGroupName $ResourceGroupName -Location $LocationName -AllocationMethod Dynamic
$NIC = New-AzNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroupName -Location $LocationName -SubnetId $Vnet.Subnets[0].Id -PublicIpAddressId $PIP.Id -NetworkSecurityGroupId $nsg.Id

$Credential = New-Object System.Management.Automation.PSCredential ($VMLocalAdminUser, $VMLocalAdminSecurePassword);

#Create the VM config
$VirtualMachine = New-AzVMConfig -VMName $VMName -VMSize $VMSize
$VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $ComputerName -Credential $Credential -ProvisionVMAgent -EnableAutoUpdate
$VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id
#Comment out the next line to use a Premium SSD instead of a (cheaper) Standard HDD
$VirtualMachine = Set-AzVMOSDisk -CreateOption fromImage -VM $VirtualMachine -StorageAccountType Standard_LRS -Windows
$VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName 'MicrosoftWindowsServer' -Offer 'WindowsServer' -Skus '2019-Datacenter' -Version latest

#Create the VM
New-AzVM -ResourceGroupName $ResourceGroupName -Location $LocationName -VM $VirtualMachine -Verbose #-OpenPorts 3389

#Add WAC Extension
$PublicSettings=@{"port"= "6516";"cspFrameAncestors"= ("https://portal.azure.com","https://*.hosting.portal.azure.net","https://localhost:1340");"corsOrigins"= ("https://portal.azure.com","https://waconazure.com")}
Set-AzVMExtension -ResourceGroupName $ResourceGroupName -Location $LocationName -VMName $VMName -Name "AdminCenter" -Publisher "Microsoft.AdminCenter" -Type "AdminCenter" -TypeHandlerVersion "0.0" -settings $PublicSettings

"Open the Azure Portal in Edge, locate the VM '"+$VMName+ "', select 'Windows Admin Center' and click 'Connect'"

"Tidy Up with"
"Remove-AzResourceGroup -Name $ResourceGroupName -Force"