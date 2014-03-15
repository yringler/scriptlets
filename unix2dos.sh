#!/bin/bash
# by Yehuda Ringler 
# arg: file to output correct
# arg2: -i to convert inplace

readonly lines=$(wc -l $1 | cut -d ' ' -f 1)
# kludge: the rest of the script expects a path name, not raw
readonly file=$(readlink -f $1)
# caution: ends without a /. eg /home/user 
in_folder=$(echo $file | sed -e "s/\(.*\)\/[^/]*/\1/" )
full_name="$file"
clean_name=${full_name/*\/}

for (( line=1; line <= lines; line++)); do
	line_text="$(sed -n -e ${line}p $1)"

	echo -e "$line_text\r" >> "$in_folder"/win_"$clean_name"
	if [ "$2" == "-i" ]; then
		mv "$in_folder"/win_"$clean_name" $full_name
	fi
done
