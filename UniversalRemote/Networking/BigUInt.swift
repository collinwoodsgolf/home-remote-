import Foundation

/// Minimal fixed-purpose big unsigned integer, only as capable as the Android
/// ADB public-key encoding needs (compare, shift-left-by-one, subtract, and a
/// `2^k mod n` routine for the Montgomery RR parameter). Stored little-endian
/// in 32-bit words.
struct BigUInt {
    private(set) var words: [UInt32]   // little-endian

    init(words: [UInt32]) {
        self.words = words
        normalize()
    }

    /// Build from big-endian bytes (as produced by DER INTEGER fields).
    init(bigEndianBytes bytes: [UInt8]) {
        var bytes = bytes
        while bytes.first == 0 { bytes.removeFirst() }           // strip sign/leading zeros
        var words = [UInt32]()
        var i = bytes.count
        while i > 0 {
            let lo = i - 4
            var word: UInt32 = 0
            for j in max(lo, 0)..<i {
                word = (word << 8) | UInt32(bytes[j])
            }
            words.append(word)
            i -= 4
        }
        self.words = words
        normalize()
    }

    private mutating func normalize() {
        while words.count > 1 && words.last == 0 { words.removeLast() }
        if words.isEmpty { words = [0] }
    }

    var isZero: Bool { words.count == 1 && words[0] == 0 }

    static func < (a: BigUInt, b: BigUInt) -> Bool { compare(a, b) < 0 }
    static func >= (a: BigUInt, b: BigUInt) -> Bool { compare(a, b) >= 0 }

    static func compare(_ a: BigUInt, _ b: BigUInt) -> Int {
        if a.words.count != b.words.count {
            return a.words.count < b.words.count ? -1 : 1
        }
        for i in stride(from: a.words.count - 1, through: 0, by: -1) {
            if a.words[i] != b.words[i] {
                return a.words[i] < b.words[i] ? -1 : 1
            }
        }
        return 0
    }

    /// In-place multiply by two.
    mutating func shiftLeftOne() {
        var carry: UInt32 = 0
        for i in 0..<words.count {
            let newCarry = words[i] >> 31
            words[i] = (words[i] << 1) | carry
            carry = newCarry
        }
        if carry != 0 { words.append(carry) }
    }

    /// Subtract `other` (must be <= self).
    mutating func subtract(_ other: BigUInt) {
        var borrow: Int64 = 0
        for i in 0..<words.count {
            let o = i < other.words.count ? Int64(other.words[i]) : 0
            var diff = Int64(words[i]) - o - borrow
            if diff < 0 { diff += 0x1_0000_0000; borrow = 1 } else { borrow = 0 }
            words[i] = UInt32(diff)
        }
        normalize()
    }

    /// Compute (2^exponent) mod modulus by repeated doubling.
    static func powerOfTwoMod(exponent: Int, modulus: BigUInt) -> BigUInt {
        var x = BigUInt(words: [1])
        for _ in 0..<exponent {
            x.shiftLeftOne()
            if x >= modulus { x.subtract(modulus) }
        }
        return x
    }

    /// Little-endian byte representation, zero-padded/truncated to `length`.
    func littleEndianBytes(length: Int) -> [UInt8] {
        var bytes = [UInt8]()
        for word in words {
            bytes.append(UInt8(word & 0xff))
            bytes.append(UInt8((word >> 8) & 0xff))
            bytes.append(UInt8((word >> 16) & 0xff))
            bytes.append(UInt8((word >> 24) & 0xff))
        }
        if bytes.count < length {
            bytes.append(contentsOf: [UInt8](repeating: 0, count: length - bytes.count))
        }
        return Array(bytes.prefix(length))
    }

    var lowestWord: UInt32 { words[0] }
}
