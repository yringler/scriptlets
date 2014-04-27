" divs, or divisions, are very important. It means divions whithin the text,
" there are an atom, the smallest, usually around a word or two, until mine,
" which is an entire thing. Bigger number for more general
let DivVal = { "atom":1, "phrase":2, "par":3, "mine":4 }
" source is a list to enable adding a new line
let Atom = { "source": "", "trans":[], "comment":[], "ends":"atom" }
let AtomList = { "atoms":[] }

function! TrimList(list)
	let list = deepcopy(a:list)
	let i = -1
	while 1
		if list[i] == ""
			call remove(list, i)
			let i -= 1
		else
			return deepcopy(list)
		endif
	endwhile
endfunction

function! AtomList.footnote() dict
	let foot_num = 1
	" because atom is a dictionary, editing atom edits the original
	for atom in self.atoms
		" trans can have 1 even if comment is empty
		for i in range(len(atom.comment))
			let atom.trans[i] .= "{".foot_num+1."}"
			let atom.comment[i] = foot_num+1.") ".atom.comment[i]
			let foot_num ++
		endfor
	endfor
endfunction

" remove through end (a div) or greater (meaning more general). Return
" AtomList which is removed
function! AtomList.remove(end) dict
	let list = []
	for i in range(len(self.atoms))
		let atom = self.atoms[i]
		let list += deepcopy(atom)
		if DivVal[atom.ends] >= DivVal[a:end]
			call remove(self.atoms,0,i)
			return deepcopy(list)
		endif
	endfor
endfunction

function! JoinString(a,b)
	if a:a != ""
		return a:a . ' ' . a:b
	else
		return a:b
	endif
endfunction

" split: {<div>:["",..] what div to seperate source from trans
" [""] just moves to next line, because loop appends to last item. to have
" blank line between, use ["",""]
"
" returns list of all source in one string [new line split according to arg]
" followed by all trans, in one string as with source, followed by all the
" comments
function! AtomList.styleSplit(split_source, split_trans) dict
	let dict = { "source":[""], "trans":[""], "comment":[] }
	for atom in self.atoms
		let dict.source[-1] = JoinString(dict.source[-1],atom.source)
		let dict.trans[-1]=JoinString(dict.trans[-1],join(atom.trans))
		let dict.comment += atom.comment
		if has_key(a:split_source, atom.ends)
			let dict.source += a:split_source[atom.ends]
		endif
		if has_key(a:split_trans, atom.ends)
			let dict.trans += a:split_trans[atom.ends]
		endif
	endfor
	for key in ["source","trans"]
		let dict[key] = TrimList(dict[key])
	endfor
	return deepcopy(dict.source + dict.trans + dict.comment)
endfunction

""""""""""""""""""""""
" generic base class "
""""""""""""""""""""""

" subClass: for example, a par contains phrases. So the subClass of Par would
" be Phrase
" subKey: key to access list of subClass. Continuing the previous example, the
" Phrases of the Par would be in a list whose key was "phrases", so subKey
" would be "phrases"
let Div = { "div" : "", "subClass" : {}, "subKey" : "" }

" expects cursor to be on start*, then moves to next line, into the thing
function! Require(div) dict
	if getline(".") != "start".a:div || search("end".a:div, "n") == -1
		throw "error:Require:" . a:start
	else
		normal j
	endif
endfunction

function! Div.read() dict
	call Require(self.div)
	while getline(".") != "end" . self.div
		let sub = deepcopy(self.subClass)
		call sub.read()
		let self[self.subKey] += [deepcopy(sub)]
	endwhile
	normal j
endfunction

" creates list of strings for raw output
function! Div.rawSplit() dict
	let list = ["start" . self.div]
	for i in self[self.subKey]
		let list += i.rawSplit()
	endfor
	let list += ["end" . self.div]
	return deepcopy(list)
endfunction

" gather all Atoms into one list
function! Div.gather() dict
	let list = deepcopy(AtomList)
	for i in self[self.subKey]
		let list.atoms += i.gather()
	endfor
	let list.atoms[-1].ends = self.div
	return deepcopy(list)
endfunction

"""""""""""""""""""""
" class definitions "
"""""""""""""""""""""

