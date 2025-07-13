.PHONY: all
all: build

.PHONY: build
build:
	ldc2 \
		-mtriple=thumbv7em-none-unknown-gnueabihf \
		-betterC \
		--boundscheck=off \
		-relocation-model=static \
		-Os \
		-c \
		-of=systick.o \
		app.d
	arm-none-eabi-ld \
		-T layout.ld \
		-nostdlib \
		-o systick.elf \
		systick.o

.PHONY: flash
flash: build
	llvm-objcopy -O binary systick.elf systick.bin
	hf2 -v 0x2886 -p 0x002d flash -f systick.bin -a 0x4000
