# manage_telemetry_reports.py Python script using Redfish API to enable or disable iDRAC Telemetry and
# MetricReportDefinitions, list MetricReportDefinition URIs, and retrieve individual MetricReportDefinitions
# or MetricReports.
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

parser = argparse.ArgumentParser(description="Python script using Redfish to enable/disable iDRAC Telemetry and MetricReportDefinitions, list MetricReportDefinition URIs, or retrieve a single MetricReportDefinition/MetricReport. Configure one iDRAC using script arguments or multiple iDRACs using a CSV file.")
parser.add_argument('--script-examples', action="store_true", help='Prints script examples')
parser.add_argument('-ip', help='iDRAC IP address, argument only required if configuring one iDRAC', required=False)
parser.add_argument('-u', help='iDRAC username, argument only required if configuring one iDRAC', required=False)
parser.add_argument('-p', help='iDRAC password, argument only required if configuring one iDRAC', required=False)
parser.add_argument('-s', help='Pass in the report status to be set. Possible values are Enabled/Disabled', default='Enabled', required=False)
parser.add_argument('-f', help='Pass in csv file name. If file is not located in same directory as script, pass in the full directory path with file name. NOTE: Make sure to use iDRACs.csv file from the repo which has the correct format.', required=False)
parser.add_argument('-d', '--get-metric-report-definition', dest='get_metric_report_definition', help='Get a single MetricReportDefinition by name (e.g. MemorySensor), or "all" to list every MetricReportDefinition name', required=False)
parser.add_argument('-r', '--get-metric-report', dest='get_metric_report', help='Get a single MetricReport by name (e.g. MemorySensor), or "all" to list every MetricReport name', required=False)
parser.add_argument('-m', '--metric-report', dest='metric_report', help='Comma-separated MetricReportDefinition name(s) to operate on (e.g. MemorySensor,CPUSensor), or "all" to operate on every MetricReportDefinition. If omitted, all MetricReportDefinitions are updated', required=False)

args = vars(parser.parse_args())

def print_examples():
    """
    Print program examples and exit
    """
    print(
        '\n\'manage_telemetry_reports.py -ip 192.168.0.120 -u root -p calvin -s Enabled, this example will enable Telemetry and all MetricReportDefinitions for a single iDRAC\n'
        '\n\'manage_telemetry_reports.py -ip 192.168.0.120 -u root -p calvin -s Disabled, this example will disable Telemetry and all MetricReportDefinitions for a single iDRAC\n'
        '\n\'manage_telemetry_reports.py -ip 192.168.0.120 -u root -p calvin -s Enabled --metric-report MemorySensor,CPUSensor, this example will enable Telemetry and only the MemorySensor and CPUSensor MetricReportDefinitions for a single iDRAC\n'
        '\n\'manage_telemetry_reports.py -ip 192.168.0.120 -u root -p calvin -s Disabled --metric-report all, this example will disable Telemetry and every MetricReportDefinition for a single iDRAC\n'
        '\n\'manage_telemetry_reports.py -ip 192.168.0.120 -u root -p calvin --get-metric-report-definition MemorySensor, this example will print the MemorySensor MetricReportDefinition JSON for a single iDRAC\n'
        '\n\'manage_telemetry_reports.py -ip 192.168.0.120 -u root -p calvin --get-metric-report-definition all, this example will list all MetricReportDefinition names for a single iDRAC\n'
        '\n\'manage_telemetry_reports.py -ip 192.168.0.120 -u root -p calvin --get-metric-report MemorySensor, this example will print the MemorySensor MetricReport JSON for a single iDRAC\n'
        '\n\'manage_telemetry_reports.py -ip 192.168.0.120 -u root -p calvin --get-metric-report all, this example will list all MetricReport names for a single iDRAC\n'
        '\n\'manage_telemetry_reports.py -f C:\\Python39\\iDRACs.csv -s Enabled, this example will enable Telemetry and all MetricReportDefinitions for all iDRACs in the CSV file\n'
        '\n\'manage_telemetry_reports.py -f C:\\Python39\\iDRACs.csv -s Disabled, this example will disable Telemetry and all MetricReportDefinitions for all iDRACs in the CSV file\n')

