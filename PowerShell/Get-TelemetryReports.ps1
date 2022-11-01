
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
   Cmdlet used to get list of telemetry report metrics
.DESCRIPTION
   - idrac_ip: Pass in iDRAC IP address
   - idrac_username: Pass in iDRAC username
   - idrac_password: Pass in iDRAC username password
.EXAMPLE
   .\Get-SystemHealth.ps1 -idrac_ip 192.168.0.120 -username root -password 'calvin'
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

class ReportMetric {
    $Host
    $ReportId
    $ReportName
    $ReportEnabled
    $MetricId
}

Try {
    Set-CertPolicy
    $Output = @()
    #$Reports = @()
    # Get Telemetry Reports
    $ReportsUri = "https://$idrac_ip/redfish/v1/TelemetryService/MetricReportDefinitions"
    $ReportsResult = Invoke-WebRequest -Uri $ReportsUri -Credential $credential -Method Get -UseBasicParsing -Headers @{"Accept"="application/json"}
    if ($ReportsResult.StatusCode -eq 200 -or $ReportsResult.StatusCode -eq 202) {
        $ReportsResultJson = $ReportsResult.Content | ConvertFrom-Json
        $Reports = $ReportsResultJson.Members
    }
    else
    {
        Write-Error $ReportsResult
        return
    }

    foreach ($Report in $Reports) {
        # Get Report Metrics
        $ReportName = $Report.'@odata.id'.split("/")[-1]
        $ReportMetricUri = "https://$idrac_ip/redfish/v1/TelemetryService/MetricReportDefinitions/$ReportName"
        $ReportMetricResult = Invoke-WebRequest -Uri $ReportMetricUri -Credential $credential -Method Get -UseBasicParsing -Headers @{"Accept"="application/json"}
        if ($ReportMetricResult.StatusCode -eq 200 -or $ReportMetricResult.StatusCode -eq 202) {
            $ReportMetricResultJson = $ReportMetricResult.Content | ConvertFrom-Json
            foreach ($ReportMetric in $ReportMetricResultJson.Metrics) {
                $ReportMetricOutput = [ReportMetric]@{
                    Host = $idrac_ip
                    ReportId = $ReportMetricResultJson.Id
                    ReportName = $ReportMetricResultJson.Name
                    ReportEnabled = $ReportMetricResultJson.MetricReportDefinitionEnabled
                    MetricId = $ReportMetric.MetricId
                }
                $Output += $ReportMetricOutput
            }
        }
        else
        {
            Write-Error $ReportMetricResult
            return
        }
    }

    return $Output
}
Catch {
    Write-Error ($_.ErrorDetails)
}
