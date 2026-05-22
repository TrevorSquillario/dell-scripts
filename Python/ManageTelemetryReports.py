# EnableOrDisableAllTelemetryReports.py Python script using Redfish API to Enable or Disable All Telemetry Reports
# with Default/Existing settings.
#
#
# _author_ = Sankunny Jayaprasad <Sankunny.Jayaprasad@Dell.com>
# _author_ = Texas Roemer <Texas_Roemer@Dell.com>
# _version_ = 2.0
#
# Copyright (c) 2022, Dell, Inc.
#
# This software is licensed to you under the GNU General Public License,
# version 2 (GPLv2). There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.
#

import argparse
import csv
import json
import logging
import sys
import warnings
import requests

warnings.filterwarnings("ignore")
#logging.getLogger().setLevel(logging.INFO)  # Change to logging.DEBUG for detailed logs
logging.basicConfig(format='%(message)s', stream=sys.stdout, level=logging.INFO)

# Default timeout (seconds) for HTTP requests
REQUEST_TIMEOUT = 30

parser = argparse.ArgumentParser(description="Python script using Redfish to Enable/Disable iDRAC Telemetry and all supported metric reports for one iDRAC using script arguments or multiple iDRACs using CSV file.")
parser.add_argument('--script-examples', action="store_true", help='Prints script examples')
parser.add_argument('-ip', help='iDRAC IP address, argument only required if configuring one iDRAC', required=False)
parser.add_argument('-u', help='iDRAC username, argument only required if configuring one iDRAC', required=False)
parser.add_argument('-p', help='iDRAC password, argument only required if configuring one iDRAC', required=False)
parser.add_argument('-s', help='Pass in the report status to be set. Possible values are Enabled/Disabled', default='Enabled', required=False)
parser.add_argument('-f', help='Pass in csv file name. If file is not located in same directory as script, pass in the full directory path with file name. NOTE: Make sure to use iDRACs.csv file from the repo which has the correct format.', required=False)
parser.add_argument('-l', '--list', action='store_true', help='Only list telemetry attribute URIs and exit', required=False)
parser.add_argument('--get-metric-report-definition', dest='get_metric_report_definition', help='Get a single MetricReportDefinition by name (e.g. MemorySensor)', required=False)
parser.add_argument('--get-metric-report', dest='get_metric_report', help='Get a single MetricReport by name (e.g. MemorySensor)', required=False)
parser.add_argument('--metric-report', dest='metric_report', help='Comma-separated MetricReportDefinition name(s) to operate on (e.g. MemorySensor,CPUSensor)', required=False)

args = vars(parser.parse_args())

def print_examples():
    """
    Print program examples and exit
    """
    print(
        '\n\'EnableOrDisableAllTelemetryReports.py -ip 192.168.0.120 -u root -p calvin -s Enabled, this example will enable Telemetry and all metric reports for single iDRAC\n'
        '\n\'EnableOrDisableAllTelemetryReports.py -ip 192.168.0.120 -u root -p calvin -s Disabled, this example will disable Telemetry and all metric reports for single iDRAC\n'
        '\n\'EnableOrDisableAllTelemetryReports.py -ip 192.168.0.120 -u root -p calvin -s Enabled -f C:\Python39\iDRACs.csv, this example will enable Telemetry and all metric reports for all iDRACs in CSV file.\n'
        '\n\'EnableOrDisableAllTelemetryReports.py -ip 192.168.0.120 -u root -p calvin -s Disabled -f C:\Python39\iDRACs.csv, this example will disable Telemetry and all metric reports for all iDRACs in CSV file.\n')

def get_attributes(ip, user, pwd):
    """Check the current status of telemetry and return a list of telemetry attribute URIs.
    Returns:
        list: telemetry attribute URIs (strings)
    """
    # Use redfish API instead of AR
    url = 'https://{}/redfish/v1/TelemetryService/MetricReportDefinitions'.format(ip)
    headers = {'content-type': 'application/json'}
    response = requests.get(url, headers=headers, verify=False, auth=(user, pwd))
    if response.status_code != 200:
        logging.error("- FAIL, status code for reading attributes is not 200, code is: {}".format(response.status_code))
        sys.exit()
    try:
        logging.info("- INFO, successfully pulled configuration attributes")
        configurations_dict = json.loads(response.text)
        attributes = configurations_dict.get('Members', [])
        telemetry_attributes = [m['@odata.id'] for m in attributes]
        #logging.debug(telemetry_attributes)
        return telemetry_attributes
    except Exception as e:
        logging.error("- FAIL: detailed error message: {0}".format(e))
        sys.exit()


