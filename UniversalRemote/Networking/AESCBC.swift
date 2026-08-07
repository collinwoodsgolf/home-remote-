import Foundation
import CommonCrypto

/// AES-128-CBC with no padding, as used by the Broadlink wire protocol.
/// CryptoKit only ships AES-GCM, so we fall back to CommonCrypto here.
enum AESCBC {
    static func crypt(operation: CCOperation,
                      data: [UInt8],
                      key: [UInt8],
                      iv: [UInt8]) -> [UInt8]? {
        guard key.count == kCCKeySizeAES128, iv.count == kCCBlockSizeAES128 else { return nil }

        var out = [UInt8](repeating: 0, count: data.count + kCCBlockSizeAES128)
        var moved = 0

        let status = key.withUnsafeBytes { keyPtr in
            iv.withUnsafeBytes { ivPtr in
                data.withUnsafeBytes { dataPtr in
                    CCCrypt(operation,
                            CCAlgorithm(kCCAlgorithmAES128),
                            CCOptions(0),                 // no padding: Broadlink pads payloads itself
                            keyPtr.baseAddress, key.count,
                            ivPtr.baseAddress,
                            dataPtr.baseAddress, data.count,
                            &out, out.count,
                            &moved)
                }
            }
        }
        guard status == kCCSuccess else { return nil }
        return Array(out.prefix(moved))
    }

    static func encrypt(_ data: [UInt8], key: [UInt8], iv: [UInt8]) -> [UInt8]? {
        crypt(operation: CCOperation(kCCEncrypt), data: data, key: key, iv: iv)
    }

    static func decrypt(_ data: [UInt8], key: [UInt8], iv: [UInt8]) -> [UInt8]? {
        crypt(operation: CCOperation(kCCDecrypt), data: data, key: key, iv: iv)
    }
}
