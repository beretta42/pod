

pod.dsk: pod.bin AUTOEXEC.BAS
	rm -f pod.dsk
	decb dskini pod.dsk
	decb copy -b -2 pod.bin pod.dsk,POD.BIN
	decb copy -a0l AUTOEXEC.BAS pod.dsk,AUTOEXEC.BAS

pod.bin: pod.asm
	lwasm -lpod.lst -mpod.map -b -opod.bin pod.asm

clean:
	rm -f pod.dsk pod.bin