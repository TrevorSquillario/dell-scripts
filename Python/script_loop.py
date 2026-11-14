# _author_ = Trevor Squillario <Trevor.Squillario@Dell.com>
#
# Copyright (c) 2023, Dell, Inc.
#
# This software is licensed to you under the GNU General Public License,
# version 2 (GPLv2). There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.

# System Requirements
# Python 3.x
import argparse, os.path, subprocess, getpass, sys
import logging

#Arguments passed into script based on flag
parser=argparse.ArgumentParser(description="Python script to execute another Python script on multiple servers")
parser.add_argument('-u', help='iDRAC username', required=True)
parser.add_argument('-p', help='iDRAC password. If you do not pass in argument -p, script will prompt to enter user password which will not be echoed to the screen.', required=False)
parser.add_argument('--file', help='Specify a text file of IP Addresses or Hostnames separated by line breaks. Example: --file devices.txt', required=True)
args=parser.parse_args()

def run_command(command):
    raw_command = command.rstrip('\n')
    output = subprocess.run(raw_command, stdout=subprocess.PIPE, universal_newlines=True, encoding='utf-8', shell=True)
    return output

def execute_script(dracip, command):
    msg = "Trying to login to " + dracip
    print(msg)
    command_result = run_command(command)
    if command_result.returncode == 0: # Command successed
        print(command_result.stdout)
    else:
        # log IPs where credentials cannot be authorized
        msg = "Unable to connect to " + dracip
        print(msg)

if __name__ == "__main__":
    idrac_username = args.u
    if args.p:
        idrac_password = args.p
    if not args.p and args.u:
        idrac_password = getpass.getpass("\n- Argument -p not detected, pass in iDRAC user %s password: " % args.u)
    
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

            for dracip in ip_list:
                try:
                    # Define command
                    #command = "python3 '/home/user/git/iDRAC-Redfish-Scripting/Redfish Python/InstallFromRepositoryREDFISH.py' -ip '%s' -u '%s' -p '%s' --install --shareip downloads.dell.com --sharetype HTTPS --applyupdate True --rebootneeded True" % (dracip, idrac_username, idrac_password)
                    command = "python3 '/home/user/git/iDRAC-Redfish-Scripting/Redfish Python/GetIdracLcSystemAttributesREDFISH.py' -ip '%s' -u '%s' -p '%s' --group-name 'idrac' --attribute-name 'NIC.1.DNSRacName'" % (dracip, idrac_username, idrac_password)
                    # Execute command
                    execute_script(dracip, command)
                except:
                    continue

            ip_file.close()
        else:
            print("Invalid file")
