// TODO(lior): Remove this once the impl of ec.cairo is automatically found.
impl OptionEcPointCopy of Copy::<Option::<EcPoint>>;

// Checks if (`signature_r`, `signature_s`) is a valid ECDSA signature for the given `public_key`
// on the given `message`.
//
// Note: the verification algorithm implemented by this function slightly deviates from the
// standard ECDSA.
// While this does not allow to create valid signatures if one does not possess the private key,
// it means that the signature algorithm used should be modified accordingly.
// Namely, it should check that `r, s < StarkCurve::ORDER`.
//
// Arguments:
// * `message_hash` - the signed message.
// * `public_key` - the public key corresponding to the key with which the message was signed.
// * `signature_r` - the `r` component of the ECDSA signature.
// * `signature_s` - the `s` component of the ECDSA signature.
//
// Returns:
//   `true` if the signature is valid and `false` otherwise.
fn check_ecdsa_signature(
    message_hash: felt, public_key: felt, signature_r: felt, signature_s: felt
) -> bool {
    // TODO(lior): Change to || once short circuiting is supported.
    // Check that s != 0 (mod StarkCurve.ORDER).
    if (signature_s == 0) {
        return false;
    }
    if (signature_s == ec::StarkCurve::ORDER) {
        return false;
    }
    if (signature_r == ec::StarkCurve::ORDER) {
        return false;
    }

    // Check that the public key is the x coordinate of a point on the curve and get such a point.
    let public_key_point = match ec::ec_point_from_x(public_key) {
        Option::Some(point) => point,
        Option::None(()) => {
            return false;
        },
    };

    // Check that `r` is the x coordinate of a point on the curve and get such a point.
    // Note that this ensures that `r != 0`.
    let signature_r_point = match ec::ec_point_from_x(signature_r) {
        Option::Some(point) => point,
        Option::None(()) => {
            return false;
        },
    };

    // Retrieve the generator point.
    let gen_point = match ec_point_try_new(ec::StarkCurve::GEN_X, ec::StarkCurve::GEN_Y) {
        Option::Some(point) => point,
        Option::None(()) => { return false; },
    };

    // To verify ECDSA, obtain:
    //   zG = z * G, where z is the message and G is a generator of the EC.
    //   rQ = r * Q, where Q.x = public_key.
    //   sR = s * R, where R.x = r.
    // and check that:
    //   zG +/- rQ = +/- sR, or more efficiently that:
    //   (zG +/- rQ).x = sR.x.

    let zG: Option::<EcPoint> = ec_mul(gen_point, message_hash);
    let rQ: Option::<EcPoint> = ec_mul(public_key_point, signature_r);
    let sR: Option::<EcPoint> = ec_mul(signature_r_point, signature_s);
    let (x_, y_) = ec_point_unwrap(option_unwrap::<EcPoint>(sR));
    debug::print_felt('sR.x')
    debug::print_felt(x_)

    let sR_x = match sR {
        Option::Some(pt) => {
            let (x, y) = ec_point_unwrap(pt);
            x
        },
        Option::None(()) => { return false; },
    };

    debug::print_felt('zG.x')
    let (x_, y_) = ec_point_unwrap(option_unwrap::<EcPoint>(zG));
    debug::print_felt(x_)
    let (x_, y_) = ec_point_unwrap(option_unwrap::<EcPoint>(rQ));
    debug::print_felt(x_)
    let (x_, y_) = ec_point_unwrap(signature_r_point);
    debug::print_felt('signature_r_point.x')
    debug::print_felt(x_)
    debug::print_felt('signature_r_point.y')
    debug::print_felt(y_)
    debug::print_felt('signature_s')
    debug::print_felt(signature_s)
    debug::print_felt('signature_r')
    debug::print_felt(signature_r)
    let candidate: Option::<EcPoint> = ec_add(zG, rQ);
    match candidate {
        Option::Some(pt) => {
            debug::print_felt('HERE')
            let (x, y) = ec_point_unwrap(pt);
            debug::print_felt(x)
            if (x == sR_x) {
                return true;
            }
        },
        Option::None(()) => {},
    };

    let candidate2: Option::<EcPoint> = ec_sub(zG, rQ);
    match candidate2 {
        Option::Some(pt) => {
            debug::print_felt('HERE')
            let (x, y) = ec_point_unwrap(pt);
            debug::print_felt(x)
            if (x == sR_x) {
                return true;
            }
        },
        Option::None(()) => {},
    };

    return false;
}