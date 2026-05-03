# 部署合约到 Sui 网络

> **与侧边栏目录对应**：3.2 Hello Sui — 部署到链上

编写和测试 Move 代码只是第一步，真正激动人心的是将合约部署到 Sui 网络上并让它运行起来。本节将通过一个 TodoList 合约示例，完整演示从编写到发布的全过程，并深入解读发布交易的每一个细节。

## 准备工作

在部署之前，确保你已完成以下准备（详见[钱包与测试币](../02_getting_started/03-wallet-and-faucet.md)章节）：

```bash
# 1. 确认当前网络为 devnet 或 testnet
sui client envs

# 2. 切换到 devnet（如果需要）
sui client switch --env devnet

# 3. 确认有足够的测试币
sui client balance

# 4. 如果余额不足，获取测试币
sui client faucet
```

## 编写 TodoList 合约

```move
/// 与本书 3.2「Hello Sui」对应：可上链的待办列表对象，用于练习 `sui move build` / `publish`。
module todo_list::todo_list;

use std::string::String;

/// 一个简单的待办事项列表（链上对象）。
public struct TodoList has key, store {
    id: object::UID,
    items: vector<String>,
}

/// 创建一个新的待办事项列表。
public fun new(ctx: &mut TxContext): TodoList {
    TodoList {
        id: object::new(ctx),
        items: vector[],
    }
}

/// 添加一个待办事项。
public fun add(list: &mut TodoList, item: String) {
    vector::push_back(&mut list.items, item);
}

/// 删除指定位置的待办事项，返回被删除的内容。
public fun remove(list: &mut TodoList, index: u64): String {
    vector::remove(&mut list.items, index)
}

/// 获取待办事项数量。
public fun length(list: &TodoList): u64 {
    vector::length(&list.items)
}
```

让我们解析这个合约的关键要素：

### 结构体定义

```move
public struct TodoList has key, store {
    id: object::UID,
    items: vector<String>,
}
```

- `has key`：表示该结构体是一个 Sui 对象，拥有全局唯一的 `id`
- `has store`：表示该对象可以被存储在其他对象中，也可以被转移
- `id: UID`：每个 Sui 对象必须有的唯一标识符字段
- `items: vector<String>`：使用向量存储待办事项列表

### 对象创建

```move
public fun new(ctx: &mut TxContext): TodoList {
    TodoList {
        id: object::new(ctx),
        items: vector[],
    }
}
```

- `ctx: &mut TxContext`：交易上下文，用于生成唯一 ID
- `object::new(ctx)`：创建新的 `UID`
- `vector[]`：Move 2024 的空向量字面量语法

### 构建与测试

在 **`todo_list` 包根目录**（本书为 `src/03_first_move/code/todo_list/`）执行：

```bash
sui move build
sui move test
```

确保编译与测试通过、无错误。

## 发布合约

使用以下命令将合约发布到链上（**须在包根目录**，且 `sui client` 已切到 devnet/testnet 并有测试币）：

```bash
cd src/03_first_move/code/todo_list   # 路径以你克隆仓库的位置为准
sui client publish
```

## 解读发布交易输出

发布成功后，CLI 会输出大量信息。让我们逐部分解读。

### Transaction Digest

```
Transaction Digest: 5JxQpNBk4r5F2UaGRe4Vb9DF7hLZqijU3aTvN8H7kQ2W
```

交易摘要（Digest）是交易的唯一标识符，可以在区块浏览器中查看交易详情。

### Transaction Data

```
╭──────────────────────────────────────────────────────────╮
│ Transaction Data                                         │
├──────────────────────────────────────────────────────────┤
│ Sender: 0x7d20dcdb...                                    │
│ Gas Budget: 100000000 MIST                               │
│ Commands:                                                │
│   Publish:                                               │
│     - Package: todo_list                                 │
│   TransferObjects:                                       │
│     - UpgradeCap → Sender                                │
╰──────────────────────────────────────────────────────────╯
```

- **Sender**：发布者的地址
- **Commands**：交易包含两个命令
  - **Publish**：发布 `todo_list` 包
  - **TransferObjects**：将 `UpgradeCap`（升级能力）转移给发布者

### Transaction Effects

```
╭──────────────────────────────────────────────────────────╮
│ Transaction Effects                                      │
├──────────────────────────────────────────────────────────┤
│ Status: Success                                          │
│ Created Objects:                                         │
│   - Package:    0xabc123...                              │
│   - UpgradeCap: 0xdef456...                              │
│ Gas Cost Summary:                                        │
│   Storage Cost:  8976000 MIST                            │
│   Computation Cost: 1000000 MIST                         │
│   Total Gas Cost: 9976000 MIST                           │
│   Storage Rebate: 978120 MIST                            │
╰──────────────────────────────────────────────────────────╯
```

- **Status: Success**：交易执行成功
- **Created Objects**：创建了两个对象
  - **Package**：发布的包，包含你的 Move 模块
  - **UpgradeCap**：升级能力对象，后续升级包时需要用到
- **Gas Cost**：Gas 费用明细

### Object Changes

```
╭──────────────────────────────────────────────────────────╮
│ Object Changes                                           │
├──────────────────────────────────────────────────────────┤
│ Published Objects:                                       │
│   PackageID: 0xabc123def456...                           │
│   Modules: todo_list                                     │
╰──────────────────────────────────────────────────────────╯
```

**PackageID** 是你的合约在链上的唯一标识，后续调用合约函数时需要用到它。

> **重要**：请记录下你的 PackageID，后续章节将需要使用它。

## 使用 JSON 格式输出

添加 `--json` 标志可以获取 JSON 格式的输出，方便程序化解析：

```bash
sui client publish --json
```

JSON 输出更适合脚本自动化处理，你可以用 `jq` 提取关键信息：

```bash
# 发布并提取 PackageID
sui client publish --json | jq -r '.objectChanges[] | select(.type == "published") | .packageId'
```


## 在区块浏览器上查看

你可以在 Sui 区块浏览器上查看已发布的包：

- **Devnet**：`https://suiscan.xyz/devnet/object/<PackageID>`
- **Testnet**：`https://suiscan.xyz/testnet/object/<PackageID>`

在浏览器中你可以看到：

- 包的所有模块
- 每个模块的公开函数
- 结构体定义
- 历史交易

## 完整发布流程总结

```bash
# 1. 进入本书配套包（或自建 todo_list 并对齐源码）
cd src/03_first_move/code/todo_list

# 2. 构建与测试
sui move build
sui move test

# 3. 确保有测试币
sui client faucet

# 4. 发布
sui client publish

# 5. 记录 PackageID
export PACKAGE_ID=0x<your-package-id>
```

## 小结

本节我们完成了一个 TodoList 合约的编写和链上发布。关键步骤包括：使用 `sui client publish` 发布包、理解交易输出中的 Digest、Effects、Created Objects 等信息。发布后我们获得了两个重要对象——**Package**（包含合约代码）与 **UpgradeCap**（升级能力）。本节的 `todo_list` 未使用模块 **`init`**；若你想了解「首次发布时自动跑一次」的初始化机制，可读 [第四章 · 包 — 首次发布与 init](../04_concepts/01-packages.md#pkg-init)，系统讲解见 [第十二章 §12.3](../12_programmability/03-module-initializer.md)。记录好 PackageID，下一节我们将学习如何通过 CLI 与已发布的合约进行交互。
