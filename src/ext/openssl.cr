require "openssl"

class OpenSSL::X509::Certificate
  def scram_signature
    # The TLS server's certificate bytes need to be hashed with SHA-256 if
    # its signature algorithm is MD5 or SHA-1 as per RFC 5929
    # (https://tools.ietf.org/html/rfc5929#section-4.1).  If something else
    # is used, the same hash as the signature algorithm is used.
    algo_type = signature_algorithm
    algo_type = "SHA256" if algo_type == "MD5" || algo_type == "SHA1"
    digest algo_type
  end
end

# Backport of https://github.com/crystal-lang/crystal/pull/8005
# for Crystal versions < 1.1.0. Can be removed once crystal-pg no longer
# supports those versions of Crystal
{% if compare_versions(Crystal::VERSION, "1.1.0") < 0 %}
  class OpenSSL::SSL::Socket::Client
    # Returns the `OpenSSL::X509::Certificate` the peer presented.
    def peer_certificate : OpenSSL::X509::Certificate
      super.not_nil!
    end
  end

  class OpenSSL::SSL::Socket
    # Returns the `OpenSSL::X509::Certificate` the peer presented, if a
    # connection was esablished.
    #
    # NOTE: Due to the protocol definition, a TLS/SSL server will always send a
    # certificate, if present. A client will only send a certificate when
    # explicitly requested to do so by the server (see `SSL_CTX_set_verify(3)`). If
    # an anonymous cipher is used, no certificates are sent. That a certificate
    # is returned does not indicate information about the verification state.
    def peer_certificate : OpenSSL::X509::Certificate?
      cert = LibSSL.ssl_get_peer_certificate(@ssl)
      OpenSSL::X509::Certificate.new cert if cert
    end
  end

  class OpenSSL::X509::Certificate
    # Returns the name of the signature algorithm.
    def signature_algorithm : String
      {% if compare_versions(LibSSL::OPENSSL_VERSION, "1.0.2") >= 0 %}
        sigid = LibCrypto.x509_get_signature_nid(@cert)
        result = LibCrypto.obj_find_sigid_algs(sigid, out algo_nid, nil)
        raise "Could not determine certificate signature algorithm" if result == 0

        sn = LibCrypto.obj_nid2sn(algo_nid)
        raise "Unknown algo NID #{algo_nid.inspect}" if sn.null?
        String.new sn
      {% else %}
        raise "Missing OpenSSL function for certificate signature algorithm (requires OpenSSL 1.0.2)"
      {% end %}
    end

    # Returns the digest using *algorithm_name*
    # ```
    # cert.digest("SHA1").hexstring   # => "6f608752059150c9b3450a9fe0a0716b4f3fa0ca"
    # cert.digest("SHA256").hexstring # => "51d80c865cc717f181cd949f0b23b5e1e82c93e01db53f0836443ec908b83748"
    # ```
    def digest(algorithm_name : String) : Slice(UInt8)
      algo_type = LibCrypto.evp_get_digestbyname algorithm_name
      raise ArgumentError.new "could not find digest for '#{algorithm_name}'" if Pointer(Void).null == algo_type
      hash = Slice(UInt8).new(64) # EVP_MAX_MD_SIZE for SHA512
      result = LibCrypto.x509_digest(@cert, algo_type, hash, out size)
      raise "could not generate certificate hash" unless result == 1

      hash[0, size]
    end
  end

  lib LibSSL
    fun ssl_get_peer_certificate = SSL_get_peer_certificate(handle : SSL) : LibCrypto::X509
  end

  lib LibCrypto
    {% if compare_versions(LibSSL::OPENSSL_VERSION, "1.0.2") >= 0 %}
      fun obj_find_sigid_algs = OBJ_find_sigid_algs(sigid : Int32, pdig_nid : Int32*, ppkey_nid : Int32*) : Int32
      fun x509_get_signature_nid = X509_get_signature_nid(x509 : X509) : Int32
    {% end %}
    fun x509_digest = X509_digest(x509 : X509, evp_md : EVP_MD, hash : UInt8*, len : Int32*) : Int32
  end
{% end %}
