let LineTranslator = { "source" : [] , "trans" : [] } 
let LineTranslator.upto = 0

" Individual translation units
" stored in list LineTranslator.trans
" div must match \(start\|end\)\(phrase\|par\)
let Trans = { "source": "", "trans": "", "div": "", "comment": "" }

function! LineTranslator.add() dict
	call add(self.trans, deepcopy(g:Trans))
endfunction

function! LineTranslator.setTrans(trans) dict
	let self.trans[-1].trans = a:trans
endfunction

function! LineTranslator.setSource(num) dict
	let source = join(self.source[self.upto : self.upto + a:num-1])
	let self.trans[-1].source = source
	let self.upto += a:num
endfunction

" arg [start/end][phrase/par]
" skips add if logical, based on last
function! LineTranslator.setDiv(div) dict
	if a:div !~ '\(start\|end\)\(par\|phrase\)'
		echo ERROR
		finish
	endif

	if len(self.trans)  > 1
		if a:div == 'startphrase' && self.trans[-2].div =~ "end"
			return
		elseif a:div == 'startpar' && self.trans[-2].div == "endpar"
			return
		endif
	endif

	let self.trans[-1].div = a:div
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

		if i.div =~ "start"
			let idx = -2	" back up over trans and source
		elseif i.div =~ "end"
			let idx = len(list)
		endif

		if i.div =~ "phrase"
			call extend(list, [""], idx)
		elseif i.div =~ "par"
			call extend(list, ["",""], idx)
		endif
	endfor

	return list + ["endmine"]
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

" upto is number of words that have been translated
" numTrans is number of *translations* which could be a smaller number
" because a translation unit (or a Trans) could translate more than one word
" at at time
function! LineTranslator.numTrans() dict
	return len(self.trans)
endfunction

"adds current source word to latest translated source
function! LineTranslator.sourceAppend() dict
	let self.trans[-1].source .= ' ' . self.source[self.upto]
	let self.upto += 1
endfunction

" erases the most recent translation added
function! LineTranslator.eraseLast() dict
	let num_words_back = len(split(self.trans[-1].source))
	call remove(self.trans, -1)
	let self.upto -= num_words_back
endfunction

"" set <back> from end not to be end of anything. 1 is 1st at end, 2 2nd etc
" I decided to simplify. If I feel this functionality is needed I'll put it
" back
function! LineTranslator.noDiv() dict
	"if a:back < 1
	"	echo ERROR!!!
	"	finish
	"endif

	let self.trans[-1].div = ""
endfunction


function! LineTranslator.command(cmd) dict
	if a:cmd == 'a'		" append
		call self.sourceAppend()
	elseif a:cmd == 'b'	" backspace
		call self.eraseLast()
	elseif a:cmd == 'c'	" clear
		call self.noDiv()
	elseif a:cmd == 'f'	" frase
		call self.setDiv("endphrase")
	elseif a:cmd == 'p'	" paragraph
		call self.setDiv("endpar")
	else 
		echo ERROR
		finish
	endif
endfunction

function! TranslateLine()
	let lineTrans = deepcopy(g:LineTranslator)
	let lineTrans.source = split(getline("."))

	" list preferable to avoid space combining stuff
	let trans = []

	" keep requesting further input untill the whole line is translated
	" todo: add stop-here command
	
	while lineTrans.upto < len(lineTrans.source)
		let input = split(input(lineTrans.genPrompt()))
		" process a command
		if len(input) == 1
			call lineTrans.command(input[0])
			continue
		endif

		" process one line of translation input
		for i in range(len(input))
			let word = input[i]

			if word !~ '\D'
				call lineTrans.add()
				call lineTrans.setSource(word)
				continue
			endif

			if word == '/' || word == '//'
				let div = word == '/' ? "phrase" : "par"

				if input[i-1] !~ '\D'
					call lineTrans.setDiv("start" . div)
				elseif i+1 == len(input) || input[i+1] !~ '\D'
					call lineTrans.setDiv("end" . div)
				else
					echo ERROR
					finish
				endif
			else
				call add(trans, word)
			endif

			if word =~ '\\\d' || word =~ '\/'
			       let word = substitute(word, '\\', '', '')
			endif
		
			if i+1 == len(input)  || input[i+1] !~ '\D'
				call lineTrans.setTrans(join(trans))
				let trans = []
			endif
		endfor
	endwhile

	" clear line on but don't clear following lines
	let output = lineTrans.join()
	call setline(line("."), output[0])
	call append(line("."), output[1:])
endfunction