def get_attributes(ip, user, pwd):
    """Retrieve the MetricReportDefinition URIs from the TelemetryService.
    Returns:
        list: MetricReportDefinition URIs (strings)
    """
    # Use redfish API instead of AR
    url = 'https://{}/redfish/v1/TelemetryService/MetricReportDefinitions'.format(ip)
    headers = {'content-type': 'application/json'}
    response = requests.get(url, headers=headers, verify=False, auth=(user, pwd), timeout=REQUEST_TIMEOUT)
    if response.status_code != 200:
        logging.error("- FAIL, status code for reading MetricReportDefinitions is not 200, code is: {}".format(response.status_code))
        sys.exit()
    try:
        logging.info("- INFO, successfully pulled MetricReportDefinition URIs")
        configurations_dict = json.loads(response.text)
        attributes = configurations_dict.get('Members', [])
        telemetry_attributes = [m['@odata.id'] for m in attributes]
        #logging.debug(telemetry_attributes)
        return telemetry_attributes
    except Exception as e:
        logging.error("- FAIL: detailed error message: {0}".format(e))
        sys.exit()


def set_service_enabled(ip, user, pwd, enabled):
    """Enable or disable the global TelemetryService.

    Args:
        enabled (bool): True to enable the service, False to disable it
    """
    headers = {'content-type': 'application/json'}
    url = 'https://{}/redfish/v1/TelemetryService'.format(ip)
    response = requests.patch(url, data=json.dumps({"ServiceEnabled": enabled}), headers=headers,
                              verify=False, auth=(user, pwd), timeout=REQUEST_TIMEOUT)
    if response.status_code != 200:
        logging.error("- FAIL, status code for {} TelemetryService is not 200, code is: {}".format(
            'enabling' if enabled else 'disabling', response.status_code))
        logging.debug(str(response))
        sys.exit()
    logging.info("- INFO, successfully set TelemetryService ServiceEnabled to %s", enabled)


def select_metric_report_definitions(telemetry_attributes):
    """Filter MetricReportDefinition URIs based on the --metric-report argument.

    Args:
        telemetry_attributes (list): All MetricReportDefinition URIs for the iDRAC

    Returns:
        list: URIs to operate on. 'all' or omitting the argument returns every URI.
    """
    metric_arg = args.get('metric_report')
    if not metric_arg:
        return telemetry_attributes
    wanted = set([x.strip().lower() for x in metric_arg.split(',') if x.strip()])
    if 'all' in wanted:
        logging.info("- INFO, 'all' specified, operating on all %d MetricReportDefinition(s)", len(telemetry_attributes))
        return telemetry_attributes
    filtered = [uri for uri in telemetry_attributes if uri.rstrip('/').split('/')[-1].lower() in wanted]
    if not filtered:
        logging.error("- INFO, no matching MetricReportDefinitions found for %s, skipping", metric_arg)
    return filtered


def set_attributes(ip, user, pwd, telemetry_attributes, toggle_service=True):
    """Uses the Redfish API to set MetricReportDefinitionEnabled to the user defined status.

    Args:
        telemetry_attributes (list): A list containing the MetricReportDefinition URIs to update
        toggle_service (bool): When True, enable/disable the global TelemetryService around the
            MetricReportDefinition updates. Set to False when the caller manages the service itself.
    """

    status_to_set = args["s"]
    if status_to_set not in ['Enabled', 'Disabled']:
        logging.error("Invalid value for report status. Supported values are Enabled & Disabled")
        sys.exit()
    if not telemetry_attributes:
        logging.error("- INFO, no MetricReportDefinitions to update for %s, skipping", ip)
        return
    headers = {'content-type': 'application/json'}
    
    # Enable the global TelemetryService
    if toggle_service and status_to_set == 'Enabled':
        set_service_enabled(ip, user, pwd, True)

    # Go to each MetricReportDefinition and enable or disable based on input
    for uri in telemetry_attributes:
        url = 'https://{}{}'.format(ip,uri)
        response = requests.patch(url, data=json.dumps({"MetricReportDefinitionEnabled": status_to_set=='Enabled'}), headers=headers,
                              verify=False, auth=(user, pwd), timeout=REQUEST_TIMEOUT)

        if response.status_code != 200:
            logging.error("- FAIL, status code for setting MetricReportDefinitionEnabled is not 200, code is: {}".format(response.status_code))
            logging.debug(str(response))
            sys.exit()
        else:
            logging.info("- INFO, successfully set MetricReportDefinitionEnabled to {} for {}".format(status_to_set, uri))

    # Disable the global TelemetryService
    if toggle_service and status_to_set == 'Disabled':
        set_service_enabled(ip, user, pwd, False)
    
    if toggle_service:
        logging.info("- INFO, successfully '{}' iDRAC Telemetry and {} MetricReportDefinition(s)".format(status_to_set, len(telemetry_attributes)))


