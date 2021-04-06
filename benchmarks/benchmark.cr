require "benchmark"
require "./../src/crystal-ecdsa"

# generate a keypair
key_pair = ECCrypto.create_key_pair
private_key = key_pair[:hex_private_key]
public_key = key_pair[:hex_public_key]

message = ECCrypto.sha256("this message is being signed")
sig = ECCrypto.sign(private_key, message)
encrypted_message = ECCrypto.encrypt(public_key, "This is a secret message")

Benchmark.ips do |x|

  x.report("hash") do
    ECCrypto.sha256("this message is being signed")
  end

  x.report("sign") do
    ECCrypto.sign(private_key, message)
  end

  x.report("verify") do
    ECCrypto.verify(public_key, message, sig["r"], sig["s"])
  end

  x.report("encrypt") do
    ECCrypto.encrypt(public_key, "This is a secret message")
  end

  x.report("decrypt") do
    ECCrypto.decrypt(private_key, encrypted_message)
  end

end