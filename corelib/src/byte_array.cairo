use traits::{Into, TryInto};
use bytes_31::U128IntoBytes31;
use array::ArrayTrait;
use option::OptionTrait;
use integer::{u128_safe_divmod, u128_to_felt252, u8_to_felt252, u256_from_felt252};
use bytes_31::bytes31_try_from_felt252;
use zeroable::NonZeroIntoImpl;

// TODO(yg): move?
const POW_2_128: felt252 = 0x100000000000000000000000000000000;
// TODO(yg): change 16, 31 to constants.

// TODO(yg): optimize all `bytes31_try_from_felt252(0).unwrap()`s by adding a libfunc to create 0 bytes31.

// TODO(yg): remove drop? Should pass without it, even if we want drop. Check...
// TODO(yuval): don't allow creation of invalid ByteArray?
#[derive(Drop)]
struct ByteArray {
    // Full "words" of 31 bytes each.
    data: Array<bytes31>,
    // Less than 31 bytes. The number of bytes in here is specified in `num_pending_bytes`.
    pending_bytes: bytes31,
    // Should be in range [0, 30].
    num_pending_bytes: u8,
}

trait ByteArrayTrait {
    // TODO(yg): copy functions from impl. or use #[generate_trait]
    // TODO(yg): doc functions.
    // TODO(yg): params should be snapshots?
    fn new() -> ByteArray;
    fn concat_single(ref self: ByteArray, word: bytes31, num_bytes: u8);
    fn concat(ref self: ByteArray, other: ByteArray);
    fn append_char(ref self: ByteArray, byte: u8);
}

impl ByteArrayImpl of ByteArrayTrait {
    // TODO(yg): rename to default (or impl Default) and add a new that initializes it.
    fn new() -> ByteArray {
        ByteArray {
            data: Default::default(),
            pending_bytes: bytes31_try_from_felt252(0).unwrap(),
            num_pending_bytes: 0
        }
    }

    // This function assumes `word` has no more than `num_bytes` bytes of data. If it has, it can
    // corrupt the ByteArray. Thus, this should be a private function. We can add masking but it
    // would be more expensive.
    fn concat_single(ref self: ByteArray, word: bytes31, num_bytes: u8) {
        if (num_bytes == 0) {
            return;
        }
        assert(num_bytes <= 31, 'num_bytes > 31');

        // TODO(yg): this is an optimization - is it worth it?
        if self.num_pending_bytes == 0 {
            if num_bytes == 31 {
                self.data.append(word);
                return;
            } else {
                self.pending_bytes = word;
                self.num_pending_bytes = num_bytes;
                return;
            }
        }

        let word_felt252 = bytes31_to_felt252(word);
        let pending_felt252 = bytes31_to_felt252(self.pending_bytes);

        let num_total_pending_bytes = self.num_pending_bytes + num_bytes;
        if num_total_pending_bytes < 31 {
            let sum = word_felt252 * one_shift_left_bytes_felt252(self.num_pending_bytes)
                + pending_felt252;

            self.pending_bytes = bytes31_try_from_felt252(sum).unwrap();
            self.num_pending_bytes = num_total_pending_bytes;
            return;
        }

        if num_total_pending_bytes == 31 {
            let sum = (word_felt252 * one_shift_left_bytes_felt252(self.num_pending_bytes))
                + pending_felt252;

            self.data.append(bytes31_try_from_felt252(sum).unwrap());
            self.num_pending_bytes = 0;
            return;
        }

        // num_total_pending_bytes > 31
        let first_num_bytes = 31 - self.num_pending_bytes;
        let (first, second) = split_bytes31(
            value: word, value_len: num_bytes, index: first_num_bytes
        );
        let first_felt252 = bytes31_to_felt252(first);
        let felt_to_append = first_felt252 * one_shift_left_bytes_felt252(self.num_pending_bytes)
            + pending_felt252;
        // TODO(yg): verify this unwrap is safe.
        self.data.append(bytes31_try_from_felt252(felt_to_append).unwrap());
        self.pending_bytes = second;
        self.num_pending_bytes = num_bytes - first_num_bytes;
    }

    fn concat(ref self: ByteArray, mut other: ByteArray) {
        let mut num_data_left = other.data.len();
        loop {
            if num_data_left == 0 {
                break;
            }
            num_data_left -= 1;
            // TODO(yg): verify this unwrap is safe.
            let next = other.data.pop_front().unwrap();
            self.concat_single(next, 31);
        };
        self.concat_single(other.pending_bytes, other.num_pending_bytes);
    }

