import ldc.attributes;
import ldc.llvmasm;

extern(C):
@nogc:
nothrow:
@system:

__gshared @section(".isr_vector._reset") typeof(&resetHandler) _reset = &resetHandler;

/* register addresses */
__gshared
{
    const uint PORT_ADDRESS_BASE = 0x4100_8000;
    const uint PA_ADDRESS_BASE = PORT_ADDRESS_BASE + 0x80 * 0;
    const uint PC_ADDRESS_BASE = PORT_ADDRESS_BASE + 0x80 * 2;
    const uint PA_DIRSET_BASE = PA_ADDRESS_BASE + 0x08;
    const uint PA_OUTSET_BASE = PA_ADDRESS_BASE + 0x14;
    const uint PA_OUTCLR_BASE = PA_ADDRESS_BASE + 0x18;
    const uint PC_DIRCLR_BASE = PC_ADDRESS_BASE + 0x04;
    const uint PC_PINCFG26_BASE = PC_ADDRESS_BASE + 0x40 + 26;
    const uint PC_IN_BASE = PC_ADDRESS_BASE + 0x20;
}

enum uint PA_BIT_LED = 15;
enum uint PC_BIT_BUTTON1 = 26;

noreturn main()
{
    // Set pin configuration
    auto PA_DIRSET = cast(uint*) PA_DIRSET_BASE;
    *PA_DIRSET = 1 << PA_BIT_LED;
    auto PC_DIRCLR = cast(uint*) PC_DIRCLR_BASE;
    *PC_DIRCLR = 1 << PC_BIT_BUTTON1;
    auto PC_PINCFG26 = cast(uint*) PC_PINCFG26_BASE;
    *PC_PINCFG26 |= 1 << 1;

    auto PC_IN = cast(uint*) PC_IN_BASE;
    auto PA_OUTSET = cast(uint*) PA_OUTSET_BASE;
    auto PA_OUTCLR = cast(uint*) PA_OUTCLR_BASE;
    while (true)
    {
        const button1Input = *PC_IN & (1 << PC_BIT_BUTTON1);
        if (button1Input > 0)
        {
            *PA_OUTSET = 1 << PA_BIT_LED;
        }
        else
        {
            *PA_OUTCLR = 1 << PA_BIT_LED;
        }
    }
}

noreturn resetHandler()
{
    main();
    while (true)
    {
        __asm("wfi", "");
    }
}
