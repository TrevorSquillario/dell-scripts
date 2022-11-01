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
    racadm -r $iDRAC --nocertwarn -u $idrac_username -p $idrac_password storage get pdisks -o -p state,RemainingRatedWriteEndurance
}
