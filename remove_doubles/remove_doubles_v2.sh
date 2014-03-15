#!/bin/bash
recursive_md5sum()
{
#	find -type f -exec md5sum \{\} \;
	find -type f -exec ~/bin/sh/short_md5sum.sh \{\} \;
}

print_match()	# stdin:cksums arg:file to search
{
	while read cksum; do
		fgrep $cksum $1
	done
}

space_diff_cksum()
{
	old_cksum=
	# rest is filename
	while read cur_cksum rest; do
		if [ "$old_cksum" != $cur_cksum ]; then
			echo
		fi
		
		size=$(wc -c "$rest" | cut -d ' ' -f 1)
		# if size not number
		# replace all - (dashes) with &
		# this is an awesome kludge!!
		echo $cur_cksum $size $rest

		old_cksum=$cur_cksum		
	done
}

full_list=`mktemp /tmp/tmpXXX.full_list`
double_md5sum_list=`mktemp /tmp/tmpXXX.double_md5sum_list`

# create list of all filenames and md5 check sums
recursive_md5sum > $full_list
# create list of all doubled md5sums
cut -d ' ' -f 1 $full_list | sort | uniq --repeated > $double_md5sum_list

#cat $full_list
thisisit=thisisit$RANDOM
cat $double_md5sum_list | print_match $full_list | space_diff_cksum | tee ~/${thisisit}.txt
