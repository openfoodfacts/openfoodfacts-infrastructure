#!/usr/bin/python3
"""
track_connections_in_mongodb_log.py logfile

This script analyzes MongoDB logs to track the opening and closing of connections by client IP address.

Usage:
    track_connections_in_mongodb_log.py [options]

Options:
    -h --help           Show this text.
    --log <mongodb log> MongoDB log to analyze

Sample log format:

{"t":{"$date":"2023-10-14T06:25:33.423+02:00"},"s":"I",  "c":"NETWORK",  "id":22943,   "ctx":"listener","msg":"Connection acc
epted","attr":{"remote":"10.0.0.1:33898","connectionId":20610563,"connectionCount":222}}
{"t":{"$date":"2023-10-14T06:25:33.424+02:00"},"s":"I",  "c":"NETWORK",  "id":51800,   "ctx":"conn20610563","msg":"client met
adata","attr":{"remote":"10.0.0.1:33898","client":"conn20610563","doc":{"driver":{"name":"MongoDB Perl Driver","version":"2.2
.0"},"os":{"type":"linux"},"platform":"Perl v5.24.1 x86_64-linux-gnu-thread-multi"}}}
{"t":{"$date":"2023-10-14T06:25:33.427+02:00"},"s":"I",  "c":"NETWORK",  "id":22944,   "ctx":"conn20610556","msg":"Connection
 ended","attr":{"remote":"10.0.0.1:33416","connectionId":20610556,"connectionCount":221}}

"""

import json
import re
from docopt import docopt

def convert_log_line(logfile):
    log = open(logfile, 'r') 

    # associative array to keep track of connections
    connections = {}
    # connections by remote address
    connectionsByIp = {}

    for line in log.readlines():
        try:
            obj = json.loads(line)
        except Exception:
            continue
        c = obj["c"]
        dt = obj['t']['$date']
        dt = re.sub('(\+\d\d):(\d\d)$',r'\1\2', dt)

        if c == 'NETWORK' and 'msg' in obj and 'attr' in obj and 'remote' in obj['attr'] and 'connectionId' in obj['attr']:
            remote = obj['attr']
            # 'remote': '10.0.0.1:33784'
            ip = remote['remote'].split(':')[0]
            msg = obj['msg']
            connectionId = obj['attr']['connectionId']
            print("msg: {} {} {}".format(msg, remote, connectionId))
            if msg == 'Connection accepted':
                connections[connectionId] = ip
                connectionsByIp[ip] = connectionsByIp.get(ip, 0) + 1
            elif msg == 'Connection ended':
                # Skip connections that were not accepted (e.g. from before the log file starts)
                if connectionId in connections:
                    remote = connections[connectionId]
                    connectionsByIp[ip] = connectionsByIp.get(ip, 0) - 1
                    del connections[connectionId]

            # Print the current number of active connections for each ip address
            for ip, count in connectionsByIp.items():
                print("IP address: {}, Active connections: {}".format(ip, count))

def main():
    opts = docopt(__doc__)
    logfile = opts['--log']
    convert_log_line(logfile)

if __name__ == '__main__':
    main()
