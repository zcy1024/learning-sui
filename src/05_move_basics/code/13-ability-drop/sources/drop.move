module ch05_13_ability_drop::drop_only;

public struct Token has drop {
    amount: u64,
}

public fun amount(t: &Token): u64 {
    t.amount
}
