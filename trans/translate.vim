let LineTranslator = { "source" : [] , "trans" : [] } 
let LineTranslator.upto = 0

" Individual translation units
" stored in list LineTranslator.trans
" div must match \(start\|end\)\(phrase\|par\)
let Trans = { "source": "", "trans": "", "div": "", "comment": [] }

function! AppendString(first, second)
	if a:first != ""
		return a:first . " " . a:second
	else
		return a:second
	endif
endfunction

function! LineTranslator.add() dict
	call add(self.trans, deepcopy(g:Trans))
endfunction

function! LineTranslator.setTrans(trans) dict
	let self.trans[-1].trans = a:trans
endfunction

function! LineTranslator.appendTrans(trans) dict
	let self.trans[-1].trans = AppendString(self.trans[-1].trans, a:trans)
endfunction

function! LineTranslator.setSource(num) dict
	let source = join(self.source[self.upto : self.upto + a:num-1])
	let self.trans[-1].source = source
	let self.upto += a:num
endfunction

"adds current source word to latest translated source
function! LineTranslator.appendSource() dict
	let self.trans[-1].source .= ' ' . self.source[self.upto]
	let self.upto += 1
endfunction

function! LineTranslator.addComment() dict
	call add(self.trans[-1].comment, "")
	self.appendTrans("*" . len(self.trans[-1].comment))
endfunction

function! LineTranslator.setComment(comment) dict
	let self.trans[-1].comment[-1] = a:comment
endfunction

function! LineTranslator.appendComment(a:comment) dict
	let new_comment = AppendString(self.trans[-1].comment[-1], a:comment)
	let self.trans[-1].comment[-1] = new_comment
endfunction

" arg [start/end/startend][phrase/par]
function! LineTranslator.setDiv(div) dict
	if a:div !~ '\(start\|end\)\(par\|phrase\)'
		echo ERROR
		finish
	endif
	
	"
	" TODO: if a start, set last as end if isn't already, look for its
	" start
	" if an end, look for start
	"
	" what if one is both?...
	" startend\(par|phrase\) 
	"
	
	let self.trans[-1].div = a:div
endfunction

" return string with the whole business - source&trans - properly formatted
function! LineTranslator.join() dict
	" mine means that from here to endmine newlines are in the world of
	" LineTranslator, used in scripts which smoosh around the translation.
	" In list because \n not intrepreted by setline()
	let list = ["mine"]
	
	for i in self.trans
		call add(list, i.source)
		" even if trans == "" - parsing expects every *other* line to
		" be source
		call add(list, i.trans)
		
		for ib in len(i.comment)
			let list += ["comment " . ib+1 . " " . i.comment[ib]])
		endif

		if i.div =~ "start"
			" back up over trans and source (and comment, if
			" there)
			let idx = -2 - len(i.comment)
		elseif i.div =~ "end"
			let idx = len(list)
		endif

		if i.div =~ 'start\|end'
			call extend(list, [i.div], idx)
		endif

		if i.div =~ 'startend'
			" -1 because idx is for insert *before*
			" to access before directly, subtract 1
			let list.[idx-1] = "start" . i.div
			call add(list, "end" . i.div)
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
		call self.appendSource()
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

" comment : ... trans [ comment ] ...
" assumes that starting after {
function GetComment(input)
	let comment = []
	for i in input
		if i == '}'
			break
		endif
		call add(comment,i)
	endfor
	return comment
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
		let i = 0
		while i < len(input)
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
			elseif word == '{'
				let comment = GetComment(input[i+1] : ])
				LineTranslator.addComment()
				LineTranslator.setComment(comment)
			" + 1 gets to closing } , +1 at end moves to next
				let i += len(comment) + 1
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

			let i += 1
		endwhile
	endwhile

	" clear line on but don't clear following lines
	let output = lineTrans.join()
	call setline(line("."), output[0])
	call append(line("."), output[1:])
endfunction
