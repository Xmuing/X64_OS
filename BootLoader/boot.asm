	org 0x7c00 ;指定程序起始地址

BaseOfStack equ 0x7c00

Label_Start :
	mov ax , cs
	mov ds , ax
	mov es , ax
	mov ss , ax
	mov sp , BaseOfStack


; ======= clear screen
;INT 10h, AH=06h 功能:按指定范围滚动窗口
	mov ax , 0600h	;AL＝ 滚动的列数，若为0则实现清空屏幕功能
	mov bx , 0700h	;BH＝液动后空出位置放入的属性
					;BH ＝颜色属性。
					;bit0～2:字体颜色{0:黑,l:蓝,2:绿,3:青,4:红,5:紫,6:综,7:白}
					;bit3	:字体亮度{0:字体正常,l:字体高亮度}
					;bit4～6:背景颜色{0:黑,1:蓝,2:绿,3:青,4:红,5:紫,6:综,7:白}
					;bit7	:字体闪烁{0:不闪烁,l:字体闪烁}
	mov cx , 0		;CH ＝滚动范围的左上角坐标列号;CL ＝滚动范围的左上角坐标行号
	mov dx , 0184fh	;DH＝ 滚动范围的右下角坐标列号;DL＝ 滚动范围的右下角坐标行号
	int 10h		

; ======= set focus
;INT 10h, AH=02h 功能:设定光标位置
	mov ax , 0200h
	mov bx , 0000h	;BH＝ 页码
	mov dx , 0000h	;DH＝ 游标的列数;DL＝游标的行数
	int 10h

; ======= display on screen . Start Booting ...
;INT 10h , AH=l3h 功能:显示一行字符串。
	mov ax , 1301h	;AL＝写入模式
					;AL=00h:字符串的属性由BL寄存器提供,而ex寄存器提供字符串长度(以B为单位),显示后光标位置不变,即显示前的光标位置。
					;AL=01h:同AL=00h,但光标会移动至字符串尾端位置。
					;AL=02h:字符串属性由每个字符后面紧跟的字节提供,故ex寄存器提供的字符串长度改成以Word为单位,显示后光标位置不变。
					;AL=03h:同AL=02h,但光标会移动至字符串尾端位置。
	mov bx , 000fh	;BH＝页码
					;BL＝字符属性／颜色属性
					;bit0～2:字体颜色{0:黑,l:蓝,2:绿,3:青,4:红,5:紫,6:综,7:白}
					;bit3	:字体亮度{0:字体正常,l:字体高亮度}
					;bit4～6:背景颜色{0:黑,1:蓝,2:绿,3:青,4:红,5:紫,6:综,7:白}
					;bit7	:字体闪烁{0:不闪烁,l:字体闪烁}
	mov dx , 0000h	;DH＝游标的坐标行号;DL＝游标的坐标列号
	mov cx , 10		;CX＝字符串的长度
	push ax
	mov ax , ds
	mov es , ax		;ES:BP＝＞要显示字符串的内存地址
	pop ax
	mov bp , StartBootMessage
	int 10h

;======= reset floppy
;INT 13h, AH=00h 功能:重置磁盘驱动器,为下一次读写软盘做准备
	xor ah , ah
	xor dl , dl		;DL＝驱动器号,00H～7FH:软盘:80H～0FFH:硬盘
					;DL=00h代表第一个软盘驱动器(“drive A:”)
					;DL=0lh代表第二个软盘驱动器(“drive B:”)
					;DL=80h代表第一个硬盘驱动器
					;DL=8lh代表第二个硬盘驱动器
	int 13h

	jmp $

	StartBootMessage : db "Start Boot"

; ======= fill zero until whole sector
	times 510 - ($ - $$) db 0	;将当前行被编译后的地址（机器码地址）减去本节（ Section ）程序的起始地址
	dw 0xaa55