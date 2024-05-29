org 10000h
	jmp Label_Start

	%include	"fat12.inc"

BaseOfKernelFile		equ	0x00
OffsetOfKernelFile		equ	0x100000

BaseTmpOfKernelAddr		equ	0x00
OffsetTmpOfKernelFile	equ	0x7E00

MemoryStructBufferAddr	equ	0x7E00

;=======	tmp IDT
IDT:
	times	0x50	dq	0
IDT_END:
 
IDT_POINTER:
		dw	IDT_END - IDT - 1
		dd	IDT
 
;=======	tmp variable
RootDirSizeForLoop		dw RootDirSectors
SectorNo				dw 0
Odd						db 0
OffsetOfKernelFileCount	dd OffsetOfKernelFile
DisplayPosition			dd 0
 
;=======	display messages
StartLoaderMessage:				db "Start Loader"
NoKernelMessage:				db "ERROR:No KERNEL Found"
KernelFileName:					db "KERNEL  BIN",0
StartGetMemStructMessage:		db "Start Get Memory Struct."
GetMemStructErrMessage:			db "Get Memory Struct ERROR"
GetMemStructOKMessage:			db "Get Memory Struct SUCCESSFUL!"
StartGetSVGAVBEInfoMessage:		db "Start Get SVGA VBE Info"
GetSVGAVBEInfoErrMessage:		db "Get SVGA VBE Info ERROR"
GetSVGAVBEInfoOKMessage:		db "Get SVGA VBE Info SUCCESSFUL!"
StartGetSVGAModeInfoMessage:	db "Start Get SVGA Mode Info"
GetSVGAModeInfoErrMessage:		db "Get SVGA Mode Info ERROR"
GetSVGAModeInfoOKMessage:		db "Get SVGA Mode Info SUCCESSFUL!"

[SECTION gdt]
;Globad Desc1iptor Table,全局描述符表
LABEL_GDT:			dd	0,0
LABEL_DESC_CODE32:	dd	0x0000FFFF,0x00CF9A00
LABEL_DESC_DATA32:	dd	0x0000FFFF,0x00CF9200
 
GdtLen	equ	$ - LABEL_GDT
GdtPtr	dw	GdtLen - 1
		dd	LABEL_GDT
 
SelectorCode32	equ	LABEL_DESC_CODE32 - LABEL_GDT
SelectorData32	equ	LABEL_DESC_DATA32 - LABEL_GDT

[SECTION gdt64]
LABEL_GDT64:		dq	0x0000000000000000
LABEL_DESC_CODE64:	dq	0x0020980000000000
LABEL_DESC_DATA64:	dq	0x0000920000000000
 
GdtLen64	equ	$ - LABEL_GDT64
GdtPtr64	dw	GdtLen64 - 1
			dd	LABEL_GDT64
 
SelectorCode64	equ	LABEL_DESC_CODE64 - LABEL_GDT64
SelectorData64	equ	LABEL_DESC_DATA64 - LABEL_GDT64


[SECTION .s16]
[BITS 16]
Label_Start:
	mov ax , cs
	mov ds , ax
	mov es , ax
	mov ax , 0x00
	mov ss , ax
	mov sp, 0x7c00

; ======= display on screen . Start Loader ...
	mov ax, 1301h
	mov bx, 000fh	
	mov dx, 0100h	;row 1
	mov cx, 12		
	push ax
	mov ax, ds
	mov es, ax
	pop ax
	mov bp, StartLoaderMessage
	int 10h

