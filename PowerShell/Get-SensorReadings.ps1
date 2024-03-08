
<#
_author_ = Trevor Squillario <Trevor_Squillario@Dell.com
_version_ = 3.0
Copyright (c) 2024, Dell, Inc.
This software is licensed to you under the GNU General Public License,
version 2 (GPLv2). There is NO WARRANTY for this software, express or
implied, including the implied warranties of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
along with this software; if not, see
http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt
#>

<#
.Synopsis
   Cmdlet used to get onboard sensors
.DESCRIPTION
   - idrac_ip: Pass in iDRAC IP address
   - idrac_username: Pass in iDRAC username
   - idrac_password: Pass in iDRAC username password
   - list_sensors: List all sensors available on system
   - sensor_name: Name of sensor
.EXAMPLE
    List Sensor Names

   .\Get-SensorReadings.ps1 -idrac_ip 192.168.0.120 -username root -password 'calvin' -list_sensors
.EXAMPLE
    Get Specific Sensor

   .\Get-SensorReadings.ps1 -idrac_ip 192.168.0.120 -username root -password 'calvin' -sensor_name "SystemBoardInletTemp"
.EXAMPLE
    Get All Available Sensors

   .\Get-SensorReadings.ps1 -idrac_ip 192.168.0.120 -username root -password 'calvin'
#>
param(
[Parameter(Mandatory=$True)]
[string]$idrac_ip,
[Parameter(Mandatory=$True)]
[string]$idrac_username,
[Parameter(Mandatory=$True)]
[string]$idrac_password,
[Parameter(Mandatory=$False)]
[string]$sensor_name,
[Parameter(Mandatory=$False)]
[switch]$list_sensors
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

function Get-SensorReading($SensorReadingUri) {
        $SensorResult = Invoke-WebRequest -Uri $SensorReadingUri -Credential $credential -Method Get -UseBasicParsing -Headers $headers
        $SensorResultJson = $SensorResult.Content | ConvertFrom-Json
        $SensorId = $SensorResultJson.Id
        $SensorName = $SensorResultJson.Name
        $SensorReadingType = $SensorResultJson.ReadingType
        $SensorReadingUnits = $SensorResultJson.ReadingUnits
        $SensorReading = $SensorResultJson.Reading

        $SensorOutput = [PSCustomObject]@{
            Host = $idrac_ip
            Id = $SensorId
            Name = $SensorName
            ReadingType = $SensorReadingType
            ReadingUnits = $SensorReadingUnits
            Reading = $SensorReading
        }
        return $SensorOutput
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::TLS12
$user = $idrac_username
$pass= $idrac_password
$secpasswd = ConvertTo-SecureString $pass -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($user, $secpasswd)
$headers = @{"Accept"="application/json"}
Try {
    Set-CertPolicy
    $Uri = "https://$idrac_ip/redfish/v1/Chassis/System.Embedded.1/Sensors"
    $Result = Invoke-WebRequest -Uri $Uri -Credential $credential -Method Get -UseBasicParsing -Headers $headers
    if ($Result.StatusCode -eq 200 -or $Result.StatusCode -eq 202)
    {
        $Output = @()
        # Convert result to JSON
        $ResultJson = $Result.Content | ConvertFrom-Json
        if ($list_sensors) {
            Write-Verbose "List Sensors..."
            foreach ($Sensor in $ResultJson.Members) {
                $SensorName = $Sensor.'@odata.id'
                $Output += $SensorName.split('/')[-1]
            }
        } elseif ($sensor_name) {
            Write-Verbose "Get Sensor $($sensor_name)"
            $SensorUri = "https://$($idrac_ip)/redfish/v1/Chassis/System.Embedded.1/Sensors/$($sensor_name)"
            $SensorReadingOutput = Get-SensorReading -SensorReadingUri $SensorUri
            $Output += $SensorReadingOutput
        } else {
            foreach ($Sensor in $ResultJson.Members) {
                Write-Verbose "Get Sensor $($Sensor.'@odata.id')"
                $SensorUri = "https://$($idrac_ip)$($Sensor.'@odata.id')"
                $SensorReadingOutput = Get-SensorReading -SensorReadingUri $SensorUri
                $Output += $SensorReadingOutput
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
