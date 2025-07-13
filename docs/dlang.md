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

## volatile load/store

pragmaを解釈する部分は[gen/pragma.cpp](https://github.com/ldc-developers/ldc/blob/46bbe8b47f7a69aff651e913d80dd846e1d6f613/gen/pragma.cpp#L128-L150)にある。

```cpp
    // Recognize LDC-specific pragmas.
    struct LdcIntrinsic {
      std::string name;
      LDCPragma pragma;
    };
    static LdcIntrinsic ldcIntrinsic[] = {
        {"bitop.bt", LLVMbitop_bt},   {"bitop.btc", LLVMbitop_btc},
        {"bitop.btr", LLVMbitop_btr}, {"bitop.bts", LLVMbitop_bts},
        {"bitop.vld", LLVMbitop_vld}, {"bitop.vst", LLVMbitop_vst},
    };

    static std::string prefix = "ldc.";
    size_t arg1str_length = strlen(arg1str);
    if (arg1str_length > prefix.length() &&
        std::equal(prefix.begin(), prefix.end(), arg1str)) {
      // Got ldc prefix, binary search through ldcIntrinsic.
      std::string name(arg1str + prefix.length());
      size_t i = 0, j = sizeof(ldcIntrinsic) / sizeof(ldcIntrinsic[0]);
      do {
        size_t k = (i + j) / 2;
        int cmp = name.compare(ldcIntrinsic[k].name);
        if (!cmp) {
          return ldcIntrinsic[k].pragma;
```

codegenは[gen/tocall.cpp](https://github.com/ldc-developers/ldc/blob/46bbe8b47f7a69aff651e913d80dd846e1d6f613/gen/tocall.cpp#L602-L628)。

```cpp
  if (fndecl->llvmInternal == LLVMbitop_vld) {
    if (e->arguments->length != 1) {
      error(e->loc, "`bitop.vld` intrinsic expects 1 argument");
      fatal();
    }
    // TODO: Check types

    Expression *exp1 = (*e->arguments)[0];
    LLValue *ptr = DtoRVal(exp1);
    result = new DImValue(e->type, DtoVolatileLoad(DtoType(e->type), ptr));
    return true;
  }

  if (fndecl->llvmInternal == LLVMbitop_vst) {
    if (e->arguments->length != 2) {
      error(e->loc, "`bitop.vst` intrinsic expects 2 arguments");
      fatal();
    }
    // TODO: Check types

    Expression *exp1 = (*e->arguments)[0];
    Expression *exp2 = (*e->arguments)[1];
    LLValue *ptr = DtoRVal(exp1);
    LLValue *val = DtoRVal(exp2);
    DtoVolatileStore(val, ptr);
    return true;
  }
```

DtoVolatileStoreの実装は[gen/tollvm.cpp](https://github.com/ldc-developers/ldc/blob/46bbe8b47f7a69aff651e913d80dd846e1d6f613/gen/tollvm.cpp#L534-L538)にある。

```cpp
LLValue *DtoVolatileLoad(LLType *type, LLValue *src, const char *name) {
  llvm::LoadInst *ld = DtoLoadImpl(type, src, name);
  ld->setVolatile(true);
  return ld;
}
```

setVolatileはLLVMのAPIで、ここから先はLLVMになる。

以下のようなコードがあるとき、

```d
pragma(LDC_intrinsic, "ldc.bitop.vld")
    uint volatileLoad(uint* ptr);

void main()
{
    uint a = 42;
    assert(volatileLoad(&a) == 42);
}
```

LLVM-IRの出力がこうなる。
loadの後ろにvolatileがついていることが確認できる。

```ll
; [#uses = 1]
; Function Attrs: uwtable
define i32 @_Dmain({ i64, ptr } %unnamed) #0 {
  %a = alloca i32, align 4                        ; [#uses = 2, size/byte = 4]
  store i32 42, ptr %a, align 4
  %1 = load volatile i32, ptr %a, align 4         ; [#uses = 1]
  %2 = icmp eq i32 %1, 42                         ; [#uses = 1]
  br i1 %2, label %assertPassed, label %assertFailed

assertPassed:                                     ; preds = %0
  ret i32 0

assertFailed:                                     ; preds = %0
  call void @_d_assert({ i64, ptr } { i64 10, ptr @.str }, i32 7) #1
  unreachable
}
```
