" divs, or divisions, are very important. It means divions whithin the text,
" there are an atom, the smallest, usually around a word or two, until
" atomlist, which is an entire thing. Bigger number for more general
let DivVal = { "atom":1, "phrase":2, "par":3, "atomlist":4 }
" source is a list to enable adding a new line
let Atom = { "source": "", "trans":[""], "comment":[], "ends":"atom" }


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
		if new_string != ""
			call add(self.trans, new_string)
		endif
	endwhile
endfunction

function! Atom.rawSplit() dict
	call self.parseSrc()
	" source is one line only
	let list = ["startatom", "startsource"] + [self.source] + ["endsource"]
	if len(self.trans) > 0
		let list += ["starttrans"] + self.trans + ["endtrans"]
	endif
	if len(self.comment) > 0
		let list += ["startcomment"] + self.comment + ["endcomment"]
	endif
	return deepcopy(list + ["startends", self.ends, "endends" , "endatom"])
endfunction

" start at start(.*)
" ends off line past end\1
" div is same as key
function! Atom.readKey(div) dict
	call Require(a:div)
	let list = []
	while getline(".") != "end" . a:div
		let list += [getline(".")]
		normal j
	endwhile
	let self[a:div] = deepcopy(list)
	normal j
endfunction

" load Atom data from file. start at startatom
function! Atom.read() dict
	call Require("atom")
	call Require("source")
	let self.source = getline(".")
	" <source> -> endsource -> starttrans
	normal jj
	if getline(".") =~ 'trans'
		call self.readKey("trans")
	endif
	if getline(".") =~ 'comment'
		call self.readKey("comment")
	endif
	call self.readKey("ends")
	" endatom -> startatom|endatomlist
	normal j
endfunction


"
" AtomList functions
"

let AtomList = { "atoms":[] }

function! AtomList.read() dict
	call Require("atomlist")
	while getline(".") != "endatomlist"
		let atom = deepcopy(g:Atom)
		call atom.read()
		let self.atoms += [deepcopy(atom)]
	endwhile
	normal j
endfunction

function! AtomList.rawSplit() dict
	let list = ["startatomlist"]
	for atom in self.atoms
		let list += atom.rawSplit()
	endfor
	return deepcopy(list + ["endatomlist"])
endfunction

function! TrimList(list)
	if len(a:list) == 0
		echo "warning:TrimList:empty"
		return
	endif

	while a:list[-1] == ""
		call remove(a:list, -1)
	endwhile 
	
	reuturn a:list
endfunction

function! AtomList.footnote() dict
	let foot_num = 1
	" because atom is a dictionary, editing atom edits the original
	for atom in self.atoms
		" trans can have 1 even if comment is empty
		for i in range(len(atom.comment))
			let atom.trans[i] .= '('.foot_num.')'
			let atom.comment[i] = foot_num.') '.atom.comment[i]
			let foot_num += 1
		endfor
	endfor
endfunction

" remove through end (a div) or greater (meaning more general). Return
" AtomList which is removed
function! AtomList.remove(end) dict
	let list = deepcopy(g:AtomList)
	for i in range(len(self.atoms))
		let atom = self.atoms[i]
		let list.atoms += [deepcopy(atom)]
		if g:DivVal[atom.ends] >= g:DivVal[a:end]
			call remove(self.atoms,0,i)
			return deepcopy(list)
		endif
	endfor
endfunction

function! JoinString(a,b)
	if a:a == ""
		return a:b
	elseif a:b == ""
		return a:a
	else
		return a:a . ' ' . a:b
	endif
endfunction

" returns list of all source in one string [new line split according to arg]
" followed by all trans, in one string as with source, followed by all the
" comments, each comment its own item in list
"
" args: dicts of type { "<div>":["",...], ... }
" 	key is div that value is appended to
" 	split_source is for source, trans for trans
"
" [""] just moves to next line, because loop appends to last item. to have
" blank line between, use ["",""] for val for key "<div>"
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

	call TrimList(dict.source)
	call TrimList(dict.trans)

	return deepcopy(dict.source + dict.trans + dict.comment)
endfunction

"
" translate definitions
"

let Translate = {}
let Translate.atomlist = deepcopy(AtomList)
let Translate.source = []	" source: space seperated source
let Translate.upto = 0		" index upto in source
" figured out, whether am inside atomlist already or am starting new one
let Translate.startatomlist = 1
" flag: if end of input is end of atomlist [= text under translate control]
" yes|no|ask
let Translate.endatomlist = "yes"


"""""""""""""""""""""""
" translate functions "
"""""""""""""""""""""""

