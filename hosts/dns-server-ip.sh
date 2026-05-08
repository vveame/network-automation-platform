#!/bin/sh

set -e

ip addr flush dev eth0
ip addr add 172.16.50.20/24 dev eth0
ip route replace default via 172.16.50.1

ip addr
ip route