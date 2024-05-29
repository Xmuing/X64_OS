org 0x7c00 ;指定程序起始地址

BaseOfStack 	equ 0x7c00	;定义栈指针
BaseOfLoader 	equ 0x1000
OffsetOfLoader 	equ 0x00	;与BaseOfLoader组合成为Loader程序的物理地址
							;BaseOfLoader<<4+OffsetOfLoader=0x10000

	jmp short Label_Start
	nop
	%include "fat12.inc"


; ======= temp value
RootDirSizeForLoop dw RootDirSectors
SectorNo dw 0
Odd db 0

; ======= display message
StartBootMessage : db "Start Boot"
NoLoaderMessage : db "ERROR:No LOADER Found"
LoaderFileName  : db "LOADER  BIN", 0

; ======= 引导代码，由偏移0字节(BS_JmpBoot)跳转过来
Label_Start:
	mov ax, cs
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov sp, BaseOfStack
; ======= clear screen
	;INT 10h, AH=06h 功能:按指定范围滚动窗口
	mov ax, 0600h	;AL＝ 滚动的列数，若为0则实现清空屏幕功能
	mov bx, 0700h	;BH＝液动后空出位置放入的属性
					;BH ＝颜色属性。
					;bit0～2:字体颜色{0:黑,l:蓝,2:绿,3:青,4:红,5:紫,6:综,7:白}
					;bit3	:字体亮度{0:字体正常,l:字体高亮度}
					;bit4～6:背景颜色{0:黑,1:蓝,2:绿,3:青,4:红,5:紫,6:综,7:白}
					;bit7	:字体闪烁{0:不闪烁,l:字体闪烁}
	mov cx, 0		;CH ＝滚动范围的左上角坐标列号;CL ＝滚动范围的左上角坐标行号
	mov dx, 0184fh	;DH＝ 滚动范围的右下角坐标列号;DL＝ 滚动范围的右下角坐标行号
	int 10h		
; ======= set focus
	;INT 10h, AH=02h 功能:设定光标位置
	mov ax, 0200h
	mov bx, 0000h	;BH＝ 页码
	mov dx, 0000h	;DH＝ 游标的列数;DL＝游标的行数
	int 10h
; ======= display on screen . Start Booting ...
	;INT 10h , AH=l3h 功能:显示一行字符串。
	mov ax, 1301h	;AL＝写入模式
					;AL=00h:字符串的属性由BL寄存器提供,而ex寄存器提供字符串长度(以B为单位),显示后光标位置不变,即显示前的光标位置。
					;AL=01h:同AL=00h,但光标会移动至字符串尾端位置。
					;AL=02h:字符串属性由每个字符后面紧跟的字节提供,故ex寄存器提供的字符串长度改成以Word为单位,显示后光标位置不变。
					;AL=03h:同AL=02h,但光标会移动至字符串尾端位置。
	mov bx, 000fh	;BH＝页码
					;BL＝字符属性／颜色属性
					;bit0～2:字体颜色{0:黑,l:蓝,2:绿,3:青,4:红,5:紫,6:综,7:白}
					;bit3	:字体亮度{0:字体正常,l:字体高亮度}
					;bit4～6:背景颜色{0:黑,1:蓝,2:绿,3:青,4:红,5:紫,6:综,7:白}
					;bit7	:字体闪烁{0:不闪烁,l:字体闪烁}
	mov dx, 0000h	;DH＝游标的坐标行号;DL＝游标的坐标列号
	mov cx, 10		;CX＝字符串的长度
	push ax
	mov ax, ds
	mov es, ax		;ES:BP＝＞要显示字符串的内存地址
	pop ax
	mov bp, StartBootMessage
	int 10h
;======= reset floppy
	;INT 13h, AH=00h 功能:重置磁盘驱动器,为下一次读写软盘做准备
	xor ah, ah
	xor dl, dl		;DL＝驱动器号,00H～7FH:软盘:80H～0FFH:硬盘
					;DL=00h代表第一个软盘驱动器(“drive A:”)
					;DL=0lh代表第二个软盘驱动器(“drive B:”)
					;DL=80h代表第一个硬盘驱动器
					;DL=8lh代表第二个硬盘驱动器
	int 13h
	; jmp $
;======= search loader bin
	mov word [SectorNo], SectorNumOfRootDirStart
Label_Search_In_Root_Dir_Begin:
	cmp word [RootDirSizeForLoop], 0
	jz Label_No_LoaderBin
	dec word [RootDirSizeForLoop]
	mov ax, 00h
	mov es, ax
	mov bx, 8000h
	mov ax, [SectorNo]
	mov cl, 1
	call Func_ReadOneSector
	mov si, LoaderFileName
	mov di, 8000h
	cld
	mov dx, 10h						;每个扇区可容纳的目录项个数(512/132=16=0x10)

