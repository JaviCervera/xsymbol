Type XSymbolList
	Field fields:XSymbolValue[]
	
	
	Function Create:XSymbolList()
		Return New XSymbolList
	End Function
	
	
	Method Add(val:XSymbolValue)
		fields = fields[.. fields.length+1]
		fields[fields.length-1] = val
	End Method
	
	
	Method Get:XSymbolValue(context:XSymbolContext, index)
		If index < 1 Or index > fields.length Then Return XSymbolValue.Nil'Error("Invalid list index", context.line)
		Return fields[index-1]
	End Method
	
	
	Method Count()
		Return fields.length
	End Method
	
	
	Method Copy:XSymbolList(context:XSymbolContext)
		Local l:XSymbolList = XSymbolList.Create()
		For Local i = 1 To Self.Count()
			l.Add(Self.Get(context, i).Copy(context))
		Next
		Return l
	End Method
End Type


Type XSymbolValue
	Const TYPE_NUMBER = 1
	Const TYPE_STRING = 2
	Const TYPE_LIST = 3
	
	Global Nil:XSymbolValue = XSymbolValue.CreateNumber(0)
	
	Field type_
	Field number:Double
	Field str$
	Field list:XSymbolList
	
	
	Function CreateNumber:XSymbolValue(value:Double)
		Local param:XSymbolValue = New XSymbolValue
		param.type_ = TYPE_NUMBER
		param.number = value
		Return param
	End Function
	
	
	Function CreateString:XSymbolValue(str$)
		Local param:XSymbolValue = New XSymbolValue
		param.type_ = TYPE_STRING
		param.str = str
		Return param
	End Function
	
	
	Function CreateList:XSymbolValue(list:XSymbolList)
		Local param:XSymbolValue = New XSymbolValue
		param.type_ = TYPE_LIST
		param.list = list
		Return param
	End Function
	
	
	Method Copy:XSymbolValue(context:XSymbolContext)
		Select Self.type_
			Case TYPE_NUMBER
				Return XSymbolValue.CreateNumber(Self.number)
			Case TYPE_STRING
				Return XSymbolValue.CreateString(Self.str)
			Case TYPE_LIST
				Return XSymbolValue.CreateList(Self.list.Copy(context))
		End Select
	End Method
End Type


Type XSymbolNativeFunction
	Field name$
	Field pointer:XSymbolValue(context:XSymbolContext, param:XSymbolValue)
	
	
	Function Create:XSymbolNativeFunction(name$, pointer:XSymbolValue(context:XSymbolContext, param:XSymbolValue))
		Local func:XSymbolNativeFunction = New XSymbolNativeFunction
		func.name = Lower$(name)
		func.pointer = pointer
		Return func
	End Function
End Type


Type XSymbolScriptFunction
	Field name$
	Field param$[]
	Field offset
	Field line
	
	Function Create:XSymbolScriptFunction(name$, params$[], offset, line)
		Local func:XSymbolScriptFunction = New XSymbolScriptFunction
		func.name = Lower$(name)
		func.param = New String[params.length]
		For Local i = 0 Until params.length
			func.param[i] = Lower$(params[i])
		Next
		func.offset = offset
		func.line = line
		Return func
	End Function
End Type