def set_attributes(ip, user, pwd, telemetry_attributes):
    """Uses the RedFish API to set the telemetry enabled attribute to user defined status.

    Args:
        telemetry_attributes (list): A list containing all telemetry attribute URIs
    """

    status_to_set = args["s"]
    if status_to_set not in ['Enabled', 'Disabled']:
        logging.error("Invalid value for report status. Supported values are Enabled & Disabled")
        sys.exit()
    headers = {'content-type': 'application/json'}
    # If user specified --metric-report, filter the telemetry attributes to only those names
    metric_arg = args.get('metric_report')
    if metric_arg:
        wanted = set([x.strip().lower() for x in metric_arg.split(',') if x.strip()])
        filtered = [uri for uri in telemetry_attributes if uri.rstrip('/').split('/')[-1].lower() in wanted]
        if not filtered:
            logging.error("- INFO, no matching MetricReportDefinitions found for %s, skipping", metric_arg)
            return
        telemetry_attributes = filtered
    
    # Enable global telemetry service    
    if status_to_set == 'Enabled':
        url = 'https://{}/redfish/v1/TelemetryService'.format(ip)
        response = requests.patch(url, data=json.dumps({"ServiceEnabled": True}), headers=headers,
                                verify=False, auth=(user, pwd), timeout=REQUEST_TIMEOUT)
        if response.status_code != 200:
            logging.error("- FAIL, status code for reading attributes is not 200, code is: {}".format(response.status_code))
            logging.debug(str(response))
            sys.exit()

    # Go to each metric report definition and enable or disable based on input
    for uri in telemetry_attributes:
        url = 'https://{}{}'.format(ip,uri)
        response = requests.patch(url, data=json.dumps({"MetricReportDefinitionEnabled": status_to_set=='Enabled'}), headers=headers,
                              verify=False, auth=(user, pwd), timeout=REQUEST_TIMEOUT)

        if response.status_code != 200:
            logging.error("- FAIL, status code for reading attributes is not 200, code is: {}".format(response.status_code))
            logging.debug(str(response))
            sys.exit()
        else:
            logging.info("- INFO, successfully set MetricReportDefinitionEnabled to {} for {}".format(status_to_set, uri))

    # Disable global telemetry service 
    if status_to_set == 'Disabled':
        url = 'https://{}/redfish/v1/TelemetryService'.format(ip)
        response = requests.patch(url, data=json.dumps({"ServiceEnabled": False}), headers=headers,
                                verify=False, auth=(user, pwd), timeout=REQUEST_TIMEOUT)

        if response.status_code != 200:
            logging.error("- FAIL, status code for reading attributes is not 200, code is: {}".format(response.status_code))
            logging.debug(str(response))
            sys.exit()
    
    logging.info("- INFO, successfully '{}' iDRAC Telemetry and all supported metric reports".format(status_to_set))


def get_metric_report_definition(ip, user, pwd, report_name):
    """Retrieve a single MetricReportDefinition by name and print JSON."""
    url = 'https://{}/redfish/v1/TelemetryService/MetricReportDefinitions/{}'.format(ip, report_name)
    headers = {'content-type': 'application/json'}
    try:
        response = requests.get(url, headers=headers, verify=False, auth=(user, pwd), timeout=REQUEST_TIMEOUT)
    except Exception as e:
        logging.error("- FAIL, error fetching MetricReportDefinition: %s", e)
        return None
    if response.status_code != 200:
        logging.error("- FAIL, status code for reading MetricReportDefinition is %s", response.status_code)
        return None
    try:
        data = json.loads(response.text)
        print(json.dumps(data, indent=2))
        return data
    except Exception as e:
        logging.error("- FAIL parsing MetricReportDefinition JSON: %s", e)
        return None


def get_metric_report(ip, user, pwd, report_name):
    """Retrieve a single MetricReport by name and print JSON."""
    url = 'https://{}/redfish/v1/TelemetryService/MetricReports/{}'.format(ip, report_name)
    headers = {'content-type': 'application/json'}
    try:
        response = requests.get(url, headers=headers, verify=False, auth=(user, pwd), timeout=REQUEST_TIMEOUT)
    except Exception as e:
        logging.error("- FAIL, error fetching MetricReport: %s", e)
        return None
    if response.status_code != 200:
        logging.error("- FAIL, status code for reading MetricReport is %s", response.status_code)
        return None
    try:
        data = json.loads(response.text)
        print(json.dumps(data, indent=2))
        return data
    except Exception as e:
        logging.error("- FAIL parsing MetricReport JSON: %s", e)
        return None


if __name__ == "__main__":
    if args["script_examples"]:
        print_examples()
    elif args.get('get_metric_report_definition') and args.get('ip') and args.get('u') and args.get('p'):
        get_metric_report_definition(args['ip'], args['u'], args['p'], args.get('get_metric_report_definition'))
    elif args.get('get_metric_report') and args.get('ip') and args.get('u') and args.get('p'):
        get_metric_report(args['ip'], args['u'], args['p'], args.get('get_metric_report'))
    elif args["ip"] and args["u"] and args["p"]:
        telemetry_attributes = get_attributes(args["ip"], args["u"], args["p"])
        if args.get("list"):
            logging.info("- INFO, listing telemetry attribute URIs for %s", args["ip"])
            for uri in telemetry_attributes:
                print(uri)
        else:
            logging.info("- INFO, setting telemetry attribute URIs for %s", args["ip"])
            set_attributes(args["ip"], args["u"], args["p"], telemetry_attributes)
    elif args["f"]:
        try:
            open_csv_file = open(args["f"], encoding='UTF8')
        except:
            logging.error("\n- ERROR, unable to locate file %s" % args["f"])
            sys.exit(0)
        csv_reader = csv.reader(open_csv_file)
        next(csv_reader)
        for line in csv_reader:
            logging.info("\n- %s Telemetry attributes for iDRAC %s -\n" % (args["s"], line[0]))
            telemetry_attributes = get_attributes(line[0], line[1], line[2])
            if args.get("list"):
                for uri in telemetry_attributes:
                    print(uri)
            else:
                set_attributes(line[0], line[1], line[2], telemetry_attributes)
    else:
        logging.warning("- WARNING, missing or incorrect arguments passed in for executing script")