#!/bin/sh
# $Id: fraxshape.sh,v 1.1 2010-11-04 10:56:58 frax Exp $

EXT_IFACE="eth0"
INT_IFACE="eth1"
TC="tc"
UNITS="kbit"
LINE="600" #maximum ext link speed
LIMIT="500" #maximum that we’ll allow

${TC} qdisc del dev ${EXT_IFACE} root
${TC} qdisc add dev ${EXT_IFACE} root handle 1:0 htb
${TC} class add dev ${EXT_IFACE} parent 1:0 classid 1:1 htb rate ${LIMIT}${UNITS} ceil ${LIMIT}${UNITS}