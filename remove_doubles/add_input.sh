#!/bin/bash
# adds newline seperated input together, prints total
# can be used with cut on remove_doubles output to get total bytes doubled

total=0

while read num; do
	if [  "$num" ]; then
		let total+=num
	fi
done

echo $total
