use option::OptionTrait;

#[test]
fn test_bytes31_to_from_felt252() {
    let one_as_bytes31: Option<bytes31> = bytes31_try_from_felt252(1);
    assert(one_as_bytes31.is_some(), '1 is not a bytes31');
    let one_as_felt252 = bytes31_to_felt252(one_as_bytes31.unwrap());
    assert(one_as_felt252 == 1_felt252, 'bad cast: 1');

    let pow_2_248 = 0x100000000000000000000000000000000000000000000000000000000000000;

    let out_of_range: Option<bytes31> = bytes31_try_from_felt252(pow_2_248);
    assert(out_of_range.is_none(), '2^248 is a bytes31');

    let max_as_bytes31: Option<bytes31> = bytes31_try_from_felt252(pow_2_248 - 1);
    assert(max_as_bytes31.is_some(), '2^248 - 1 is not a bytes31');
    let max_as_felt252 = bytes31_to_felt252(max_as_bytes31.unwrap());
    assert(max_as_felt252 == pow_2_248 - 1, 'bad cast: 2^248 - 1');
}

use traits::Into;
use bytes_31::U128IntoBytes31;
#[test]
fn test_u128_into_bytes31() {
    let one_u128 = 1_u128;
    let one_as_bytes31: bytes31 = one_u128.into();
    assert(bytes31_to_felt252(one_as_bytes31) == 1_felt252, 'bad cast: 1');

    let max_u128 = 0xffffffffffffffffffffffffffffffff_u128;
    let max_as_bytes31: bytes31 = max_u128.into();
    assert(
        bytes31_to_felt252(max_as_bytes31) == 0xffffffffffffffffffffffffffffffff_felt252,
        'bad cast: 2^128 - 1'
    );
}
