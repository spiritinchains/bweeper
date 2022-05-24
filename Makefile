
QEMU=qemu-system-i386
AS=nasm
FNAME=bweeper

.PHONY: all clean run

all:
	$(AS) -f bin $(FNAME).asm -o $(FNAME).bin -l $(FNAME).lst
	tail -n 2 $(FNAME).lst | head -n 1 - | awk '{gsub ("^0*", "", $$2); print "0x"$$2}' | xargs printf "%d bytes\n"

clean:
	rm *.bin
	rm *.lst

run: all
	$(QEMU) -hda $(FNAME).bin
