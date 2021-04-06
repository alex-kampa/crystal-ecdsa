require "./../src/crystal-ecdsa"

# generate a keypair
key_pair = ECCrypto.create_key_pair
private_key = key_pair[:hex_private_key]
public_key = key_pair[:hex_public_key]
puts private_key
puts public_key
puts

# hash a text message
message = ECCrypto.sha256("this message is being signed")
puts message

# sign the message with a private key
sig = ECCrypto.sign(private_key, message)
puts sig.inspect

# verify the signature with the public key and the signature
ECCrypto.verify(public_key, message, sig["r"], sig["s"])

# get the public key from a private key
public_key = ECCrypto.get_public_key_from_private(private_key)
puts public_key

# encrypt a message using a given receiver's public key
encrypted_message = ECCrypto.encrypt(public_key, "This is a secret message")

# decrypt a received message using known private key
puts "\ndecrypt"
decrypted_message = ECCrypto.decrypt(private_key, encrypted_message)
puts decrypted_message