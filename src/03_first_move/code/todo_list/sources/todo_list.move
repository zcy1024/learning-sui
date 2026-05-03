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
