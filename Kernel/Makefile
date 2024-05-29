
SYSTEM_OBJ += Objects/main.o
SYSTEM_OBJ += Objects/head.o

all:system
	objcopy -I elf64-x86-64 -S -R ".eh_frame" -R ".comment" -O binary system kernel.bin
	mv system Objects/

system:head.o main.o
	mv *.o Objects/
	ld -b elf64-x86-64 -o system ${SYSTEM_OBJ} -T Kernel.lds

head.o:head.S
	gcc -E head.S > Objects/head.s
	as --64 -o head.o Objects/head.s

main.o:main.c
	gcc -mcmodel=large -fno-builtin -m64 -c main.c

clean:
	rm -rf *.o *.s~ *.s *.S~ *.c~ *.h~ system  Makefile~ Kernel.lds~ kernel.bin 




