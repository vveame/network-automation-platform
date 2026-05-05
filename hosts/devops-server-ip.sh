#!/bin/sh

ip addr flush dev eth0
ip addr add 192.168.99.10/24 dev eth0
ip route replace default via 192.168.99.1

ip addr
ip route