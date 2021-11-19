
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
   .\Get-NetworkInventory.ps1 -idrac_ip 192.168.0.120 -username root -password 'calvin'
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

Try {
    Set-CertPolicy
    $Uri = "https://$idrac_ip/redfish/v1/Systems/System.Embedded.1/NetworkAdapters"
    $Result = Invoke-WebRequest -Uri $Uri -Credential $credential -Method Get -UseBasicParsing -Headers @{"Accept"="application/json"}
    if ($Result.StatusCode -eq 200 -or $Result.StatusCode -eq 202)
    {
        $Output = @()
        # Convert result to JSON
        $ResultJson = $Result.Content | ConvertFrom-Json
        foreach ($NIC in $ResultJson.Members) {
            $NICUri = "https://$($idrac_ip)$($NIC.'@odata.id')"
            $NICResult = Invoke-WebRequest -Uri $NICUri -Credential $credential -Method Get -UseBasicParsing -Headers @{"Accept"="application/json"}
            $NICResultJson = $NICResult.Content | ConvertFrom-Json
            $CardManufacturer = $NICResultJson.Manufacturer
            $CardModel = $NICResultJson.Model
            $CardId = $NICResultJson.Id
            $CardPartNumber = $NICResultJson.PartNumber
            $CardSerialNumber = $NICResultJson.SerialNumber
            foreach ($Port in $NICResultJson.Controllers.Links.NetworkPorts) {
                $NICPortUri = "https://$($idrac_ip)$($Port.'@odata.id')"
                $NICPortResult = Invoke-WebRequest -Uri $NICPortUri -Credential $credential -Method Get -UseBasicParsing -Headers @{"Accept"="application/json"}
                $NICPortResultJson = $NICPortResult.Content | ConvertFrom-Json
                $PortId = $NICPortResultJson.Id
                $PortLinkStatus = $NICPortResultJson.LinkStatus
                $NICPortTransceiver = $NICPortResultJson.Oem.Dell.DellNetworkTransceiver
                $TransceiverDeviceDescription = ""
                $TransceiverFQDD = ""
                $TransceiverId = ""
                $TransceiverIdentifierType = ""
                $TransceiverInterfaceType = ""
                $TransceiverName = ""
                $TransceiverPartNumber = ""
                $TransceiverRevision = ""
                $TransceiverSerialNumber = ""
                $TransceiverVendorName = ""
                if ($NICPortTransceiver) {
                    $TransceiverDeviceDescription = $NICPortTransceiver.DeviceDescription
                    $TransceiverFQDD = $NICPortTransceiver.FQDD
                    $TransceiverId = $NICPortTransceiver.Id
                    $TransceiverIdentifierType = $NICPortTransceiver.IdentifierType
                    $TransceiverInterfaceType = $NICPortTransceiver.InterfaceType
                    $TransceiverName = $NICPortTransceiver.Name
                    $TransceiverPartNumber = $NICPortTransceiver.PartNumber
                    $TransceiverRevision = $NICPortTransceiver.Revision
                    $TransceiverSerialNumber = $NICPortTransceiver.SerialNumber
                    $TransceiverVendorName = $NICPortTransceiver.VendorName
                }

                $PortOutput = [PSCustomObject]@{
                    CardId = $CardId
                    CardManufacturer = $CardManufacturer
                    CardModel = $CardModel
                    CardPartNumber = $CardPartNumber
                    CardSerialNumber = $CardSerialNumber
                    PortId = $PortId
                    PortLinkStatus = $PortLinkStatus
                    TransceiverDeviceDescription = $TransceiverDeviceDescription
                    TransceiverFQDD = $TransceiverFQDD
                    TransceiverId = $TransceiverId
                    TransceiverIdentifierType = $TransceiverIdentifierType
                    TransceiverInterfaceType = $TransceiverInterfaceType
                    TransceiverName = $TransceiverName
                    TransceiverPartNumber = $TransceiverPartNumber
                    TransceiverRevision = $TransceiverRevision
                    TransceiverSerialNumber = $TransceiverSerialNumber
                    TransceiverVendorName = $TransceiverVendorName
                    
                }
                $Output += $PortOutput
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