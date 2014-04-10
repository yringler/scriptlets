" opens dialog to assist translation of line where cursor is at
function! Translate_line()
	normal ^	" the rest position of cursor is start of first word
			" to be tranlated
	let source = split(getline("."))
	" number of words in this line translated so far
	let num_done = 0

	" as long as all the words haven't been translated
	while num_done < len(source)
		" bite sized portion of source text to work on
		let prompt = join(source[num_done : num_done+10]) . ": "
		let trans = split(input(prompt))
		" this is a scary flag. I don't like flags.
		" it is set to true if and only if the first word of
		" translation following a digit wasn't processed yet
		let at_new_trans = 1

		" process translation input
		for index in range(len(trans))
			let word = trans[index]

			if word =~ '\d'
				" digit in input means following phrase
				" translates <digit> words of source
				let num_trans_now = word
				let num_done += num_trans_now
				continue
			elseif trans[index-1] =~ '\d' && word =~ '/'
				" / for phrase break , represented by \n and
				" // for paragraph break, represented by \n\n
				" must be immidiately following a digit
				if word == '/'
					exe "normal Ea\<LF>\<LF>\<Esc>^d0"
				elseif word == '//'
					exe "normal Ea\<LF>\<LF>\<LF>\<Esc>^d0"
				endif
				continue
			endif

			if at_new_trans
				let trans_part = word
				let at_new_trans = 0
			else
				let trans_part = trans_part . ' ' . word
			endif

			" write translation part to output
			" this is done if next is new part (which is preceded
			" by a digit), or if this is last word

			if index+1 == len(trans) || trans[index+1] =~ '\d' 
				" move cursor into position
				exe "normal" . num_trans_now . "E"
				" this puts in the translation
				exe "norm a\<LF>" . trans_part . "\<LF>\<Esc>"
				" this gets cursor to start of first word to
				" be translated. Probably already there
				exe "normal ^d0"
				" this is important-see test above. Having
				" this communication scheme seperate is a bit
				" scary
				let at_new_trans = 1
			endif
		endfor
	endwhile
endfunction
