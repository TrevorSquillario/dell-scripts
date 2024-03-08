param(
[Parameter(Mandatory=$True)]
[string]$idrac_username,
[Parameter(Mandatory=$True)]
[string]$idrac_password,
[Parameter(Mandatory=$False)]
[string]$hosts_file,
[Parameter(Mandatory=$False)]
[string[]]$hosts,
[Parameter(Mandatory=$False)]
[string]$exportcsv = "C:\Temp\SensorReadings.csv"
)

$InventoryAll = @()
$Hosts = @()
if ($hosts_file) {
    $Hosts = Get-Content $hosts_file
} else {
    $Hosts = $Hosts
}
foreach ($iDRAC in $Hosts) {
    $Inventory = & "./PowerShell/Get-SensorReadings.ps1" -idrac_ip $iDRAC -idrac_username $idrac_username -idrac_password $idrac_password -sensor_name "SystemBoardInletTemp" -Verbose
    $InventoryAll += $Inventory
}
$InventoryAll | Format-Table

# Export to CSV
if ($exportcsv) {
    Write-Verbose "Exported to file $($exportcsv)"
    $InventoryAll | Export-Csv $exportcsv -NoTypeInformation
}