Type XSymbolContext
	Field NativeFuncs:XSymbolNativeFunction[]
	Field ScriptFuncs:XSymbolScriptFunction[]
	Field offset, prevOffset
	Field buffer:Byte[]
	Field pname$[]
	Field param:XSymbolValue
	Field line


	Function Create:XSymbolContext()
		Return New XSymbolContext
	End Function
	
	
	Method AddFunction(name$, FuncPtr:XSymbolValue(context:XSymbolContext, param:XSymbolValue))
		NativeFuncs = NativeFuncs[.. NativeFuncs.length+1]
		NativeFuncs[NativeFuncs.length-1] = XSymbolNativeFunction.Create(name, FuncPtr)
	End Method
	
	
	Method Run:XSymbolValue(script$, func$, param:XSymbolValue)		
		'Create buffer with the script
		script = Replace$(script, Chr(13) + Chr(10), Chr(13))
		script = Replace$(script, Chr(10), Chr(13))
		buffer = New Byte[script.length]
		For Local i = 0 Until script.length
			buffer[i] = script[i]
		Next
		
		'Since we are starting execution of the script, we will
		'start at line 1
		line = 1

		'Prescan
		_Prescan()
		
		'Execute
		Return _CallScriptFunction(func$, param)
	End Method
	
	
	Method RunFile:XSymbolValue(file$, func$, param:XSymbolValue)
		Return Run(LoadText$(file), func$, param)
	End Method
	
	
	Method _Prescan()
		While offset < buffer.length
			Local tok$ = _GetToken()
			Select tok
				Case "@"
					_DefineFunction()
			End Select
		Wend
	End Method


	Method _DefineFunction()
		Local name$ = _GetToken()	'Function name
		Local param$ = _GetToken()	'Function param
		Local params$[]
		If param$ = "("
			While param$ <> ")"
				param$ = _GetToken()
				If param$ <> ")" Then params = params[.. params.length+1]; params[params.length-1] = param
			Wend
		Else
			params = New String[1]
			params[0] = param
		End If
		_SkipSpaces()
		ScriptFuncs = ScriptFuncs[.. ScriptFuncs.length+1]
		ScriptFuncs[ScriptFuncs.length-1] = XSymbolScriptFunction.Create(name, params, offset, line)
	End Method
	
	
	Method _SeekFunction(func$)
		For Local i = 0 Until ScriptFuncs.length
			If ScriptFuncs[i].name = Lower$(func)
				offset = ScriptFuncs[i].offset
				pname = New String[ScriptFuncs[i].param.length]
				Local length = ScriptFuncs[i].param.length
				For Local j = 0 Until length
					pname[j] = ScriptFuncs[i].param[j]
				Next
				line = ScriptFuncs[i].line
				Return
			End If
		Next
		Error("Function '" + func$ + "' not found.", line)
	End Method
	
	
	Method _CallScriptFunction:XSymbolValue(func$, parm:XSymbolValue)
		Local pname_$[] = New String[pname.length]
		For Local i = 0 Until pname.length
			pname_[i] = pname[i]
		Next
		Local oldparm:XSymbolValue = param
		Local ofs = offset
		Local prevOfs = prevOffset
		Local oldline = line
		Local ret:XSymbolValue
		
		'Set current param
		param = parm
		
		'Seek function
		_SeekFunction(func$)
		
		'If param is a nominal list, ensure we received the correct number of parameters
		If pname.length = 0
			If parm.type_ <> XSymbolValue.TYPE_LIST Then Error("An empty list is expected as parameter", line)
			If parm.list.fields.length <> 0 Then Error("An empty list is expected as parameter", line)
		Else If pname.length > 1
			If parm.type_ <> XSymbolValue.TYPE_LIST Then Error("A list is expected as parameter", line)
			If parm.list.fields.length <> pname.length Then Error("Incorrect number of elements in parameter list", line)
		End If
		
		Repeat
			ret = _ParseExpression()
			If _GetToken() = ";" Then Exit
			_GoBack()
		Forever
		
		pname = pname_
		param = oldparm
		offset = ofs
		prevOffset = prevOfs
		line = oldline
		Return ret
	End Method
	
	
	Method _ParseExpression:XSymbolValue()
		Return _ParseOrExp()
	End Method

	
	'$andexp *[or $andexp]
	'expanded from [$orexp or] $andexp
	Method _ParseOrExp:XSymbolValue()
		'$andexp
		Local ret:XSymbolValue = _ParseAndExp()
		
		'*[or $andexp]
		Local tok$ = _GetToken()
		While tok = "|"
			If ret.type_ <> XSymbolValue.TYPE_NUMBER Then Error("Cannot compare non-numeric values", line)
			
			Local otherExp:XSymbolValue = _ParseAndExp()
			If otherExp.type_ <> XSymbolValue.TYPE_NUMBER Then Error("Cannot compare non-numeric values", line)
			ret = XSymbolValue.CreateNumber(ret.number Or otherExp.number)
			
			tok = _GetToken()
		Wend
		_GoBack()
		
		Return ret
	End Method
	
	
	'$equalexp *[and $equalexp]
	'expanded from [$andexp and] $equalexp
	Method _ParseAndExp:XSymbolValue()
		'$equalexp
		Local ret:XSymbolValue = _ParseEqualExp()
		
		'*[and $equalexp]
		Local tok$ = _GetToken()
		While tok = "&"
			If ret.type_ <> XSymbolValue.TYPE_NUMBER Then Error("Cannot compare non-numeric values", line)
			
			Local otherExp:XSymbolValue = _ParseEqualExp()
			If otherExp.type_ <> XSymbolValue.TYPE_NUMBER Then Error("Cannot compare non-numeric values", line)
			ret = XSymbolValue.CreateNumber(ret.number And otherExp.number)
			
			tok = _GetToken()
		Wend
		_GoBack()
		
		Return ret
	End Method
	

	'$relexp *[equal | notequal $relexp]
	'expanded from ([$equalexp equal] $relexp) | ([$equalexp notequal] $relexp)
	Method _ParseEqualExp:XSymbolValue()
		'$relexp 
		Local ret:XSymbolValue = _ParseRelExp()
		
		'*[equal | notequal $relexp]
		Local tok$ = _GetToken()
		While tok = "=" Or tok = "!="
			Local otherExp:XSymbolValue = _ParseRelExp()
			If tok = "="
				ret = XSymbolValue.CreateNumber(Not (ret.number <> otherExp.number))
			Else
				ret = XSymbolValue.CreateNumber(ret.number <> otherExp.number)
			End If
			tok = _GetToken()
		Wend
		_GoBack()
		
		Return ret
	End Method
	

	'$addexp *[lesser | lequal | greater | gequal $addexp]
	'expanded from ([$relexp lesser] $addexp) | ([$relexp lequal] $addexp) | ([$relexp greater] $addexp) | ([$relexp gequal] $addexp)
	Method _ParseRelExp:XSymbolValue()
		'$addexp
		Local ret:XSymbolValue = _ParseAddExp()
		
		'*[lesser | lequal | greater | gequal $addexp]
		Local tok$ = _GetToken()
		While tok = "<" Or tok = "<=" Or tok = ">" Or tok = ">="
			If ret.type_ <> XSymbolValue.TYPE_NUMBER Then Error("Cannot compare non-numeric values", line)
			
			Local otherExp:XSymbolValue = _ParseAddExp()
			If otherExp.type_ <> XSymbolValue.TYPE_NUMBER Then Error("Cannot compare non-numeric values", line)
			If tok = "<"
				ret = XSymbolValue.CreateNumber(ret.number < otherExp.number)
			Else If tok = "<="
				ret = XSymbolValue.CreateNumber(ret.number <= otherExp.number)
			Else If tok = ">"
				ret = XSymbolValue.CreateNumber(ret.number > otherExp.number)
			Else If tok = ">="
				ret = XSymbolValue.CreateNumber(ret.number >= otherExp.number)
			End If
			tok = _GetToken()
		Wend
		_GoBack()
		
		Return ret
	End Method
	
	
	'$mulexp *[plus | minus $mulexp]
	'expanded from ([$addexp plus] $mulexp) | ([$addexp minus] $mulexp)
	Method _ParseAddExp:XSymbolValue()
		'$mulexp
		Local ret:XSymbolValue = _ParseMulExp()
		
		'*[plus | minus $mulexp]
		Local tok$ = _GetToken()
		While tok = "+" Or tok = "-"
			If tok = "+"
				If ret.type_ <> XSymbolValue.TYPE_NUMBER And ret.type_ <> XSymbolValue.TYPE_STRING Then Error("Cannot add values", line)
			Else
				If ret.type_ <> XSymbolValue.TYPE_NUMBER Then Error("Cannot subtract non-numeric values", line)
			End If
			
			Local otherExp:XSymbolValue = _ParseMulExp()
			If tok = "+"
				If otherExp.type_ <> XSymbolValue.TYPE_NUMBER And otherExp.type_ <> XSymbolValue.TYPE_STRING Then Error("Cannot add values", line)
			Else
				If otherExp.type_ <> XSymbolValue.TYPE_NUMBER Then Error("Cannot subtract non-numeric values", line)
			End If
			If tok = "+"
				If ret.type_ = XSymbolValue.TYPE_NUMBER And otherExp.type_ = XSymbolValue.TYPE_NUMBER
					ret = XSymbolValue.CreateNumber(ret.number + otherExp.number)
				Else
					Local a:String
					Local b:String
					If ret.type_ = XSymbolValue.TYPE_STRING
						a = ret.str
					Else
						a = String.FromInt(ret.number)
					End If
					If otherExp.type_ = XSymbolValue.TYPE_STRING
						b = otherExp.str
					Else
						b = String.FromInt(otherExp.number)
					End If

					ret = XSymbolValue.CreateString(a + b)
				End If
			Else
				ret = XSymbolValue.CreateNumber(ret.number - otherExp.number)
			End If
			tok = _GetToken()
		Wend
		_GoBack()
		
		Return ret

	End Method
	
	
	'$unaryexp *[mul | div | mod $unaryexp]
	'expanded from ([$mulexp mul] $unaryexp) | ([$mulexp div] $unaryexp) | [$mulexp mod] $unaryexp)
	Method _ParseMulExp:XSymbolValue()
	
	End Method
	
	
	Method _OldParseExpression:XSymbolValue()
		Local tok$ = _GetToken()
		
		'Number
		If Len(tok$) > 0 And Instr("0123456789", Left$(tok$, 1))
			Return XSymbolValue.CreateNumber(tok.ToDouble())
		End If
		
		'String
		If buffer[offset-1] = 34
			Return XSymbolValue.CreateString(tok$)
		End If
		
		'Negate
		If tok = "-"
			Local arg:XSymbolValue = _ParseExpression()
			If arg.type_ <> XSymbolValue.TYPE_NUMBER Then Error("Cannot negate non-numeric values", line)
			Return XSymbolValue.CreateNumber(-arg.number)
		End If
		
		'Sum
		If tok = "+"
			Local arg1:XSymbolValue = _ParseExpression()
			If arg1.type_ <> XSymbolValue.TYPE_NUMBER Then Error("Cannot sum non-numeric values", line)
			Local arg2:XSymbolValue = _ParseExpression()
			If arg2.type_ <> XSymbolValue.TYPE_NUMBER Then Error("Cannot sum non-numeric values", line)
			Return XSymbolValue.CreateNumber(arg1.number + arg2.number)
		End If
		
		'Sub
		If tok = "- "
			Local arg1:XSymbolValue = _ParseExpression()
			If arg1.type_ <> XSymbolValue.TYPE_NUMBER Then Error("Cannot substract non-numeric values", line)
			Local arg2:XSymbolValue = _ParseExpression()
			If arg2.type_ <> XSymbolValue.TYPE_NUMBER Then Error("Cannot substract non-numeric values", line)
			Return XSymbolValue.CreateNumber(arg1.number - arg2.number)
		End If
		
		'Mul
		If tok = "*"
			Local arg1:XSymbolValue = _ParseExpression()
			If arg1.type_ <> XSymbolValue.TYPE_NUMBER Then Error("Cannot multiply non-numeric values", line)
			Local arg2:XSymbolValue = _ParseExpression()
			If arg2.type_ <> XSymbolValue.TYPE_NUMBER Then Error("Cannot multiply non-numeric values", line)
			Return XSymbolValue.CreateNumber(arg1.number * arg2.number)
		End If
		
		'Div
		If tok = "/"
			Local arg1:XSymbolValue = _ParseExpression()
			If arg1.type_ <> XSymbolValue.TYPE_NUMBER Then Error("Cannot divide non-numeric values", line)
			Local arg2:XSymbolValue = _ParseExpression()
			If arg2.type_ <> XSymbolValue.TYPE_NUMBER Then Error("Cannot divide non-numeric values", line)
			Return XSymbolValue.CreateNumber(arg1.number / arg2.number)
		End If
		
		'Mod
		If tok = "%"
			Local arg1:XSymbolValue = _ParseExpression()
			If arg1.type_ <> XSymbolValue.TYPE_NUMBER Then Error("Cannot mod non-numeric values", line)
			Local arg2:XSymbolValue = _ParseExpression()
			If arg2.type_ <> XSymbolValue.TYPE_NUMBER Then Error("Cannot mod non-numeric values", line)
			Return XSymbolValue.CreateNumber(arg1.number Mod arg2.number)
		End If
		
		'And
		If tok = "&"
			Local arg1:XSymbolValue = _ParseExpression()
			If arg1.type_ <> XSymbolValue.TYPE_NUMBER Then Error("Cannot compare non-numeric values", line)
			Local arg2:XSymbolValue = _ParseExpression()
			If arg2.type_ <> XSymbolValue.TYPE_NUMBER Then Error("Cannot compare non-numeric values", line)
			Return XSymbolValue.CreateNumber(arg1.number And arg2.number)
		End If
		
		'Or
		If tok = "|"
			Local arg1:XSymbolValue = _ParseExpression()
			If arg1.type_ <> XSymbolValue.TYPE_NUMBER Then Error("Cannot compare non-numeric values", line)
			Local arg2:XSymbolValue = _ParseExpression()
			If arg2.type_ <> XSymbolValue.TYPE_NUMBER Then Error("Cannot compare non-numeric values", line)
			Return XSymbolValue.CreateNumber(arg1.number Or arg2.number)
		End If
		
		'Not
		If tok = "!"
			Local arg:XSymbolValue = _ParseExpression()
			If arg.type_ <> XSymbolValue.TYPE_NUMBER Then Error("Cannot negate non-numeric values", line)
			Return XSymbolValue.CreateNumber(Not arg.number)
		End If
		
		'Equals
		If tok = "="
			Local arg1:XSymbolValue = _ParseExpression()
			If arg1.type_ <> XSymbolValue.TYPE_NUMBER Then Error("Cannot compare non-numeric values", line)
			Local arg2:XSymbolValue = _ParseExpression()
			If arg2.type_ <> XSymbolValue.TYPE_NUMBER Then Error("Cannot compare non-numeric values", line)
			Return XSymbolValue.CreateNumber(arg1.number = arg2.number)
		End If
		
		'Lesser
		If tok = "<"
			Local arg1:XSymbolValue = _ParseExpression()
			If arg1.type_ <> XSymbolValue.TYPE_NUMBER Then Error("Cannot compare non-numeric values", line)
			Local arg2:XSymbolValue = _ParseExpression()
			If arg2.type_ <> XSymbolValue.TYPE_NUMBER Then Error("Cannot compare non-numeric values", line)
			Return XSymbolValue.CreateNumber(arg1.number < arg2.number)
		End If
		
		'Greater
		If tok = ">"
			Local arg1:XSymbolValue = _ParseExpression()
			If arg1.type_ <> XSymbolValue.TYPE_NUMBER Then Error("Cannot compare non-numeric values", line)
			Local arg2:XSymbolValue = _ParseExpression()
			If arg2.type_ <> XSymbolValue.TYPE_NUMBER Then Error("Cannot compare non-numeric values", line)
			Return XSymbolValue.CreateNumber(arg1.number > arg2.number)
		End If
		
		'Less equal
		If tok = "<="
			Local arg1:XSymbolValue = _ParseExpression()
			If arg1.type_ <> XSymbolValue.TYPE_NUMBER Then Error("Cannot compare non-numeric values", line)
			Local arg2:XSymbolValue = _ParseExpression()
			If arg2.type_ <> XSymbolValue.TYPE_NUMBER Then Error("Cannot compare non-numeric values", line)
			Return XSymbolValue.CreateNumber(arg1.number <= arg2.number)
		End If
		
		'Great equal
		If tok = ">="
			Local arg1:XSymbolValue = _ParseExpression()
			If arg1.type_ <> XSymbolValue.TYPE_NUMBER Then Error("Cannot compare non-numeric values", line)
			Local arg2:XSymbolValue = _ParseExpression()
			If arg2.type_ <> XSymbolValue.TYPE_NUMBER Then Error("Cannot compare non-numeric values", line)
			Return XSymbolValue.CreateNumber(arg1.number >= arg2.number)
		End If
		
		'If
		If tok = "?"
			Local ret:XSymbolValue = _ParseExpression()
			If ret.type_ <> XSymbolValue.TYPE_NUMBER Then Error("Expression in IF condition must return a numeric value", line)
			If ret.number <> 0	'Execute THEN block
				Repeat
					ret = _ParseExpression()
					If _GetToken() = ":" Then Exit
					_GoBack()
				Forever
				'Skip Else...
				Local level = 1
				While level
					level = _SkipExpression(level)
				Wend
			Else	'Execute ELSE block
				'Skip Then...
				Local level = 1
				While level
					level = _SkipExpression(level)
				Wend
				If Chr(buffer[offset-1]) = ";" Then Error("Expected ':'", line)
				Repeat
					ret = _ParseExpression()
					If _GetToken() = ";" Then Exit
					_GoBack()
				Forever
			End If
			Return ret
		End If
		
		'List
		If tok = "("
			Local list:XSymbolList = XSymbolList.Create()
			Repeat
				If _GetToken() = ")" Then Exit
				_GoBack()
				list.Add(_ParseExpression())
			Forever
			Return XSymbolValue.CreateList(list)
		End If
			
		'Identifier
		If _FindScriptFunction(tok)
			If tok = "GeneraNodo" Then DebugStop
			Local arg:XSymbolValue = _ParseExpression()
			Return _CallScriptFunction(tok, arg)
		Else If _FindNativeFunction(tok)
			Local arg:XSymbolValue = _ParseExpression()
			Return _FindNativeFunction(tok).pointer(Self, arg)
		Else If _IsParam(Lower$(tok))
			If pname.length = 1
				Return param
			Else
				Local list:XSymbolList = XSymbolList.Create()
				list.Add(param)
				list.Add(XSymbolValue.CreateNumber(_IsParam(Lower$(tok))))
				Return XSymbolLibrary.Get(Self, XSymbolValue.CreateList(list))
			End If
		Else
			Error("Unexpected token '" + tok + "'", line)
		End If
	End Method
	
	
	Method _GetToken$()
		_SkipSpaces()
		
		If offset = buffer.length Then Error("Unexpected end of file", line)
		
		prevOffset = offset
		
		'Semicolon
		If Chr(buffer[offset]) = ";"
			offset :+ 1
			Return ";"
		End If
		
		'Number
		If _IsNumber()
			Local str$ = ""
			While offset < buffer.length And buffer[offset] <> 13 And _IsNumber()
				str$ :+ Chr(buffer[offset])
				offset :+ 1
			Wend
			If offset < buffer.length And Chr(buffer[offset]) = "."
				str$ :+ "."
				offset :+ 1
				If Not _IsNumber() Then Error("Invalid decimal format", line)
				While offset < buffer.length And buffer[offset] <> 13 And _IsNumber()
					str$ :+ Chr(buffer[offset])
					offset :+ 1
				Wend
			End If
			Return str
		End If
		
		'String delimiter
		If buffer[offset] = 34
			Local str$ = ""
			offset :+ 1
			While offset < buffer.length And buffer[offset] <> 13 And buffer[offset] <> 34
				str :+ Chr(buffer[offset])
				offset :+ 1
			Wend
			If buffer[offset] = 13 Then Error("Unexpected end of line", line)
			offset :+ 1
			Return str
		End If
		
		'Sub of negate
		If Chr(buffer[offset]) = "-"
			offset :+ 1
			
			'Sub
			If offset < buffer.length And Chr(buffer[offset]) = " "
				offset :+ 1
				Return "- "
			End If
			
			'Negate
			Return "-"
		End If
		
		'Symbol
		If Instr("+*/%&|!=()", Chr(buffer[offset]))
			Local str$ = Chr(buffer[offset])
			offset :+ 1
			Return str$
		End If
		
		'Symbol (these ones may be 2-char len)
		If Instr("<>", Chr(buffer[offset]))
			Local str$ = Chr(buffer[offset])
			offset :+ 1
			If Chr(buffer[offset]) = "="
				str$ :+ "="
				offset :+ 1
			End If
			Return str$		
		End If
		
		'If
		If Chr(buffer[offset]) = "?"
			offset :+ 1
			Return "?"
		End If
		
		'Else
		If Chr(buffer[offset]) = ":"
			offset :+ 1
			Return ":"
		End If
		
		'Function definition
		If Chr$(buffer[offset]) = "@"
			offset :+ 1
			Return "@"
		End If
		
		'Identifier
		If _IsLetter()
			Local str$ = ""
			While _IsAlphaNumeric()
				str :+ Chr$(buffer[offset])
				offset :+ 1
			Wend
			Return str
		End If

		'At this point, the parser should have identified the token
		Error("Unexpected token '" + Chr$(buffer[offset]) + "'", line)
	End Method
	
	
	Method _GoBack()
		offset = prevOffset
	End Method
	
	
	Method _SkipSpaces()
		While (offset < buffer.length) And (buffer[offset] = 9 Or buffer[offset] = 13 Or buffer[offset] = 32 Or Chr(buffer[offset]) = "'")
			If Chr(buffer[offset]) = "'"
				While offset < buffer.length And buffer[offset] <> 13
					offset :+ 1
				Wend
				line :+ 1
			Else
				If buffer[offset] = 13 Then line :+ 1
				offset :+ 1
			End If
		Wend
	End Method
	
	
	Method _SkipExpression(level)
		Local tok$ = _GetToken()
		
		'Number
		If Instr("0123456789", Left$(tok$, 1)) Then Return level
		
		'String
		If buffer[offset-1] = 34 Then Return level
		
		'Negate
		If tok = "-" Then Return _SkipExpression(level)
		
		'Sum
		If tok = "+"
			level = _SkipExpression(level)
			Return _SkipExpression(level)
		End If
		
		'Sub
		If tok = "- "
			level = _SkipExpression(level)
			Return _SkipExpression(level)
		End If
		
		'Mul
		If tok = "*"
			level = _SkipExpression(level)
			Return _SkipExpression(level)
		End If
		
		'Div
		If tok = "/"
			level = _SkipExpression(level)
			Return _SkipExpression(level)
		End If
		
		'Mod
		If tok = "%"
			level = _SkipExpression(level)
			Return _SkipExpression(level)
		End If
		
		'And
		If tok = "&"
			level = _SkipExpression(level)
			Return _SkipExpression(level)
		End If
		
		'Or
		If tok = "|"
			level = _SkipExpression(level)
			Return _SkipExpression(level)
		End If
		
		'Not
		If tok = "!" Then Return _SkipExpression(level)
		
		'Equals
		If tok = "="
			level = _SkipExpression(level)
			Return _SkipExpression(level)
		End If
		
		'Lesser
		If tok = "<"
			level = _SkipExpression(level)
			Return _SkipExpression(level)
		End If
		
		'Greater
		If tok = ">"
			level = _SkipExpression(level)
			Return _SkipExpression(level)
		End If
		
		'Less equal
		If tok = "<="
			level = _SkipExpression(level)
			Return _SkipExpression(level)
		End If
		
		'Great equal
		If tok = ">="
			level = _SkipExpression(level)
			Return _SkipExpression(level)
		End If
		
		'If
		If tok = "?" Then Return _SkipExpression(level + 2)
		
		'Else
		If tok = ":" Then Return level - 1
		
		'Semicolon
		If tok = ";" Then Return level - 1
		
		'List
		If tok = "("
			Repeat
				If _GetToken() = ")" Then Exit
				_GoBack()
				level = _SkipExpression(level)
			Forever
			Return level
		End If

		'Identifier
		If _FindScriptFunction(tok) Or _FindNativeFunction(tok)
			Return _SkipExpression(level)
		Else
			Return level
		End If
	End Method
	
	
	Method _IsLetter()
		If (buffer[offset] => 65 And buffer[offset] <= 90) Or (buffer[offset] => 97 And buffer[offset] <= 122)
			Return True
		Else
			Return False
		End If
	End Method
	
	
	Method _IsNumber()
		If buffer[offset] => 48 And buffer[offset] <= 57
			Return True
		Else
			Return False
		End If
	End Method
	
	
	Method _IsAlphaNumeric()
		Return _IsLetter() Or _IsNumber() Or Chr(buffer[offset]) = "_"
	End Method
	
	
	Method _FindScriptFunction:XSymbolScriptFunction(name$)
		For Local i = 0 Until ScriptFuncs.length
			If ScriptFuncs[i].name$ = Lower$(name) Then Return ScriptFuncs[i]
		Next
	End Method
	
	
	Method _FindNativeFunction:XSymbolNativeFunction(name$)
		For Local i = 0 Until NativeFuncs.length
			If NativeFuncs[i].name$ = Lower$(name) Then Return NativeFuncs[i]
		Next
		Return Null
	End Method
	
	Method _IsParam(p$)
		For Local i = 0 Until pname.length
			If pname[i] = p Then Return i+1
		Next
		Return 0
	End Method
End Type


Function Error(str$, line)
	Print "Error at line " + line + ": " + str$
	End
End Function
