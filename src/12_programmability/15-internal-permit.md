# `std::internal` 与 `Permit<T>`

## 导读

Move 标准库在 **`std::internal`** 中提供了类型级「授权凭证」**`Permit<phantom T>`**，以及唯一能构造它的 **`internal::permit<T>()`**。编译器保证：**只有定义了类型 `T` 的那个模块**才能调用 `permit<T>()`，因此你可以把 `Permit<T>` 当作**由 `T` 的所属模块背书的 witness（见证）**，把泛型 API 的合法调用方约束到「与 `T` 同族」的代码路径上。

- **源码**：[MystenLabs/sui · `move-stdlib/sources/internal.move`](https://github.com/MystenLabs/sui/blob/main/crates/sui-framework/packages/move-stdlib/sources/internal.move)  
- **前置**：[§13.1 · Move 标准库](01-sui-framework.md)；与 **Witness / Capability** 的对照见 [第十二章 · Witness 模式](../12_patterns/02-witness.md)、[Capability 模式](../12_patterns/01-capability.md)  
- **配套示例**：[code/permit_lab](code/permit_lab/)（`sui move build` / `sui move test`）

---

## 一、API 在做什么

官方模块（概念上）等价于下面这段说明（以你当前工具链里的 `std::internal` 为准）：

- **`public struct Permit<phantom T>() has drop`**：`T` 是 **phantom** 类型参数，运行时不携带 `T` 的值，只参与**类型检查**。`Permit<T>` 本身无字段，且带 **`drop`**，用完即可丢弃，不要求像「热土豆」那样必须沿调用链传到底。  
- **`public fun permit<T>(): Permit<T>`**：返回一个 `Permit<T>`。**语言规则**：该调用**只能**出现在**定义了 `T` 的模块**里。其它模块即使用 `use` 拿到了 `Permit` 和 `T` 的名字，也**不能**自己 `permit<T>()`，否则无法通过编译。

因此，`Permit<T>` 表达的是：**「某个由 `T` 的声明模块参与过的控制流」**——而不是「链上谁付了 gas」或「谁持有一个对象」。它解决的是 **模块边界上的泛型授权**，与 [第十章 · `sui::transfer::Receiving` 与内部约束](../10_using_objects/05-internal-constraint.md)里那种「值级 witness」是不同层面的工具，可对照理解。

---

## 二、典型用法：类型注册表、插件式 API

常见模式如下。

1. 在包 **A** 中定义标记类型 **`MyTag`**（通常 `has drop`，无状态）。  
2. 仅在 **A** 中实现 **`public fun issue(): Permit<MyTag> { internal::permit<MyTag>() }`**（名称自定），按需决定何时向调用方发放 `Permit`。  
3. 在包 **B** 中编写 **`public fun sensitive_op<T>(_: Permit<T>, ...)`** 一类函数：任意 `T` 在语法上都可以代入，但**没有对应模块签发的 `Permit<T>`**，调用方就无法构造参数，从而把「谁有资格触发 `sensitive_op`」交回给 **`T` 的定义模块**。

这与 **OTW（一次性见证）** 或 **`AdminCap` 对象** 的差别在于：`Permit<T>` **不是**发布时由运行时注入的唯一值，也**不必**在全局存储里记账；它是 **编译期 + 模块可见性** 下的证明。若你需要「链上唯一、可转移的权限载体」，仍应优先 [Capability](../12_patterns/01-capability.md) 或 [OTW](../12_patterns/03-one-time-witness.md)。

---

## 三、完整示例（`permit_lab`）

下面两个模块与仓库中 **[`code/permit_lab/sources/`](code/permit_lab/sources/)** 一致：`brand` 定义类型并签发 `Permit`；`registry` 要求调用方必须持有 `Permit<brand::Brand>` 才能注册展示名。

**`brand.move`** — 定义 `Brand` 并作为唯一能构造 `Permit<Brand>` 的模块：

```move
module permit_lab::brand;

use std::internal::Permit;

#[error]
const ENameEmpty: vector<u8> = b"display name must be non-empty";

/// 由本模块独占的类型标记；其它包无法调用 `internal::permit<Brand>()`。
public struct Brand has drop {}

/// 向调用方发放「本模块已授权」的证明；只有此处能合法构造 `Permit<Brand>`。
public fun issue_permit(): Permit<Brand> {
    internal::permit<Brand>()
}

/// 由 `Brand` 所在模块提供的业务校验，供注册表在消费 `Permit` 时复用。
public fun assert_non_empty_name(name: &vector<u8>) {
    assert!(vector::length(name) > 0, ENameEmpty);
}
```

**`registry.move`** — 将授权绑定到 `brand::Brand`，没有 `brand::issue_permit()` 返回的值则无法通过类型检查：

```move
module permit_lab::registry;

use permit_lab::brand;
use std::internal::Permit;

public fun register_display_name(_proof: Permit<brand::Brand>, display_name: vector<u8>): u64 {
    brand::assert_non_empty_name(&display_name);
    vector::length(&display_name)
}
```

**测试思路**（见 `sources/permit_tests.move`）：先 `let proof = brand::issue_permit();`，再 `registry::register_display_name(proof, b"DemoToken")`。若在**第三个模块**里手写 `internal::permit<Brand>()`，编译器会报错——这正是 `Permit` 要提供的保证。

---

## 四、使用注意

- **`Permit<T>` 不防伪造「业务含义」**：它只保证 **`Permit` 的构造** 来自 `T` 的定义模块。你仍要在 `issue_permit` 路径上写好**谁、在何种条件下**能拿到 permit（例如配合 `public(package)`、`friend`、或链上状态）。  
- **与 `phantom T` 泛型**：`Permit<T>` 适合把「授权」钉在类型层面；若你还需要运行时按 `T` 分派，可结合 [第八章 · 类型反射](../08_move_advanced/04-type-reflection.md) 中的 `type_name` 等，但注意不要过度混用导致难以审计。  
- **版本**：`std::internal` 随 **MoveStdlib** 发布；若升级工具链后签名有变，请以当前 `internal.move` 为准。
