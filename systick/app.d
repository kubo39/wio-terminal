import ldc.attributes;
import ldc.llvmasm;

extern(C):
@nogc:
nothrow:
@system:

/**
volatileLoad/volatileStore intrinsic.
 */
pragma(LDC_intrinsic, "ldc.bitop.vld")
    ubyte volatileLoad(ubyte * ptr);
pragma(LDC_intrinsic, "ldc.bitop.vld")
    ushort volatileLoad(ushort* ptr);
pragma(LDC_intrinsic, "ldc.bitop.vld")
    uint volatileLoad(uint* ptr);
pragma(LDC_intrinsic, "ldc.bitop.vld")
    ulong volatileLoad(ulong * ptr);

pragma(LDC_intrinsic, "ldc.bitop.vst")
    void volatileStore(ubyte * ptr, ubyte value);
pragma(LDC_intrinsic, "ldc.bitop.vst")
    void volatileStore(ushort* ptr, ushort value);
pragma(LDC_intrinsic, "ldc.bitop.vst")
    void volatileStore(uint  * ptr, uint value);
pragma(LDC_intrinsic, "ldc.bitop.vst")
    void volatileStore(ulong * ptr, ulong value);


__gshared @section(".isr_vector._reset") typeof(&resetHandler) _reset = &resetHandler;

/* register addresses */
__gshared
{
    const uint PORT_ADDRESS = 0x4100_8000;
    const uint PA_ADDRESS = PORT_ADDRESS + 0x80 * 0;
    const uint PA_DIRSET = PA_ADDRESS + 0x08;
    const uint PA_OUTSET = PA_ADDRESS + 0x14;
    const uint PA_OUTCLR = PA_ADDRESS + 0x18;

    const uint SYST_ADDRESS = 0xE000_E010;
    const uint SYST_CSR = SYST_ADDRESS;
    const uint SYST_RVR = SYST_ADDRESS + 0x04;
    const uint SYST_CVR = SYST_ADDRESS + 0x08;
}

enum uint PA_BIT_LED = 15;
enum uint PC_BIT_BUTTON1 = 26;

enum uint SYST_CSR_ENABLE = 1 << 0;
//enum uint SYST_CSR_CLKSOURCE = 1 << 2;

enum uint CPU_FREQ_HZ = 120000000;

void delay(uint ms, uint* rvr, uint* cvr, uint* csr)
{
    uint ticks = (CPU_FREQ_HZ / 1000) - 1;
    volatileStore(rvr, ticks);
    volatileStore(cvr, 0);
    volatileStore(csr, SYST_CSR_ENABLE);

    foreach (uint i; 0 .. ms)
    {
        while ((volatileLoad(csr) & (1 << 16)) == 0) {}
    }
    volatileStore(cvr, 0);
}

void main()
{
    // Set pin configuration
    volatileStore(cast(uint*) PA_DIRSET, 1 << PA_BIT_LED);
    volatileStore(cast(uint*) SYST_CSR, 0);
    volatileStore(cast(uint*) SYST_CVR, 0);

    while (true)
    {
        volatileStore(cast(uint*) PA_OUTSET, 1 << PA_BIT_LED);
        delay(1000, cast(uint*) SYST_RVR, cast(uint*) SYST_CVR, cast(uint*) SYST_CSR);

        volatileStore(cast(uint*) PA_OUTCLR, 1 << PA_BIT_LED);
        delay(1000, cast(uint*) SYST_RVR, cast(uint*) SYST_CVR, cast(uint*) SYST_CSR);
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
