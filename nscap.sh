#!/bin/bash

function randomGenerator() {
    echo $(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 6 | head -n 1)
}

function setupNs() {
    ip netn add $nsName
    ip link add $veth_1 type veth peer name $veth_2
    ip link set $veth_1 netns $nsName
    ip netns exec $nsName ifconfig $veth_1 up 192.168.163.1 netmask 255.255.255.0
    ifconfig $veth_2 up 192.168.163.254 netmask 255.255.255.0
    ip netns exec $nsName route add default gw 192.168.163.254 dev $veth_1
    echo 1 >/proc/sys/net/ipv4/ip_forward
    iptables -t nat -A POSTROUTING -s 192.168.163.0/24 -o $ifname -j MASQUERADE
}
function runCommand() {
    mkfifo /tmp/nscap
    ip netns exec $nsName bash -c "tcpdump -i $veth_1 -U -w /tmp/nscap 2>/dev/null &"
    if (($with_ws == 1)); then
        wireshark -i /tmp/nscap &
    fi
    ip netns exec $nsName $command &
}
function finish() {
    echo "Triggered"
    pkill tcpdump
    ip link delete $veth_2
    ip netn delete $nsName
    rm /tmp/nscap
    exit
}

trap finish INT QUIT TERM
nsName=ns_$(randomGenerator)
veth_1=veth_$(randomGenerator)
veth_2=veth_$(randomGenerator)
while [ "$veth_1" = "$veth_2" ]; do
    veth_2=veth_$(randomGenerator)
done
with_ws=0
command=""
if [ "$1" = "" ]; then
    echo "Please specify the interface name of outbound if by --ifname \$ifname. Open wireshark can be done by specifying option --with-ws"
fi
while [ "$1" != "" ]; do
    case $1 in
    --ifname)
        shift
        ifname=$1
        ;;
    --with-ws)
        with_ws=1
        ;;
    *) command+=" $1" ;;
    esac
    shift
done

if [ "$command" != "" ]; then
    setupNs
    runCommand
    while [ true ]; do
        read input
        if [ "$input" -eq "q" ]; then
            finish
        fi
    done
fi