Label_Search_For_LoaderBin:
	cmp dx, 0
	jz Label_Goto_Next_Sector_In_Root_Dir
	dec dx
	mov cx, 11						;目录项的文件名长度(文件名长度为llB,包括文件名和扩展名,但不包含分隔符“.”)

Label_Cmp_FileName:
	cmp cx, 0
	jz Label_FileName_Found
	dec cx
	lodsb
	cmp al, byte [es:di]
	jz Label_Go_On
	jmp Label_Different

Label_Go_On:
	inc di
	jmp Label_Cmp_FileName

Label_Different:
	and di, 0ffe0h
	add di, 20h
	mov si, LoaderFileName
	jmp Label_Search_For_LoaderBin

Label_Goto_Next_Sector_In_Root_Dir:
	add word [SectorNo], 1
	jmp Label_Search_In_Root_Dir_Begin

; ======= Found Loader.bin
Label_FileName_Found:
	mov ax, RootDirSectors
	and di, 0ffe0h
	add di, 01ah
	mov cx, word [es:di]
	push cx
	add cx, ax
	add cx, SectorBalance
	mov ax, BaseOfLoader
	mov es, ax
	mov bx, OffsetOfLoader
	mov ax, cx

Label_Go_On_Loading_File:
	push ax
	push bx
	mov ah, 0eh
	mov al, '.'
	mov bl, 0fh
	int 10h
	pop bx
	pop ax

	mov cl, 1
	call Func_ReadOneSector
	pop ax
	call Func_GetFATEntry
	cmp ax, 0fffh
	jz Label_File_Loaded
	push ax
	mov dx, RootDirSectors
	add ax, dx
	add ax, SectorBalance
	add bx, [BPB_BytesPerSec]
	jmp Label_Go_On_Loading_File

Label_File_Loaded:
	jmp BaseOfLoader:OffsetOfLoader

; ======= Didn't found Loader.bin
Label_No_LoaderBin:
	; ======= display on screen : ERROR:NO LOADER FOUND
	mov ax, 1301h
	mov bx, 008ch
	mov dx, 0100h
	mov cx, 21
	push ax
	mov ax, ds
	mov es, ax
	pop ax
	mov bp, NoLoaderMessage
	int 10h
	jmp $

; ============================== FAT12 Operation ============================== ;
; ======= read one sector from floppy
Func_ReadOneSector:
	;软盘读取功能;
	;输入参数:
	;AX＝待读取的磁盘起始扇区号,LBA (Logical Block Address,逻辑块寻址)格式
	;CL=读入的扇区数量
	;ES:BX＝＞目标缓冲区起始地址

	;保存栈帧寄存器和栈寄存器的数值
	push bp
	mov bp, sp
	sub esp, 2
	mov byte [bp-2], cl
	push bx

	;LBA格式转换为CHS格式
	mov bl, [BPB_SecPerTrk]
	div bl					;LBA扇区号÷每磁道扇区数,商AL(目标磁道号),余数AH(目标磁道内的起始扇区号)
	inc ah					;起始扇区号＝AH+l
	mov cl, ah				;CL＝扇区号l～63(bit0～5)和磁道号(柱面号)的高2位(bit6～7)(只对硬盘有效)
	mov dh, al				;DH＝磁头号=AL
	shr al, 1				
	mov ch, al				;CH＝磁道号(柱面号)的低8位＝AL>>1
	and dh, 1				;DH＝AL&1
	pop bx					
	mov dl, [BS_DrvNum]		;DL＝驱动器号(如果操作的是硬盘驱动器,bit7必须被置位)

Label_Go_On_Reading:
	;INT 13h AH= 02h 实现软盘扇区的读取操作
	mov ah, 2
	mov al, byte [bp-2]	;AL＝读人的扇区数(必须非0)
	int 13h
	jc Label_Go_On_Reading
	add esp, 2
	pop bp
	ret

; ======= get FAT Entry
Func_GetFATEntry:
	push es
	push bx
	push ax
	mov ax, 00
	mov es, ax
	pop ax
	mov byte [Odd], 0
	mov bx, 3
	mul bx
	mov bx, 2
	div bx
	cmp dx, 0
	jz Label_Even
	mov byte [Odd], 1

Label_Even:
	xor dx, dx
	mov bx, [BPB_BytesPerSec]
	div bx
	push dx
	mov bx, 8000h
	add ax, SectorNumOfFAT1Start
	mov cl, 2
	call Func_ReadOneSector

	pop dx
	add bx, dx
	mov ax, [es:bx]
	cmp byte [Odd], 1
	jnz Label_Even_2
	shr ax, 4

Label_Even_2:
	and ax, 0fffh
	pop bx
	pop es
	ret

; ======= fill zero until whole sector
	times 510 - ($ - $$) db 0	;将当前行被编译后的地址（机器码地址）减去本节（ Section ）程序的起始地址
	dw 0xaa55