    fn append_char(ref self: ByteArray, byte: u8) {
        if self.num_pending_bytes == 0 {
            // TODO(yg): optimize by implementing libfunc u8_to_bytes31.
            self.pending_bytes = bytes31_try_from_felt252(u8_to_felt252(byte)).unwrap();
            self.num_pending_bytes = 1;
            return;
        }

        let new_pending = bytes31_try_from_felt252(
            bytes31_to_felt252(self.pending_bytes)
                + u8_to_felt252(byte) * one_shift_left_bytes_felt252(self.num_pending_bytes)
        )
            .unwrap();

        if self.num_pending_bytes != 30 {
            self.pending_bytes = new_pending;
            self.num_pending_bytes += 1;
            return;
        }

        // self.num_pending_bytes == 30
        self.data.append(new_pending);
        self.pending_bytes = bytes31_try_from_felt252(0).unwrap();
        self.num_pending_bytes = 0;
    }
}

// TODO(yg): move to bytes31 as a util?
// This function assumes `value` has no more than `value_len` bytes of data. If it has, it can
// corrupt the ByteArray. Thus, this should be a private function. We can add masking but it would
// be more expensive.
fn split_bytes31(value: bytes31, value_len: u8, index: u8) -> (bytes31, bytes31) {
    assert(index <= value_len, 'index > value_len');
    assert(value_len <= 31, 'value_len > 31');

    if index == 0 {
        return (bytes31_try_from_felt252(0).unwrap(), value);
    }
    if index == value_len {
        return (value, bytes31_try_from_felt252(0).unwrap());
    }

    let u256{low, high } = u256_from_felt252(bytes31_to_felt252(value));

    if index == 16 {
        return (low.into(), high.into());
    }

    if value_len <= 16 {
        let (quotient, remainder) = u128_safe_divmod(
            low, one_shift_left_bytes(index).try_into().unwrap()
        );
        return (remainder.into(), quotient.into());
    }

    // value_len > 16
    if index < 16 {
        let (low_quotient, low_remainder) = u128_safe_divmod(
            low, one_shift_left_bytes(index).try_into().unwrap()
        );
        let right = u128_to_felt252(high) * one_shift_left_bytes_felt252(16 - index)
            + u128_to_felt252(low_quotient);
        return (low_remainder.into(), bytes31_try_from_felt252(right).unwrap());
    }

    // value_len > 16 && index > 16
    let (high_quotient, high_remainder) = u128_safe_divmod(
        high, one_shift_left_bytes(index - 16).try_into().unwrap()
    );
    let left = u128_to_felt252(high_remainder) * POW_2_128 + u128_to_felt252(low);
    return (bytes31_try_from_felt252(left).unwrap(), high_quotient.into());
}

// Returns 1 << (8 * `n_bytes`) as felt252, where `n_bytes` must be < 31.
fn one_shift_left_bytes_felt252(n_bytes: u8) -> felt252 {
    if n_bytes < 16 {
        one_shift_left_bytes(n_bytes).into()
    } else {
        assert(n_bytes < 31, 'n_bytes > 30');
        one_shift_left_bytes(n_bytes - 16).into() * POW_2_128
    }
}

// Returns 1 << (8 * `n_bytes`) as u128, where `n_bytes` must be < 16.
fn one_shift_left_bytes(n_bytes: u8) -> u128 {
    if n_bytes == 0 {
        0x1_u128
    } else if n_bytes == 1 {
        0x100_u128
    } else if n_bytes == 2 {
        0x10000_u128
    } else if n_bytes == 3 {
        0x1000000_u128
    } else if n_bytes == 4 {
        0x100000000_u128
    } else if n_bytes == 5 {
        0x10000000000_u128
    } else if n_bytes == 6 {
        0x1000000000000_u128
    } else if n_bytes == 7 {
        0x100000000000000_u128
    } else if n_bytes == 8 {
        0x10000000000000000_u128
    } else if n_bytes == 9 {
        0x1000000000000000000_u128
    } else if n_bytes == 10 {
        0x100000000000000000000_u128
    } else if n_bytes == 11 {
        0x10000000000000000000000_u128
    } else if n_bytes == 12 {
        0x1000000000000000000000000_u128
    } else if n_bytes == 13 {
        0x100000000000000000000000000_u128
    } else if n_bytes == 14 {
        0x10000000000000000000000000000_u128
    } else if n_bytes == 15 {
        0x1000000000000000000000000000000_u128
    } else {
        panic_with_felt252('n_bytes > 15')
    }
}
