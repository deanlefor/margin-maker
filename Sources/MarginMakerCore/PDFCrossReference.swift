import Foundation

/// Repairs a Quartz writer defect in newly generated PDFs, never imported bytes.
/// Quartz can mark unused object numbers as in-use at offset zero. Such references
/// already resolve to null in PDF readers; mark them free and link the free list.
/// Every edit is fixed width, leaving all object bytes and offsets untouched.
enum PDFCrossReference {
    static func repairingQuartzOutput(_ data: Data) -> Data {
        let footerSearch = max(0, data.count - 128)..<data.count
        guard let marker = data.range(of: Data("startxref".utf8), options: .backwards, in: footerSearch),
              let footer = String(data: data[marker.lowerBound...], encoding: .ascii) else { return data }
        let words = footer.split(whereSeparator: { $0.isWhitespace })
        guard words.count == 3, words[0] == "startxref", words[2] == "%%EOF",
              let offset = Int(words[1]), offset >= 0, offset < marker.lowerBound else { return data }

        // Only the single, contiguous, classic xref table emitted by Quartz is
        // supported. Do not guess at incremental updates or cross-reference streams.
        var cursor = offset
        func line() -> String? {
            guard cursor < marker.lowerBound,
                  let end = data[cursor..<marker.lowerBound].firstIndex(of: 10),
                  let value = String(data: data[cursor..<end], encoding: .ascii) else { return nil }
            cursor = end + 1
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard line() == "xref", let header = line() else { return data }
        let fields = header.split(whereSeparator: { $0.isWhitespace })
        guard fields.count == 2, fields[0] == "0", let count = Int(fields[1]), count > 0,
              count <= (marker.lowerBound - cursor) / 20 else { return data }
        let entriesStart = cursor
        cursor += count * 20
        guard line() == "trailer" else { return data }
        guard let trailer = String(data: data[cursor..<marker.lowerBound], encoding: .ascii),
              !trailer.contains("/Prev"), !trailer.contains("/XRefStm") else { return data }

        var free: [(number: Int, generation: Int)] = []
        var needsRepair = false
        for number in 0..<count {
            let start = entriesStart + number * 20
            let entry = Array(data[start..<start + 20])
            guard entry[10] == 32, entry[16] == 32,
                  entry[17] == 102 || entry[17] == 110,
                  entry[18] == 32 || entry[18] == 13, entry[19] == 10,
                  entry[0..<10].allSatisfy({ (48...57).contains($0) }),
                  entry[11..<16].allSatisfy({ (48...57).contains($0) }) else { return data }
            let position = entry[0..<10].reduce(0) { $0 * 10 + Int($1 - 48) }
            let generation = entry[11..<16].reduce(0) { $0 * 10 + Int($1 - 48) }
            guard generation <= 65535 else { return data }
            if number == 0 {
                guard entry[17] == 102, generation == 65535 else { return data }
            }
            if entry[17] == 102 {
                free.append((number, generation))
            } else if position == 0 {
                guard generation == 0 else { return data }
                // Permanently free the unused number; it never had an object body.
                free.append((number, 65535))
                needsRepair = true
            }
        }
        guard needsRepair else { return data }
        var repaired = data
        for (index, entry) in free.enumerated() {
            let next = index + 1 < free.count ? free[index + 1].number : 0
            let replacement = Data(String(format: "%010lld %05d f \n", Int64(next), Int32(entry.generation)).utf8)
            let start = entriesStart + entry.number * 20
            repaired.replaceSubrange(start..<start + 20, with: replacement)
        }
        return repaired
    }
}