;======= open address A20
	;开启A20功能的常用方法是操作键盘控制器,由于键盘控制器是低速设备,以至于功能开启速度相对较慢
	;A20快速门(Fast Gate A20),它使用I/O端口Ox92来处理A20信号线.对于不含键盘控制器的操作系统,就只能使用0x92端口来控制,但是该端口有可能被其他设备使用
	;使用BIOS中断服务程序INT15h的主功能号AX=2401可开启A20地址线,功能号AX=2400可禁用A20地址线,功能号AX=2403可查询A20地址线的当前状态
	;还有一种方法是,通过读Oxee端口来开启A20信号线,而写该端口则会禁止A20信号线
	;本系统通过访问A20快速门来开启A20功能，即置位Ox92端口的第1位
	push ax
	in al,	92h
	or al,	00000010b
	out 92h, al
	pop ax
	
	cli				;关闭外部中断
 
	;进入保护模式
	db 0x66
	lgdt [GdtPtr]	;加载保护模式结构数据信息
 
	mov eax, cr0
	or eax,	1
	mov cr0, eax	;置位CR0寄存器的第0位来开启保护模式
 
	;为FS段寄存器加载新的数据段值,借助FS段寄存器的特殊寻址能力,就可将内核程序移动到1MB以上的内存地址空间中
	;寻址能力从20位(1MB)扩展到32位(4GB)
	;如果重新对其赋值的话,那么它就会失去特殊能力
	mov	ax,	SelectorData32
	mov	fs,	ax
	mov	eax, cr0
	and	al,	11111110b
	mov	cr0, eax
 
	sti				;开启外部中断

;= ====== search kernel.bin
	mov	word	[SectorNo],	SectorNumOfRootDirStart
Label_Search_In_Root_Dir_Begin:
	cmp word [RootDirSizeForLoop], 0
	jz Label_No_KernelBin
	dec word [RootDirSizeForLoop]
	mov ax, 00h
	mov es, ax
	mov bx, 8000h
	mov ax, [SectorNo]
	mov cl, 1
	call Func_ReadOneSector
	mov si, KernelFileName
	mov di, 8000h
	cld
	mov dx, 10h						;每个扇区可容纳的目录项个数(512/132=16=0x10)

Label_Search_For_KernelBin:
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
	mov si, KernelFileName
	jmp Label_Search_For_KernelBin

Label_Goto_Next_Sector_In_Root_Dir:
	add word [SectorNo], 1
	jmp Label_Search_In_Root_Dir_Begin

; ======= Didn't found kernel.bin
Label_No_KernelBin:
	; ======= display on screen : ERROR : No KERNEL Found
	mov ax, 1301h
	mov bx, 008ch
	mov dx, 0200h
	mov cx, 21
	push ax
	mov ax, ds
	mov es, ax
	pop ax
	mov bp, NoKernelMessage
	int 10h
	jmp $

; ======= Found kernel.bin
Label_FileName_Found:
	mov ax, RootDirSectors
	and di, 0ffe0h
	add di, 01ah
	mov cx, word [es:di]
	push cx
	add cx, ax
	add cx, SectorBalance
	mov ax, BaseTmpOfKernelAddr		;BaseOfKernelFile
	mov es, ax
	mov bx, OffsetTmpOfKernelFile	;OffsetOfKernelFile
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

;;;;;;;;;;;;;;;;;;;;;;;	
	;将内核程序读取到临时转存空间中
	push cx
	push eax
	push fs
	push edi
	push ds
	push esi
 
	mov	cx,	200h
	mov	ax,	BaseOfKernelFile
	mov	fs,	ax
	mov	edi, dword [OffsetOfKernelFileCount]
 
	mov	ax,	BaseTmpOfKernelAddr
	mov	ds,	ax
	mov	esi, OffsetTmpOfKernelFile
 
Label_Mov_Kernel:	;一个字节一个字节的复制
	mov	al,	byte [ds:esi]
	mov	byte [fs:edi], al ;只适用于bochs虚拟机,实际fs值改变后寻址能力恢复为20位
 
	inc	esi
	inc	edi
 
	loop Label_Mov_Kernel
 
	mov	eax, 0x1000
	mov	ds,	eax
 
	mov	dword [OffsetOfKernelFileCount],	edi
 
	pop	esi
	pop	ds
	pop	edi
	pop	fs
	pop	eax
	pop	cx
;;;;;;;;;;;;;;;;;;;;;;;	
	call Func_GetFATEntry
	cmp	ax,	0FFFh
	jz	Label_File_Loaded
	push ax
	mov	dx,	RootDirSectors
	add	ax,	dx
	add	ax,	SectorBalance
 
	jmp	Label_Go_On_Loading_File
 
Label_File_Loaded:
	mov	ax, 0B800h
	mov	gs, ax
	mov	ah, 0Fh				; 0000: 黑底    1111: 白字
	mov	al, 'G'
	mov	[gs:((80 * 0 + 39) * 2)], ax	; 屏幕第 0 行, 第 39 列。
	
