# 测试场景（Test Scenario）

`sui::test_scenario` 是 Sui Framework 提供的 **`#[test_only]`** 工具：在**一次**单元测试函数里，用内存中的「对象池 + 各地址库存」模拟**多笔交易**、不同 `sender`、以及共享 / 冻结对象的生命周期。它与真实链上的执行器行为对齐到「对象何时进库存、何时能 `take`」这一层，但不会跑真实验证者或网络。

下面分**三小节**：先讲**场景与交易边界**（何时能取对象、如何读上一笔的 `TransactionEffects`），再讲**拥有对象**的取还 API，最后讲**共享 / 不可变对象**、**时间与 epoch**、以及 **`create_system_objects` / `TxContextBuilder`** 等进阶入口。示例统一采用与本书仓库一致的 **`test_scenario::函数(&mut s, …)`** 风格（见 `object_lab/tests/counter_tests.move`、`testing_lab/tests/demo_tests.move`）。

> **约定**：每个 `#[test]` 里通常只用一个 `Scenario`，结束时必须调用 **`test_scenario::end`**；共享 / 不可变对象若被 `take` 出库存，须在**同一笔模拟交易**内按规则 **`return_shared` / `return_immutable`**，否则 `next_tx` / `end` 可能 **abort**（与 `EInvalidSharedOrImmutableUsage` 等常量说明一致，详见 Framework 源码 `test_scenario.move`）。

---

## 一、场景生命周期、发送者与 `next_tx`

### `begin`：开启场景并指定「当前交易」的发送者

第一笔**模拟交易**的发送者由 `begin` 的实参决定；此时 `txn_number` 为 0，尚未调用过 `next_tx`（`num_concluded_txes` 仍为 0）。

```move
#[test_only]
module examples::snippet_begin;

use sui::test_scenario::{Self, Scenario};

#[test]
fun begin_sets_sender() {
    let alice = @0xA;
    let s: Scenario = test_scenario::begin(alice);
    assert!(test_scenario::sender(&s) == alice, 0);
    let _fx = test_scenario::end(s);
}
```

### `ctx`：在当前交易中拿到 `&mut TxContext`

创建 `UID`、调用依赖 `ctx` 的业务函数时，用 **`test_scenario::ctx(&mut s)`**。注意：只在**当前这一笔**尚未 `next_tx` 的块里使用。若不想手写 `object::new(ctx)`，也可用同文件中的 **`test_scenario::new_object(&mut s)`**（语义等价）。

```move
#[test_only]
module examples::snippet_ctx;

use sui::test_scenario::{Self, Scenario};

#[test]
fun ctx_for_new_uid() {
    let mut s: Scenario = test_scenario::begin(@0xA);
    {
        let ctx = test_scenario::ctx(&mut s);
        let _id = object::new(ctx);
    };
    let _fx = test_scenario::end(s);
}
```

### `sender`：只读当前发送者地址

不修改场景时，可用 **`test_scenario::sender(&s)`**（`&Scenario` 即可）。

```move
#[test_only]
module examples::snippet_sender;

use sui::test_scenario::{Self, Scenario};

#[test]
fun sender_readonly() {
    let bob = @0xB;
    let s: Scenario = test_scenario::begin(bob);
    assert!(test_scenario::sender(&s) == bob, 0);
    let _fx = test_scenario::end(s);
}
```

### `next_tx`：结束上一笔交易、把转移落库，并切换到新的 `sender`

**要点**：在上一笔里 `transfer` 给 Alice 的对象，**只有**在调用 `next_tx(..., alice)`（且下一笔发送者是 Alice）之后，才会出现在 Alice 的库存里；**同一笔内**不能指望 `take_from_sender` 立刻拿到刚转给自己的对象。

```move
#[test_only]
module examples::snippet_next_tx;

use sui::test_scenario::{Self, Scenario};

public struct Parcel has key, store {
    id: UID,
}

#[test]
fun next_tx_moves_inventory() {
    let alice = @0xA;
    let bob = @0xB;
    let mut s: Scenario = test_scenario::begin(alice);
    // Tx 0：alice 造对象并转给 bob
    {
        let ctx = test_scenario::ctx(&mut s);
        let p = Parcel { id: object::new(ctx) };
        transfer::public_transfer(p, bob);
    };
    // 结束 Tx 0、开始 Tx 1，发送者为 bob —— 此时 bob 库存中才有 Parcel
    let _fx0 = test_scenario::next_tx(&mut s, bob);
    {
        let _p: Parcel = test_scenario::take_from_sender(&s);
        test_scenario::return_to_sender(&s, _p);
    };
    let _fx1 = test_scenario::end(s);
}
```

