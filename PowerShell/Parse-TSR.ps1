
<#
_author_ = Trevor Squillario <Trevor_Squillario@Dell.com
_version_ = 3.0
Copyright (c) 2020, Dell, Inc.
This software is licensed to you under the GNU General Public License,
version 2 (GPLv2). There is NO WARRANTY for this software, express or
implied, including the implied warranties of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
along with this software; if not, see
http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt
#>

<#
.Synopsis
   Cmdlet used to parse all TSR zip files in a directory, extract the sysinfo_DCIM_View.xml file and generate report showing Service Tag, CPU and System Component Rollup
.DESCRIPTION
   - tsr_dir: Directory containing TSR collection zip files (Example: "C:\Temp"). 
.EXAMPLE
   .\Parse-TSR.ps1 -tsr_dir "C:\Temp"
#>

param(
[Parameter(Mandatory=$True)]
[string]$tsr_dir
)

Add-Type -Assembly System.IO.Compression.FileSystem

$TSRDir = $tsr_dir
$TSRFiles = Get-ChildItem -Path $TSRDir -File -Filter "*.zip"

class SystemHealthStatus {
    $Host
    $ServiceTag
    $CPUInfo
    $BatteryRollupStatus
    $CPURollupStatus
    $CurrentRollupStatus
    $FanRollupStatus
    $IDSDMRollupStatus
    $IntrusionRollupStatus
    $LicensingRollupStatus
    $MemoryRollupStatus
    $PSRollupStatus
    $RollupStatus
    $SDCardRollupStatus
    $SELRollupStatus
    $StorageRollupStatus
    $TempRollupStatus
    $TempStatisticsRollupStatus
    $VoltRollupStatus
}

