#!/bin/bash
#
# print internet usage this session and also total usage this month

# WLAN
if [ -e /sys/class/net/wlan0/statistics/rx_bytes ]; then
    wlan_usage=$(echo "scale=1; `cat /sys/class/net/wlan0/statistics/rx_bytes`/1000000" | bc)
    echo "Internet usage this session (WLAN) = ${wlan_usage} MB"
    wlan_total=`cat /home/varun/.total_wlan_usage`
    wlan_total=`echo "scale=1; ${wlan_total}+${wlan_usage}" | bc`
    echo "Total internet usage        (WLAN) = ${wlan_total} MB"
fi

# ETH
if [ -e /sys/class/net/eth0/statistics/rx_bytes ]; then
    eth_usage=$(echo "scale=1; `cat /sys/class/net/eth0/statistics/rx_bytes`/1000000" | bc)
    echo "Internet usage this session (ETH)  = ${eth_usage} MB"
    eth_total=`cat /home/varun/.total_eth_usage`
    eth_total=`echo "scale=1; ${eth_total}+${eth_usage}" | bc`
    echo "Total internet usage        (ETH)  = ${eth_total} MB"
fi

# PPP
if [ -e /sys/class/net/ppp0/statistics/rx_bytes ]; then
    ppp_usage=$(echo "scale=1; `cat /sys/class/net/ppp0/statistics/rx_bytes`/1000000" | bc)
    echo "Internet usage this session (PPP)  = ${ppp_usage} MB"
    ppp_total=`cat /home/varun/.total_ppp_usage`
    ppp_total=`echo "scale=1; ${ppp_total}+${ppp_usage}" | bc`
    echo "Total internet usage        (PPP)  = ${ppp_total} MB"
fi