KillMotor:
	;加载完成,关闭软盘驱动
	push dx
	mov	dx,	03F2h
	mov	al,	0	
	out	dx,	al
	pop	dx

;=======	get memory address size type
	mov	ax,	1301h
	mov	bx,	000Fh
	mov	dx,	0300h		;row3
	mov	cx,	24
	push	ax
	mov	ax,	ds
	mov	es,	ax
	pop	ax
	mov	bp,	StartGetMemStructMessage
	int	10h
 
	mov	ebx, 0
	mov	ax,	0x00
	mov	es,	ax
	mov	di,	MemoryStructBufferAddr	
 
Label_Get_Mem_Struct:
	mov	eax, 0x0E820
	mov	ecx, 20
	mov	edx, 0x534D4150
	int	15h
	jc	Label_Get_Mem_Fail
	add	di,	20
 
	cmp	ebx,	0
	jne	Label_Get_Mem_Struct
	jmp	Label_Get_Mem_OK
 
Label_Get_Mem_Fail:
	mov	ax,	1301h
	mov	bx,	008Ch
	mov	dx,	0400h		;row4
	mov	cx,	23
	push ax
	mov	ax,	ds
	mov	es,	ax
	pop	ax
	mov	bp,	GetMemStructErrMessage
	int	10h
	jmp	$
 
Label_Get_Mem_OK:
	mov	ax,	1301h
	mov	bx,	000Fh
	mov	dx,	0500h		;row5
	mov	cx,	29
	push ax
	mov	ax,	ds
	mov	es,	ax
	pop	ax
	mov	bp,	GetMemStructOKMessage
	int	10h	

;=======	get SVGA information
	mov	ax,	1301h
	mov	bx,	000Fh
	mov	dx,	0800h		;row 8
	mov	cx,	23
	push	ax
	mov	ax,	ds
	mov	es,	ax
	pop	ax
	mov	bp,	StartGetSVGAVBEInfoMessage
	int	10h
 
	mov	ax,	0x00
	mov	es,	ax
	mov	di,	0x8000
	mov	ax,	4F00h
 
	int	10h
 
	cmp	ax,	004Fh
 
	jz	.KO
	
;=======	Fail
	mov	ax,	1301h
	mov	bx,	008Ch
	mov	dx,	0900h		;row 9
	mov	cx,	23
	push	ax
	mov	ax,	ds
	mov	es,	ax
	pop	ax
	mov	bp,	GetSVGAVBEInfoErrMessage
	int	10h
 
	jmp	$
 
.KO:
	mov	ax,	1301h
	mov	bx,	000Fh
	mov	dx,	0A00h		;row 10
	mov	cx,	29
	push	ax
	mov	ax,	ds
	mov	es,	ax
	pop	ax
	mov	bp,	GetSVGAVBEInfoOKMessage
	int	10h
 
;=======	Get SVGA Mode Info
	mov	ax,	1301h
	mov	bx,	000Fh
	mov	dx,	0C00h		;row 12
	mov	cx,	24
	push	ax
	mov	ax,	ds
	mov	es,	ax
	pop	ax
	mov	bp,	StartGetSVGAModeInfoMessage
	int	10h
 
 
	mov	ax,	0x00
	mov	es,	ax
	mov	si,	0x800e
 
	mov	esi,	dword	[es:si]
	mov	edi,	0x8200
 
Label_SVGA_Mode_Info_Get:
	mov	cx,	word	[es:esi]
 
;=======	display SVGA mode information
	push	ax
	
	mov	ax,	00h
	mov	al,	ch
	call	Func_DispAL
 
	mov	ax,	00h
	mov	al,	cl	
	call	Func_DispAL
	
	pop	ax
 
;=======
	cmp	cx,	0FFFFh
	jz	Label_SVGA_Mode_Info_Finish
 
	mov	ax,	4F01h
	int	10h
 
	cmp	ax,	004Fh
 
	jnz	Label_SVGA_Mode_Info_FAIL	
 
	add	esi,	2
	add	edi,	0x100
 
	jmp	Label_SVGA_Mode_Info_Get
		
Label_SVGA_Mode_Info_FAIL:
	mov	ax,	1301h
	mov	bx,	008Ch
	mov	dx,	0D00h		;row 13
	mov	cx,	24
	push	ax
	mov	ax,	ds
	mov	es,	ax
	pop	ax
	mov	bp,	GetSVGAModeInfoErrMessage
	int	10h
 
