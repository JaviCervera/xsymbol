Type XSymbolLibrary
	Function AddStandard(context:XSymbolContext)
		context.AddFunction("print", Print)
		context.AddFunction("car", Car)
		context.AddFunction("cdr", Cdr)
		context.AddFunction("list", List)
		context.AddFunction("null", Null_)
		context.AddFunction("get", Get)
		context.AddFunction("index", Index)
		context.AddFunction("cat", Cat)
		context.AddFunction("random", Random)
		context.AddFunction("val", Val)
		context.AddFunction("str", Str)
		context.AddFunction("strcat", StrCat)
		context.AddFunction("inc", Inc)
		context.AddFunction("dec", Dec)
		context.AddFunction("zero", Zero)
	End Function
	
	
	Function Print:XSymbolValue(context:XSymbolContext, param:XSymbolValue)
		Local str$ = ""
		Select param.type_
			Case XSymbolValue.TYPE_NUMBER
				str = _PrintNumber(param.number)
			Case XSymbolValue.TYPE_STRING
				If Left(param.str, 3) = "ME:" Then DebugStop
				str = param.str
			Case XSymbolValue.TYPE_LIST
				str = _StrList(context, param.list)
		End Select
		BRL.StandardIO.Print str$
		Return XSymbolValue.Nil
	End Function
	
	
	Function _StrList$(context:XSymbolContext, list:XSymbolList)
		Local str$ = "( "
		For Local i = 1 To list.Count()
			Select list.Get(context, i).type_
				Case XSymbolValue.TYPE_NUMBER
					str :+ _PrintNumber(list.Get(context, i).number) + " "
				Case XSymbolValue.TYPE_STRING
					str :+ Chr(34) + list.Get(context, i).str + Chr(34) + " "
				Case XSymbolValue.TYPE_LIST
					str :+ _StrList(context, list.Get(context, i).list) + " "
			End Select
		Next
		Return str$ + ")"
	End Function


	Function _PrintNumber$(number:Double)
		If Double(Int(number)) = number Then Return String.FromInt(Int(number))
		Return String.FromDouble(number)
	End Function
	
	
	Function Car:XSymbolValue(context:XSymbolContext, param:XSymbolValue)
		If param.type_ <> XSymbolValue.TYPE_LIST Then Return XSymbolValue.Nil
		Return param.list.Get(context, 1)
	End Function
	
	
	Function Cdr:XSymbolValue(context:XSymbolContext, param:XSymbolValue)
		If param.type_ <> XSymbolValue.TYPE_LIST Then Return XSymbolValue.Nil
		Local list : XSymbolList = XSymbolList.Create()
		For Local i = 2 To param.list.Count()
			list.Add(param.list.Get(context, i))
		Next
		Return XSymbolValue.CreateList(list)
	End Function
	
	
	Function List:XSymbolValue(context:XSymbolContext, param:XSymbolValue)
		If param.type_ = XSymbolValue.TYPE_LIST
			Return XSymbolValue.CreateNumber(1)
		Else
			Return XSymbolValue.CreateNumber(0)
		End If
	End Function
	
	
	Function Null_:XSymbolValue(context:XSymbolContext, param:XSymbolValue)
		If param.type_ <> XSymbolValue.TYPE_LIST Then Return XSymbolValue.CreateNumber(0)
		If param.list.Count() = 0 Then Return XSymbolValue.CreateNumber(1)
		Return XSymbolValue.CreateNumber(0)
	End Function
	
	
	'get (list index)
	Function Get:XSymbolValue(context:XSymbolContext, param:XSymbolValue)
		If param.type_ <> XSymbolValue.TYPE_LIST Then Return XSymbolValue.Nil
		If param.list.Count() <> 2 Then Return XSymbolValue.Nil
		If param.list.Get(context, 1).type_ <> XSymbolValue.TYPE_LIST Then Return XSymbolValue.Nil
		If param.list.Get(context, 2).type_ <> XSymbolValue.TYPE_NUMBER Then Return XSymbolValue.Nil
		Return param.list.Get(context, 1).list.Get(context, param.list.Get(context, 2).number)
	End Function
	
	
	Function Index:XSymbolValue(context:XSymbolContext, param:XSymbolValue)
		If param.type_ <> XSymbolValue.TYPE_LIST Then Return XSymbolValue.Nil
		If param.list.Count() <> 2 Then Return XSymbolValue.Nil
		If param.list.Get(context, 1).type_ <> XSymbolValue.TYPE_LIST Then Return XSymbolValue.Nil
		If param.list.Get(context, 2).type_ <> XSymbolValue.TYPE_STRING Then Return XSymbolValue.Nil
		For Local i = 1 To param.list.Get(context, 1).list.Count() Step 2
			If (param.list.Get(context, 1).list.Get(context, i).type_ = XSymbolValue.TYPE_STRING) And (param.list.Get(context, 1).list.Get(context, i).str = param.list.Get(context, 2).str) And (i+1 <= param.list.Get(context, 1).list.Count()) Then Return XSymbolValue.CreateNumber(i+1)
		Next
		Return XSymbolValue.Nil
	End Function
	
	
	Function Cat:XSymbolValue(context:XSymbolContext, param:XSymbolValue)
		If param.type_ <> XSymbolValue.TYPE_LIST Then Return XSymbolValue.CreateList(XSymbolList.Create())
		If param.list.Count() <> 2 Then Return XSymbolValue.CreateList(XSymbolList.Create())
		If param.list.Get(context, 1).type_ <> XSymbolValue.TYPE_LIST Then Return XSymbolValue.CreateList(XSymbolList.Create())
		If param.list.Get(context, 2).type_ <> XSymbolValue.TYPE_LIST Then Return XSymbolValue.CreateList(XSymbolList.Create())
		Local list:XSymbolList = param.list.Get(context, 1).list.Copy(context)
		For Local i = 1 To param.list.Get(context, 2).list.Count()
			Select param.list.Get(context, 2).list.Get(context, i).type_
				Case XSymbolValue.TYPE_NUMBER
					list.Add(XSymbolValue.CreateNumber(param.list.Get(context, 2).list.Get(context, i).number))
				Case XSymbolValue.TYPE_STRING
					list.Add(XSymbolValue.CreateString(param.list.Get(context, 2).list.Get(context, i).str))
				Case XSymbolValue.TYPE_LIST
					list.Add(XSymbolValue.CreateList(param.list.Get(context, 2).list.Get(context, i).list.Copy(context)))
			End Select
		Next
		Return XSymbolValue.CreateList(list)
	End Function
	
	
	Function Random:XSymbolValue(context:XSymbolContext, param:XSymbolValue)
		If param.type_ <> XSymbolValue.TYPE_LIST Then Return XSymbolValue.Nil
		If param.list.Count() <> 2 Then Return XSymbolValue.Nil
		If param.list.Get(context, 1).type_ <> XSymbolValue.TYPE_NUMBER Then Return XSymbolValue.Nil
		If param.list.Get(context, 2).type_ <> XSymbolValue.TYPE_NUMBER Then Return XSymbolValue.Nil
		Return XSymbolValue.CreateNumber(Rand(param.list.Get(context, 1).number, param.list.Get(context, 2).number))
	End Function
	
	
	Function Val:XSymbolValue(context:XSymbolContext, param:XSymbolValue)
		If param.type_ <> XSymbolValue.TYPE_STRING Then Return XSymbolValue.Nil
		Return XSymbolValue.CreateNumber(param.str.ToDouble())
	End Function
	
	
	Function Str:XSymbolValue(context:XSymbolContext, param:XSymbolValue)
		If param.type_ <> XSymbolValue.TYPE_NUMBER Then Return XSymbolValue.CreateString("")
		Return XSymbolValue.CreateString(_PrintNumber(param.number))
	End Function
	
	
	Function StrCat:XSymbolValue(context:XSymbolContext, param:XSymbolValue)
		If param.type_ <> XSymbolValue.TYPE_LIST Then Return XSymbolValue.CreateString("")
		Local str$ = ""
		For Local i = 1 To param.list.Count()
			If param.list.Get(context, i).type_ <> XSymbolValue.TYPE_STRING Then Return XSymbolValue.CreateString("")
			str :+ param.list.Get(context, i).str
		Next
		Return XSymbolValue.CreateString(str)
	End Function
	

	Function Inc:XSymbolValue(context:XSymbolContext, param:XSymbolValue)
		If param.type_ <> XSymbolValue.TYPE_NUMBER Then Return XSymbolValue.Nil
		Return XSymbolValue.CreateNumber(param.number+1)
	End Function
	
	
	Function Dec:XSymbolValue(context:XSymbolContext, param:XSymbolValue)
		If param.type_ <> XSymbolValue.TYPE_NUMBER Then Return XSymbolValue.Nil
		Return XSymbolValue.CreateNumber(param.number-1)
	End Function
	
	
	Function Zero:XSymbolValue(context:XSymbolContext, param:XSymbolValue)
		If param.type_ <> XSymbolValue.TYPE_NUMBER Then Return XSymbolValue.Nil
		Return XSymbolValue.CreateNumber(param.number = 0)
	End Function
End Type
