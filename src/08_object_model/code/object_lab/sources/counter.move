/// 第八章对象模型：带 `key` 与 `UID` 的最小链上对象示例。
module object_lab::counter;

public struct Counter has key, store {
    id: UID,
    value: u64,
}

public fun new(ctx: &mut TxContext): Counter {
    Counter {
        id: object::new(ctx),
        value: 0,
    }
}

/// 教学用：将调用方传入的 `Counter` 转为共享对象（会触发 share_owned lint，此处显式允许）。
#[allow(lint(share_owned))]
public fun share(self: Counter) {
    transfer::public_share_object(self);
}

public fun value(self: &Counter): u64 {
    self.value
}

public fun bump(self: &mut Counter) {
    self.value = self.value + 1;
}

/// 实战练习：将计数归零。
public fun reset(self: &mut Counter) {
    self.value = 0;
}
