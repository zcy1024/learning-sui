module ch06_01_stdlib::demo;

public fun empty_vec_len(): u64 {
    let v = vector<u64>[];
    v.length()
}