### `num_concluded_txes`：已结束的交易笔数（不含当前未 `next_tx` 的半笔）

常用于断言「已经推进了几笔」。

```move
#[test_only]
module examples::snippet_num_tx;

use sui::test_scenario::{Self, Scenario};

#[test]
fun num_concluded_txes() {
    let mut s: Scenario = test_scenario::begin(@0xA);
    assert!(test_scenario::num_concluded_txes(&s) == 0, 0);
    let _fx = test_scenario::next_tx(&mut s, @0xB);
    assert!(test_scenario::num_concluded_txes(&s) == 1, 1);
    let _fx2 = test_scenario::end(s);
}
```

### `TransactionEffects`：读上一笔 / 最后一笔的摘要

`next_tx` 与 `end` 的返回值类型为 **`TransactionEffects`**。字段访问应使用 **`test_scenario::created` / `written` / `deleted` / `shared` / `frozen` / `num_user_events` 等**（传入 `&TransactionEffects`），不要假设存在 `effects.created()` 方法式调用。

```move
#[test_only]
module examples::snippet_effects;

use sui::test_scenario::{Self, Scenario};

public struct Blob has key, store {
    id: UID,
}

#[test]
fun inspect_effects() {
    let mut s: Scenario = test_scenario::begin(@0xA);
    {
        let ctx = test_scenario::ctx(&mut s);
        let b = Blob { id: object::new(ctx) };
        transfer::public_transfer(b, @0xA);
    };
    let fx = test_scenario::next_tx(&mut s, @0xA);
    assert!(test_scenario::num_user_events(&fx) == 0, 0);
    assert!(test_scenario::created(&fx).length() >= 1, 1);
    let _fx2 = test_scenario::end(s);
}
```

### `end`：结束整个场景并返回最后一笔交易的 `TransactionEffects`

`end` 会消费掉 `Scenario`（按值传入），之后不要再使用该变量。

```move
#[test_only]
module examples::snippet_end;

use sui::test_scenario::{Self, Scenario};

#[test]
fun end_returns_final_effects() {
    let s: Scenario = test_scenario::begin(@0xA);
    let fx = test_scenario::end(s);
    assert!(test_scenario::num_user_events(&fx) == 0, 0);
}
```

---

## 二、拥有对象：从「发送者 / 任意地址」库存取出与归还

拥有对象（`key + store` 等）被 `transfer` 到某地址后，会进入该地址在场景里的**库存**。测试里用 **`take_*` 取出、`return_to_*` 或再次 `transfer` 归还**；`return_to_address` / `return_to_sender` 会校验该对象是否**确实**从对应库存取出过（否则 `ECantReturnObject`）。

### `take_from_sender` / `return_to_sender`：当前发送者库存

与本书 `simple_nft/tests/hero_tests.move` 相同模式：先 `next_tx` 到接收者，再 `take_from_sender`，用毕 **`return_to_sender(&s, obj)`**。

```move
#[test_only]
module examples::snippet_take_sender;

use sui::test_scenario::{Self, Scenario};

public struct Ticket has key, store {
    id: UID,
    seat: u8,
}

#[test]
fun take_from_sender_roundtrip() {
    let mut s: Scenario = test_scenario::begin(@0xA);
    {
        let ctx = test_scenario::ctx(&mut s);
        let t = Ticket { id: object::new(ctx), seat: 3 };
        transfer::public_transfer(t, @0xA);
    };
    test_scenario::next_tx(&mut s, @0xA);
    {
        let t: Ticket = test_scenario::take_from_sender(&s);
        assert!(t.seat == 3, 0);
        test_scenario::return_to_sender(&s, t);
    };
    let _fx = test_scenario::end(s);
}
```

### `has_most_recent_for_sender` / `most_recent_id_for_sender`

在 `take` 前探测「当前发送者是否至少有一个未取走的类型 `T` 实例」；`most_recent_id_for_sender` 返回 **`Option<ID>`**。

