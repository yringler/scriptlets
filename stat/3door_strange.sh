#!/bin/bash
# by Yehuda Ringler
# weird idea. This is with 3, but one is opened to begin with.
# arg: num runs

readonly RUNS=${1-1000}
readonly all="1 2 3"
success=

for (( run=1; run < RUNS; run++ )); do
	behind=$(( RANDOM % 3 + 1 ))

	show_pos=${all/$behind}
	# show is now list of two
	# switch to one randomly
	field=$(( RANDOM % 2 + 1 ))
	show_act=$( echo $show_pos | cut -d ' ' -f $field )
	
	pick_pos=${all/$show_act}
	field=$(( RANDOM % 2 + 1 ))
	pick_act=$( echo $pick_pos | cut -d ' ' -f $field )
	
	if [ $pick_act == $behind ]; then
		let success++
	fi
done

percent_success=$( echo "scale=5; ${success}/${run}" | bc )
echo success:$success runs:$run percent-success:$percent_success
