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
		let self[self.subKey] += [deepcopy(sub)]
	endwhile
	normal j
endfunction

" creates of strings for raw output
function! Div.rawSplit() dict
	let list = ["start" . self.div]
	for i in self[self.subKey]
		let list += i.rawSplit()
	endfor
	let list += ["end" . self.div]
	return deepcopy(list)
endfunction

function! CombineString(first, second)
	if a:first != ""
		return a:first . " " . a:second
	else
		return a:second
	endif
endfunction

" gather all FlatDivs  into one list, with div info
function! Div.gather() dict
	let list = []
	for i in self[self.subKey]
		let list += i.gather()
	endfor
	let list[-1].ends = self.div
	return deepcopy(list)
endfunction

"""""""""""""""""""""
" class definitions "
"""""""""""""""""""""

let DivVal = { "atom":1, "phrase":2, "par":3, "mine":4 }

let Atom = { "source": [], "trans":[], "comment":[], "div":"atom" }
let AtomList = { "atoms":[] }

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
call extend(Translate, { "source":[], "pars":[Par], "upto":0 })
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
	normal j
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
	return [deepcopy(self)]
endfunction

function! AtomList.footnote() dict
	let foot_num = 1
	" atom=dict=shallow copy = original edited
	for atom in self.atoms
		" trans can have 1 even if comment is empty
		for i in range(len(atom.comment))
			let atom.trans[i] .= "{foot_num}"
			let atom.comment[i] = foot_num . ") " . atom.comment[i]
			let foot_num ++
		endfor
	endfor
endfunction

" remove through end or greater
" return AtomList of removed
function! AtomList.remove(end) dict
	let list = []
	for i in range(len(self.atoms))
		let atom = self.atoms[i]
		let list += deepcopy(atom)
		if DivVal[a:end] >= DivVal[atom.div] 
			call remove(self.atoms,0,i)
			return deepcopy(list)
		endif
	endfor
endfunction

" returns list of all strings - all source, then trans, then comments
function! AtomList.sort() dict
	let dict = { "source":[], "trans":[], "comments":[] }
	for atom in self.atoms
		let dict.source += join(atom.source)
		let dict.trans += join(atom.trans)
		let dict.comments += atom.comments
	endfor
	return dict
endfunction

"""""""""""""""""""""""
" translate functions "
"""""""""""""""""""""""

" arg: num source to add
function! Translate.add(num) dict
	let atom = deepcopy(Atom)
	let atom.source = self.source[self.upto : self.upto+a:num-1]
	let self.pars[-1].phrases[-1].atoms += deepcopy(atom)
	let self.upto += a:num
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

function TrimList(list)
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

" sep_div: {<div>:[<[""] for every new line you want]}: what div(and
" also done at greater then) to seperate source from trans
"
" nl_divs[=newline_divs]: sep_div-style dictionary, with keys for each div
" where should add NL within source and trans, with value of [[]..] for each
" new line wanted
function! Translate.styleSplit(sep_div, nl_sourcedivs, nl_transdivs)
	let gather = self.gather()
	let list = []

	while !empty(gather)
		let sub_gather = gather.remove(keys(a:sep_div)[0])
		call sub_gather.footnote()

		for atom in sub_gather
			" if atom ends div in source that a new line is wanted
			" after
			if has_key(a:nl_sourcedivs, atom.div)
				let atom.source += nl_sourcedivs[atom.div]
			elseif has_key(a:nl_transdivs, atom.div)
				let atom.trans += nl_transdivs[atom.div]
			endif
		endfor

		let sorted = sub_gather.sort()
		call map(sorted, "TrimList(v:val)")
		let list += sorted.source + sorted.trans + sorted.comments 
		let list += values(a:sep_div)[0] 
	endwhile
	let list = TrimList(list)

	return list
endfunction
