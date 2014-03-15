#!/bin/bash
# usage: if=... of=...
# (all passed as-is to dd)

readonly log=/root/dd_log
readonly bak=/root/dd_log.bak

cp $log /root/safe_log_just_in_case 2>-

if ! [ -e $log ]; then echo 0 > $log; fi

function save_state # arg: pid of dd. input: num bytes to save.
{
	# otherwise the kill doesn't work. I don't know why.
	sleep 20
	while kill -s USR1 $1; do
		read line	# I wish I had a do-while loop...
		
		# skip to dd output that says how many bytes were processed
		while ! echo $line | grep -q bytes; do
			read line
		done

		# paranoid protection for catastrophic failure
		cp -f $log $bak
		# only the first space-seperated field of dd out is byte count
		echo $line | cut -d ' ' -f 1 > $log
		
		sleep 20
	done	
}

start=`cat $log`
coproc dd $* iflag=skip_bytes oflag=seek_bytes seek=$start skip=$start 2>&1
#echo dd $* iflag=skip_bytes oflag=seek_bytes seek=$start skip=$start 2>&1
save_state $COPROC_PID $start <&${COPROC[0]}

