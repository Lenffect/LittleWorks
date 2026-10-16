import AppKit
import Foundation
import UniformTypeIdentifiers
import LittleWorksCore

// MARK: - Minimal .xlsx writer (OOXML + /usr/bin/zip, no dependencies)

enum XCell {
    case text(String)
    case bold(String)
    case date(Date)
    case time(Date)
    case hours(Double)
    case money(Decimal)
    case boldHours(Double)
    case boldMoney(Decimal)
    case empty
}

struct XSheet {
    var name: String
    var widths: [Double]
    var rows: [[XCell]]
}

enum XLSX {
    // Style indexes in styles.xml below.
    private static func style(_ c: XCell) -> Int {
        switch c {
        case .text, .empty: 0
        case .bold: 1
        case .date: 2
        case .time: 3
        case .hours: 4
        case .money: 5
        case .boldHours: 6
        case .boldMoney: 7
        }
    }

    static func write(sheets: [XSheet], to url: URL) throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("tikk-xlsx-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: dir) }
        for sub in ["_rels", "xl/_rels", "xl/worksheets"] {
            try fm.createDirectory(at: dir.appendingPathComponent(sub), withIntermediateDirectories: true)
        }
        func put(_ path: String, _ text: String) throws {
            try text.write(to: dir.appendingPathComponent(path), atomically: true, encoding: .utf8)
        }
        let head = #"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>"#

        try put("[Content_Types].xml", head + """
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Default Extension="xml" ContentType="application/xml"/>
        <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
        <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
        \(sheets.indices.map { #"<Override PartName="/xl/worksheets/sheet\#($0 + 1).xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>"# }.joined())
        </Types>
        """)
        try put("_rels/.rels", head + """
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
        </Relationships>
        """)
        try put("xl/workbook.xml", head + """
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        <sheets>\(sheets.enumerated().map { #"<sheet name="\#(esc($1.name))" sheetId="\#($0 + 1)" r:id="rId\#($0 + 1)"/>"# }.joined())</sheets>
        </workbook>
        """)
        try put("xl/_rels/workbook.xml.rels", head + """
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        \(sheets.indices.map { #"<Relationship Id="rId\#($0 + 1)" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet\#($0 + 1).xml"/>"# }.joined())
        <Relationship Id="rId\(sheets.count + 1)" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
        </Relationships>
        """)
        try put("xl/styles.xml", head + """
        <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
        <numFmts count="4">
        <numFmt numFmtId="164" formatCode="dd\\-mm\\-yyyy"/>
        <numFmt numFmtId="165" formatCode="hh:mm"/>
        <numFmt numFmtId="166" formatCode="0.00"/>
        <numFmt numFmtId="167" formatCode="&quot;€&quot;\\ #,##0.00"/>
        </numFmts>
        <fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts>
        <fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>
        <borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>
        <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
        <cellXfs count="8">
        <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
        <xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>
        <xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>
        <xf numFmtId="165" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>
        <xf numFmtId="166" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>
        <xf numFmtId="167" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>
        <xf numFmtId="166" fontId="1" fillId="0" borderId="0" xfId="0" applyNumberFormat="1" applyFont="1"/>
        <xf numFmtId="167" fontId="1" fillId="0" borderId="0" xfId="0" applyNumberFormat="1" applyFont="1"/>
        </cellXfs>
        </styleSheet>
        """)
        for (i, sheet) in sheets.enumerated() {
            try put("xl/worksheets/sheet\(i + 1).xml", sheetXML(sheet, head: head))
        }

        let tmp = dir.appendingPathComponent("out.xlsx")
        let zip = Process()
        zip.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        zip.currentDirectoryURL = dir
        zip.arguments = ["-X", "-D", "-q", "-r", "out.xlsx", "[Content_Types].xml", "_rels", "xl"]
        try zip.run()
        zip.waitUntilExit()
        guard zip.terminationStatus == 0 else {
            throw NSError(domain: "tikk", code: 1, userInfo: [NSLocalizedDescriptionKey: "Zippen mislukt"])
        }
        if fm.fileExists(atPath: url.path) { try fm.removeItem(at: url) }
        try fm.copyItem(at: tmp, to: url)
    }

