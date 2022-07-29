param(
[Parameter(Mandatory=$True)]
[string]$idrac_username,
[Parameter(Mandatory=$True)]
[string]$idrac_password,
[Parameter(Mandatory=$False)]
[string]$hosts_file,
[Parameter(Mandatory=$False)]
[string[]]$hosts
)

$InventoryAll = @()
$Hosts = @()
if ($hosts_file) {
    $Hosts = Get-Content $hosts_file
} else {
    $Hosts = $Hosts
}
foreach ($iDRAC in $Hosts) {
    $Inventory = & "./PowerShell/Get-SystemHealth.ps1" -idrac_ip $iDRAC -idrac_username $idrac_username -idrac_password $idrac_password
    $InventoryAll += $Inventory
}
$InventoryAll | Format-Table
