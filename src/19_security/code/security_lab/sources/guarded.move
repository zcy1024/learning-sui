/// 第十八章：能力对象（Capability）约束敏感操作的最小模式。
/// 演示 Clever Errors（`#[error]`）；正文见第二十章「错误处理最佳实践」。
module ch18_security_lab::guarded;

#[error]
const EInsufficientVaultBalance: vector<u8> = b"Vault balance insufficient";

public struct AdminCap has key, store {
    id: object::UID,
}

public struct Vault has key {
    id: object::UID,
    balance: u64,
}

/// 仅持有 `AdminCap` 的调用者可读取金库余额（示例：真实项目需额外检查 `TxContext::sender`）。
public fun read_balance(_cap: &AdminCap, v: &Vault): u64 {
    v.balance
}

/// 扣减金库余额；余额不足时以可读 Clever Error 中止（非裸 `u64` 码）。
public fun withdraw(_cap: &AdminCap, v: &mut Vault, amount: u64) {
    assert!(v.balance >= amount, EInsufficientVaultBalance);
    v.balance = v.balance - amount;
}
