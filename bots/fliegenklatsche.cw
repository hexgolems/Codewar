;name: fliegenklatsche
;author: mompff
		jmp @worm
:loop	jmp 0 *-101-

:worm	mov ptr 1
		sti
		clk 4600 @loop
		mvp *0 *10-

