#!/bin/sh
my_mount() 
{
	sleep 2
#mount --move old new
#mount --bind old new (or rbind)
	mnt_dev=`blkid | grep Passport | cut -d : -f 1`
#	fuser --kill /dev/sdc1
#	umount $mnt_dev 2> /tmp/umount_err
	mount -t auto $mnt_dev /mnt/my_passport 2>&1
}

my_mount &
echo >> /tmp/passport_log.txt
echo $1 >> /tmp/passport_log.txt