    private static func sheetXML(_ sheet: XSheet, head: String) -> String {
        var xml = head + #"<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">"#
        xml += "<cols>" + sheet.widths.enumerated().map {
            #"<col min="\#($0 + 1)" max="\#($0 + 1)" width="\#($1)" customWidth="1"/>"#
        }.joined() + "</cols><sheetData>"
        for (r, row) in sheet.rows.enumerated() {
            xml += #"<row r="\#(r + 1)">"#
            for (c, cell) in row.enumerated() {
                let ref = "\(column(c))\(r + 1)"
                let s = style(cell)
                switch cell {
                case .empty: continue
                case .text(let t), .bold(let t):
                    xml += #"<c r="\#(ref)" s="\#(s)" t="inlineStr"><is><t xml:space="preserve">\#(esc(t))</t></is></c>"#
                case .date(let d): xml += #"<c r="\#(ref)" s="\#(s)"><v>\#(floor(serial(d)))</v></c>"#
                case .time(let d):
                    let v = serial(d); xml += #"<c r="\#(ref)" s="\#(s)"><v>\#(v - floor(v))</v></c>"#
                case .hours(let h), .boldHours(let h): xml += #"<c r="\#(ref)" s="\#(s)"><v>\#(h)</v></c>"#
                case .money(let m), .boldMoney(let m): xml += #"<c r="\#(ref)" s="\#(s)"><v>\#(NSDecimalNumber(decimal: m).doubleValue)</v></c>"#
                }
            }
            xml += "</row>"
        }
        return xml + "</sheetData></worksheet>"
    }

    private static func column(_ i: Int) -> String {
        var n = i, s = ""
        repeat { s = String(UnicodeScalar(UInt8(65 + n % 26))) + s; n = n / 26 - 1 } while n >= 0
        return s
    }

    /// Excel serial date in local time.
    private static func serial(_ d: Date) -> Double {
        let offset = TimeZone.current.secondsFromGMT(for: d)
        return (d.timeIntervalSince1970 + Double(offset)) / 86400 + 25569
    }

    private static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }
}

// MARK: - Report export

struct ExportEntry {
    let client: Client
    let start: Date
    let end: Date
    let isRunning: Bool
    let note: String?
    var seconds: TimeInterval { end.timeIntervalSince(start) }
}

enum ReportExport {
    @MainActor
    static func save(entries: [ExportEntry], summary: [ReportRow], interval: DateInterval, includeIncome: Bool) throws -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "xlsx")!]
        let f = Date.ISO8601FormatStyle().year().month().day()
        let last = interval.end.addingTimeInterval(-1)
        panel.nameFieldStringValue = "tikk-rapport-\(interval.start.formatted(f))_\(last.formatted(f)).xlsx"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return nil }

        try XLSX.write(sheets: [
            registrations(entries, includeIncome: includeIncome),
            summarySheet(summary, interval: interval, includeIncome: includeIncome),
        ], to: url)
        return url
    }

    private static func registrations(_ entries: [ExportEntry], includeIncome: Bool) -> XSheet {
        var header: [XCell] = ["Datum", "Klant", "Start", "Eind", "Uren", "Notitie"].map { .bold($0) }
        if includeIncome { header += [.bold("Uurloon"), .bold("Bedrag")] }
        var rows = [header]
        var totalHours = 0.0
        var totalMoney: Decimal = 0
        for e in entries {
            let hours = e.seconds / 3600
            totalHours += hours
            var row: [XCell] = [
                .date(e.start), .text(e.client.name), .time(e.start),
                e.isRunning ? .text("loopt") : .time(e.end),
                .hours(hours), .text(e.note ?? ""),
            ]
            if includeIncome {
                if let rate = e.client.hourlyRate {
                    let amount = rate * Decimal(hours)
                    totalMoney += amount
                    row += [.money(rate), .money(amount)]
                } else { row += [.empty, .empty] }
            }
            rows.append(row)
        }
        var total: [XCell] = [.bold("Totaal"), .empty, .empty, .empty, .boldHours(totalHours), .empty]
        if includeIncome { total += [.empty, .boldMoney(totalMoney)] }
        rows += [[], total]
        return XSheet(name: "Registraties",
                      widths: includeIncome ? [12, 22, 9, 9, 9, 50, 11, 12] : [12, 22, 9, 9, 9, 50],
                      rows: rows)
    }

    private static func summarySheet(_ summary: [ReportRow], interval: DateInterval, includeIncome: Bool) -> XSheet {
        let last = interval.end.addingTimeInterval(-1)
        var rows: [[XCell]] = [
            [.bold("tikk. rapport")],
            [.text("Periode"), .text("\(interval.start.formatted(date: .long, time: .omitted)) t/m \(last.formatted(date: .long, time: .omitted))")],
            [],
        ]
        var header: [XCell] = [.bold("Klant"), .bold("Uren")]
        if includeIncome { header += [.bold("Uurloon"), .bold("Bedrag")] }
        rows.append(header)
        var totalHours = 0.0
        var totalMoney: Decimal = 0
        for r in summary {
            totalHours += r.hours
            var row: [XCell] = [.text(r.client.name), .hours(r.hours)]
            if includeIncome {
                if let rate = r.client.hourlyRate, let income = r.income {
                    totalMoney += income
                    row += [.money(rate), .money(income)]
                } else { row += [.empty, .empty] }
            }
            rows.append(row)
        }
        var total: [XCell] = [.bold("Totaal"), .boldHours(totalHours)]
        if includeIncome { total += [.empty, .boldMoney(totalMoney)] }
        rows += [[], total]
        return XSheet(name: "Samenvatting", widths: [28, 12, 12, 14], rows: rows)
    }
}
