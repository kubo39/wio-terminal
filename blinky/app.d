import ldc.attributes;
import ldc.llvmasm;

extern(C):
@nogc:
nothrow:
@system:

__gshared @section(".isr_vector._reset") typeof(&resetHandler) _reset = &resetHandler;

/* register addresses */
private __gshared
{
    const uint PORT_ADDRESS = 0x4100_8000;
    const uint PA_ADDRESS = PORT_ADDRESS + 0x80 * 0;
    const uint PC_ADDRESS = PORT_ADDRESS + 0x80 * 2;
    const uint PA_DIRSET = PA_ADDRESS + 0x08;
    const uint PA_OUTSET = PA_ADDRESS + 0x14;
    const uint PA_OUTCLR = PA_ADDRESS + 0x18;
    const uint PC_DIRCLR = PC_ADDRESS + 0x04;
    const uint PC_PINCFG26 = PC_ADDRESS + 0x40 + 26;
    const uint PC_IN = PC_ADDRESS + 0x20;
}

enum uint PA_BIT_LED = 15;
enum uint PC_BIT_BUTTON1 = 26;

private struct Uninitialized {}
private struct PushPullOutput {}

struct GpioA15Pin(T)
{
    @disable this(this);

    static if (is(T == Uninitialized))
    {
        GpioA15Pin!(PushPullOutput)* pushPullOutput()
        {
            // Set pin configuration
            *(cast(uint*) PA_DIRSET) = 1 << PA_BIT_LED;
            __gshared static GpioA15Pin!PushPullOutput pin;
            pin = GpioA15Pin!PushPullOutput();
            return &pin;
        }
    }

    static if (is(T == PushPullOutput))
    {
        void setHigh()
        {
            *(cast(uint*) PA_OUTSET) = 1 << PA_BIT_LED;
        }

        void setLow()
        {
            *(cast(uint*) PA_OUTCLR) = 1 << PA_BIT_LED;
        }
    }
}

GpioA15Pin!Uninitialized* getGpioA15Pin()
{
    __gshared static GpioA15Pin!Uninitialized uninitPin;
    uninitPin = GpioA15Pin!Uninitialized();
    return &uninitPin;
}

struct Led
{
private:
    GpioA15Pin!PushPullOutput* pin;

    @disable this(this);

public:
    this(GpioA15Pin!Uninitialized* pin) @nogc nothrow
    {
        this.pin = pin.pushPullOutput();
    }

    void turnOn() @nogc nothrow
    {
        this.pin.setHigh();
    }

    void turnOff() @nogc nothrow
    {
        this.pin.setLow();
    }
}

noreturn main()
{
    // Set pin configuration
    *(cast(uint*) PC_DIRCLR) = 1 << PC_BIT_BUTTON1;
    *(cast(uint*) PC_PINCFG26) |= 1 << 1;

    auto pin = getGpioA15Pin();
    auto led = Led(pin);

    while (true)
    {
        const button1Input = *(cast(uint*)PC_IN) & (1 << PC_BIT_BUTTON1);
        if (button1Input > 0)
        {
            led.turnOn();
        }
        else
        {
            led.turnOff();
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
