function! FlipWideString(str)
	let char_list = split(a:str, '\zs')
	call reverse(char_list)

	for i in range(len(char_list))
		" ugly ugly kludge because of brain dead vimscript rules. Why
		" can't I append to an empty string???? stupid stupid stupid
		if i != 0
			let tmp = tmp . char_list[i]
		else
			let tmp = char_list[i]
		endif
	endfor
	
	return tmp
endfunction

" three lines in prompt
function! GenPrompt(source, upto)
	let hist_start = a:upto < 10? 0: a:upto - 10
	let line1 = FlipWideString(join(a:source[hist_start : a:upto-1]))
	let line2 = FlipWideString(join(a:source[a:upto : a:upto+7]))
	let line3 = FlipWideString(join(a:source[a:upto+8 : a:upto+18])) 
	let line4 = "\n" . line2 . ": "
	
	if a:upto != 0
		let prompt = join([line1,line2,line3,line4], "\n")
	else
		let prompt = join([line2,line3,line4], "\n")
	endif

	return prompt
endfunction

" opens dialog to assist translation of line where cursor is at
function! Translate_line()
	normal ^	" the rest position of cursor is start of first word
			" to be tranlated
	let source = split(getline("."))
	" number of words in this line translated so far
	let num_done = 0
	" more scary flags
	let start_phrase = 0
	let start_par = 0

	" as long as all the words haven't been translated
	while num_done < len(source)
		" bite sized portion of source text to work on
		let prompt = FlipWideString(join(source[num_done : num_done+5])) . ": "
		let trans = split(input(prompt))
		" this is a scary flag. I don't like flags.
		" it is set to true if and only if the first word of
		" translation following a digit wasn't processed yet
		let at_new_trans = 1

		" process translation input
		for index in range(len(trans))
			let word = trans[index]

			if word !~ '\D'
				" digit in input means following phrase
				" translates <digit> words of source
				let num_trans_now = word
				let num_done += num_trans_now
				continue
			endif

			" if don't add word to translation string
			if word == '/' || word == '//'
				" / for phrase break , represented by \n and
				" // for paragraph break, represented by \n\n
				" must be immidiately following a digit
				if word == '/'
					let start_phrase = 1
				elseif word == '//'
					let start_par = 1
				endif
			" if add word to translation string
			else
				" to enter a digit or / in translation, put a
				" back slash before it. all other charachters
				" of the string are untouched
				if word =~ '\d' || word =~ '\\'
				       let word = substitute(word, '\\', '', '')
				endif

				if at_new_trans
					let trans_part = word
					let at_new_trans = 0
				else
					let trans_part = trans_part . ' ' . word
				endif
			endif

			" write translation part to output
			" this is done if next is new part (which is preceded
			" by a digit), or if this is last word

			if index+1 == len(trans) || trans[index+1] !~ '\D' 
				if start_phrase
					exe "normal i\<LF>\<Esc>^d0"
				elseif start_par
					exe "normal i\<LF>\<LF>\<Esc>^d0"
				endif

				" move cursor into position
				exe "normal" . num_trans_now . "E"
				" this puts in the translation
				exe "norm a\<LF>" . trans_part . "\<LF>\<Esc>"
				" this gets cursor to start of first word to
				" be translated. Probably already there
				exe "normal ^d0"


				let at_new_trans = 1
				let start_phrase = 0
				let start_par = 0
			endif
		endfor
	endwhile
endfunction
