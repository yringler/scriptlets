#!/bin/bash

function get_dat	# args: string to extract from, string proceding nums to get
{	
	# sed not makpid on case
	echo $1 | sed -n -e "s/.*$2\([0-9]*\).*/\1/ip"
}

for i in *.mp3; do
	tape=$(get_dat "$i" Tape)
	side=$(get_dat "$i" Side)
	ch=$(get_dat "$i" Ch)
	part=$(get_dat "$i" Part)

	if [ "$part" ]; then
		name="$ch-part$part"
	elif [ "$tape" ]; then
		name="${ch}-tape${tape},side${side}"
	else
		name=0\ intro
	fi

	#echo $i  "###"  $name
	mv "$i" "$name".mp3
done
