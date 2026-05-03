# 错误处理最佳实践

本节讲解 Move 合约中的错误处理策略。良好的错误处理不仅能帮助调试，还能向用户提供有意义的反馈。我们将介绍错误码设计、分类策略和三条核心规则。

**与全书一致**：本书正文与示例中的可中止错误**默认采用** **`#[error]` + `vector<u8>`**（Clever Errors），见[第五章 · 断言与中止](../05_move_basics/19-assert-and-abort.md)。**命名规则（`EPascalCase`）与「一义一码」原则**仍适用：每个失败场景对应**单独**的 `#[error]` 常量，消息字符串应简短可读。链外若需映射用户文案，可优先解析工具链返回的**常量名与消息**；仅在对接**旧合约**或遗留系统时，才需维护历史 **`u64` 码表**。

## Move 中的错误机制

当执行遇到 `abort` 时，交易失败并返回中止码（abort code）。Move VM 会返回中止交易的模块名称和中止码。但这种行为对调用者来说不够透明，特别是当一个函数包含多个可能中止的调用时。

### 问题场景

```move
module book::module_a;

use book::module_b;

public fun do_something() {
    let field_1 = module_b::get_field(1); // 可能以 abort code 0 中止
    /* ... 大量逻辑 ... */
    let field_2 = module_b::get_field(2); // 可能以 abort code 0 中止
    /* ... 更多逻辑 ... */
    let field_3 = module_b::get_field(3); // 可能以 abort code 0 中止
}
```

如果调用者收到 abort code `0`，无法确定是哪个调用失败了。

## 三条核心规则

### 规则一：处理所有可能的场景

在调用可能中止的函数之前，先用安全的检查函数验证：

```move
module book::module_a;

use book::module_b;

#[error]
const ENoField: vector<u8> = b"no field";
public fun do_something() {
    assert!(module_b::has_field(1), ENoField);
    let field_1 = module_b::get_field(1);
    /* ... */
    assert!(module_b::has_field(2), ENoField);
    let field_2 = module_b::get_field(2);
    /* ... */
    assert!(module_b::has_field(3), ENoField);
    let field_3 = module_b::get_field(3);
}
```

通过在每次调用前添加自定义检查，开发者掌握了错误处理的控制权。

### 规则二：使用不同的错误码

为每个失败场景分配唯一的错误码：

```move
module book::module_a;

use book::module_b;

#[error]
const ENoFieldA: vector<u8> = b"no field a";
#[error]
const ENoFieldB: vector<u8> = b"no field b";
#[error]
const ENoFieldC: vector<u8> = b"no field c";
public fun do_something() {
    assert!(module_b::has_field(1), ENoFieldA);
    let field_1 = module_b::get_field(1);
    /* ... */
    assert!(module_b::has_field(2), ENoFieldB);
    let field_2 = module_b::get_field(2);
    /* ... */
    assert!(module_b::has_field(3), ENoFieldC);
    let field_3 = module_b::get_field(3);
}
```

现在调用者可以依据**不同的 `#[error]` 常量名与解码后的消息**区分是哪一个 `assert!` 失败（CLI / GraphQL 会展示可读信息），而不再依赖易混淆的裸数字 `0/1/…`。

### 规则三：返回 bool 而非 assert

不要暴露一个公共的 assert 函数，而是提供返回 bool 的检查函数：

```move
// 不推荐：暴露断言函数
module book::some_app_assert;

#[error]
const ENotAuthorized: vector<u8> = b"not authorized";
public fun do_a() {
    assert_is_authorized();
    // ...
}

/// 不要这样做
public fun assert_is_authorized() {
    assert!(/* 某个条件 */ true, ENotAuthorized);
}
```

```move
// 推荐：暴露布尔函数
module book::some_app;

#[error]
const ENotAuthorized: vector<u8> = b"not authorized";
public fun do_a() {
    assert!(is_authorized(), ENotAuthorized);
    // ...
}

public fun do_b() {
    assert!(is_authorized(), ENotAuthorized);
    // ...
}

/// 返回 bool，让调用者决定如何处理
public fun is_authorized(): bool {
    /* 某个条件 */ true
}

// 内部使用的断言函数仍然可以存在
fun assert_is_authorized() {
    assert!(is_authorized(), ENotAuthorized);
}
```

## 错误常量设计规范

### 命名约定

错误常量使用 `EPascalCase` 前缀：

