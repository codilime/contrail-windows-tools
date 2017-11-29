#!/usr/bin/python3

import socket
import sys

if len(sys.argv) != 3:
    print("UDP echo server.")
    print("Usage: udp_echo_server <local address> <local port>")
    exit(0)

local_address = sys.argv[1]
local_port = sys.argv[2]
udp_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
udp_socket.bind((local_address, int(local_port)))
print("Running UDP echo server ({0}:{1})...".format(local_address, local_port))

while True:
    rcv_data, remote_address = udp_socket.recvfrom(4096)
    print('Received message "{0}" from {1}. Sending message back...'.format(\
        rcv_data.decode('utf-8'), remote_address))
    udp_socket.sendto(rcv_data, remote_address)


