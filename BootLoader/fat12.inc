RootDirSectors			equ 14	;根目录扇区总数,这个数值是根据FAT12文件系统提供的信息经过计算而得
								;(BPB_RootEntCnt*32+BPB_BytesPerSec-1)/BPB_BytesPerSec = (224×32+512 -1)/512 = 14
SectorNumOfRootDirStart	equ 19	;根目录起始扇区号,这个数值也是通过计算而得
								;保留扇区数+FAT表扇区数＊FAT表份数＝ 1+9*2 = 19,因为扇区编号的计数值从0开始,故根目录的起始扇区号为19
SectorNumOfFAT1Start	equ 1	;FAT1表的起始扇区号,在FAT1表前面只有一个保留扇区(引导扇区,扇区编号是0),那么FAT1表的起始扇区号理应为1
SectorBalance			equ 17	;用于平衡文件（或者目录）的起始簇号与数据区起始簇号的差值.
								;因为数据区对应的有效簇号是2(FAT[2]),为了正确计算出FAT表项对应的数据区起始扇区号,则必须将FAT表项值减2
								;或者将数据区的起始簇号(扇区号)减2(仅在每簇由一个扇区组成时可用).
								;起始扇区号为33(根目录起始扇区号+根目录扇区总数 = 19+14 = 33）
 
	BS_OEMName 		db 'X64_boot'	;OEM字符串，必须为 8 个字符，不足会以空格填充
	BPB_BytesPerSec dw 512			;每个扇区字节数
	BPB_SecPerClus 	db 1			;每簇占用的扇区数
	BPB_RsvdSecCnt 	dw 1			;Boot占用的扇区数
	BPB_NumFATs 	db 2			;FAT表的数量
	BPB_RootEntCnt 	dw 224			;根目录可容纳的目录项数
	BPB_TotSec16 	dw 2880			;逻辑扇区总数
	BPB_Media 		db 0xf0			;媒体描述符
	BPB_FATSzl6 	dw 9			;每个FAT占用扇区数
	BPB_SecPerTrk 	dw 18			;每个磁道扇区数
	BPB_NumHeads 	dw 2			;磁头数
	BPB_hiddSec 	dd 0			;隐藏扇区数
	BPB_TotSec32 	dd 0			;若BPB_TotSec16是0，则在这里记录扇区总数
	BS_DrvNum 		db 0			;中断 13(int 13h)的驱动器号
	BS_Reservedl 	db 0			;未使用
	BS_BootSig 		db 29h			;扩展引导标志
	BS_VolID 		dd 0			;卷序列号
	BS_VolLab		db 'boot_loader';卷标，必须为11个字符，不足会以空格填充
	BS_FileSysType	db 'FAT12   '	;文件系统类型，必须是8个字符，不足以空格填充
