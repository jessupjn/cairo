#[derive(Copy, Drop)]
extern type bytes31;

extern fn bytes31_try_from_felt252(value: felt252) -> Option<bytes31> implicits(RangeCheck) nopanic;
extern fn bytes31_to_felt252(value: bytes31) -> felt252 nopanic;

impl U128IntoBytes31 of Into<u128, bytes31> {
    fn into(self: u128) -> bytes31 {
        integer::upcast(self)
    }
}
