#!/bin/bash

function get_dat	# args: string to extract from, string proceding nums to get
{	
	# sed not makpid on case
	echo $1 | sed -n -e "s/.*$2\([0-9]*\).*/\1/ip"
}

track=1
for i in $(ls *mp3 | sort -n); do
	tape=$(get_dat "$i" Tape)
	side=$(get_dat "$i" Side)
	ch=$(echo $i | cut -d \- -f 1 )
	part=$(get_dat "$i" Part)

	if [ "$part" ]; then
		name="$ch-$part"
	elif [ "$tape" ]; then
		name="$ch($tape,$side)"
	else
		name=000\ intro
	fi

	id3v2 --song "$name" --artist "Rabbi Markel" --track $track --album "Advanced Shaar Hayichud" "$i"
	let track++
done
