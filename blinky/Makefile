.PHONY: all
all: build

.PHONY: build
build:
	ldc2 \
		-mtriple=thumbv7em-none-unknown-gnueabihf \
		-betterC \
		--boundscheck=off \
		-defaultlib= \
		-relocation-model=static \
		-Os \
		-c \
		-of=blinky.o \
		app.d
	arm-none-eabi-ld \
		-T layout.ld \
		-nostdlib \
		-o blinky.elf \
		blinky.o

.PHONY: flash
flash: build
	llvm-objcopy -O binary blinky.elf blinky.bin
	hf2 -v 0x2886 -p 0x002d flash -f blinky.bin -a 0x4000
