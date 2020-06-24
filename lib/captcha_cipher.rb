require 'openssl'
require 'digest/sha1'
require 'base64'
require_relative '../logger'

KEY = "tohle musi byt 32 znakuuuuuuuuuu"

def cipher(msg)
  # create the cipher for encrypting
  cipher = OpenSSL::Cipher.new("aes-256-cbc")
  cipher.encrypt

  # load them into the cipher
  cipher.key = KEY
  iv = cipher.random_iv
  cipher.iv = iv

  # encrypt the message
  encrypted = cipher.update(msg)
  encrypted << cipher.final

  # filename
  Base64.urlsafe_encode64(iv, padding: false)+'='+Base64.urlsafe_encode64(encrypted, padding: false)
end

def decipher(filename)
  iv, encrypted = filename.split('=')
  iv = Base64.urlsafe_decode64(iv)
  encrypted = Base64.urlsafe_decode64(encrypted)

  # now we create a sipher for decrypting
  cipher = OpenSSL::Cipher.new("aes-256-cbc")
  cipher.decrypt
  cipher.key = KEY
  cipher.iv = iv

  # and decrypt it
  decrypted = cipher.update(encrypted)
  decrypted << cipher.final
  
  decrypted
end
