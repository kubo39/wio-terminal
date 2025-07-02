# 組み込みプログラミングのデザイン

## 先行者について

Rustのembedded-halとかTinyGoとか

### embedded-hal (Rust)

- ドライバオブジェクトが複数にならないようにperipheralsオブジェクトは二回目以降Noneを返す
  - またperipheralsはCopy/Cloneできない型になっている
  - 「ハードウェアは本質的にシングルトン」を型で表現しているといえる
  - あるリソース(Pinとか)へのアクセスは同時にたかだが一つ
- Traits+Genericsで型安全な設計
  - 有効/無効の状態を型パラメータで表現
  - Pinが準備できていない状態で行ってはいけない操作を型エラーにできる

## 以上を踏まえて

欲しい機能・テクニックとして

- コピーできない型
- シングルトンパターンをAPIで表現したい
- テンプレートパラメータを使った型安全な設計

### コピーできない型

`@disable this(this)`でnon-copyableな型を表現できる。

```d
struct GpioPin
{
    @disable this(this);
}
```

### シングルトンパターンをAPIで表現したい

常に関数を通して取得するのがいいのかな。

```d
struct GpioPin
{
    @disable this(this);
}

GpioPin* getGpioPin()
{
    static gpioPin = GpioPin();
    return &gpioPin;
}

void main()
{
    auto pinFirst = getGpioPin;

    /// embedded-hal的にはNone相当が返ってきてほしいが、
    /// とりあえずシングルトンパターンの実装ということで
    auto pinSecond = getGpioPin;
}
```

### 型安全な設計

雑にembedded-halを踏襲するとこんな感じか。

```d
private struct Uninitialized {}
private struct PushPullOutput {}

struct Pin
{
    @disable this(this);
}

struct GpioPin(T)
{
    private Pin* pin;

    @disable this(this);

    this(Pin* pin)
    {
        this.pin = pin;
    }

    static if (is(T == Uninitialized))
    {
        GpioPin!(PushPullOutput) pushPullOutput()
        {
            return GpioPin!(PushPullOutput)(this.pin);
        }
    }

    static if (is(T == PushPullOutput))
    {
        void setHigh() { }
        void setLow() { }
    }
}

void main()
{
    static pin = Pin();
    auto uninitPin = GpioPin!(Uninitialized)(&pin);
    // uninitPin.setHigh(); /* compile error */
    auto outputPin = uninitPin.pushPullOutput();
    outputPin.setHigh();
}
```

## このあたりを組み合わせる

こんな感じに書ける？

```d
private struct Uninitialized {}
private struct PushPullOutput {}

struct Pin
{
    @disable this(this);
}

struct GpioPin(T)
{
    private Pin* pin;

    @disable this(this);

    this(Pin* pin)
    {
        this.pin = pin;
    }

    static if (is(T == Uninitialized))
    {
        GpioPin!(PushPullOutput) pushPullOutput()
        {
            return GpioPin!(PushPullOutput)(this.pin);
        }
    }

    static if (is(T == PushPullOutput))
    {
        void setHigh() { }
        void setLow() { }
    }
}

GpioPin!Uninitialized* getGpioPin(Pin* pin)
{
    static GpioPin!(Uninitialized) uninitPin;
    uninitPin = GpioPin!(Uninitialized)(pin);
    return &uninitPin;
}

void main()
{
    static pin = Pin();
    auto uninitPin = getGpioPin(&pin);
    // uninitPin.setHigh(); /* compile error */
    auto outputPin = uninitPin.pushPullOutput();
    outputPin.setHigh();
}
```
