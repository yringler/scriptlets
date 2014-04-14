#!/bin/bash

function get_dat	# args: string to extract from, string proceding nums to get
{	
	# sed not makpid on case
	echo $1 | sed -n -e "s/.*$2\([0-9]*\).*/\1/ip"
}

track=1
oldchap=
last_part_chap=
oldi=
part=
for i in $(ls *mp3 | sort -n); do
	ch=$(echo $i | cut -d \- -f 1 )

	if [ $ch == "$oldchap" ]; then
		if [ "$last_part_chap" != $ch ]; then
			part=2
			#mp3info -t ${ch}-1 -a "Rabbi Markel" \
			#	-n $(( track - 1 )) \
			#	-l "Advanced Shaar Hayichud" "$oldi"
			id3v2 --song ${ch}-1 --artist "Rabbi Yossi Markel" --track \
			$(( track - 1 )) --album "Advanced Shaar Hayichud" \
			"$oldi"
			last_part_chap=$ch
		fi
	else
		part=
	fi

	if [ "$part" ]; then
		name="$ch-$part"
		let part++
	elif [ "$ch" ]; then
		name="$ch"
	else
		name=000\ intro
	fi

	#mp3info -t "$name" -a "Rabbi Markel" -n $track -l "Advanced Shaar Hayichud" "$i"
	id3v2 --song "$name" --artist "Rabbi Yossi Markel" --track $track --album "Advanced Shaar Hayichud" $i

	oldi="$i"
	oldchap=$ch
	let track++
done
