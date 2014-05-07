so translate.vim

function! Format()
	let translate = deepcopy(g:Translate)
	if getline(".") != 'startmine'
		throw "ERROR:Format:onbadline"
	endif
	
	call translate.read()
	echo "yay!"
	sleep 2
	call ReplaceAppend(translate.styleSplit({"atom":[""]}, {}))
endfunction
