#!/bin/bash
# if a rootkit makes windows files hidden, this can be used
# it moves all folder contents into a tmp dir, deletes original, and moves them back
# it moves all files into tmp folder, copies them back, and deletes original.
# kind of dangerous, but I think it works

repair_dir=asdfajksdf4JKL
if ! [ -e $repair_dir ]; then
	mkdir $repair_dir
fi

for i in *; do
	if [ -d "$i" ]; then
		if [ "$i" == $repair_dir ]; then continue; fi

		mv "$i"/* $repair_dir
		rmdir "$i"

		mkdir "$i"
		mv $repair_dir/* "$i"
	else
		mv "$i" $repair_dir
		cp $repair_dir/"$i" .
		rm $repair_dir/"$i"
	fi
done

rmdir $repair_dir
