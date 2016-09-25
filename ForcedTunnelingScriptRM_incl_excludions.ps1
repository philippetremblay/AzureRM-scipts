########################################################################
# Rudimentary created to automate the configuration of forced Tunneling in Azure
# Script is as-is, feel free to modify and improve
########################################################################


 
# Connect to an Azure subscription

add-AzureRmAccount
 
# Select your subscription if required
Get-AzureRmSubscription 
$azureSubscriptionName = Read-Host "`n Select Subscription Name"
Select-AzureRmSubscription -SubscriptionName $azureSubscriptionName

Write-Host "`n Listing available Virtual Networks (having Gateways):" -ForegroundColor Cyan
Get-AzureRmResourceGroup | select ResourceGroupName,Location | FT
$rgname=Read-Host "`n Select Resource Name"
$rg=Get-AzureRmResourceGroup -name $rgname

Write-Host "`n Listing available Virtual Networks (having Gateways):" -ForegroundColor Cyan
Get-AzureRmVirtualNetwork -ResourceGroupName $rg.ResourceGroupName | select Name
$vnetname=Read-Host "`n Select Virtual Network Name"
If (!( Get-AzureRmVirtualNetwork -ResourceGroupName $rg.ResourceGroupName -name $vnetname -ErrorAction SilentlyContinue)){ Write-Host "`n FAILED: Invalid Virtual Network Name`n" -fore red;Exit }
$vnet=Get-AzureRmVirtualNetwork -ResourceGroupName $rg.ResourceGroupName -name $vnetname
$loc = (Get-AzureRmVirtualNetwork -ResourceGroupName $rg.ResourceGroupName -name $vnet.Name).Location


##Select Local Gateway
Write-Host "`n Listing available Local Gateways:" -ForegroundColor Cyan
Get-AzureRmLocalNetworkGateway -ResourceGroupName $rg.ResourceGroupName | select Name
$lgname=Read-Host "`n Select Local Gateway Name"
$lg=Get-AzureRmLocalNetworkGateway -ResourceGroupName $rg.ResourceGroupName -Name $lgname

##select Virtual Gateway in Azure
Write-Host "`n Listing available Virtual Gateways:" -ForegroundColor Cyan
Get-AzureRmVirtualNetworkGateway -ResourceGroupName $rg.ResourceGroupName | select Name
$vgname = Read-Host "`n Select Virtual Gateway Name"
$vg = Get-AzureRmVirtualNetworkGateway -ResourceGroupName $rg.ResourceGroupName -Name $vgname


#Export VNet Config #nice to have for later

#Export RouteTable #nice to have for later

#Export Vnet Site Info #nice to have for later
 
#Create a routing table. Use the following cmdlet to create your route table.

New-AzureRmRouteTable –Name "RT-ForcedTunneling" -ResourceGroupName $rg –Location $loc
#Add a default route to the routing table.
#The cmdlet example below adds a default route to the routing table created in Step 1. Note that the only route supported is the destination prefix of "0.0.0.0/0" to the "VPNGateway" nexthop.

$rt = Get-AzureRmRouteTable –Name "RT-ForcedTunneling" -ResourceGroupName $rg.ResourceGroupName 
Add-AzureRmRouteConfig -Name "DefaultRoute" -AddressPrefix "0.0.0.0/0" -NextHopType VirtualNetworkGateway -RouteTable $rt

# You may need to add routes which help traffic go directly to the internal Azure IPs which were unnaivailable on the internet. Without these VM OS's will either not activate or not receive updates.
# The IPs specified may change without warning, ideally this could be avoided. So check if the issue still exists.
#KMS server  
#Add-AzureRmRouteConfig -Name "RTCfg-DirectRouteToKMS" -AddressPrefix 23.102.135.246/32 -NextHopType Internet -RouteTable $rt
#SUSE update servers
#Add-AzureRmRouteConfig -Name "RTCfg-DirectRouteToSUSE1" -AddressPrefix 23.101.151.152/32 -NextHopType Internet -RouteTable $rt
#Add-AzureRmRouteConfig -Name "RTCfg-DirectRouteToSUSE2" -AddressPrefix 23.101.150.193/32 -NextHopType Internet -RouteTable $rt
#Add-AzureRmRouteConfig -Name "RTCfg-DirectRouteToSUSE" -AddressPrefix 191.237.254.253/32 -NextHopType Internet -RouteTable $rt

Set-AzureRmRouteTable -RouteTable $rt



#3. Associate the routing table to the subnets.
#After a routing table is created and a route added, use the cmdlet below to add or associate the route table to a VNet subnet. The samples below add the route table "MyRouteTable" to the Midtier and Backend subnets of VNet MultiTier-VNet.


##select Subnet
Write-Host "`n Listing available subnets:" -ForegroundColor Cyan
(Get-AzureRmVirtualNetwork -ResourceGroupName $rg.ResourceGroupName -name $vnet.Name) | Get-AzureRmVirtualNetworkSubnetConfig | Select name,AddressPrefix
$subnetname=Read-Host "`n Select Subnet Name"
$subnet=Get-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $vnet -name $subnetname

#$subnets = $subnet
#foreach ($subnet in $subnets) {
Write-Host "`n Setting route " $rt.Name " for subnet "$subnet.name" in VNET: "$vnet.name
Set-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $subnet.name -AddressPrefix $subnet.AddressPrefix -RouteTable $rt
Set-AzureRmVirtualNetwork -VirtualNetwork $vnet


#4.Assign a default site for forced tunneling.
#In the preceding step, the sample cmdlet scripts created the routing table and associated the route table to two of the VNet subnets. The remaining step is to select a local site among the multi-site connections of the virtual network as the default site or tunnel.

Set-AzureRmVirtualNetworkGatewayDefaultSite -GatewayDefaultSite $lg -VirtualNetworkGateway $vg
