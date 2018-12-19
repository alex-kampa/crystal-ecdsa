require "openssl"
require "./lib_ec"
require "big"
# http://fm4dd.com/openssl/eckeycreate.htm
# https://stackoverflow.com/questions/34404427/how-do-i-check-if-an-evp-pkey-contains-a-private-key
# https://davidederosa.com/basic-blockchain-programming/elliptic-curve-keys/

module ECCrypto

  def self.create_key_pair
    # Create a EC key structure, setting the group type from NID
    eccgrp_id = LibSSL.OBJ_txt2nid("secp256k1")
    raise "Error could not set EC group" unless eccgrp_id != 0
    myecc = LibSSL.EC_KEY_new_by_curve_name(eccgrp_id)
    raise "Error could not create curve" if myecc.null?

    # Create the public/private EC key pair
    gen_res = LibSSL.EC_KEY_generate_key(myecc)
    raise "Error could not generate an EC public/private key pair" unless gen_res == 1

    #  Get the private key
    bn = LibSSL.EC_KEY_get0_private_key(myecc)
    raise "Error could not get the private key" if bn.null?
    private_key_pointer = LibSSL.BN_bn2hex(bn)
    raise "Error could not get the private key pointer" if private_key_pointer.null?
    private_key = String.new(private_key_pointer).downcase

    # Get the public key
    ec_point = LibSSL.EC_KEY_get0_public_key(myecc)
    raise "Error could not get the public key" if ec_point.null?
    form = LibSSL::PointConversionFormT::PointConversionUncompressed
    eccgrp = LibSSL.EC_GROUP_new_by_curve_name(eccgrp_id)
    raise "Error could not get the group curve" if eccgrp.null?
    public_key_pointer = LibSSL.EC_POINT_point2hex(eccgrp, ec_point, form)
    raise "Error could not get the public key pointer" if public_key_pointer.null?
    public_key = String.new(public_key_pointer).downcase

    # Free up mem
    LibSSL.EC_KEY_free(myecc)
    LibSSL.EC_GROUP_free(eccgrp)

    return create_key_pair if private_key.hexbytes? == nil || private_key.size != 64
    return create_key_pair if public_key.hexbytes? == nil || public_key.size != 130

    {
      hex_private_key: private_key,
      hex_public_key:  public_key,
    }
  end

  def self.sha256(base : Bytes | String) : String
    hash = OpenSSL::Digest.new("SHA256")
    hash.update(base)
    hash.hexdigest
  end

  def self.sign(hex_private_key : String, message : String)
    # Create a EC key structure, setting the group type from NID
    eccgrp_id = LibSSL.OBJ_txt2nid("secp256k1")
    raise "Error could not set EC group" unless eccgrp_id != 0
    myecc = LibSSL.EC_KEY_new_by_curve_name(eccgrp_id)
    raise "Error could not create curve" if myecc.null?

    # set signing algo
    LibSSL.EC_KEY_set_asn1_flag(myecc, 1)

    # convert hex private key to binary
    bn = LibSSL.BN_new
    raise "Error could not create a new bn" if bn.null?
    binary_private_key = LibSSL.BN_hex2bn(pointerof(bn), hex_private_key)
    raise "Error private key binary is wrong size" if binary_private_key != 64

    # add binary private key to EC structure
    set_key = LibSSL.EC_KEY_set_private_key(myecc, bn)
    raise "Error could not set private key to EC" unless set_key == 1

    # # ------------
    # # convert binary public key to point
    # eccgrp = LibSSL.EC_GROUP_new_by_curve_name(eccgrp_id)
    # raise "Error could not get the group curve" if eccgrp.null?
    # ec_point = LibSSL.EC_POINT_new(eccgrp)
    # raise "Error could not create point from group" if ec_point.null?
    #
    # point_res = LibSSL.EC_POINT_hex2point(eccgrp, hex_public_key.to_unsafe, ec_point, nil)
    # raise "Error could not get point from public key" if point_res.null?
    #
    # # set the public key on the EC structure
    # set_key = LibSSL.EC_KEY_set_public_key(myecc, ec_point)
    # raise "Error could not set public key to EC" unless set_key == 1
    #
    # # ------------


    # sign
    sign_pointer = LibSSL.ECDSA_do_sign(message, message.bytesize, myecc)
    raise "Error could not sign message with key" if sign_pointer.null?

    # get the r,s from the signing
    r_raw = LibSSL.ECDSA_SIG_get0_r(sign_pointer)
    r_hex = LibSSL.BN_bn2hex(r_raw)
    r = String.new(r_hex).downcase

    s_raw = LibSSL.ECDSA_SIG_get0_s(sign_pointer)
    s_hex = LibSSL.BN_bn2hex(s_raw)
    s = String.new(s_hex).downcase

    # Free up mem
    LibSSL.EC_KEY_free(myecc)
    LibSSL.BN_clear_free(bn)
    LibSSL.ECDSA_SIG_free(sign_pointer)

    {
      r: r,
      s: s,
    }
  end

  def self.verify(hex_public_key : String, message : String, r : String, s : String)
    # Create a EC key structure, setting the group type from NID
    eccgrp_id = LibSSL.OBJ_txt2nid("secp256k1")
    raise "Error could not set EC group" unless eccgrp_id != 0
    myecc = LibSSL.EC_KEY_new_by_curve_name(eccgrp_id)
    raise "Error could not create curve" if myecc.null?

    # convert binary public key to point
    eccgrp = LibSSL.EC_GROUP_new_by_curve_name(eccgrp_id)
    raise "Error could not get the group curve" if eccgrp.null?
    ec_point = LibSSL.EC_POINT_new(eccgrp)
    raise "Error could not create point from group" if ec_point.null?

    point_res = LibSSL.EC_POINT_hex2point(eccgrp, hex_public_key.to_unsafe, ec_point, nil)
    raise "Error could not get point from public key" if point_res.null?

    # set the public key on the EC structure
    set_key = LibSSL.EC_KEY_set_public_key(myecc, ec_point)
    raise "Error could not set public key to EC" unless set_key == 1

    # create signature
    signature = LibSSL.ECDSA_SIG_new
    raise "Error could not create a new signature" if signature.null?

    # convert r,s hex to bn
    r_bn = LibSSL.BN_new
    raise "Error could not create a new bn for r" if r_bn.null?
    LibSSL.BN_hex2bn(pointerof(r_bn), r)

    s_bn = LibSSL.BN_new
    raise "Error could not create a new bn for s" if s_bn.null?
    LibSSL.BN_hex2bn(pointerof(s_bn), s)

    # set r,s onto signature
    LibSSL.ECDSA_SIG_set0(signature, r_bn, s_bn)

    # verify
    result = LibSSL.ECDSA_do_verify(message, message.bytesize, signature, myecc)

    # Free up mem
    LibSSL.EC_KEY_free(myecc)
    LibSSL.EC_POINT_free(ec_point)
    LibSSL.BN_clear_free(r_bn)
    LibSSL.BN_clear_free(s_bn)
    LibSSL.ECDSA_SIG_free(signature)

    result == 1
  end


end


key_pair = ECCrypto.create_key_pair
private_key = key_pair[:hex_private_key]
public_key = key_pair[:hex_public_key]

message = ECCrypto.sha256("this message is being signed")
sig = ECCrypto.sign(private_key, message)
p ECCrypto.verify(public_key, message, sig["r"], sig["s"])
