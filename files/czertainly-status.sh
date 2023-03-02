#!/bin/bash

declare -a NS=( 'kube-system' 'ingress-nginx' 'cert-manager' 'czertainly' )

kubectl='/var/lib/rancher/rke2/bin/kubectl'

OK=0
for ns in ${NS[@]};
do
    tmpf=`mktemp /tmp/$1-$ns-XXXX`
    cmd="$kubectl get pods -n "$ns" --no-headers=true"
    if output=$(sudo $cmd 2>&1 >$tmpf)
    then
	total_cnt=`cat $tmpf | wc -l`
	running_cnt=`cat $tmpf | tr -s ' ' | cut -f 3 -d ' ' | grep Running | wc -l`
	completed_cnt=`cat $tmpf | tr -s ' ' | cut -f 3 -d ' ' | grep Completed | wc -l`
	done_cnt=$(($running_cnt + $completed_cnt))
	if [ $total_cnt -gt 0 ] && [ $total_cnt -eq $done_cnt ]
	then
	    echo "$ns	$running_cnt PODs OK"
	    OK=$(( $OK+1 ))
	else
	    echo "$ns	only $done_cnt of $total_cnt PODs are fine"
	    cat $tmpf | sed "s/^/  /"
	fi
    else
	echo "Failed to exec $cmd: $output"
    fi
    rm $tmpf
done

if [ $OK -eq ${#NS[@]} ]
then
    fqdn=`hostname -f`
    echo "

Everything is OK, administrative interface is available at:

https://$fqdn/administrator/
"
else
    echo "Some PODs are not running. Enter system shell and examine where is the problem."
fi
