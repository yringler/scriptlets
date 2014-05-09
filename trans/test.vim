so translate.vim

function! Format()
	let translate = deepcopy(g:Translate)
	if getline(".") != 'startmine'
		throw "ERROR:Format:onbadline"
	endif
	
	call translate.read()
	normal gg dG
	let list = translate.rawSplit()
	call ReplaceAppend(list)
	echo "yay!"

	let list = translate.styleSplit({"atom":[""]}, {}, {})) 
	call ReplaceAppend(list)
endfunction
