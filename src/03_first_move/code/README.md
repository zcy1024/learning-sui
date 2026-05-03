# 第三章 · 示例代码

| 目录 | 对应正文 | 说明 |
|------|-----------|------|
| **`hello_world/`** | §3.1 Hello World | `Hello` 对象与 `entry fun mint_hello` |
| **`todo_list/`** | §3.2 Hello Sui | `TodoList` 对象；`build` / `test` / `publish` 练习 |

## `hello_world/`

```bash
cd hello_world
sui move build
sui move test
```

- **Move 2024**：`edition = "2024"`，Framework 为隐式依赖。

## `todo_list/`

与 **§3.2 · 部署合约到 Sui 网络** 中的 TodoList 示例一致。

```bash
cd todo_list
sui move build
sui move test
```

发布（需已配置 `sui client` 网络与 Gas）：

```bash
sui client publish
```

记录输出中的 **Package ID**，供 §3.3 与后续章节调用。
