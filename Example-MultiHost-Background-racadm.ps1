[CmdletBinding()]
Param(
    [Parameter(Mandatory=$false, HelpMessage="Path to the racadm executable (e.g., 'racadm' if in PATH, or 'C:\Program Files\Dell\RACADM\racadm.exe')")]
    [string]$RacadmCommand = "racadm",

    [Parameter(Mandatory=$false, HelpMessage="Username for racadm (e.g., 'root')")]
    [string]$RacadmUser = "root",

    [Parameter(Mandatory=$false, HelpMessage="Password for racadm (WARNING: Storing passwords directly in arguments or script is not secure for production. Consider SecureString.)")]
    [string]$RacadmPassword = "calvin",

    [Parameter(Mandatory=$true, HelpMessage="The racadm action to perform (e.g., 'lclog view -n 25')")]
    [string]$RacadmAction,

    [Parameter(Mandatory=$false, HelpMessage="Path to the hosts.txt file containing IP addresses, one per line.")]
    [string]$HostsFile = "hosts.txt"
)

# Get the current directory to save output files.
# Output files will be named after the IP address (e.g., 192.168.5.69.txt).
$outputDirectory = Get-Location

# --- Script Start ---

Write-Host "Starting RACADM command execution for hosts listed in $($HostsFile)..."
Write-Host "Output for each host will be saved in '$($outputDirectory)'."
Write-Host "RACADM Command: '$RacadmCommand'"
Write-Host "RACADM User: '$RacadmUser'"
Write-Host "RACADM Action: '$RacadmAction'"

# Check if the hosts file exists
if (-not (Test-Path $hostsFile)) {
    Write-Error "Error: The hosts file '$hostsFile' was not found. Please ensure the path is correct."
    exit 1
}

# Read IPs from the hosts file
$ipAddresses = Get-Content $hostsFile | Where-Object { $_ -match '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}' }

if ($ipAddresses.Count -eq 0) {
    Write-Warning "No valid IP addresses found in '$hostsFile'. Please check the file content."
    exit 0
}

$firstActionWord = ($RacadmAction -split ' ')[0]
# Sanitize the word for use in a filename (e.g., replace problematic characters with underscores)
$firstActionWord = $firstActionWord -replace '[^a-zA-Z0-9_\-]', '_'

# Loop through each IP address and execute the command
foreach ($ip in $ipAddresses) {
    $ip = $ip.Trim() # Remove any leading/trailing whitespace

    # Skip empty lines or lines that are not valid IPs (though Where-Object above should handle most)
    if ([string]::IsNullOrEmpty($ip) -or (-not ($ip -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$'))) {
        Write-Warning "Skipping invalid or empty line: '$ip'"
        continue
    }

    Write-Host "Processing host: $ip"

    # Define the output file name for this host
    $outputFileName = "$($ip)_$($firstActionWord).txt"
    $fullOutputPath = Join-Path -Path $outputDirectory -ChildPath $outputFileName

    # Construct the arguments for Start-Process, including redirection to the host-specific file
    # Note: 'racadm -r 192.168.5.69 -u 'root' -p 'calvin' lclog view -n 25 > 192.168.5.69.txt'
    # The redirection operator '>' will create/overwrite the file.
    $arguments = "--nocertwarn -r `"$ip`" -u `"$racadmUser`" -p `"$racadmPassword`" $racadmAction"

    # Start the process in the background.
    # -NoNewWindow: Prevents a new console window from popping up for each process.
    # -PassThru: Returns a process object, which can be useful if you want to monitor the processes later.
    try {
        # Using cmd.exe /c to ensure the redirection is handled by the command interpreter,
        # as Start-Process with -ArgumentList doesn't directly process PowerShell redirection operators.
        Write-Host "Running $racadmCommand $arguments"
        Write-Host "Output to file $fullOutputPath"
        Start-Process -FilePath $racadmCommand -ArgumentList "$arguments" -NoNewWindow -RedirectStandardOutput $fullOutputPath
        Write-Host "Successfully launched command for $ip with output to '$outputFileName' in the background."
    }
    catch {
        Write-Error "Failed to launch command for $ip. Error: $($_.Exception.Message)"
    }
}

Write-Host "All RACADM commands have been launched. They are running in the background."
Write-Host "Check '$($outputDirectory)' for the generated output files (e.g., 192.168.5.69.txt)."

# --- Example hosts.txt content (create this file next to your script or at the specified path) ---
# 192.168.5.69
# 192.168.5.70
# 192.168.5.71
# # This is a comment
# 10.0.0.1
#
# another.host.ip

