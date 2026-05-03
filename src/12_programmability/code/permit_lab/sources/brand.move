/// 定义 `Brand` 类型，并作为**唯一**能构造 `std::internal::Permit<Brand>` 的模块。
module permit_lab::brand;

use std::internal::Permit;

#[error]
const ENameEmpty: vector<u8> = b"display name must be non-empty";

/// 由本模块独占的类型标记；其它包无法调用 `internal::permit<Brand>()`。
public struct Brand has drop {}

/// 向调用方发放「本模块已授权」的证明；只有此处能合法构造 `Permit<Brand>`。
public fun issue_permit(): Permit<Brand> {
    internal::permit<Brand>()
}

/// 由 `Brand` 所在模块提供的业务校验，供注册表在消费 `Permit` 时复用。
public fun assert_non_empty_name(name: &vector<u8>) {
    assert!(vector::length(name) > 0, ENameEmpty);
}