```move
#[test_only]
module examples::snippet_most_recent_sender;

use sui::test_scenario::{Self, Scenario};

public struct Coin has key, store {
    id: UID,
}

#[test]
fun probe_sender_inventory() {
    let mut s: Scenario = test_scenario::begin(@0xA);
    {
        let ctx = test_scenario::ctx(&mut s);
        let c = Coin { id: object::new(ctx) };
        transfer::public_transfer(c, @0xA);
    };
    test_scenario::next_tx(&mut s, @0xA);
    assert!(test_scenario::has_most_recent_for_sender<Coin>(&s), 0);
    let id_opt = test_scenario::most_recent_id_for_sender<Coin>(&s);
    assert!(id_opt.is_some(), 1);
    let _id = id_opt.destroy_some(); // 需要 `ID` 时传给 `take_from_sender_by_id`
    let c: Coin = test_scenario::take_from_sender(&s);
    test_scenario::return_to_sender(&s, c);
    let _fx = test_scenario::end(s);
}
```

### `take_from_sender_by_id`：同类型多枚时按 `ID` 精确取

先保存 `object::id(&obj)`，再在下一笔用 **`take_from_sender_by_id`**。

```move
#[test_only]
module examples::snippet_take_by_id;

use sui::test_scenario::{Self, Scenario};

public struct Label has key, store {
    id: UID,
    n: u64,
}

#[test]
fun take_sender_by_id() {
    let mut s: Scenario = test_scenario::begin(@0xA);
    let id_low = {
        let ctx = test_scenario::ctx(&mut s);
        let a = Label { id: object::new(ctx), n: 1 };
        let id = object::id(&a);
        transfer::public_transfer(a, @0xA);
        id
    };
    {
        let ctx = test_scenario::ctx(&mut s);
        let b = Label { id: object::new(ctx), n: 2 };
        transfer::public_transfer(b, @0xA);
    };
    test_scenario::next_tx(&mut s, @0xA);
    {
        let got: Label = test_scenario::take_from_sender_by_id(&s, id_low);
        assert!(got.n == 1, 0);
        test_scenario::return_to_sender(&s, got);
    };
    let _fx = test_scenario::end(s);
}
```

### `ids_for_sender`：列出当前发送者库存中某类型的全部 `ID`

适合做「数量对不齐」类断言。

```move
#[test_only]
module examples::snippet_ids_sender;

use sui::test_scenario::{Self, Scenario};

public struct Stamp has key, store {
    id: UID,
}

#[test]
fun ids_for_sender_len() {
    let mut s: Scenario = test_scenario::begin(@0xA);
    {
        let ctx = test_scenario::ctx(&mut s);
        transfer::public_transfer(Stamp { id: object::new(ctx) }, @0xA);
        let ctx = test_scenario::ctx(&mut s);
        transfer::public_transfer(Stamp { id: object::new(ctx) }, @0xA);
    };
    test_scenario::next_tx(&mut s, @0xA);
    let ids = test_scenario::ids_for_sender<Stamp>(&s);
    assert!(ids.length() == 2, 0);
    let _fx = test_scenario::end(s);
}
```

### `take_from_address` / `return_to_address` / `take_from_address_by_id`

与「发送者」版本类似，但显式传入 **`account: address`**，用于模拟「Bob 的库存里有什么」。

```move
#[test_only]
module examples::snippet_take_address;

use sui::test_scenario::{Self, Scenario};

public struct Key has key, store {
    id: UID,
}

#[test]
fun take_from_address_roundtrip() {
    let bob = @0xB;
    let mut s: Scenario = test_scenario::begin(@0xA);
    {
        let ctx = test_scenario::ctx(&mut s);
        let k = Key { id: object::new(ctx) };
        transfer::public_transfer(k, bob);
    };
    test_scenario::next_tx(&mut s, bob);
    {
        let k: Key = test_scenario::take_from_address(&s, bob);
        test_scenario::return_to_address(bob, k);
    };
    let _fx = test_scenario::end(s);
}
```

### `has_most_recent_for_address` / `was_taken_from_sender`

- **`has_most_recent_for_address<T>(addr)`**：某地址是否有「最近转入且尚未被取走」的 `T`。  
- **`was_taken_from_sender(&s, id)`**：配合 `return_to_sender` 使用，可断言某 `ID` 是否经由本场景从发送者库存取出过（详见 Framework 文档注释）。

---

## 三、共享对象、不可变对象、时间与系统对象

### `take_shared` / `return_shared`

共享对象进入**全局库存**；任意发送者在对应 `next_tx` 后可用 **`take_shared`** 取出可变引用，用毕 **`return_shared`**。本书 **`object_lab::counter_tests`** 即典型写法。

