#!/bin/bash
# By yehuda Ringler
# arg: number of time to run the simulation
#	default is 100

readonly RUNS=${1-100}
readonly all="1 2 3"
stay_success=
switch_success=

for (( run=1; run < RUNS; run++ )); do
	behind=$(( RANDOM % 3 + 1 ))
	pick_1=$(( RANDOM % 3 + 1 ))

	show=${all/$behind}		# won't show the right one
	show=${show/$pick_1}	# won't show picked one

	if [ $pick_1 == $behind ]; then
		# IF 		picked the right one at first
		# THEN 		only 1 of 3 was excluded above
		# THEREFOR 	show a random of the two possible
		field=$(( RANDOM % 2 + 1 ))
		show=$( echo $show | cut -d ' ' -f $field )
	fi

	if [ $pick_1 == $behind ]; then
		let stay_success++
	else 
		let switch_success++
	fi

done

echo success: stay:$stay_success switch:$switch_success total:$run
