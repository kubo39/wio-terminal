# D言語くん画像表示 実装計画

## 概要

Wio TerminalのLCDディスプレイにD言語くん（D言語マスコットキャラクター）の画像を表示する。

---

## ハードウェア仕様

### LCDコントローラ

- **型番**: Sitronix ST7789V
- **解像度**: 320×240 ピクセル
- **色深度**: 16ビット（RGB565フォーマット）
- **インターフェース**: SPI（4線式）

### ピン配置

Seeed ArduinoCore-samd [variant.cpp](https://github.com/Seeed-Studio/ArduinoCore-samd/blob/master/variants/wio_terminal/variant.cpp) より確認済み：

| 信号名    | ピン  | 用途                               |
|----------|-------|------------------------------------|
| TFT_MOSI | PB19  | SPI データ出力（SERCOM7 PAD[3]）   |
| TFT_SCK  | PB20  | SPI クロック（SERCOM7 PAD[1]）     |
| TFT_MISO | PB18  | SPI データ入力（SERCOM7 PAD[2]）   |
| TFT_CS   | PB21  | チップセレクト（GPIO、低アクティブ）|
| TFT_DC   | PC6   | データ/コマンド切り替え（GPIO）     |
| TFT_RST  | PC7   | ハードウェアリセット（GPIO、低アクティブ）|
| TFT_BL   | PC5   | バックライト制御（GPIO）            |

※ TFT_MISOは今回不要（送信のみ）。TFT_CSはGPIOで手動制御。

### SERCOM7 SPI 設定

[variant.h](https://github.com/Seeed-Studio/ArduinoCore-samd/blob/master/variants/wio_terminal/variant.h) より：

- **PERIPH**: SERCOM7（SPI3として使用）
- **PAD_SPI3_TX**: `SPI_PAD_3_SCK_1` → **DOPO = 2**（MOSI=PAD[3], SCK=PAD[1]）
- **PAD_SPI3_RX**: `SERCOM_RX_PAD_2` → DIPO = 2（不使用）

---

## ハードウェアレジスタ一覧（確認済み）

### PORT レジスタ

```
PORT ベースアドレス: 0x4100_8000

PORTA ベース: 0x4100_8000 + 0x80×0 = 0x4100_8000
PORTB ベース: 0x4100_8000 + 0x80×1 = 0x4100_8080
PORTC ベース: 0x4100_8000 + 0x80×2 = 0x4100_8100

各ポート共通オフセット:
  DIRSET: +0x08  (出力方向セット)
  DIRCLR: +0x04  (出力方向クリア)
  OUTSET: +0x14  (出力High)
  OUTCLR: +0x18  (出力Low)
  PMUX[n]: +0x30 + n  (ピン機能多重化、n = pin/2)
  PINCFG[n]: +0x40 + n  (ピン設定)
```

### PMUX 設定（PB18/PB19/PB20 → SERCOM7、関数D）

`PIO_SERCOM_ALT` = 関数D = PMUX値 **3**

| ピン  | PMUX レジスタアドレス       | 設定値 | 内容                    |
|------|---------------------------|--------|------------------------|
| PB18 | 0x4100_80B9 (PMUX[9]下位) | 3      | PMUXE=D (SERCOM7 PAD2) |
| PB19 | 0x4100_80B9 (PMUX[9]上位) | 3      | PMUXO=D (SERCOM7 PAD3) |
| PB20 | 0x4100_80BA (PMUX[10]下位)| 3      | PMUXE=D (SERCOM7 PAD1) |

※ PMUX[n] は1バイト: 下位ニブル[3:0]=偶数ピン(PMUXE)、上位ニブル[7:4]=奇数ピン(PMUXO)
※ PB18とPB19は同じPMUXレジスタ(PMUX[9])を共有する

各ピンのPINCFGにPMUXEN(bit0)を立てる：

| ピン  | PINCFG アドレス | 設定値 |
|------|----------------|--------|
| PB18 | 0x4100_80D2    | 0x01   |
| PB19 | 0x4100_80D3    | 0x01   |
| PB20 | 0x4100_80D4    | 0x01   |

### MCLK レジスタ

出典: [asf4/samd51/include/component/mclk.h](https://github.com/adafruit/asf4/blob/master/samd51/include/component/mclk.h)

```
MCLK ベース: 0x4000_0800
APBDMASK オフセット: 0x20

SERCOM7 有効化:
  bit 3 (1 << 3) をセット
  → 0x4000_0820 |= (1 << 3)
```

### GCLK レジスタ

出典: [embedded/samd51/include/instance/sercom7.h](https://gitlab.cba.mit.edu/jakeread/atkstepper17/blob/openocd/embedded/samd51/include/instance/sercom7.h)

```
GCLK ベース: 0x4000_1C00
PCHCTRL ベース: GCLK ベース + 0x80 = 0x4000_1C80
PCHCTRL[n] = PCHCTRL ベース + n×4

SERCOM7_GCLK_ID_CORE = 37
PCHCTRL[37] アドレス: 0x4000_1C80 + 37×4 = 0x4000_1D14

設定値:
  bit [3:0]: GEN = 0  (GCLK0 = 120MHz)
  bit 6: CHEN = 1  (チャネル有効)
  → 0x4000_1D14 = 0x0000_0040
```

### SERCOM7 SPI レジスタ

```
SERCOM7 ベース: 0x4300_0C00

オフセット  レジスタ   用途
0x00       CTRLA     モード・有効化
0x04       CTRLB     データ長設定
0x0C       BAUD      ボーレート（8bit）
0x18       INTFLAG   割り込みフラグ（DRE=bit0, TXC=bit1）
0x1C       SYNCBUSY  同期待ち（SWRST=bit0, ENABLE=bit1, CTRLB=bit2）
0x28       DATA      送受信データ（32bit）
```

**CTRLA 設定値の計算:**

```
MODE[4:2]   = 3 (SPI Master) → 3 << 2  = 0x0000_000C
DOPO[17:16] = 2 (MOSI=PAD3, SCK=PAD1) → 2 << 16 = 0x0002_0000
DIPO[21:20] = 2 (MISO=PAD2, 不使用) → 2 << 20  = 0x0020_0000

初期値 (ENABLE=0): 0x0022_000C
有効化時 (ENABLE=bit1): 0x0022_000E
```

**BAUD 設定値の計算:**

```
f_baud = f_ref / (2 × (BAUD + 1))
f_ref = 120 MHz (GCLK0)

10 MHz 目標: BAUD = (120 / (2×10)) - 1 = 5
 → BAUD = 5 (実際: 10 MHz)

32 MHz 目標: BAUD = (120 / (2×32)) - 1 ≈ 1
 → BAUD = 1 (実際: 30 MHz)
```

---

## 実装方針

### 画像データの扱い

入力は**生のピクセルデータ（RGB565バイナリファイル）**とする。

```
dlang-kun.rgb565（生バイナリ）
        ↓
  D の import() でコンパイル時に埋め込み
        ↓
   .rodata セクション（Flash）
```

D言語のコンパイル時 `import()` 式を使ってバイナリファイルをそのまま埋め込む：

```d
static immutable ubyte[] IMAGE_DATA = cast(immutable ubyte[]) import("dlang-kun.rgb565");
```

- **入力フォーマット**: RGB565バイナリ（各ピクセル2バイト、ビッグエンディアン、行優先）
- **解像度**: 320×240 固定
- **データサイズ**: 320×240×2 = 153,600バイト（≒150KB）
  - Flash容量は約496KB（512KB - 16KB bootloader）なので収まる
- **格納場所**: `.rodata` セクション（Flash）
- LDCの `-J` フラグで `import()` のファイル検索ディレクトリを指定する

---

## ディレクトリ構成

```
wio-terminal/
├── image-display/
│   ├── app.d            # メインアプリケーション
│   ├── layout.ld        # リンカスクリプト（blinkyから流用・調整）
│   ├── Makefile         # ビルド・フラッシュ
│   ├── README.md
│   └── dlang-kun.rgb565 # 生のRGB565ピクセルデータ（ユーザーが用意）
```

---

## 実装フェーズ

### Phase 1: 画像データの埋め込み

D言語の `import()` 式でコンパイル時にバイナリを埋め込む。

```d
// app.d 内
static immutable ubyte[] IMAGE_DATA = cast(immutable ubyte[]) import("dlang-kun.rgb565");
```

`dlang-kun.rgb565` は 320×240×2 = 153,600バイトの生RGB565データ。
各ピクセルは上位バイト・下位バイトの順（ビッグエンディアン）で格納する。

LDCの `-J` フラグで `import()` のファイル検索パスを指定する：

```makefile
DFLAGS += -J.   # image-display/ ディレクトリを import() の検索対象に
```

---

### Phase 2: GPIO ドライバ（汎用化）

既存の `blinky/app.d` では GPIO ピンが `GpioA15Pin` のように特定ピン専用になっている。
今回は TFT_CS(PB21), TFT_DC(PC6), TFT_RST(PC7), TFT_BL(PC5) を制御する
複数のGPIO出力が必要なため、バンクとビット番号をテンプレートパラメータで持つ
汎用GPIO構造体を設計する。

```d
private enum uint PORT_ADDRESS = 0x4100_8000;
private enum uint PORT_BANK_SIZE = 0x80;

// GpioPin!(bankIndex, bitIndex, T)
// bankIndex: 0=PORTA, 1=PORTB, 2=PORTC
// bitIndex: 0-31

struct GpioPin(uint bankIndex, uint bitIndex, T)
{
    @disable this(this);

    private enum uint bankBase = PORT_ADDRESS + PORT_BANK_SIZE * bankIndex;

    static if (is(T == Uninitialized))
    {
        GpioPin!(bankIndex, bitIndex, PushPullOutput)* pushPullOutput() { ... }
    }

    static if (is(T == PushPullOutput))
    {
        void setHigh() { volatileStore(cast(uint*)(bankBase + 0x14), 1 << bitIndex); }
        void setLow()  { volatileStore(cast(uint*)(bankBase + 0x18), 1 << bitIndex); }
    }
}

// 各ピンの型エイリアス
alias CsPin  = GpioPin!(1, 21, Uninitialized); // PB21
alias DcPin  = GpioPin!(2,  6, Uninitialized); // PC6
alias RstPin = GpioPin!(2,  7, Uninitialized); // PC7
alias BlPin  = GpioPin!(2,  5, Uninitialized); // PC5
```

既存コードのパターン（シングルトン、型安全な状態遷移）を踏襲する。

---

### Phase 3: PORT PMUX 設定（SERCOM7 SPI ピン割り当て）

SPI通信のために、MOSI(PB19)・SCK(PB20)・MISO(PB18)をSERCOM7に割り当てる。

```d
void initPmux()
{
    // PB18(MISO), PB19(MOSI) → PMUX[9] に両方まとめてセット
    // PMUXE=D(3), PMUXO=D(3) → byte値 = (3 << 4) | 3 = 0x33
    volatileStore(cast(ubyte*) 0x4100_80B9, 0x33);

    // PB20(SCK) → PMUX[10] 下位ニブル = D(3)
    // 上位ニブル(PB21)は触らない（PB21はGPIOのままでよい）
    const auto pmux10 = volatileLoad(cast(ubyte*) 0x4100_80BA);
    volatileStore(cast(ubyte*) 0x4100_80BA, (pmux10 & 0xF0) | 3);

    // 各ピンの PINCFG.PMUXEN (bit0) を有効化
    volatileStore(cast(ubyte*) 0x4100_80D2, 0x01); // PB18
    volatileStore(cast(ubyte*) 0x4100_80D3, 0x01); // PB19
    volatileStore(cast(ubyte*) 0x4100_80D4, 0x01); // PB20
}
```

---

### Phase 4: SPI ドライバ（SERCOM7 SPI Master 初期化）

```d
private enum uint MCLK_BASE    = 0x4000_0800;
private enum uint GCLK_BASE    = 0x4000_1C00;
private enum uint SERCOM7_BASE = 0x4300_0C00;

void initSpi()
{
    // 1. MCLK: SERCOM7へのAPBDクロック供給を有効化 (bit3)
    const auto apbd = volatileLoad(cast(uint*)(MCLK_BASE + 0x20));
    volatileStore(cast(uint*)(MCLK_BASE + 0x20), apbd | (1 << 3));

    // 2. GCLK: SERCOM7_CORE (ID=37) に GCLK0 (120MHz) を接続
    // CHEN(bit6)=1, GEN[3:0]=0 (GCLK0)
    volatileStore(cast(uint*) 0x4000_1D14, 0x0000_0040);

    // 3. PMUX 設定 (Phase 3参照)
    initPmux();

    // 4. SERCOM7 ソフトウェアリセット
    volatileStore(cast(uint*)(SERCOM7_BASE + 0x00), 0x01); // CTRLA.SWRST
    while (volatileLoad(cast(uint*)(SERCOM7_BASE + 0x1C)) & 0x01) {} // SYNCBUSY.SWRST

    // 5. CTRLA 設定 (ENABLE=0のまま)
    //   MODE[4:2]=3 (SPI Master), DOPO[17:16]=2 (MOSI=PAD3,SCK=PAD1)
    volatileStore(cast(uint*)(SERCOM7_BASE + 0x00), 0x0022_000C);

    // 6. CTRLB 設定: CHSIZE=0 (8bit), RXEN=0 (受信不要)
    volatileStore(cast(uint*)(SERCOM7_BASE + 0x04), 0x00);
    while (volatileLoad(cast(uint*)(SERCOM7_BASE + 0x1C)) & 0x04) {} // SYNCBUSY.CTRLB

    // 7. BAUD = 5 → 10MHz SPI (120MHz / (2×6))
    volatileStore(cast(ubyte*)(SERCOM7_BASE + 0x0C), 5);

    // 8. ENABLE
    const auto ctrla = volatileLoad(cast(uint*)(SERCOM7_BASE + 0x00));
    volatileStore(cast(uint*)(SERCOM7_BASE + 0x00), ctrla | (1 << 1));
    while (volatileLoad(cast(uint*)(SERCOM7_BASE + 0x1C)) & 0x02) {} // SYNCBUSY.ENABLE
}

void spiWrite(ubyte data)
{
    // DRE (Data Register Empty, bit0) が立つまで待機
    while (!(volatileLoad(cast(uint*)(SERCOM7_BASE + 0x18)) & 0x01)) {}
    volatileStore(cast(uint*)(SERCOM7_BASE + 0x28), data);
}
```

---

### Phase 5: ST7789V LCDドライバ

#### 初期化シーケンス

1. GPIO出力ピン（CS, DC, RST, BL）を全てDIRSETで出力モードに
2. ハードウェアリセット（RST Low → 10ms → High → 150ms）
3. ソフトウェアリセット（cmd `0x01`）→ 150ms待機
4. スリープ解除（cmd `0x11`）→ 500ms待機
5. カラーモード設定（cmd `0x3A`, data `0x55`）→ RGB565
6. メモリアクセス制御（cmd `0x36`, data `0x00`）→ 方向設定
7. 表示ON（cmd `0x29`）
8. バックライト点灯（BL High）

#### コマンド/データ送信

```d
void writeCommand(ubyte cmd)
{
    dcPin.setLow();  // DC=Low → コマンド
    csPin.setLow();
    spiWrite(cmd);
    csPin.setHigh();
}

void writeData(ubyte data)
{
    dcPin.setHigh(); // DC=High → データ
    csPin.setLow();
    spiWrite(data);
    csPin.setHigh();
}
```

#### 描画ウィンドウ設定

```d
void setWindow(ushort x0, ushort y0, ushort x1, ushort y1)
{
    writeCommand(0x2A); // CASET
    writeData(cast(ubyte)(x0 >> 8)); writeData(cast(ubyte)(x0 & 0xFF));
    writeData(cast(ubyte)(x1 >> 8)); writeData(cast(ubyte)(x1 & 0xFF));

    writeCommand(0x2B); // RASET
    writeData(cast(ubyte)(y0 >> 8)); writeData(cast(ubyte)(y0 & 0xFF));
    writeData(cast(ubyte)(y1 >> 8)); writeData(cast(ubyte)(y1 & 0xFF));

    writeCommand(0x2C); // RAMWR → 続けてピクセルデータを送信
}
```

---

### Phase 6: 画像表示

```d
void displayImage(const ubyte[] imageData)
{
    setWindow(0, 0, 319, 239); // 全画面
    dcPin.setHigh();
    csPin.setLow();
    foreach (b; imageData) // RGB565バイト列をそのまま送信
    {
        spiWrite(b);
    }
    csPin.setHigh();
}

noreturn main()
{
    initSpi();
    initLcd();
    displayImage(IMAGE_DATA[]);
    while (true)
    {
        __asm("wfi", "");
    }
}
```

---

## 遅延の実装

ST7789V初期化時に数百msの待機が必要。`systick/app.d` のSysTick実装を流用する。

---

## Makefile

`image-display/Makefile` は既存の `blinky/Makefile` を基本とし、`-J.` を追加：

```makefile
app.o: app.d dlang-kun.rgb565
	ldc2 $(DFLAGS) -J. -c app.d -of app.o
```

`dlang-kun.rgb565` が変更されたら再コンパイルされるよう依存関係に含める。

---

## 実装上の注意事項

1. **betterC制約**: GC、例外、Phobosの大部分は使用不可。
2. **volatile**: すべてのレジスタアクセスに `volatileLoad`/`volatileStore` を使用。
3. **シングルトン**: SPIドライバ・LCDドライバも `__gshared` + フラグパターンを採用。
4. **型安全**: GPIO出力ピンも `Uninitialized` → `PushPullOutput` の型状態遷移を維持。
5. **PMUX注意**: PB18とPB19は同じPMUXレジスタ(PMUX[9])を共有するため、一度に両方設定する。

---

## 参考資料

- [Seeed ArduinoCore-samd variant.h](https://github.com/Seeed-Studio/ArduinoCore-samd/blob/master/variants/wio_terminal/variant.h)
- [Seeed ArduinoCore-samd variant.cpp](https://github.com/Seeed-Studio/ArduinoCore-samd/blob/master/variants/wio_terminal/variant.cpp)
- [SERCOM7 instance header (SAMD51)](https://gitlab.cba.mit.edu/jakeread/atkstepper17/blob/openocd/embedded/samd51/include/instance/sercom7.h)
- [adafruit/asf4 mclk.h](https://github.com/adafruit/asf4/blob/master/samd51/include/component/mclk.h)
- [Wio Terminal Schematic](https://files.seeedstudio.com/wiki/Wio-Terminal/res/Wio-Terminal-Schematics.pdf)
- [SAMD51 Datasheet](https://ww1.microchip.com/downloads/aemDocuments/documents/MCU32/ProductDocuments/DataSheets/SAM-D5x-E5x-Family-Data-Sheet-DS60001507.pdf)
- [ST7789V Datasheet](https://www.displayfuture.com/Display/datasheet/controller/ST7789V.pdf)
- `docs/dlang.md` - volatileLoad/Store の使い方
- `systick/app.d` - SysTick遅延の参考実装
