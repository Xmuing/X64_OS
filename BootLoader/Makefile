BOOT_OBJ = boot.asm
LOADER_OBJ = loader.asm
FS_OBJ = fat12.inc
IMG_OBJ = boot.img

IMG_OBJ:boot.bin loader.bin
	$(shell dd if=boot.bin of=boot.img bs=512 count=1 conv=notrunc)
	$(shell sudo mount boot.img /media/)
	$(shell sudo cp loader.bin /media/)
	$(shell sudo cp ../Kernel/kernel.bin /media/)
	$(shell sync)
	$(shell sudo umount /media/)

boot.bin:${BOOT_OBJ} ${FS_OBJ}
	nasm ${BOOT_OBJ} -o boot.bin

loader.bin:${LOADER_OBJ} ${FS_OBJ}
	nasm ${LOADER_OBJ} -o loader.bin

clean:
	rm *.bin