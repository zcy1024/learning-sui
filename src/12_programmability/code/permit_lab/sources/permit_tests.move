#[test_only]
module permit_lab::permit_tests;

use permit_lab::brand;
use permit_lab::registry;

#[test]
fun register_with_issued_permit() {
    let proof = brand::issue_permit();
    let len = registry::register_display_name(proof, b"DemoToken");
    assert!(len == 9);
}