```move
// 正确：EPascalCase
#[error]
const ENotAuthorized: vector<u8> = b"not authorized";
#[error]
const EInsufficientBalance: vector<u8> = b"insufficient balance";
#[error]
const EObjectNotFound: vector<u8> = b"object not found";
// 错误：错误常量未用 #[error]，且未以 E 前缀命名
const NOT_AUTHORIZED: vector<u8> = b"bad naming"; // 不推荐
```

### 按功能分组（语义分区）

同一模块内可按**业务域**分组定义错误常量（便于检索与文档化；**不再依赖** `0–9` / `10–19` 这类数值区间）：

```move
module my_protocol::marketplace;

// 权限类
#[error]
const ENotOwner: vector<u8> = b"not owner";
#[error]
const ENotAdmin: vector<u8> = b"not admin";
#[error]
const ENotApproved: vector<u8> = b"not approved";
// 输入校验类
#[error]
const EInvalidPrice: vector<u8> = b"invalid price";
#[error]
const EInvalidQuantity: vector<u8> = b"invalid quantity";
#[error]
const EInvalidName: vector<u8> = b"invalid name";
// 状态类
#[error]
const EAlreadyListed: vector<u8> = b"already listed";
#[error]
const ENotListed: vector<u8> = b"not listed";
#[error]
const EAlreadySold: vector<u8> = b"already sold";
// 余额 / 支付类
#[error]
const EInsufficientBalance: vector<u8> = b"insufficient balance";
#[error]
const EInsufficientPayment: vector<u8> = b"insufficient payment";
// 版本 / 弃用类
#[error]
const EInvalidPackageVersion: vector<u8> = b"invalid package version";
#[error]
const EDeprecated: vector<u8> = b"deprecated";
```

### 前端与链下展示

Clever Errors 在 RPC / GraphQL / 钱包中通常会带上**模块位置、常量名与 UTF-8 消息**。前端优先根据**常量名或消息子串**映射到本地化文案；**仅当对接旧合约**仍返回纯 `u64` 中止码时，才需要维护 `abortCode → 文案` 的数值映射表。

## 高级模式

### 错误上下文包装

当需要区分同一模块中不同位置的相同类型错误时：

```move
#[error]
const ETransferFailed_SenderCheck: vector<u8> = b"transfer failed sender check";
#[error]
const ETransferFailed_ReceiverCheck: vector<u8> = b"transfer failed receiver check";
#[error]
const ETransferFailed_AmountCheck: vector<u8> = b"transfer failed amount check";
public fun transfer(
    from: &mut Account,
    to: &mut Account,
    amount: u64,
) {
    assert!(from.is_active(), ETransferFailed_SenderCheck);
    assert!(to.is_active(), ETransferFailed_ReceiverCheck);
    assert!(from.balance >= amount, ETransferFailed_AmountCheck);
    // ...
}
```

### 优雅降级

对于非关键操作，考虑返回结果而非中止：

```move
/// 尝试装备武器，返回操作结果
public fun try_equip_weapon(
    hero: &mut Hero,
    weapon: Weapon,
): (bool, Option<Weapon>) {
    if (hero.weapon.is_some()) {
        // 已有武器，返回失败和未使用的武器
        (false, option::some(weapon))
    } else {
        hero.weapon.fill(weapon);
        (true, option::none())
    }
}
```

## 测试错误处理

对 **`#[error]`** 常量，测试中应使用 **`#[test, expected_failure]`** 且**省略** `abort_code`，避免 clever 编码随源码行变化导致脆弱测试。

```move
#[test, expected_failure]
fun unauthorized_access_fails() {
    let ctx = &mut tx_context::dummy();
    unauthorized_action(ctx);
    abort 0xFF // 如果执行到这里说明测试失败
}

#[test]
fun error_returns_correct_code() {
    // 验证 is_authorized 返回正确的布尔值
    assert!(!is_authorized_for(@0x0));
    assert!(is_authorized_for(@0x1));
}
```

## 小结

- 遵循三条核心规则：处理所有场景、为不同失败场景使用**不同**的 `#[error]` 常量、返回 bool 而非 assert
- 错误常量使用 `EPascalCase` 命名约定，并以 `#[error]` + `vector<u8>` 提供可读消息
- 按功能域分组定义错误常量，便于定位和维护
- 前端优先消费 Clever Error 的**常量名 / 消息**；纯 `u64` 码表仅用于旧合约兼容
- 提供 `is_*` 检查函数让调用者在中止前验证条件
- 对非关键操作考虑优雅降级（返回结果而非中止）
- 用 `expected_failure` 覆盖错误路径：**不写** `abort_code`（配合 `#[error]`）
