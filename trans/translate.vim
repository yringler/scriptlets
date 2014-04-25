" seperate string in trans for each comment
" this is here just for show - theoretically its used, but not explicetly
" see Atom.gather()
let FlatDiv = { "source": "", "trans":[], "comment":[], "ends": "" ] 

" number refers to footnote numbers
function! Number(flatdiv_list)
	let list = []
	let foot_num = 1
	for flatdiv in a:flatdiv_list
		" trans can have 1 even if comment is empty
		for i in range(len(a:flatdiv_list.comment))
			let flatdiv.trans[i] .= "{foot_num}"
			let comment = foot_num.") ".flatdiv.comment[i]
			let flatdiv.comment[i] = comment
		endfor
		let list += deepcopy([flatdiv])
	endfor
	return deepcopy(list)
endfunction

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

" number refers to footnote numbers
function! Div.numberGather() dict
	return Number(self.gather())
endfunction

"""""""""""""""""""""
" class definitions "
"""""""""""""""""""""

let Atom = { "source": [], "trans": [], "comment": [] }

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
	let list = ["startatom", "source", self.source]
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
	" startatom -> source -> <source>
	normal 2j
	let self.source = [getline(".")]
	" -> starttrans
	normal j
	call self.readKey("trans")
	call self.readKey("comment")
endfunction

function! Atom.gather() dict
	" this is to tempting to split up
	" returns a list of FlatDivs 
	return [extend(deepcopy(self),{ "ends":"" })]
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

" sep_div: div that trans and src are seperated at
" eg phrase: prints entire source of phrase, then entire trans (then comments)
" nl_div[=newline_div]: what is the smallest div between which there is a new
" line to seperate
" eg phrase: between every phrase *and* every par but *not* every atom there
" is a new line
function! Translate.styleSplit(sep_div, nl_div)
	let DivNum = { "atom":1, "phrase":2, "par":3, "mine":4 }
	let gather = self.gather()
	let list = []

	let Sep = { "source":[], "trans":[], "comment":[] }
	let sep = deepcopy(Sep)
	for atom in gather
		let sub += atom
		if DivNum[atom.div] >= DivNum[a:sep_div]
			let sub = Number(sub)
			for i in sub
				let sep.source += [atom.source]
				let sep.trans += [join(atom.trans)]
				let sep.comment += atom.comment
				if DivNum[atom.div] >= DivNum[a:nl_div]
					let sep.source += [""]
					let sep.trans += [""]
				endif
			endfor
			let list += sep.source + sep.trans + sep.comment
			let list += [""]
			let sep = deepcopy(Sep)
		endif
	endfor

	" the last 2 are extra spaces
	return list[0:-3]
endfunction