def set_all_attributes(ip, user, pwd, telemetry_attributes):
    """Call set_attributes for each MetricReportDefinition individually.

    The global TelemetryService is toggled once around the whole loop rather than
    once per MetricReportDefinition.

    Args:
        telemetry_attributes (list): All MetricReportDefinition URIs for the iDRAC
    """
    status_to_set = args["s"]
    if status_to_set not in ['Enabled', 'Disabled']:
        logging.error("Invalid value for report status. Supported values are Enabled & Disabled")
        sys.exit()
    if not telemetry_attributes:
        logging.error("- INFO, no MetricReportDefinitions found for %s, skipping", ip)
        return
    if status_to_set == 'Enabled':
        set_service_enabled(ip, user, pwd, True)
    for uri in telemetry_attributes:
        set_attributes(ip, user, pwd, [uri], toggle_service=False)
    if status_to_set == 'Disabled':
        set_service_enabled(ip, user, pwd, False)
    logging.info("- INFO, successfully '{}' iDRAC Telemetry and {} MetricReportDefinition(s)".format(status_to_set, len(telemetry_attributes)))


def apply_status(ip, user, pwd, telemetry_attributes):
    """Apply the requested status to the MetricReportDefinitions selected by --metric-report.

    Args:
        telemetry_attributes (list): All MetricReportDefinition URIs for the iDRAC
    """
    selected = select_metric_report_definitions(telemetry_attributes)
    if not selected:
        return
    metric_arg = args.get('metric_report')
    if metric_arg and 'all' in [x.strip().lower() for x in metric_arg.split(',') if x.strip()]:
        set_all_attributes(ip, user, pwd, selected)
    else:
        set_attributes(ip, user, pwd, selected)


def list_collection_members(ip, user, pwd, collection_uri, label):
    """Retrieve a Redfish collection and print only the last segment of each Members' @odata.id.

    For example, '/redfish/v1/TelemetryService/MetricReports/OME-PMP-SystemUsage'
    is printed as 'OME-PMP-SystemUsage'.

    Args:
        collection_uri (str): Full URL of the collection resource
        label (str): Human readable resource name used in log messages

    Returns:
        list: The collection's Members entries, or None on failure
    """
    headers = {'content-type': 'application/json'}
    try:
        response = requests.get(collection_uri, headers=headers, verify=False, auth=(user, pwd), timeout=REQUEST_TIMEOUT)
    except Exception as e:
        logging.error("- FAIL, error fetching %s: %s", label, e)
        return None
    if response.status_code != 200:
        logging.error("- FAIL, status code for reading %s is %s", label, response.status_code)
        return None
    try:
        data = json.loads(response.text)
        members = data.get('Members', [])
        for member in members:
            odata_id = member.get('@odata.id', '')
            print(odata_id.rstrip('/').split('/')[-1])
        return members
    except Exception as e:
        logging.error("- FAIL parsing %s JSON: %s", label, e)
        return None


def get_metric_report_definition(ip, user, pwd, report_name):
    """Retrieve a single MetricReportDefinition by name and print JSON.

    Passing 'all' retrieves the MetricReportDefinitions collection and lists only
    the name (last segment of @odata.id) of each member.
    """
    if report_name.strip().lower() == 'all':
        return list_collection_members(
            ip, user, pwd,
            'https://{}/redfish/v1/TelemetryService/MetricReportDefinitions'.format(ip),
            'MetricReportDefinitions')
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
    """Retrieve a single MetricReport by name and print JSON.

    Passing 'all' retrieves the MetricReports collection and lists only the
    name (last segment of @odata.id) of each member.
    """
    if report_name.strip().lower() == 'all':
        return list_collection_members(
            ip, user, pwd,
            'https://{}/redfish/v1/TelemetryService/MetricReports'.format(ip),
            'MetricReports')
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
        logging.info("- INFO, setting MetricReportDefinitionEnabled for %s", args["ip"])
        apply_status(args["ip"], args["u"], args["p"], telemetry_attributes)
    elif args["f"]:
        try:
            open_csv_file = open(args["f"], encoding='UTF8')
        except:
            logging.error("\n- ERROR, unable to locate file %s" % args["f"])
            sys.exit(0)
        csv_reader = csv.reader(open_csv_file)
        next(csv_reader)
        for line in csv_reader:
            logging.info("\n- %s Telemetry MetricReportDefinitions for iDRAC %s -\n" % (args["s"], line[0]))
            telemetry_attributes = get_attributes(line[0], line[1], line[2])
            apply_status(line[0], line[1], line[2], telemetry_attributes)
    else:
        logging.warning("- WARNING, missing or incorrect arguments passed in for executing script")