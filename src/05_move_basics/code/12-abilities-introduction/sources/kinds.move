module ch05_12_abilities_intro::kinds;

public struct OnlyCopy has copy {}

public struct CopyDrop has copy, drop {}

public struct WithStore has store, drop {
    flag: bool,
}

/// 仅用于让 `flag` 字段在示例包中「被使用」，避免 unused_field 警告。
public fun store_flag(w: &WithStore): bool {
    w.flag
}