Label_SET_SVGA_Mode_VESA_VBE_FAIL:
	jmp	$
 
Label_SVGA_Mode_Info_Finish:
	mov	ax,	1301h
	mov	bx,	000Fh
	mov	dx,	0E00h		;row 14
	mov	cx,	30
	push	ax
	mov	ax,	ds
	mov	es,	ax
	pop	ax
	mov	bp,	GetSVGAModeInfoOKMessage
	int	10h

;=======	set the SVGA mode(VESA VBE)
	;设置SVGA芯片的显示模式
	mov	ax,	4F02h	
	mov	bx,	4180h	;========================mode : 0x180 or 0x143
	int 	10h
 
	cmp	ax,	004Fh
	jnz	Label_SET_SVGA_Mode_VESA_VBE_FAIL

;=======	init IDT GDT goto protect mode 
	cli			;======close interrupt
 
	db	0x66
	lgdt	[GdtPtr]
 
;	db	0x66
;	lidt	[IDT_POINTER]
 
	mov	eax,	cr0
	or	eax,	1
	mov	cr0,	eax	
 
	jmp	dword SelectorCode32:GO_TO_TMP_Protect
 
[SECTION .s32]
[BITS 32]
GO_TO_TMP_Protect:
	;=======	go to tmp long mode
	mov	ax,	0x10
	mov	ds,	ax
	mov	es,	ax
	mov	fs,	ax
	mov	ss,	ax
	mov	esp,	7E00h
 
	call	support_long_mode
	test	eax,	eax
 
	jz	no_support
 
;=======	init temporary page table 0x90000
	mov	dword	[0x90000],	0x91007
	mov	dword	[0x90800],	0x91007		
 
	mov	dword	[0x91000],	0x92007
 
	mov	dword	[0x92000],	0x000083
 
	mov	dword	[0x92008],	0x200083
 
	mov	dword	[0x92010],	0x400083
 
	mov	dword	[0x92018],	0x600083
 
	mov	dword	[0x92020],	0x800083
 
	mov	dword	[0x92028],	0xa00083
 
;=======	load GDTR
	db	0x66
	lgdt	[GdtPtr64]
	mov	ax,	0x10
	mov	ds,	ax
	mov	es,	ax
	mov	fs,	ax
	mov	gs,	ax
	mov	ss,	ax
 
	mov	esp,	7E00h
 
;=======	open PAE
	mov	eax,	cr4
	bts	eax,	5
	mov	cr4,	eax
 
;=======	load	cr3
	mov	eax,	0x90000
	mov	cr3,	eax
 
;=======	enable long-mode
	mov	ecx,	0C0000080h		;IA32_EFER
	rdmsr
 
	bts	eax,	8
	wrmsr
 
;=======	open PE and paging
	mov	eax,	cr0
	bts	eax,	0
	bts	eax,	31
	mov	cr0,	eax
 
	jmp	SelectorCode64:OffsetOfKernelFile
 
;=======	test support long mode or not
support_long_mode:
	mov	eax,	0x80000000
	cpuid
	cmp	eax,	0x80000001
	setnb	al	
	jb	support_long_mode_done
	mov	eax,	0x80000001
	cpuid
	bt	edx,	29
	setc	al

support_long_mode_done:
	movzx	eax,	al
	ret
 
;=======	no support
no_support:
	jmp	$

[SECTION .s16lib]
[BITS 16]
; ============================== SCREEN Operation ============================== ;
;=======	display num in al
Func_DispAL:
	;AL＝要显示的十六进制数
	push ecx
	push edx
	push edi
	
	mov	edi,	[DisplayPosition]
	mov	ah,	0Fh
	mov	dl,	al
	shr	al,	4
	mov	ecx, 2

.begin:
	and	al,	0Fh
	cmp	al,	9
	ja	.1
	add	al,	'0'
	jmp	.2

.1:
	sub	al,	0Ah
	add	al,	'A'

.2:
	mov	[gs:edi], ax
	add	edi, 2
	
	mov	al,	dl
	loop .begin
 
	mov	[DisplayPosition], edi
 
	pop	edi
	pop	edx
	pop	ecx
	
	ret
 
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





