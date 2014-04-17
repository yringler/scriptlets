let LineTranslator = { "source":[], "trans":[]} 
let LineTranslator = { "upto": 0}

" Individual translation units
" stored in list LineTranslator.trans
let Trans = { "source": "", "trans": "", "comment": "" }
let Trans = { "end_phrase":0, "end_par":0 }

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
	let string = "mine\n"
	
	for i in self.trans
		let string .= i.source . "\n"
		" even if trans == "" - parsing expects every *other* line to
		" be source
		let string .= i.trans . "\n"

		if i.end_phrase
			let string .= "\n"
		elseif i.end_par 
			let string .= "\n\n"
		endif

	endfor

	return string . "endmine\n"
endfunction

" add translation. num is number of words being translated. 
function! LineTranslator.trans(num, trans) dict
	" this is awsome! *four* trans variables in diffrent scope!
	let trans = deepcopy(g:Trans)
	let trans.trans = a:trans
	" subtract 1 - eg upto=0,num=2: [0 : 0+2-1] gets two: upto and after
	let trans.source = join(self.source[self.upto : self.upto+a:num-1])

	add(self.trans, deepcopy(trans))
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
	let line1 = FlipString(join(self.source[hist_start : self.upto-1]))
	let line2 = FlipString(join(self.source[self.upto : self.upto+9]))
	let line3 = FlipString(join(self.source[self.upto+10 : self.upto+20]))
	let line4 = "\n" . line2 . ": "
	
	if self.upto > 0
		let prompt = join([line1,line2,line3,line4], "\n")
	else
		let prompt = join([line2,line3,line4], "\n")
	endif

	return prompt
endfunction

" this function is embaressingly long, but very straight-forward, and
" hopefully it will shrink soon enough
function! TranslateLine()
	let lineTranslator = deepcopy(LineTranslator)
	let lineTranslator.src = split(getline("."))

	" first get number of words this section will translate
	" if get new number and num_trans is not 0, this means that the phrase
	" wasn't tranlated, and an empty trans is added with that number
	let num_trans = 0
	let trans = ""
	let end_phrase = 0
	let end_par = 0

	" keep requesting further input untill the whole line is translated
	" todo: add stop-here command
	while lineTranslator.upto < len(lineTranslator.src)
		let input = split(input(lineTranslator.genPrompt()))
		" process a command
		if len(input) == 1
			word = input[0]
			if word == 'a'		" append
				lineTranslator.sourceAppend()
			elseif word == 'b'	" backspace
				lineTranslator.eraseLast()
			elseif word == 'c'	" clear
				lineTranslator.noEnd()
			elseif word == 'f'	" frase
				lineTranslator.end("phrase")
			elseif word == 'p'	" paragraph
				lineTranslator.end("par")
			else 
				echo ERROR
				finish
			endif
			continue
		endif

		" process one line of translation input
		for i in range(len(input))
			if input[i] !~ '\D'
				if num_trans != 0
					lineTranslator.trans(num_trans,"")
				endif
				let num_trans = input[i]
			endif
			" if / or // before digit or end of current
			" translation input, set current translation unit as
			" end of phrase. But method edits last added so set
			" flag to set when trans is added.
			if i+1 == len(input)  || input[i+1] !~ '\D'
				if input[i] == '/'
					let end_phrase = 1
				elseif input[i] == '//'
					let end_par = 1
				endif
			" if right after digit set as beggining of phrase
			" this is done by saying that the last translation
			" unit was the end
			elseif i != 0 && input[i-1] !~ '\D'
				if input[i] == '/'
					lineTranslator.end("phrase")
				elseif input[i] == '//'
					lineTranslator.end("par")
				endif
			endif
			if word =~ '\\\d' || word =~ '\/'
				       let word = substitute(word, '\\', '', '')
			endif
			
			let trans .= word
		endfor
		
		if num_trans < 1
			echo ERROR
			finish
		endif

		lineTranslator.trans(num_trans,trans)
		trans = ""
		
		if end_phrase
			lineTranslator.end("phrase")
			let end_phrase = 0
		elseif end_par
			lineTranslator.end("par")
			let end_par = 0
		endif
	endwhile

	setline(line("."), lineTranslator.join())
endfunction
