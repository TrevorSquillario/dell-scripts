# Dell OpenManage and iDRAC Scripts

# Examples
Execute script on a single iDRAC
```
Get-PCIDeviceInventory.ps1 -idrac_ip "192.168.1.100" -idrac_username "root" -idrac_password "calvin" 
```

Loop through text file and execute script for each iDRAC
```
$InventoryAll = @()
foreach ($iDRAC in Get-Content "C:\Temp\hosts.txt") {
    $Inventory = & "./PowerShell/Get-PCIDeviceInventory.ps1" -idrac_ip $iDRAC -idrac_username "root" -idrac_password "calvin" 
    # Parse Output
    foreach ($Line in $Inventory) {
        if ($Line.CardName -match "X710") {    
            Write-Host "Match found for $($iDRAC)"
            $Line | Format-List
        }
    }
    # Export to CSV
    $Inventory | Export-Csv "C:\Temp\$($iDRAC).csv" -NoTypeInformation

    # Create CSV with inventory from all hosts
    $InventoryAll += $Inventory
}
# Print to Console
#$InventoryAll | Format-Table

# Export to CSV
$InventoryAll | Export-Csv "C:\Temp\PCIInventory.csv" -NoTypeInformation
```

## Support
This code is provided as-is and currently not officially supported by Dell EMC.

## License
Copyright Dell EMC