$Output = @()
foreach ($TSRFile in $TSRFiles) {
    $OuterZip = [IO.Compression.ZipFile]::OpenRead($TSRFile)
    $OuterZipContents = $OuterZip.Entries | Where {$_.Name -like '*.zip'} 
    $InnerZipStream = $OuterZipContents.Open()
    $InnerZip = [IO.Compression.ZipArchive]::new($InnerZipStream)
    $InnerZipContents = $InnerZip.Entries | Where {$_.Name -eq 'sysinfo_DCIM_View.xml'} 
    $XMLStream = $InnerZipContents.Open()

    $XMLContent = [xml]::new()
    $XMLContent.Load($XMLStream)

    # SystemView
    $SystemView = $XMLContent.CIM.MESSAGE.SIMPLEREQ.'VALUE.NAMEDINSTANCE'.INSTANCE | Where-Object { $_.CLASSNAME -eq "DCIM_SystemView" } 

    # RollupStatus
    $BatteryRollupStatus = $SystemView | ForEach-Object { $_.PROPERTY } | Where-Object { $_.NAME -eq "BatteryRollupStatus" } | Select-Object -ExpandProperty DisplayValue
    $CPURollupStatus = $SystemView | ForEach-Object { $_.PROPERTY } | Where-Object { $_.NAME -eq "CPURollupStatus" } | Select-Object -ExpandProperty DisplayValue
    $CurrentRollupStatus = $SystemView | ForEach-Object { $_.PROPERTY } | Where-Object { $_.NAME -eq "CurrentRollupStatus" } | Select-Object -ExpandProperty DisplayValue
    $FanRollupStatus = $SystemView | ForEach-Object { $_.PROPERTY } | Where-Object { $_.NAME -eq "FanRollupStatus" } | Select-Object -ExpandProperty DisplayValue
    $IDSDMRollupStatus = $SystemView | ForEach-Object { $_.PROPERTY } | Where-Object { $_.NAME -eq "IDSDMRollupStatus" } | Select-Object -ExpandProperty DisplayValue
    $IntrusionRollupStatus = $SystemView | ForEach-Object { $_.PROPERTY } | Where-Object { $_.NAME -eq "IntrusionRollupStatus" } | Select-Object -ExpandProperty DisplayValue
    $LicensingRollupStatus = $SystemView | ForEach-Object { $_.PROPERTY } | Where-Object { $_.NAME -eq "LicensingRollupStatus" } | Select-Object -ExpandProperty DisplayValue
    $MemoryRollupStatus = $SystemView | ForEach-Object { $_.PROPERTY } | Where-Object { $_.NAME -eq "MemoryRollupStatus" } | Select-Object -ExpandProperty DisplayValue
    $PSRollupStatus = $SystemView | ForEach-Object { $_.PROPERTY } | Where-Object { $_.NAME -eq "PSRollupStatus" } | Select-Object -ExpandProperty DisplayValue
    $RollupStatus = $SystemView | ForEach-Object { $_.PROPERTY } | Where-Object { $_.NAME -eq "RollupStatus" } | Select-Object -ExpandProperty DisplayValue
    $SDCardRollupStatus = $SystemView | ForEach-Object { $_.PROPERTY } | Where-Object { $_.NAME -eq "SDCardRollupStatus" } | Select-Object -ExpandProperty DisplayValue
    $SELRollupStatus = $SystemView | ForEach-Object { $_.PROPERTY } | Where-Object { $_.NAME -eq "SELRollupStatus" } | Select-Object -ExpandProperty DisplayValue
    $StorageRollupStatus = $SystemView | ForEach-Object { $_.PROPERTY } | Where-Object { $_.NAME -eq "StorageRollupStatus" } | Select-Object -ExpandProperty DisplayValue
    $TempRollupStatus = $SystemView | ForEach-Object { $_.PROPERTY } | Where-Object { $_.NAME -eq "TempRollupStatus" } | Select-Object -ExpandProperty DisplayValue
    $TempStatisticsRollupStatus = $SystemView | ForEach-Object { $_.PROPERTY } | Where-Object { $_.NAME -eq "TempStatisticsRollupStatus" } | Select-Object -ExpandProperty DisplayValue
    $VoltRollupStatus = $SystemView | ForEach-Object { $_.PROPERTY } | Where-Object { $_.NAME -eq "VoltRollupStatus" } | Select-Object -ExpandProperty DisplayValue

    # ServiceTag
    $ServiceTag = $SystemView | ForEach-Object { $_.PROPERTY } | 
        Where-Object { $_.NAME -eq "ServiceTag" } | Select-Object -ExpandProperty DisplayValue

    # CPUView
    $CPUView = $XMLContent.CIM.MESSAGE.SIMPLEREQ.'VALUE.NAMEDINSTANCE'.INSTANCE | Where-Object { $_.CLASSNAME -eq "DCIM_CPUView" } 

    # CPUInfo
    $CPUInfo = $CPUView | ForEach-Object { $_.PROPERTY } | 
        Where-Object { $_.NAME -like "*Model" } | Select-Object -ExpandProperty DisplayValue

    $SubSystemHealthOutput = [SystemHealthStatus]@{
        Host = $TSRFile
        ServiceTag = $ServiceTag  
        CPUInfo = $CPUInfo
        BatteryRollupStatus = $BatteryRollupStatus
        CPURollupStatus = $CPURollupStatus
        CurrentRollupStatus = $CurrentRollupStatus
        FanRollupStatus = $FanRollupStatus
        IDSDMRollupStatus = $IDSDMRollupStatus
        IntrusionRollupStatus = $IntrusionRollupStatus
        LicensingRollupStatus = $LicensingRollupStatus
        MemoryRollupStatus = $MemoryRollupStatus
        PSRollupStatus = $PSRollupStatus
        RollupStatus = $RollupStatus
        SDCardRollupStatus = $SDCardRollupStatus
        SELRollupStatus = $SELRollupStatus
        StorageRollupStatus = $StorageRollupStatus
        TempRollupStatus = $TempRollupStatus
        TempStatisticsRollupStatus = $TempStatisticsRollupStatus
        VoltRollupStatus = $VoltRollupStatus
    }
    $Output += $SubSystemHealthOutput

}
Write-Host $($Output | Format-Table | Out-String)
$Output | Export-Csv -Path "$TSRDir\Output.csv"