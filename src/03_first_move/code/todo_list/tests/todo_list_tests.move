#[test_only]
module todo_list::todo_list_tests;

use std::string;
use std::unit_test::destroy;
use todo_list::todo_list::{Self, TodoList};

#[test]
fun test_add_remove_length() {
    let ctx = &mut tx_context::dummy();
    let mut list: TodoList = todo_list::new(ctx);
    todo_list::add(&mut list, string::utf8(b"a"));
    todo_list::add(&mut list, string::utf8(b"b"));
    assert!(todo_list::length(&list) == 2);
    let s = todo_list::remove(&mut list, 0);
    assert!(s == string::utf8(b"a"));
    assert!(todo_list::length(&list) == 1);
    destroy(list);
}
