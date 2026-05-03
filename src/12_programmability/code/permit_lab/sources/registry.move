/// 消费 `Permit<Brand>`：没有来自 `brand` 模块签发的证明，就无法通过类型检查调用本函数。
module permit_lab::registry;

use permit_lab::brand;
use std::internal::Permit;

/// 演示「带 Permit 的入口」：第二个参数是普通数据，第一个参数把授权绑定到类型 `Brand`。
public fun register_display_name(_proof: Permit<brand::Brand>, display_name: vector<u8>): u64 {
    brand::assert_non_empty_name(&display_name);
    vector::length(&display_name)
}
