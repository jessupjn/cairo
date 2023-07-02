use array::ArrayTrait;
use byte_array::{split_bytes31, ByteArrayTrait};
use option::OptionTrait;

// TODO(yg): move to bytes31?
#[test]
fn test_split_bytes31() {
    let x = bytes31_try_from_felt252(0x1122).unwrap();
    let (left, right) = split_bytes31(x, 2, 1);
    assert(bytes31_to_felt252(left) == 0x22, 'bad split (2, 1) left');
    assert(bytes31_to_felt252(right) == 0x11, 'bad split (2, 1) right');

    let x = bytes31_try_from_felt252(0x112233445566778899aabbccddeeff00112233).unwrap();
    let (left, right) = split_bytes31(x, 19, 0);
    assert(bytes31_to_felt252(left) == 0, 'bad split (19, 0) left');
    assert(
        bytes31_to_felt252(right) == 0x112233445566778899aabbccddeeff00112233,
        'bad split (19, 0) right'
    );

    let (left, right) = split_bytes31(x, 19, 1);
    assert(bytes31_to_felt252(left) == 0x33, 'bad split (19, 1) left');
    assert(
        bytes31_to_felt252(right) == 0x112233445566778899aabbccddeeff001122,
        'bad split (19, 1) right'
    );

    let (left, right) = split_bytes31(x, 19, 15);
    assert(bytes31_to_felt252(left) == 0x5566778899aabbccddeeff00112233, 'bad split (19, 15) left');
    assert(bytes31_to_felt252(right) == 0x11223344, 'bad split (19, 15) right');

    let (left, right) = split_bytes31(x, 19, 16);
    assert(
        bytes31_to_felt252(left) == 0x445566778899aabbccddeeff00112233, 'bad split (19, 16) left'
    );
    assert(bytes31_to_felt252(right) == 0x112233, 'bad split (19, 16) right');

    let (left, right) = split_bytes31(x, 19, 18);
    assert(
        bytes31_to_felt252(left) == 0x2233445566778899aabbccddeeff00112233,
        'bad split (19, 18) left'
    );
    assert(bytes31_to_felt252(right) == 0x11, 'bad split (19, 18) right');

    let (left, right) = split_bytes31(x, 19, 19);
    assert(
        bytes31_to_felt252(left) == 0x112233445566778899aabbccddeeff00112233,
        'bad split (19, 19) left'
    );
    assert(bytes31_to_felt252(right) == 0, 'bad split (19, 19) right');
}

#[test]
#[available_gas(1000000)]
fn test_append_char() {
    let mut ba = ByteArrayTrait::new();
    let mut c = 1_u8;
    loop {
        if c == 34 {
            break;
        }
        ba.append_char(c);
        c += 1;
    };

    assert(ba.data.len() == 1, 'data len != 1');
    assert(
        bytes31_to_felt252(
            ba.data.pop_front().unwrap()
        ) == 0x1f1e1d1c1b1a191817161514131211100f0e0d0c0b0a090807060504030201,
        'wrong data[0]'
    );
    assert(ba.num_pending_bytes == 2, 'num_pending_bytes != 2');
    assert(bytes31_to_felt252(ba.pending_bytes) == 0x2120, 'wrong pending_bytes');
}
