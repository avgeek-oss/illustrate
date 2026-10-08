import Foundation

enum CSVParser {
    struct Row {
        let filename: String?
        let prompt: String
    }

    static func parse(_ content: String) -> [Row] {
        var cleaned = content
        if cleaned.hasPrefix("\u{FEFF}") {
            cleaned.removeFirst()
        }
        cleaned = cleaned
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let rows = parseRows(cleaned)
        guard !rows.isEmpty else { return [] }

        let headers = rows[0].map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
        guard let promptIndex = headers.firstIndex(of: "prompt") else {
            return []
        }

        let filenameIndex = headers.firstIndex(of: "filename")

        var items: [Row] = []
        for row in rows.dropFirst() {
            guard promptIndex < row.count else { continue }
            let prompt = row[promptIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !prompt.isEmpty else { continue }

            var filename: String?
            if let fnIdx = filenameIndex, fnIdx < row.count {
                let fn = row[fnIdx].trimmingCharacters(in: .whitespacesAndNewlines)
                filename = fn.isEmpty ? nil : fn
            }
            items.append(Row(filename: filename, prompt: prompt))
        }

        return items
    }

    static func parseRows(_ content: String) -> [[String]] {
        var rows: [[String]] = []
        var currentField = ""
        var currentRow: [String] = []
        var insideQuotes = false
        let chars = Array(content)

        var i = 0
        while i < chars.count {
            let char = chars[i]

            if insideQuotes {
                if char == "\"" {
                    if i + 1 < chars.count, chars[i + 1] == "\"" {
                        currentField.append("\"")
                        i += 2
                        continue
                    } else {
                        insideQuotes = false
                    }
                } else {
                    currentField.append(char)
                }
            } else {
                if char == "\"" {
                    insideQuotes = true
                } else if char == "," {
                    currentRow.append(currentField)
                    currentField = ""
                } else if char == "\n" {
                    currentRow.append(currentField)
                    currentField = ""
                    if !currentRow.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                        rows.append(currentRow)
                    }
                    currentRow = []
                } else {
                    currentField.append(char)
                }
            }

            i += 1
        }

        currentRow.append(currentField)
        if !currentRow.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            rows.append(currentRow)
        }

        return rows
    }
}
