import Foundation
import Security

/// Manages the RSA key pair ADB uses to authenticate with a Fire TV, persists
/// it in the keychain, signs auth tokens, and encodes the public key in the
/// Android `adbkey.pub` binary format the device expects.
enum ADBKey {
    private static let tag = "com.universalremote.adb.key".data(using: .utf8)!

    /// Returns the existing key pair, generating and storing one on first use.
    static func privateKey() throws -> SecKey {
        if let existing = loadKey() { return existing }
        return try generateKey()
    }

    private static func loadKey() -> SecKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecReturnRef as String: true
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let key = item else { return nil }
        return (key as! SecKey)
    }

    private static func generateKey() throws -> SecKey {
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 2048,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: tag
            ]
        ]
        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw error!.takeRetainedValue() as Error
        }
        return key
    }

    /// Sign a 20-byte ADB auth token. ADB treats the token as a pre-computed
    /// SHA-1 digest and applies PKCS#1 v1.5 padding — exactly what
    /// `.rsaSignatureDigestPKCS1v15SHA1` does.
    static func sign(token: Data) throws -> Data {
        let key = try privateKey()
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            key, .rsaSignatureDigestPKCS1v15SHA1, token as CFData, &error) else {
            throw error!.takeRetainedValue() as Error
        }
        return signature as Data
    }

    /// Build the Android public-key payload: base64 of the RSAPublicKey struct,
    /// followed by a space and an identifying suffix, null-terminated.
    static func androidPublicKey(user: String = "universal-remote@ios") throws -> Data {
        let key = try privateKey()
        guard let publicKey = SecKeyCopyPublicKey(key) else {
            throw RemoteError.cryptoFailure
        }
        var error: Unmanaged<CFError>?
        guard let der = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            throw error!.takeRetainedValue() as Error
        }
        let (modulus, exponent) = try parsePKCS1(der)
        let blob = encodeAndroidPublicKey(modulus: modulus, exponent: exponent)
        let base64 = blob.base64EncodedString()
        var payload = Data((base64 + " " + user).utf8)
        payload.append(0) // null terminator
        return payload
    }

    // MARK: - PKCS#1 DER parsing (RSAPublicKey ::= SEQUENCE { modulus, exponent })

    private static func parsePKCS1(_ der: Data) throws -> (modulus: [UInt8], exponent: UInt32) {
        var bytes = [UInt8](der)
        var i = 0

        func readLength() throws -> Int {
            guard i < bytes.count else { throw RemoteError.cryptoFailure }
            let first = bytes[i]; i += 1
            if first & 0x80 == 0 { return Int(first) }
            let count = Int(first & 0x7f)
            var length = 0
            for _ in 0..<count {
                guard i < bytes.count else { throw RemoteError.cryptoFailure }
                length = (length << 8) | Int(bytes[i]); i += 1
            }
            return length
        }

        guard i < bytes.count, bytes[i] == 0x30 else { throw RemoteError.cryptoFailure }
        i += 1
        _ = try readLength()                              // sequence length

        guard i < bytes.count, bytes[i] == 0x02 else { throw RemoteError.cryptoFailure }
        i += 1
        let modLen = try readLength()
        guard i + modLen <= bytes.count else { throw RemoteError.cryptoFailure }
        var modulus = Array(bytes[i..<i + modLen]); i += modLen
        while modulus.first == 0 { modulus.removeFirst() } // strip leading sign byte

        guard i < bytes.count, bytes[i] == 0x02 else { throw RemoteError.cryptoFailure }
        i += 1
        let expLen = try readLength()
        guard i + expLen <= bytes.count else { throw RemoteError.cryptoFailure }
        let expBytes = Array(bytes[i..<i + expLen])
        var exponent: UInt32 = 0
        for b in expBytes { exponent = (exponent << 8) | UInt32(b) }

        return (modulus, exponent)
    }

    // MARK: - Android RSAPublicKey struct

    /// struct { uint32 len; uint32 n0inv; uint8 modulus[256]; uint8 rr[256];
    ///          uint32 exponent; } — all little-endian.
    private static func encodeAndroidPublicKey(modulus: [UInt8], exponent: UInt32) -> Data {
        let wordCount = 64                  // 2048-bit modulus = 64 words
        let n = BigUInt(bigEndianBytes: modulus)

        // n0inv = -(n^-1) mod 2^32, on the lowest word.
        let n0 = n.lowestWord
        let inv = modInverse32(n0)
        let n0inv = (~inv) &+ 1             // negate modulo 2^32

        // rr = (2^(32*wordCount))^2 mod n = 2^(2*2048) mod n
        let rr = BigUInt.powerOfTwoMod(exponent: 2 * 32 * wordCount, modulus: n)

        var data = Data()
        func appendUInt32(_ value: UInt32) {
            data.append(UInt8(value & 0xff))
            data.append(UInt8((value >> 8) & 0xff))
            data.append(UInt8((value >> 16) & 0xff))
            data.append(UInt8((value >> 24) & 0xff))
        }

        appendUInt32(UInt32(wordCount))
        appendUInt32(n0inv)
        data.append(contentsOf: n.littleEndianBytes(length: 256))
        data.append(contentsOf: rr.littleEndianBytes(length: 256))
        appendUInt32(exponent)
        return data
    }

    /// Modular inverse of an odd 32-bit value modulo 2^32 (Newton iteration).
    private static func modInverse32(_ a: UInt32) -> UInt32 {
        var x: UInt32 = 1
        for _ in 0..<5 {                    // converges in 5 steps for 2^32
            x = x &* (2 &- a &* x)
        }
        return x
    }
}
