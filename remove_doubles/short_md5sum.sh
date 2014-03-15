#!/bin/bash
#short md5sum
#arg: file to check
#sed prat-trying to find / not in filename/path
#sed klall-reads stdin, filename is -, replace with actual filename
dd if="$1" bs=1M count=1 2>- | md5sum | sed -e s^\\-^"$1"^ 
#dd if="$1" bs=1M count=1 2>- | md5sum | sed -e s^[0-9a-f]* *-^"$1"^ 
