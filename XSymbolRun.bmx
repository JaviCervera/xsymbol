Strict

Framework BRL.Retro

Include "XSymbol.bmx"
Include "XSymbolLibrary.bmx"

'Config command line
If AppArgs.length < 2 Then Print "Usage: xsymbol <script> [params...]"; End
Local file$ = AppArgs$[1]
Local list:XSymbolList = XSymbolList.Create()
For Local i = 2 Until AppArgs.length
	list.Add(XSymbolValue.CreateString(AppArgs$[i]))
Next

'Set random number seed
SeedRnd MilliSecs()

Local context:XSymbolContext = XSymbolContext.Create()
XSymbolLibrary.AddStandard(context)
context.RunFile(file$, "main", XSymbolValue.CreateList(list))