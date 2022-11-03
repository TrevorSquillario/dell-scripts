
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
   Cmdlet used to get system health rollup status
.DESCRIPTION
   - idrac_ip: Pass in iDRAC IP address
   - idrac_username: Pass in iDRAC username
   - idrac_password: Pass in iDRAC username password
   - collection_data: Pass in a value for the type of data you want to collect for Support Assist collection. Supported values are: "0" for DebugLogs, "1" for HWData, "2" for OSAppData or "3" for TTYLogs. Defaults to "HWData" only. Note: You can pass in one value or multiple values to collect. If you pass in multiple values, use comma separator for the values and surround it with double quotes (Example: "0,3"). 
.EXAMPLE
   .\Invoke-SupportAssistCollection.ps1 -idrac_ip 192.168.0.120 -username root -password 'calvin'
#>

param(
[Parameter(Mandatory=$True)]
[string]$idrac_ip,
[Parameter(Mandatory=$True)]
[string]$idrac_username,
[Parameter(Mandatory=$True)]
[string]$idrac_password,
[Parameter(Mandatory=$False)]
[string]$collection_data
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

function Get-ServiceTag() {
    $SystemInfoUrl = "https://$idrac_ip/redfish/v1/Systems/System.Embedded.1"
    $SystemInfoResult = Invoke-WebRequest -SkipCertificateCheck -SkipHeaderValidation -Uri $SystemInfoUrl -Credential $credential -Method Get -UseBasicParsing -Headers @{"Accept"="application/json"}
    if ($SystemInfoResult.StatusCode -eq 200 -or $SystemInfoResult.StatusCode -eq 202) {
        $SystemInfoResultJson = $SystemInfoResult.Content | ConvertFrom-Json
        $ServiceTag = $SystemInfoResultJson.SKU
        return $ServiceTag
    }
}


function Invoke-DownloadCollection($CollectionPath){
    $ServiceTag = Get-ServiceTag
    $FileName = "TSR$((Get-Date).ToString('yyyyMMddHHmmss'))_$ServiceTag.zip"
    $DownloadPath = Join-Path $PSScriptRoot $FileName
    Invoke-WebRequest -Uri "https://$idrac_ip$CollectionPath" -Credential $credential -OutFile $DownloadPath
    Write-Host "- File downloaded to $DownloadPath`n"
}

function Wait-OnJob($JobId)
{

$get_time_old=Get-Date -DisplayHint Time
$start_time = Get-Date

$end_time = $start_time.AddMinutes(50)
$force_count=0
Write-Host "- WARNING, script will now loop polling the job ($JobId) status every 30 seconds until marked completed`n"
while ($true)
{
$loop_time = Get-Date
$uri ="https://$idrac_ip/redfish/v1/Managers/iDRAC.Embedded.1/Jobs/$JobId"

   try
    {
    $result = Invoke-WebRequest -SkipCertificateCheck -SkipHeaderValidation -Uri $uri -Credential $credential -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept"="application/json"}
    }
    catch
    {
    Write-Host
    $RespErr
    break
    }
    try
    {
    $SA_report_file_location = $result.Headers.Location
    }
    catch
    {
    Write-Host "- FAIL, unable to locate file location in headers output"
    break
}
$overall_job_output=$result.Content | ConvertFrom-Json

if ($overall_job_output.Message.Contains("Fail") -or $overall_job_output.Message.Contains("Failed") -or $overall_job_output.Message.Contains("fail") -or $overall_job_output.Message.Contains("failed") -or $overall_job_output.Message.Contains("already"))
{
    Write-Host
    [String]::Format("- FAIL, job id $JobId marked as failed, error message: {0}",$overall_job_output.Message)
    break
}
elseif ($overall_job_output.Message.Contains("partially") -or $overall_job_output.Message.Contains("part"))
{
    Write-Host
    [String]::Format("- WARNING, job id $JobId completed with issues, check iDRAC Lifecyle Logs for more details. Final job message: {0}",$overall_job_output.Message)
    $get_current_time=Get-Date -DisplayHint Time
    $final_time=$get_current_time-$get_time_old
    $final_completion_time=$final_time | select Minutes,Seconds
    Write-Host "`n- PASS, job ID '$JobId' successfully marked as completed"
    Write-Host "`nSupport Assist collection job execution time:"
    $final_completion_time
    Write-Host "`n- URI Support Assist collection file location: $SA_report_file_location`n"
    Invoke-DownloadCollection($SA_report_file_location)
    break
}
elseif ($loop_time -gt $end_time)
{
    Write-Host "- FAIL, timeout of 50 minutes has been reached before marking the job completed"
    break
}
elseif ($overall_job_output.Message -eq "The SupportAssist Collection Operation is completed successfully." -or $overall_job_output.Message -eq  "Job completed successfully." -or $overall_job_output.Message.Contains("complete"))
{
    $get_current_time=Get-Date -DisplayHint Time
    $final_time=$get_current_time-$get_time_old
    $final_completion_time=$final_time | select Minutes,Seconds
    Write-Host "`n- PASS, job ID '$JobId' successfully marked as completed"
    Write-Host "`nSupport Assist collection job execution time:"
    $final_completion_time
    Write-Host "`n- URI Support Assist collection file location: $SA_report_file_location`n"
    Invoke-DownloadCollection($SA_report_file_location)
    break
}
else
{
    Write-Host "- Job ID '$JobId' not marked completed, checking job status again"
    Start-Sleep 30
}

}

}

function Invoke-Collect()
{
    # Create body payload for POST command
    if ($collection_data.Contains(",")) { # Multiple options selected
        $string_split = $collection_data.Split(",")
        $JsonBody = @{"ShareType"="Local";"DataSelectorArrayIn"=''}
        $data_selector_array = @()
        [System.Collections.ArrayList]$data_selector_array = $data_selector_array
            foreach ($item in $string_split)
            {
                if ($item -eq 0)
                {
                $data_selector_array+="DebugLogs"
                }
                if ($item -eq 1)
                {
                $data_selector_array+="HWData"
                }
                if ($item -eq 2)
                {
                $data_selector_array+="OSAppData"
                }
                if ($item -eq 3)
                {
                $data_selector_array+="TTYLogs"
                }
            }
        $JsonBody["DataSelectorArrayIn"] = $data_selector_array

    } elseif ($collection_data -eq "") { # No options selected
        $JsonBody = @{"ShareType"="Local";"DataSelectorArrayIn"=[System.Collections.ArrayList]@()}
        $JsonBody["DataSelectorArrayIn"]+="HWData"
    } else { # All options selecdted
        $JsonBody = @{"ShareType"="Local";"DataSelectorArrayIn"=[System.Collections.ArrayList]@()}
            if ($collection_data -eq 0)
            {
            $JsonBody["DataSelectorArrayIn"]+="DebugLogs"
            }
            if ($collection_data -eq 1)
            {
            $JsonBody["DataSelectorArrayIn"]+="HWData"
            }
            if ($collection_data -eq 2)
            {
            $JsonBody["DataSelectorArrayIn"]+="OSAppData"
            }
            if ($collection_data -eq 3)
            {
            $JsonBody["DataSelectorArrayIn"]+="TTYLogs"
            }
    }
    Write-Host "`n- Keys and Values being passed in for POST action 'SupportAssistCollection' -`n"
    $JsonBody = $JsonBody | ConvertTo-Json -Compress
    Write-Host $JsonBody

    $uri = "https://$idrac_ip/redfish/v1/Dell/Managers/iDRAC.Embedded.1/DellLCService/Actions/DellLCService.SupportAssistCollection"

    $post_result = Invoke-WebRequest -UseBasicParsing -SkipHeaderValidation -SkipCertificateCheck -Uri $uri -Credential $credential -Body $JsonBody -Method Post -ContentType 'application/json' -Headers @{"Accept"="application/json"} -ErrorVariable RespErr

    if ($post_result.StatusCode -eq 202 -or $post_result.StatusCode -eq 200)
    {
        $job_id_search = $post_result.Headers['Location']
        $job_id = $job_id_search.Split("/")[-1]
        return $job_id
    }
    else
    {
        return ""
    }
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::TLS12
$user = $idrac_username
$pass = $idrac_password
$secpasswd = ConvertTo-SecureString $pass -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($user, $secpasswd)

Set-CertPolicy
$JobId = Invoke-Collect
if ($JobId -ne "") {
    Wait-OnJob($JobId)
}