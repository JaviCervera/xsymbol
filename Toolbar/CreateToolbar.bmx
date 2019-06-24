Strict

Const ICONSIZE = 24

Local icons$[] = ["New.png", "Open.png", "Save.png", "Run.png", "Close.png"]

Graphics ICONSIZE*icons.length, ICONSIZE, 0

For Local i = 0 Until icons.length
	Local icon:TPixmap = ResizePixmap(LoadPixmap(icons[i]), ICONSIZE, ICONSIZE)
	DrawPixmap icon, i*ICONSIZE, 0
Next

SavePixmapPNG GrabPixmap(0, 0, ICONSIZE*icons.length, ICONSIZE), "Toolbar.png", 9