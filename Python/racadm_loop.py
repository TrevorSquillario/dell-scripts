
# _author_ = Trevor Squillario <Trevor.Squillario@Dell.com>
#
# Copyright (c) 2019, Dell, Inc.
#
# This software is licensed to you under the GNU General Public License,
# version 2 (GPLv2). There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.

# System Requirements
# Python 3.x
import argparse, os.path, subprocess, getpass 

#Arguments passed into script based on flag
parser=argparse.ArgumentParser(description="Python script to execute racadm commands on multiple servers")
parser.add_argument('--command', help='racadm command to execute. Example: --command "get BIOS.BiosBootSettings"', required=True)
parser.add_argument('--user', help='Username used to login to iDRAC. Example: --user root', required=True)
parser.add_argument('--file', help='Specify a text file of IP Addresses or Hostnames separated by line breaks. Example: --file devices.txt', required=True)
args=parser.parse_args()

###
# Script Variables
###

# Credential to attempt to login to iDRAC with
default_idrac_username = args.user
default_idrac_password = ""
default_idrac_command = args.command

###
# Start of Script
###
def run_command(command):
    raw_command = command.rstrip('\n')
    output = subprocess.run(raw_command, stdout=subprocess.PIPE, universal_newlines=True, encoding='utf-8')
    return output

# Main function to login to iDRAC, if successfull change credentials. Accepts array of IPs
def execute_command(dracs):
    # Loop through each IP
    for dracip in dracs:
        try:
            msg = "Trying to login to " + dracip + " as " + default_idrac_username
            print(msg)
            command_result = run_command('racadm --nocertwarn -r %s -u %s -p \"%s\" %s' % (dracip, default_idrac_username, default_idrac_password, default_idrac_command))
            if command_result.returncode == 0: # Command successed
                print(command_result.stdout)
            else:
                # log IPs where credentials cannot be authorized
                msg = "Unable to connect to " + dracip
                print(msg)
        except FileNotFoundError as err:
            #Log IPs that cannot establish a connection
            msg = "Unable to find racadm executable"
            print(msg)
            print(err)
            continue

# Get IPs from Input File
if args.file:
    if(os.path.isfile(args.file)):
        ip_list= []
        ip_file= open(args.file, "r")
        while True:
            ip_line = ip_file.readline().rstrip("\n")
            ip_list.append(ip_line)
            if not ip_line:
                break
        del ip_list[-1]

        # Prompt for password
        default_idrac_password = getpass.getpass() 
        
        # Execute command
        execute_command(ip_list)

        ip_file.close()
    else:
        print("Invalid file")