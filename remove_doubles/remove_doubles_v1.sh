#!/bin/bash
recursive_md5sum()
{
	find -type f -exec md5sum \{\} \;
}

flip()
{	
	sed -e 's/\([^[:space:]]*\)[[:space:]]*\(.*\)/\2 \1/'
}



recursive_md5sum | sort | flip | uniq --skip-fields=1 --all-repeated