" arg: number of words that this atom translates
function! Translate.add(num) dict
	let num = a:num

	" first expr: eg upto=5, proccessing 2, =proccessing 5&6, 5+2-1
	" second expr: highest valid index - len counts from 1, index from 0
	" if highest index being proccessed is more then then highest valid
	" index...
	if self.upto + a:num - 1 > len(self.source) - 1
		" eg highest index is 5, upto 4: 5-4=1
		" +1 because using 4&5 =2
		let num = len(self.source) - 1 - self.upto + 1
	endif
	if num == 0 
		echo "ERROR:add:0"
		return
	endif

	let atom = deepcopy(g:Atom)
	let atom.source = join(self.source[self.upto : self.upto+num-1])
	let self.atomlist.atoms += [deepcopy(atom)]
	let self.upto += num
endfunction

function! Translate.appendTrans(trans) dict
	let trans = JoinString(self.atomlist.atoms[-1].trans[-1],a:trans)
	let self.atomlist.atoms[-1].trans[-1] = trans
endfunction

" support function for genPrompt. echo <hebrew> is left-to-right...which is
" probably the best option. But it would be nice if a reverse string function
" was supplied

function! FlipString(str)
	let char_list = split(a:str, '\zs')
	call reverse(char_list)
	return join(char_list, '')
endfunction

function! Translate.genPrompt() dict
	let list = []
	for [start,end] in [[-10,-1], [0,9], [10,19]]
		let start += self.upto
		let end += self.upto
		if start > 0 && end < len(self.source)
			let string = FlipString(join(self.source[start:and]))
			let list += [string]
		endif
	endfor
	let string = FlipString(join(self.source[self.upto:self.upto+9]))
	let list += [""] + [string . ": "]
	return list[0] == "" ? list[1] : join(list,"\n")
endfunction

function! Translate.setDiv(div) dict
	if a:div !~ '^\(start\|end\)\(par\|phrase\|atomlist\)$'
		throw "ERROR:div:bad arg:" . a:div
	elseif a:div =~ 'start' && len(self.atomlist.atoms) < 2
		echo "warning:setDiv:input error"
		return
	endif

	" start means set second-to-last as end
	let index = a:div =~ 'end' ? -1 : -2

	let ends = matchstr(a:div, 'par\|phrase\|atomlist')

	if DivVal[self.atomlist.atoms[index].ends] >= DivVal[ends]
		return
	endif

	let self.atomlist.atoms[index].ends = ends
endfunction

function! Translate.endMine(arg) dict
	let self.endatomlist = a:arg
endfunction

" ask whether end of input is endatomlist
function! Translate.askEnd()
	echo "endatomlist?(y/n): "
	let response = getchar()
	if response == "y" || nr2char(response) == "y"
		self.endatomlist = "yes"
	else 
		self.endatomlist = "no"
	endif
endfunction

" checks if in the middle of atomlist
function! Translate.checkCont() dict
	let line = line("." - 1)
	if line > 0 && getline(line) == "endpar"
		let self.startatomlist = 0
	elseif getline(line) =~ 'end\(phrase\|atom\)'
		call self.jumpoffcliff()
	else
		let self.startatomlist = 1
	endif
endfunction

" 
" output functions
" following a call to rawSplit() or styleSplit(), no further input is possible
"

function! Translate.rawSplit() dict
	call self.setDiv("endatomlist")
	let list = self.atomlist.rawSplit()

	if self.endatomlist == "ask"
		self.askEnd()
	endif

	" upto is one more then index done, len() 1 more then top index
	" if all was proccessed, upto should equal len
	if self.endatomlist == "no" || self.upto < len(self.source)
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
	call self.setDiv("endatomlist")
	let list = []

	while !empty(self.atoms.atomlist)
		let sub = self.atomlist.remove(keys(a:split_sep)[0])
		call sub.footnote()
		let list += sub.styleSplit(a:split_source,a:split_trans)
		let list += values(a:split_sep)[0]
	endwhile

	return deepcopy(TrimList(list))
endfunction

function! ReplaceAppend(list)
	if len(a:list) > 0
		call setline(line("."), a:list[0])
	endif
	if len(a:list) > 1
		call append(line("."), a:list[1:])
	endif
endfunction

function! TranslateLine()
	let lineTrans = deepcopy(g:Translate)
	let lineTrans.source = split(getline("."))

	while 1
		if lineTrans.upto == len(lineTrans.source)
			break
		endif
		let input = split(input(lineTrans.genPrompt()))
		if len(input) == 0 
			break
		endif

		for i in range(len(input))
			let word = input[i]

			if word !~ '\D'
				call lineTrans.add(word)
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

				continue	" / or // not a word
			endif

			if word =~ '\\\d' || word =~ '\/'
			       let word = substitute(word, '\\', '', '')
			endif

			call lineTrans.appendTrans(word)
		endfor
	endwhile

	if lineTrans.upto > 0
		call ReplaceAppend(lineTrans.rawSplit())
	endif
endfunction
