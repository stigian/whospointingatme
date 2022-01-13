function Get-WhosPointingAtMe{
[CmdletBinding()]
param (
$targetIP,
[switch]$display 
)
$pointers = @()
$routeTables = Get-AzRouteTable
foreach($routeTable in $routeTables){
    $routeTableName = $routeTable.Name 
    Write-Verbose "Checking ROUTE TABLE $routeTableName"
    $routes = $routeTable.Routes
    foreach($route in $routes){
        $routeName = $route.Name
        Write-Verbose "Checking ROUTE $routeName in ROUTE TABLE $routeTableName"
        if($route.NextHopType -eq "VirtualAppliance" -and $route.NextHopIpAddress -eq $targetIP){
            $addressPrefix = ($route.AddressPrefix).ToString()
            $subnets = $routeTable.Subnets
            foreach($subnet in $subnets){
                $vnet = Get-AzVirtualNetwork -Name ($subnet.id.split("/"))[8]
                $subnetName = ($subnet.id.split("/"))[10]
                $subnetConfigs = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $subnetName
                $networkName = $vnet.Name,$subnetName -join "/"
                Write-Verbose -Message "checking SUBNET $subnetName for VMs associated with ROUTE"
                $subnetAddress = (($subnetConfigs.AddressPrefix) -join "; ").ToString()
                if($subnetConfigs.IpConfigurations){
                    write-verbose "line 27"
                    foreach($ipConfig in $subnetConfigs.Ipconfigurations){
                        write-verbose "line 29"
                        $nicName = $ipConfig.Id.Split("/")[8]
                        $nicQuery = (Get-AzNetworkInterface -Name $nicName)
                        $nicAttachedVM = $nicQuery.VirtualMachine.Id 
                        if ($nicAttachedVM){
                                $vmArray = $nicAttachedVM.Split("/")
                                $VMRG = $vmArray[4]
                                $VMName = $vmArray[8]
                                if($display){Write-Host $VMName -f Red -NoNewline; Write-Host " is pointing to " -NoNewline; Write-Host $targetIP -f Cyan -NoNewline; Write-Host " for target " -NoNewline; Write-Host $addressPrefix -f Magenta -NoNewline; `
                                Write-Host " using Network Interface " -NoNewline; Write-Host $nicName -ForegroundColor Yellow -NoNewline; Write-Host " on vnet/subnet " -NoNewline; Write-Host $networkName -f Green}
                                }
                        if ($nicAttachedVM -eq $null){
                                $VMRG = ""
                                $VMName = ""
                                if($display){Write-Host "Detached Network Interface " -NoNewline; Write-Host $nicName -ForegroundColor Yellow -NoNewline; Write-Host " is pointing to " -NoNewline; Write-Host $targetIP -f Cyan -NoNewline; `
                                Write-Host " for target " -NoNewline; Write-Host $addressPrefix -f Magenta -NoNewline; Write-Host " on vnet/subnet " -NoNewline; Write-Host $networkName -f Green}
                                }
                        $nicIP = @()
                        if($nicQuery.ipconfigurations.count -gt 1){
                            $nicIP = $nicQuery.ipconfigurations.PrivateIpAddress
                            $nicIPJoined = ($nicIP -join "; ").ToString()
                            }
                        if($nicQuery.ipconfigurations.count -eq 1){
                            $nicIP = $nicQuery.ipconfigurations.PrivateIpAddress
                            $nicIPJoined = $nicIP.ToString()
                            }
                        $pointerTemp = New-Object PSObject
                        $pointerTemp | Add-Member -MemberType NoteProperty -Name "VMRG" -Value $VMRG
                        $pointerTemp | Add-Member -MemberType NoteProperty -Name "VirtualMachine" -Value $VMName
                        $pointerTemp | Add-Member -MemberType NoteProperty -Name "NetworkInterface" -Value $nicName
                        $pointerTemp | Add-Member -MemberType NoteProperty -Name "VirtualNetwork" -Value $vnet.Name
                        $pointerTemp | Add-Member -MemberType NoteProperty -Name "SubnetName" -Value $subnetName
                        $pointerTemp | Add-Member -MemberType NoteProperty -Name "SubnetIP" -Value $subnetAddress
                        $pointerTemp | Add-Member -MemberType NoteProperty -Name "NicIP" -Value $nicIPJoined
                        $pointerTemp | Add-Member -MemberType NoteProperty -Name "Destination" -Value $addressPrefix
                        $pointerTemp | Add-Member -MemberType NoteProperty -Name "RouteTableName" -Value $routeTableName
                        $pointers += $pointerTemp
                        #   }
                        }
                    }
                if(!$subnetConfigs.IpConfigurations){
                    if($display){Write-Host "$subnetName has a route pointing to $targetIP but has no Network Interfaces associated with it"}
                    $pointerTemp = New-Object PSObject
                    $pointerTemp | Add-Member -MemberType NoteProperty -Name "VMRG" -Value ""
                    $pointerTemp | Add-Member -MemberType NoteProperty -Name "VirtualMachine" -Value ""
                    $pointerTemp | Add-Member -MemberType NoteProperty -Name "NetworkInterface" -Value ""
                    $pointerTemp | Add-Member -MemberType NoteProperty -Name "VirtualNetwork" -Value $vnet.Name
                    $pointerTemp | Add-Member -MemberType NoteProperty -Name "SubnetName" -Value $subnetName
                    $pointerTemp | Add-Member -MemberType NoteProperty -Name "SubnetIP" -Value $subnetAddress
                    $pointerTemp | Add-Member -MemberType NoteProperty -Name "NicIP" -Value ""
                    $pointerTemp | Add-Member -MemberType NoteProperty -Name "Destination" -Value $addressPrefix
                    $pointerTemp | Add-Member -MemberType NoteProperty -Name "RouteTableName" -Value $routeTableName
                    $pointers += $pointerTemp
                    }
                }
            }
        }
    }
    $pointers = $pointers | Sort-Object -Property NetworkInterface -Unique
    return $pointers    
}
    
