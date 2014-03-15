#!/bin/bash

a_list="2 3 4 5"
op_list="+ - M /" 
# bug here: had ${var/change_this//}

for a in $a_list; do
	b_list=${a_list/$a/}
	for b in $b_list; do
		c_list=${b_list/$b/}
		for c in $c_list; do
			d=${c_list/$c/}

for X in $op_list; do
	for Y in $op_list; do
		for Z in $op_list; do

prob="$a $X $b $Y $c $Z $d"
prob=${prob//M/*}
answer=$( echo "$prob" | bc )

if [ "$answer" == 28 ]; then
	echo "$prob" 
fi
		
		done
	done
done
		done
	done
done
