/// 第十章实战：`init` 仅在发布时运行一次，向部署者发放 `LabAdminCap`。
module programmability_lab::lab_init;

public struct LabAdminCap has key, store {
    id: UID,
}

fun init(ctx: &mut TxContext) {
    transfer::public_transfer(
        LabAdminCap {
            id: object::new(ctx),
        },
        tx_context::sender(ctx),
    );
}
