so translate.vim

function Format()
	let translate = deepcopy(g:Translate)
	if getline(".") != 'startmine'
		throw "ERROR:Format:onbadline"
	endif
	
	call translate.read()
	call ReplaceAppend(translate.styleSplit({"atom":[""]}, {}))
endfunction
