let LineTranslator = { "source" : [] , "trans" : [] } 
let LineTranslator.upto = 0

" Individual translation units
" stored in list LineTranslator.trans
let Trans = { "source": "", "trans": "", "comment": "" }
let Trans.end_phrase = 0
let Trans.end_par = 0

" upto is number of words that have been translated
" numTrans is number of *translations* which could be a smaller number
" because a translation unit (or a Trans) could translate more than one word
" at at time
function! LineTranslator.numTrans() dict
	return len(self.trans)
endfunction

"adds current source word to latest translated source
function! LineTranslator.sourceAppend() dict
	self.trans[-1].source += self.source[self.upto]
	let self.upto += 1
	" don't clear flags
endfunction

" erases the most recent translation added
function! LineTranslator.eraseLast() dict
	num_words_back = len(split(self.trans[-1].source))
	call remove(self.trans, -1)
	let self.upto -= num_words_back
endfunction

" return string with the whole business - source&trans - properly formatted
function! LineTranslator.join() dict
	" mine means that from here to endmine newlines are in the world of
	" LineTranslator. Used in scripts which smoosh around the translation
	" in list because \n not intrepreted by setline()
	let list = ["mine"]
	
	for i in self.trans
		call add(list, i.source)
		" even if trans == "" - parsing expects every *other* line to
		" be source
		call add(list, i.trans)

		if i.end_phrase
			call add(list, "")
		elseif i.end_par 
			call extend(list, ["",""])
		endif
	endfor

	return list + ["endmine"]
endfunction

" add translation. num is number of words being translated. 
function! LineTranslator.addTrans(num, arg) dict
	" this is awsome! *four* trans variables in diffrent scope!
	let tmp_trans = deepcopy(g:Trans)
	let tmp_trans.trans = a:arg
	" subtract 1 - eg upto=0,num=2: [0 : 0+2-1] gets two: upto and after
	let tmp_trans.source = join(self.source[self.upto : self.upto +a:num-1])

	call add(self.trans, deepcopy(tmp_trans))
	let self.upto += a:num
endfunction

" arg: "phrase" or "par" short for paragraph. Any string containing par will
" match
function! LineTranslator.end(ends) dict
	if a:ends == "phrase"
		let self.trans[-1].end_phrase = 1
		" to allow changing mind
		let self.trans[-1].end_par = 0
	elseif a:ends =~ "par"
		let self.trans[-1].end_par = 1
		let self.trans[-1].end_phrase = 0
	endif
endfunction

"" set <back> from end not to be end of anything. 1 is 1st at end, 2 2nd etc
" I decided to simplify. If I feel this functionality is needed I'll put it
" back
function! LineTranslator.noEnd() dict
	"if a:back < 1
	"	echo ERROR!!!
	"	finish
	"endif

	let self.trans[-1].end_phrase = 0
	let self.trans[-1].end_par = 0
endfunction

" support function for genPrompt. echo <hebrew> is left-to-right...which is
" probably the best option. But it would be nice if a reverse string function
" was supplied
function! FlipString(str)
	let char_list = split(a:str, '\zs')
	call reverse(char_list)

	let tmp = ''
	for i in char_list
		let tmp .= i
	endfor

	return tmp
endfunction

function! LineTranslator.genPrompt() dict
	let hist_start = self.upto < 10? 0: self.upto - 10
	let line1 = FlipString(join(self.source[hist_start : self.upto -1]))
	let line2 = FlipString(join(self.source[self.upto : self.upto +9]))
	let line3 = FlipString(join(self.source[self.upto +10 : self.upto +20]))
	let line4 = "\n" . line2 . ": "
	
	if self.upto > 0
		let prompt = join([line1,line2,line3,line4], "\n")
	else
		let prompt = join([line2,line3,line4], "\n")
	endif

	return prompt
endfunction

function! LineTranslator.command(cmd) dict
	if a:cmd == 'a'		" append
		self.sourceAppend()
	elseif a:cmd == 'b'	" backspace
		self.eraseLast()
	elseif a:cmd == 'c'	" clear
		self.noEnd()
	elseif a:cmd == 'f'	" frase
		self.end("phrase")
	elseif a:cmd == 'p'	" paragraph
		self.end("par")
	else 
		echo ERROR
		finish
	endif
endfunction


" this function is embaressingly long, but very straight-forward, and
" hopefully it will shrink soon enough
" update: this function is a complete mess and needs to shring NOW
function! TranslateLine()
	let lintTrans = deepcopy(g:LineTranslator)
	let lintTrans.source = split(getline("."))

	let num_trans = 0
	let last_was_empty = 0
	" list preferable to avoid space combining stuff
	let trans = []
	let end_phrase = 0
	let end_par = 0

	" keep requesting further input untill the whole line is translated
	" todo: add stop-here command
	
	while lintTrans.upto < len(lintTrans.source)
		let input = split(input(lintTrans.genPrompt()))
		" process a command
		if len(input) == 1
			call lintTrans.command(input[0])
			continue
		endif

		" process one line of translation input
		for i in range(len(input))
			let word = input[i]
			if word !~ '\D'
				" if input has two consequtive numbers
				if last_was_empty
					call lintTrans.addTrans(num_trans,"")
				endif
				let num_trans = word
				" I hate flags
				let last_was_empty = 1
				continue
			endif
			" if / or // before digit or end of current
			" translation input, set current translation unit as
			" end of phrase. But method edits last added so set
			" flag to set when trans is added.
			if word == '/'
				if i+1 == len(input)  || input[i+1] !~ '\D'
					let end_phrase = 1
				elseif input[i-1] !~ '\D'
					call lintTrans.end("phrase")
				endif
			" if right after digit set as beggining of phrase
			" this is done by saying that the last translation
			" unit was the end
			elseif word == '//'
				if i+1 == len(input)  || input[i+1] !~ '\D'
					let end_par = 1
				elseif input[i-1] !~ '\D'
					call lintTrans.end("par")
				endif
			elseif word =~ '\\\d' || word =~ '\/'
				       let word = substitute(word, '\\', '', '')
			endif

			" wow this code is a complete mess
			" needs clean up
			if word != '/' && word != '//'
				call add(trans, word)
			endif
			let last_was_empty = 0
		
			if i+1 == len(input)  || input[i+1] !~ '\D'
				call lintTrans.addTrans(num_trans,join(trans))
				let trans = []
			
				if end_phrase
					call lintTrans.end("phrase")
					let end_phrase = 0
				elseif end_par
					call lintTrans.end("par")
					let end_par = 0
				endif
			endif
		endfor
	endwhile

	call setline(line("."), lintTrans.join())
endfunction
