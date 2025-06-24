ENTRY(resetHandler);

MEMORY
{
  /* Leave 16k for the default bootloader on the Wio Terminal */
  FLASH (rx)  : ORIGIN = 0x00000000 + 16K, LENGTH = 512K - 16K
  RAM   (rxw) : ORIGIN = 0x20000000, LENGTH = 192K
}

PROVIDE(_stack_start = ORIGIN(RAM) + LENGTH(RAM));


SECTIONS
{
  .isr_vector ORIGIN(FLASH) : ALIGN(4)
  {
    /* Vector table */
    _reset = .;
    LONG(_stack_start);
    KEEP(*(.isr_vector._reset));
  } > FLASH

  _stext = .;

  .text _stext : ALIGN(4)
  {
    /* Reset handler */
    KEEP(*(.text.resetHandler));

    /* the code */
    *(.text);
    *(.text*);
    _etext = .;
  } > FLASH

  /* __gshared immutable variables. */
  .rodata : ALIGN(4)
  {
    *(.rodata);
    *(.rodata*);
    . = ALIGN(4);
  } > FLASH

  /* uninitialized __gshared variables and C linkage. */
  .bss : ALIGN(4)
  {
    _sbss = .;
    *(.bss);
    *(.bss.*);
    . = ALIGN(4);
    _ebss = .;
  } > RAM

  /* __gshared variables. */
  .data : ALIGN(4)
  {
    _sidata = LOADADDR(.data);
    _sdata = .;
    *(.data);
    *(.data.*);
    . = ALIGN(4);
    _edata = .;
  } > RAM AT > FLASH

  /* The heap starts right after the .bss + .data section ends. */
  _sheap =_edata;

  /DISCARD/ :
  {
    *(.ARM.exidx*)
    *(.ARM.extab*)
    *(.note.gnu.build-id*)
    *(.ARM.attributes*)
    *(.comment)
  }
}