```move
#[test_only]
module examples::snippet_shared_min;

use sui::test_scenario::{Self, Scenario};

public struct Counter has key, store {
    id: UID,
    value: u64,
}

fun share_new(ctx: &mut TxContext) {
    transfer::share_object(Counter {
        id: object::new(ctx),
        value: 0,
    });
}

fun bump(c: &mut Counter) {
    c.value = c.value + 1;
}

#[test]
fun shared_two_tx() {
    let mut s: Scenario = test_scenario::begin(@0xA);
    {
        let ctx = test_scenario::ctx(&mut s);
        share_new(ctx);
    };
    test_scenario::next_tx(&mut s, @0xB);
    {
        let mut c = test_scenario::take_shared<Counter>(&s);
        bump(&mut c);
        test_scenario::return_shared(c);
    };
    let _fx = test_scenario::end(s);
}
```

### `has_most_recent_shared` / `take_shared_by_id`

与拥有对象类似：多实例时用 **`take_shared_by_id(&s, id)`**；探测用 **`has_most_recent_shared<T>()`**（无 `scenario` 参数，与 Framework 签名一致）。

### `take_immutable` / `return_immutable`

冻结对象用 **`take_immutable`** 取出**只读**视图，必须用 **`return_immutable`** 归还，**不能**当可变共享对象使用。

```move
#[test_only]
module examples::snippet_immutable;

use sui::test_scenario::{Self, Scenario};

public struct Config has key, store {
    id: UID,
    max: u64,
}

fun freeze_cfg(ctx: &mut TxContext) {
    transfer::freeze_object(Config {
        id: object::new(ctx),
        max: 99,
    });
}

#[test]
fun immutable_roundtrip() {
    let mut s: Scenario = test_scenario::begin(@0xA);
    {
        let ctx = test_scenario::ctx(&mut s);
        freeze_cfg(ctx);
    };
    test_scenario::next_tx(&mut s, @0xA);
    {
        let cfg = test_scenario::take_immutable<Config>(&s);
        assert!(cfg.max == 99, 0);
        test_scenario::return_immutable(cfg);
    };
    let _fx = test_scenario::end(s);
}
```

### `next_epoch` / `later_epoch` / `skip_to_epoch`

- **`next_epoch(&mut s, sender)`**：epoch +1，并结束当前交易、开启以 `sender` 为发送者的新交易。  
- **`later_epoch(&mut s, delta_ms, sender)`**：在 `next_epoch` 基础上把 **`epoch_timestamp_ms`** 向前拨 `delta_ms` 毫秒。  
- **`skip_to_epoch(&mut s, epoch)`**：跳到指定 epoch（中间会多次 `end_transaction`），用于跨度较大的时间逻辑。

```move
#[test_only]
module examples::snippet_epoch;

use sui::test_scenario::{Self, Scenario};

#[test]
fun epoch_and_time() {
    let mut s: Scenario = test_scenario::begin(@0xA);
    assert!(test_scenario::ctx(&mut s).epoch() == 0, 0);
    let _fx1 = test_scenario::next_epoch(&mut s, @0xA);
    assert!(test_scenario::ctx(&mut s).epoch() == 1, 1);
    let _fx2 = test_scenario::later_epoch(&mut s, 500, @0xA);
    assert!(test_scenario::ctx(&mut s).epoch_timestamp_ms() == 500, 2);
    let _fx3 = test_scenario::end(s);
}
```

### `create_system_objects`

一键把 **`Clock`、`Random`、`DenyList`、`DisplayRegistry`** 等测试用系统对象放进场景（内部会调度 `next_tx`，详见 Framework 实现）。需要测 **Epoch / Random / Clock** 相关逻辑时，在 `begin` 后尽早调用。

```move
#[test_only]
module examples::snippet_sys_objects;

use sui::test_scenario::{Self, Scenario};

#[test]
fun with_system_objects() {
    let mut s: Scenario = test_scenario::begin(@0xA);
    test_scenario::create_system_objects(&mut s);
    // 之后按业务需要 next_tx，再 take_shared<Clock> / Random 等（API 以当前 Framework 为准）
    let _fx = test_scenario::end(s);
}
```

### `TxContextBuilder` 与 `next_with_context`

当默认 `begin` 生成的 `TxContext` 字段不够用（例如要改 **gas budget / sponsor / rgp** 或在不同时刻模拟 **epoch 跳跃**）时：

1. 用 **`test_scenario::ctx_builder_from_sender(addr)`** 或 **`ctx_builder(&s)`** 得到 `TxContextBuilder`；  
2. 链式调用 **`set_epoch` / `set_gas_budget` / `set_sponsor` …**；  
3. 用 **`next_with_context(&mut s, builder)`** 结束当前交易并以新上下文开启下一笔。

