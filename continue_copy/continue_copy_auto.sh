#!/bin/bash
# SKIPS FIRST 512 BYTES !!!
if ps -a | grep \ dd\$ -q ; then
	echo error `data` >> /root/copy_error
fi 


echo Random Test

readonly log=/root/dd_log
readonly bak=/root/dd_log.bak

if ! [ -e "$log" ]; then echo 512 > $log; fi
cp $log /root/safe_log_just_in_case

# prints to stdout
function get_dev_path # arg: uuid or lable of partition
{
	blkid | grep "$1" | cut -d : -f 1 | sed -e s/[[:digit:]]//
}

# watches for: continue copy, dd prints bytes written...not including old!
function save_state # ARG: 1) pid of dd. 2) number of bytes written so far. INPUT: dd output
{
	
	sleep 20	# otherwise the kill doesn't work. I don't know why.
	while kill -s USR1 $1; do
		read line	# I wish I had a do-while loop...
		
		# skip to dd output that says how many bytes were processed
		while ! echo $line | grep -q bytes; do
			read line
		done

		# paranoid protection for catastrophic failure
		cp -f $log $bak
		# only the first space-seperated field of dd out is byte count
		new_copied=$(echo $line | cut -d ' ' -f 1)
		let "new_copied += $2"	# compensate for ddout=new need total
		echo $new_copied > $log
		
		sleep 20
	done	
}


#start=`cat $log`
#from_path=`get_dev_path C01C72541C724606`
#to_path=`get_dev_path DESTROY`

#if [ ! "$from_path" -o ! "$to_path" -o "$from_path" == "$to_path" ]; then echo ERROR >&2; exit; fi

#coproc dd if=$from_path of=$to_path iflag=skip_bytes oflag=seek_bytes seek=$start skip=$start 2>&1
coproc dd $* iflag=skip_bytes oflag=seek_bytes seek=$start skip=$start 2>&1
save_state $COPROC_PID $start <&${COPROC[0]}