" phrases: list of atoms
" atoms left empty so add is to start
let Phrase = deepcopy(Div)
call extend(Phrase, { "div":"phrase", "subClass":Atom, "subkey":"atoms"})
call extend(Phrase, { "atoms":[] })

let Par = deepcopy(Div)
call extend(Par, { "div":"par", "subClass":Phrase, "subkey":"phrases"})
call extend(Par, { "phrases":[deepcopy(Phrase)] })

let Translate = deepcopy(Div)
call extend(Translate, { "div":"mine", "subClass":Par, "subkey":"pars"})
call extend(Translate, { "pars":[deepcopy(Par)] })

" source: space seperated source
call extend(Translate, { "source":[], "upto":0 })
let Translate.parentRawSplit = Div.rawSplit
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
	let list = ["startatom", "startsource"] + self.source + ["endsource"]
	let list += ["starttrans"] + self.trans + ["endtrans"]
	if len(self.comment) > 0)
		let list += ["startcomment"] + self.comment + ["endcomment"]
	endif
	return deepcopy(list + ["endatom"])
endfunction

" start at start(.*)
" ends off line past end\1
" div is same as key
function! Atom.readKey(div) 
	call Require(a:div)
	while getline(".") != "end" . a:div
		let self[a:div] += [getline(".")]
		normal j
	endwhile
	normal j
endfunction

" load Atom data from file. start at startatom
function! Atom.read() dict
	call Require("atom")
	" startatom -> startsource
	normal j
	call self.readKey("source")
	call self.readKey("trans")
	call self.readKey("comment")
endfunction

function! Atom.gather() dict
	atomList = deepcopy(g:AtomList)
	atomList.atoms = [ deepcopy(self) ]
	return deepcopy(atomList)
endfunction


"""""""""""""""""""""""
" translate functions "
"""""""""""""""""""""""

" arg: num source to add
function! Translate.add(num) dict
	let atom = deepcopy(g:Atom)
	let atom.source = join(self.source[self.upto : self.upto+a:num-1])
	let self.pars[-1].phrases[-1].atoms += deepcopy(atom)
	let self.upto += a:num
endfunction

function! Translate.genPrompt() dict
	let list = []
	for [start,end] in [[-10,-1], [0,9], [10,19]]
		let start += self.upto
		let end += self.upto
		if start > 0 && end < len(self.source)
			let list += self.source[start:end]
		endif
	endfor
	let list += [""] + [join(self.source[self.upto:self.upto + 9]) . ": "]
	return list[0] == "" ? list[1] : join(list,"\n")
endfunction

function! Translate.setDiv(div) dict
	if a:div !~ '^\(start\|end\)\(par\|phrase\)$'
		throw "ERROR:div:bad arg:" . a:div
	endif

	let atom = deepcopy(self.pars[-1].phrases[-1].atoms[-1])
	call remove(self.pars[-1].phrases[-1].atoms, -1)
	
	if a:div =~ 'end'
		call add(self.pars[-1].phrases[-1].atoms, deepcopy(atom))
	endif

	if a:div =~ 'par'
		call add(self.pars, deepcopy(Pars))
	elseif a:div =~ "phrase"
		call add(self.pars[-1].phrases, deepcopy(Phrase))
	endif

	if a:div =~ 'start'
		call add(self.pars[-1].phrases[-1].atoms, deepcopy(atom))
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
	else
		let self.startmine = 1
	endif
endfunction

" also calls endInput()
function! Translate.rawSplit() dict
	call self.endInput()
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

	return deepcopy(list)
endfunction

" split_sep: {<div>:["",..] what div(and also done at greater then) to
" seperate source from trans
"
" other splits: same dictionary, with keys for each div where should add NL
" within source and trans
function! Translate.styleSplit(split_sep, split_source, split_trans) dict
	let gather = self.gather()
	let list = []

	while !empty(gather)
		let sub_gather = gather.remove(keys(a:split_sep)[0])
		call sub_gather.footnote()
		let list += sub_gather.styleSplit(a:split_source,a:split_trans)
		let list += values(a:split_sep)
	endwhile

	let list = TrimList(list)

	return deepcopy(list)
endfunction
