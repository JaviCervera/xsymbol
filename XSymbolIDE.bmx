Strict

Incbin "Toolbar/Toolbar.png"

Type XSymbolIDE
	Field win:TGadget
	Field toolbar:TGadget
	Field tabber:TGadget
	Field textareas:TGadget[]
	
	
	Function Create:XSymbolIDE(title$)
		Local ide:XSymbolIDE = New XSymbolIDE
		ide.win = CreateWindow(title$, 32, 32, 600, 300, Null, WINDOW_TITLEBAR | WINDOW_RESIZABLE)
		ide.toolbar = CreateToolBar("incbin::Toolbar/Toolbar.png", 0, 0, 0, 0, ide.win)
		ide.tabber = CreateTabber(0, GadgetHeight(ide.toolbar), ClientWidth(ide.win), ClientHeight(ide.win) - GadgetHeight(ide.toolbar), ide.win)
		SetGadgetLayout ide.tabber, 1,1,1,1
		ide.AddPage()
		Return ide
	End Function
	
	
	Method Run()
		Repeat
			Select WaitEvent()
				Case EVENT_APPTERMINATE
					Exit
				Case EVENT_WINDOWCLOSE
					PostEvent CreateEvent(EVENT_APPTERMINATE)
			End Select
		Forever
	End Method
	
	
	Method AddPage()
		AddGadgetItem tabber, "Page " + (CountGadgetItems(tabber) + 1)
		textareas = textareas[.. textareas.length+1]
		textareas[textareas.length-1] = CreateTextArea(0, 0, ClientWidth(tabber), ClientHeight(tabber), tabber)
		SetGadgetLayout textareas[textareas.length-1], 1, 1, 1, 1
		SetGadgetFont textareas[textareas.length-1], LoadGuiFont("Monaco", 10)
	End Method
End Type

XSymbolIDE.Create("XSymbol").Run()