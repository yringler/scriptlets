#!/bin/bash

function get_dat	# args: string to extract from, string proceding nums to get
{	
	# sed not makpid on case
	echo $1 | sed -n -e "s/.*$2[[:space:]]*\([0-9]*\).*/\1/ip"
}

function get_chap
{
	echo $1 | sed -n -e \
	"s/.*[ch]\+[[:space:]]*\([0-9]\+\)[[:space:]&-]\+\([0-9]\+\).*/\1,\2/ip" \
		-e t -e "s/.*ch[[:space:]]*\([0-9]*\).*/\1/ip"
}

for i in *.mp3; do
	tape=$(get_dat "$i" Tape)
	side=$(get_dat "$i" Side)
	ch=$(get_chap "$i")
	part=$(get_dat "$i" Part)

	if [ "$tape" ]; then
		name="${ch}-tape${tape},side${side}"
	elif [ "$part" ]; then
		name="$ch-part$part"
	else
		name=0\ intro
	fi

	#echo $i  "###"  $name
	mv "$i" "$name".mp3
done
