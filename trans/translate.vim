""""""""""""""""""""""
" generic base class "
""""""""""""""""""""""

" div: eg par,phrase,etc
" subClass: dict div contains list of
" subKey: key to access list of subClass
let Div = { "div" : "", "subClass" : {}, "subKey" : "" }

function! Require(div) dict
	if getline(".") != "start".a:div || search("end".a:div, "n") == -1
		throw "error:Require:" . a:start
	endif
endfunction

function! Div.read() dict
	call Require(self.div)
	normal j
	while getline(".") != "end" . self.div
		let sub = deepcopy(self.subClass)
		call sub.read()
		let self[subKey] += [deepcopy(sub)]
	endwhile
	normal j
endfunction


function! Div.rawSplit() dict
	let list = ["start" . self.div]
	for i in self[self.subKey]
		let list += i.rawSplit()
	endfor
	let list += ["end" . self.div]
	return list
endfunction

function! CombineString(first, second)
	if a:first != ""
		return a:first . " " . a:second
	else
		return a:second
	endif
endfunction


" gather all subdiv source into one list, all subdiv trans into another, etc
function! Div.gather() dict
	let list = [[][][]]
	for i in self[self.subKey]
		let sub_gather = i.gather()
		let list[0] .= CombineString(list[0], sub_gather.source)
		let list[1] += sub_gather.trans
		let list[2] += sub_gather.comment
	endfor
	return list
endfunction

" as before, but prepare for printing
" source is good as is, but join trans, numbering notes when there
" comment stays seperate, bug with numbers at start
function! Div.styleSplit() dict
	let gather_list = self.gather()
	let list = [gather_list.source, [], []]
	" use length of 2, empty means no comments
	for i in len(gather_list[2])
		let list[1] += [CombineString(gather_list[1][i], "{".i+1."}")]
		let list[2] += [CombineString(gather_list[2][i], i+1.")")]
	endfor
	return [list[0], join(list[1]), list[2]]
endfunction

"""""""""""""""""""""
" class definitions "
"""""""""""""""""""""

" trans left empty so add starts at beggining
let Atom = { "source": [], "trans": [], "comment": [] }

" phrases: list of atoms
let Phrase = deepcopy(Div)
call extend(Phrase, { "div":"phrase", "subClass":Atom, "subkey":"atoms"})
call extend(Phrase, { "atoms":[Atom] })

let Par = deepcopy(Div)
call extend(Par, { "div":"par", "subClass":Phrase, "subkey":"phrases"})
call extend(Par, { "phrases":[Phrase] })

let Translate = deepcopy(Div)
call extend(Translate, { "div":"mine", "subClass":Par, "subkey":"pars"})
call extend(Translate, { "pars":[Par] })

call extend(Translate, { "source":[], "pars":[Par], "upto":0 })
let Translate.parentRawSplit = Div.rawSplit
let Translate.partentStyleSplit = Div.styleSplit
" flag: if end of input is end of mine [= text under translate control]
let Translate.startmine = 1
" yes|no|ask
let Translate.endmine = ""


"""""""""""""""""""""
" atom functions    "
"""""""""""""""""""""

function! Trim(string)
	return matchstr(a:string, '^[[:space:]]*\zs.*\ze[[:space:]]*$')
endfunction

function! Atom.parseSrc() dict
	while self.trans[-1] =~ '{.*}'
		let comment = Trim(matchstr(self.trans[-1], '{\zs[^}]*'))
		call add(self.comment, comment)

		let new_string = Trim(matchstr(self.trans[-1], '}\zs.*'))
		let old_string = Trim(matchstr(self.trans[-1], '^[^{]*'))

		let self.trans[-1] = old_string
		call add(self.trans, new_string)
	endwhile
endfunction

function! Atom.rawSplit() dict
	" source is one line only
	let list = ["startatom", "source", self.source]
	let list += ["starttrans"] + self.trans + ["endtrans"]
	if len(self.comment) > 0)
		let list += ["startcomment"] + self.comment + ["endcomment"]
	endif
	return list + ["endatom"]
endfunction

" start at start(.*)
" ends off line past end\1
function! Atom.readKey(key,div) 
	call Require(a:div)
	normal j
	while getline(".") != a:end
		let self[a:key] += [getline(".")]
		normal j
	endwhile
	normal j
endfunction

" load Atom data from file. start at startatom
function! Atom.read() dict
	call Require("startatom")
	" startatom -> source -> <source>
	normal 2j
	let self.source = [getline(".")]
	" -> starttrans
	normal j
	call self.readKey("trans", "trans")
	call self.readKey("comment", "comment")
endfunction

function! Atom.gather() dict
	return self
endfunction

let Atom.styleSplit = Div.styleSplit

"""""""""""""""""""""""
" translate functions "
"""""""""""""""""""""""

" arg: num source to add
function! Translate.add(num) dict
	let atom = deepcopy(Atom)
	let atom.source = self.source[self.upto : self.upto+a:num-1]
	let self.pars[-1].phrases[-1].atoms[-1] = deepcopy(atom)
	let self.upto += a:num
endfunction

function! Translate.setDiv(div) dict
	if a:div !~ '^\(start\|end\)\(par\|phrase\)$'
		throw "ERROR:div:bad arg"

	let atom = deepcopy(self.pars[-1].phrases[-1].atoms[-1])
	call remove(self.pars[-1].phrases[-1].atoms, -1)
	
	if a:div =~ 'end'
		call add(self.pars[-1].phrases[-1], deepcopy(atom))
	endif

	if a:div =~ 'par'
		call add(self.pars[-1], deepcopy(Pars))
	elseif a:div =~ "phrase"
		call add(self.pars[-1].phrases[-1], deepcopy(Phrase))
	endif

	if a:div =~ 'start'
		call add(self.pars[-1].phrases[-1], deepcopy(atom))
	endif
endfunction

function! Translate.endInput() dict
	call self.div("endpar")
endfunction

function! Translate.endMine(arg) dict
	self.endmine = a:arg
endfunction

" ask whether end of input is endmine
function! Translate.askEnd()
	echo "endmine?(y/n): "
	let response = getchar()
	if response == "y" || nr2char(response) == "y"
		self.endmine = "yes"
	else 
		self.endmine = "no"
	endif
endfunction

" checks if in the middle of mine
function! Translate.checkCont() dict
	let line = line("." - 1)
	if line > 0 && line == "endpar"
		let self.startmine = 0
	elseif getline(line) == "endphrase"
		call self.jumpoffcliff()
	endif
endfunction

" also calls endInput() and clears self
function! Translate.rawSplit() dict
	self.endInput()
	let list = self.parentRawSplit()

	if self.startmine == 0
		" mine item added in parentRawSplit()
		call remove(list, 0)
	endif

	if self.endmine == "ask"
		self.askEnd()
	endif

	if self.endmine == "no"
		call remove(list, -1)
	endif

	return list
endfunction


" atom|phrase|par|mine
"" this function causes an evil amount of repeated work
"" 21st century programming is awesome
function! Translate.styleSplit(style)
	master_list = { "atoms":[], "phrases":[], "pars":[], "mine":[] }
	master_list.mine = self.partentStyleSplit()

	for par in self.pars
		let master_list["pars"] += par.styleSplit()
		for phrase in par.phrases
			let master_list["phrases"] += phrase.styleSplit()
			for atom in phrase.atoms
				let master_list["atoms"] += atom.styleSplit()
			endfor
		endfor
	endfor

	if a:style != 'atom|phrase|par|mine'
		throw "ERROR:Translate.styleSplit:bad arg:" . a:style
	else
		return master_list[a:style]
	endif
endfunction
