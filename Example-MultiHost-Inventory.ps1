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