#!/bin/bash

OUTPUT="/vg_vps/images/backup/conf"
nodes=`cat $OUTPUT/nodes.txt`
services=`cat $OUTPUT/services.txt`
for node in $nodes; do
	mkdir -p $OUTPUT/`date +%Y%m%d`/$node/etc
	for service in $services; do
		if ssh root@$node '[ -d `/etc/$service` ]'; then
			scp -r $node:/etc/$service $OUTPUT/`date +%Y%m%d`/$node/etc
		fi
	done
done
