
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
   Cmdlet used to get network card info including ports and transceivers
.DESCRIPTION
   - idrac_ip: Pass in iDRAC IP address
   - idrac_username: Pass in iDRAC username
   - idrac_password: Pass in iDRAC username password
.EXAMPLE
   .\Get-StorageInventory.ps1 -idrac_ip 192.168.0.120 -username root -password 'calvin'
#>
param(
[Parameter(Mandatory=$True)]
[string]$idrac_ip,
[Parameter(Mandatory=$True)]
[string]$idrac_username,
[Parameter(Mandatory=$True)]
[string]$idrac_password
)

# Function to ignore SSL certs
function Set-CertPolicy() {
    if ($PSVersionTable.PSEdition -eq 'Core') {
        $PSDefaultParameterValues["Invoke-RestMethod:SkipCertificatcd eCheck"] = $true
        $PSDefaultParameterValues["Invoke-WebRequest:SkipCertificateCheck"] = $true
        #$PSDefaultParameterValues.Add("Invoke-RestMethod:SkipCertificateCheck", $true)
        #$PSDefaultParameterValues.Add("Invoke-WebRequest:SkipCertificateCheck", $true)
    } else {
        ## Trust all certs - for sample usage only
        try {
            Add-Type @"
            using System.Net;
            using System.Security.Cryptography.X509Certificates;
            public class TrustAllCertsPolicy : ICertificatePolicy {
                public bool CheckValidationResult(
                    ServicePoint srvPoint, X509Certificate certificate,
                    WebRequest request, int certificateProblem) {
                    return true;
                }
            }
"@
        [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        }
        catch {
            Write-Error "Unable to add type for cert policy"
        }
    } 
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::TLS12
$user = $idrac_username
$pass= $idrac_password
$secpasswd = ConvertTo-SecureString $pass -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($user, $secpasswd)
$headers = @{"Accept"="application/json"}
Try {
    Set-CertPolicy
    $Uri = "https://$idrac_ip/redfish/v1/Systems/System.Embedded.1/Storage"
    $Result = Invoke-WebRequest -Uri $Uri -Credential $credential -Method Get -UseBasicParsing -Headers $headers
    if ($Result.StatusCode -eq 200 -or $Result.StatusCode -eq 202)
    {
        $Output = @()
        # Convert result to JSON
        $ResultJson = $Result.Content | ConvertFrom-Json
        foreach ($Controller in $ResultJson.Members) {
            $ControllerUri = "https://$($idrac_ip)$($Controller.'@odata.id')"
            $ControllerResult = Invoke-WebRequest -Uri $ControllerUri -Credential $credential -Method Get -UseBasicParsing -Headers $headers
            $ControllerResultJson = $ControllerResult.Content | ConvertFrom-Json
            $ControllerId = $ControllerResultJson.Id
            if (-not $($ControllerResultJson | Get-Member -MemberType NoteProperty -Name "StorageControllers")) {
                continue
            }
            $ControllerManufacturer = $ControllerResultJson.StorageControllers[0].Manufacturer
            $ControllerModel = $ControllerResultJson.StorageControllers[0].Model
            $ControllerFirmwareVersion = $ControllerResultJson.StorageControllers[0].FirmwareVersion
            foreach ($Drive in $ControllerResultJson.Drives) {
                $DriveUri = "https://$($idrac_ip)$($Drive.'@odata.id')"
                $DriveResult = Invoke-WebRequest -Uri $DriveUri -Credential $credential -Method Get -UseBasicParsing -Headers $headers
                $DriveResultJson = $DriveResult.Content | ConvertFrom-Json
                $DriveId = $DriveResultJson.Id
                $DriveManufacturer = $DriveResultJson.Manufacturer
                $DriveMediaType = $DriveResultJson.MediaType
                $DriveModel = $DriveResultJson.Model
                $DrivePartNumber = $DriveResultJson.PartNumber
                $DriveProtocol = $DriveResultJson.Protocol
                $DriveRevision = $DriveResultJson.Revision
                $DriveSerialNumber = $DriveResultJson.SerialNumber

                $DriveOutput = [PSCustomObject]@{
                    Host = $idrac_ip
                    ControllerId = $ControllerId
                    ControllerManufacturer = $ControllerManufacturer
                    ControllerModel = $ControllerModel
                    ControllerFirmwareVersion = $ControllerFirmwareVersion
                    DriveId = $DriveId
                    DriveManufacturer = $DriveManufacturer
                    DriveMediaType = $DriveMediaType
                    DriveModel = $DriveModel
                    DrivePartNumber = $DrivePartNumber
                    DriveProtocol = $DriveProtocol
                    DriveRevision = $DriveRevision
                    DriveSerialNumber = $DriveSerialNumber                        
                }
                $Output += $DriveOutput
            }
        }
        return $Output #| Export-Csv "C:\Temp\Export.csv" -NoTypeInformation
    }
    else
    {
        Write-Error $result
        return
    }
}
Catch {
    Write-Error ($_.ErrorDetails)
    Write-Error ($_.Exception | Format-List -Force | Out-String) 
    Write-Error ($_.InvocationInfo | Format-List -Force | Out-String)
}