具体断言与字段含义以 **`sui::test_scenario`** 源码为准；日常测试多数场景 **`begin` + `next_tx` + `next_epoch` 已足够**。

### 宏 `with_shared!` / `with_shared_by_id!`（可选）

Framework 提供 **`with_shared!`**，在闭包体中自动 **`take_shared` + `return_shared`**，减少遗漏归还导致的 abort。需要时在业务测试模块中 **`use sui::test_scenario::with_shared;`**（宏名以当前版本 `test_scenario.move` 为准）。

---

## 综合示例：多地址 + `TransactionEffects` + 拥有对象

```move
#[test_only]
module examples::token_flow;

use sui::test_scenario::{Self, Scenario};

public struct Token has key, store {
    id: UID,
    amount: u64,
}

fun mint(amount: u64, ctx: &mut TxContext): Token {
    Token {
        id: object::new(ctx),
        amount,
    }
}

#[test]
fun transfer_flow_with_effects() {
    let admin = @0xAD;
    let alice = @0xA;
    let bob = @0xB;
    let mut s: Scenario = test_scenario::begin(admin);
    {
        let ctx = test_scenario::ctx(&mut s);
        let t = mint(1000, ctx);
        transfer::public_transfer(t, alice);
    };
    let fx1 = test_scenario::next_tx(&mut s, alice);
    assert!(test_scenario::created(&fx1).length() >= 1, 0);

    {
        assert!(test_scenario::has_most_recent_for_sender<Token>(&s), 1);
        let t: Token = test_scenario::take_from_sender(&s);
        assert!(t.amount == 1000, 2);
        transfer::public_transfer(t, bob);
    };
    let _fx2 = test_scenario::next_tx(&mut s, bob);
    {
        let t: Token = test_scenario::take_from_sender(&s);
        test_scenario::return_to_sender(&s, t);
    };
    let _fx3 = test_scenario::end(s);
}
```

---

## 函数速查（模块函数风格）

| 函数 | 典型用途 |
|------|----------|
| `begin(sender)` | 开启场景，第一笔 tx 的发送者 |
| `end(s)` | 结束场景，消费 `Scenario` |
| `ctx(&mut s)` | 当前 tx 的 `&mut TxContext` |
| `sender(&s)` | 当前 tx 发送者 |
| `new_object(&mut s)` | 等价于 `object::new(ctx)` |
| `next_tx(&mut s, sender)` | 结束上一笔、切换发送者，返回 `TransactionEffects` |
| `num_concluded_txes(&s)` | 已结束交易数 |
| `take_from_sender` / `return_to_sender` | 当前发送者库存 |
| `take_from_address` / `return_to_address` | 任意地址库存 |
| `take_from_sender_by_id` / `take_from_address_by_id` | 按 `ID` 精确取 |
| `has_most_recent_for_sender` / `most_recent_id_for_sender` / `ids_for_sender` | 探测 / 枚举 |
| `take_shared` / `return_shared` | 共享对象 |
| `take_immutable` / `return_immutable` | 冻结（不可变）对象 |
| `next_epoch` / `later_epoch` / `skip_to_epoch` | 时间线与 epoch |
| `create_system_objects` | 注入 Clock、Random 等测试系统对象 |
| `ctx_builder*` / `next_with_context` | 自定义 `TxContext` 字段 |

`TransactionEffects` 请使用 **`test_scenario::created(&fx)`** 等访问器，而非方法链式调用。

---

## 小结

- **`begin` / `end`** 界定整段测试；**`next_tx`** 界定「上一笔交易」与对象进入库存的时机。  
- **拥有对象**用 **`take_from_sender` / `take_from_address` 系列** 与 **`return_to_*`**；多实例时用 **`by_id`** 与 **`ids_for_*`**。  
- **共享 / 不可变**分别用 **`take_shared` / `return_shared`** 与 **`take_immutable` / `return_immutable`**，且须在规则允许的路径内配对归还。  
- **时间**用 **`next_epoch` / `later_epoch` / `skip_to_epoch`**；需要系统对象时用 **`create_system_objects`**。  
- 与真实项目一致的可运行示例见 **`src/08_object_model/code/object_lab/tests/`**、**`src/13_testing/code/testing_lab/tests/`**、**`src/15_nft_kiosk/code/simple_nft/tests/`**。
