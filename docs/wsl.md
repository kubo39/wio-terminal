# wsl

以下はPowerShellでの操作。

まずwingetでusbipdを入れる。

```console
winget install usbipd
```

自分の環境では`usbipd: error: The VBoxUsbMon driver is currently not running; a reboot should fix that.`というエラーが出たが、なぜかuninstallして再インストールすると[解決](https://github.com/dorssel/usbipd-win/issues/286#issuecomment-2960690352)するようだ。

`usbipd list`でまず確認。

```console
PS C:\Users\hinod> usbipd list
Connected:
BUSID  VID:PID    DEVICE                                                        STATE
1-3    04f2:b735  HP Wide Vision HD Camera, Camera DFU Device                   Not shared
1-4    04f3:0c00  ELAN WBF Fingerprint Sensor                                   Not shared
2-2    2886:002d  USB シリアル デバイス (COM4), USB 大容量記憶装置, USB 入 ...  Not Shared
2-3    0bda:2852  Realtek Wireless Bluetooth Adapter                            Not shared
```

bindでwslとデバイスを共有する。

```console
PS C:\Users\hinod> usbipd bind --busid 2-2
PS C:\Users\hinod> usbipd list
Connected:
BUSID  VID:PID    DEVICE                                                        STATE
1-3    04f2:b735  HP Wide Vision HD Camera, Camera DFU Device                   Not shared
1-4    04f3:0c00  ELAN WBF Fingerprint Sensor                                   Not shared
2-2    2886:002d  USB シリアル デバイス (COM4), USB 大容量記憶装置, USB 入 ...  Shared
2-3    0bda:2852  Realtek Wireless Bluetooth Adapter                            Not shared
```

attachでみえるように。

```console
PS C:\Users\hinod> usbipd attach --wsl --busid 2-2
usbipd: info: Using WSL distribution 'Ubuntu-22.04' to attach; the device will be available in all WSL 2 distributions.
usbipd: info: Detected networking mode 'nat'.
usbipd: info: Using IP address 172.22.240.1 to reach the host.
```

以下はWSL上のUbuntu。
lsusbでWSL環境からデバイスを認識していることを確認。

```console
$ lsusb
Bus 002 Device 001: ID 1d6b:0003 Linux Foundation 3.0 root hub
Bus 001 Device 009: ID 2886:002d Seeed Technology Co., Ltd. Wio Terminal
Bus 001 Device 001: ID 1d6b:0002 Linux Foundation 2.0 root hub
```
