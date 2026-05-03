# Sui 生态全景

本节概述 Sui 网络上的**浏览器入口、官方钱包**、开发者工具与主流应用方向。浏览器与钱包的界面会随产品迭代而变化，**使用前请在页内切换到正确的网络**（Mainnet / Testnet / Devnet），并以各产品官网与 [docs.sui.io](https://docs.sui.io/) 当前说明为准。

## 常用区块链浏览器

浏览器用于按**地址、对象 ID、交易摘要、包 ID** 等查询链上状态、代币余额与交易轨迹。下列为社区与文档中**最常引用**的 Sui 浏览器（非穷尽列表；第三方产品由各自团队运营）。

| 名称 | 说明 | 入口（示例） |
|------|------|----------------|
| **SuiVision** | Mysten 生态常用的可视化浏览器，支持多网络切换 | [suivision.xyz](https://suivision.xyz/)（各环境子域见站点内切换，例如 Testnet） |
| **SuiScan** | 使用面广泛的浏览器，支持账户 / 对象 / 交易 / 包等维度查询 | [suiscan.xyz](https://suiscan.xyz/)（进入后在界面中选择网络） |

官方文档在介绍地址与链上查询时，也会列举常用浏览器，可与上表对照：[Create a Sui Address — Query information about an address](https://docs.sui.io/guides/developer/getting-started/get-address#query-information-about-an-address) 一节中的 *Popular Sui explorers*。

> **注意**：不同浏览器对同一链上数据的展示字段、索引延迟可能略有差异；**合约调试与脚本自动化**仍以 `sui client`、TypeScript SDK 等为准，浏览器适合人工核对与分享链接。

## 官方钱包（Slush）

**Slush** 由 **Mysten Labs** 提供，是 Sui 上当前的**官方钱包**产品（浏览器扩展、网页与移动端等；以 Chromium 系浏览器扩展为常见入口）。2025 年起，原 **Sui Wallet** 与 **Stashed** 已合并并更名为 **Slush**（公告见 [Sui Wallet and Stashed are Now Slush](https://www.mystenlabs.com/blog/sui-wallet-and-stashed-are-now-slush)）：已安装旧版扩展的用户一般会通过应用商店**自动更新**获得新名称与界面，**账户、助记词与地址通常保持不变**；新用户请一律从官方站点获取入口，勿轻信陌生「单独下载 Slush」链接。

典型用途包括：保存地址与助记词（或使用 zkLogin 等低门槛登录）、切换网络、连接 dApp、签名交易与消息。实现上仍遵循 **Wallet Standard**，因此许多教程与前端（如 `@mysten/dapp-kit-react`）在连接列表中会显示 **Slush** 或与商店上架名称一致的条目。

- **官方入口**：[slush.app](https://slush.app/) · 使用说明：[Slush user guides](https://slush.app/guides/) · 产品总览：[Mysten · Products](https://www.mystenlabs.com/products)  
- **与本书其他章节的关系**：用 **CLI 管理本地地址与领测试币**见 [第二章 · 钱包与测试币](../02_getting_started/03-wallet-and-faucet.md)；在 **网页里连接钱包、调用合约**见第十七章、第十八章与 dApp Kit 相关小节。文档与商店展示名称若仍有「Sui Wallet」等历史字样，以 **Slush** 官方页面为准。

除官方钱包外，生态中还有其它兼容 Wallet Standard 的实现；选型时请关注**是否开源审计、支持网络、是否与你的 dApp 依赖的 API 版本一致**。

## 开发者入口

- 官方文档：<https://docs.sui.io/>
- 主网 / 测试网与部署、RPC 等进阶说明见本书后续章节（如第二章网络配置、第十七章客户端等）。
