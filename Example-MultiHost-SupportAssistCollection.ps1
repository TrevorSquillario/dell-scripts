param(
[Parameter(Mandatory=$True)]
[string]$hosts_file,
[Parameter(Mandatory=$True)]
[string]$idrac_username,
[Parameter(Mandatory=$True)]
[string]$idrac_password,
[Parameter(Mandatory=$False)]
[string]$collection_data,
[Parameter(Mandatory=$False)]
[string]$output_directory
)

foreach ($iDRAC in Get-Content $hosts_file) {
    Start-Job -Name $iDRAC -FilePath "./PowerShell/Invoke-SupportAssistCollection.ps1" -ArgumentList $iDRAC, $idrac_username, $idrac_password, $collection_data, $output_directory
}
Get-Job | Wait-Job