# D言語

## BetterCとは

組み込みで利用できるD言語のサブセット。

[betterC](https://dlang.org/spec/betterc.html)仕様によると

- GC
- TypeInfoやModuleInfo
- クラス
- Built-in Thread (core.thread)
- 動的配列
- 連想配列
- 例外
- synchronizedやcore.sync
- static module constructor/destructor

といった機能、いわゆるランタイムに依存した機能が使えない。
あと標準ライブラリとか。
