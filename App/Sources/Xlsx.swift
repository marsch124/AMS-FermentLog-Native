import Foundation

/// A tiny, dependency-free .xlsx writer (port of js/xlsx.js): stored (uncompressed) zip entries,
/// a bold white-on-orange header row that stays put when you scroll, numbers as numbers, text as inline strings.
enum Xlsx {
    static let mime = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"

    static func workbook(_ sheets: [Sheet]) -> Data {
        let xml = #"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>"#
        let relNS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
        let overrides = sheets.indices.map {
            #"<Override PartName="/xl/worksheets/sheet\#($0 + 1).xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>"#
        }.joined()
        let contentTypes = xml
            + #"<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">"#
            + #"<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>"#
            + #"<Default Extension="xml" ContentType="application/xml"/>"#
            + #"<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>"#
            + #"<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>"#
            + overrides + "</Types>"
        let rootRels = xml
            + #"<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">"#
            + #"<Relationship Id="rId1" Type="\#(relNS)/officeDocument" Target="xl/workbook.xml"/></Relationships>"#
        let sheetRels = sheets.indices.map {
            #"<Relationship Id="rId\#($0 + 1)" Type="\#(relNS)/worksheet" Target="worksheets/sheet\#($0 + 1).xml"/>"#
        }.joined()
        let wbRels = xml
            + #"<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">"#
            + sheetRels
            + #"<Relationship Id="rId\#(sheets.count + 1)" Type="\#(relNS)/styles" Target="styles.xml"/></Relationships>"#
        let sheetTags = sheets.enumerated().map {
            #"<sheet name="\#(escape($0.element.name))" sheetId="\#($0.offset + 1)" r:id="rId\#($0.offset + 1)"/>"#
        }.joined()
        let workbook = xml
            + #"<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="\#(relNS)">"#
            + "<sheets>\(sheetTags)</sheets></workbook>"
        var files: [(String, Data)] = [
            ("[Content_Types].xml", Data(contentTypes.utf8)),
            ("_rels/.rels", Data(rootRels.utf8)),
            ("xl/workbook.xml", Data(workbook.utf8)),
            ("xl/_rels/workbook.xml.rels", Data(wbRels.utf8)),
            ("xl/styles.xml", Data(stylesXML.utf8)),
        ]
        for (i, s) in sheets.enumerated() { files.append(("xl/worksheets/sheet\(i + 1).xml", Data(sheetXML(s).utf8))) }
        return zipStored(files)
    }

    // MARK: Worksheet

    static func escape(_ s: String) -> String {
        var out = ""
        for ch in s {
            switch ch {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            case "'": out += "&apos;"
            default: out.append(ch)
            }
        }
        return out
    }

    /// 0 -> A, 25 -> Z, 26 -> AA
    static func columnLetter(_ index: Int) -> String {
        var s = ""; var n = index + 1
        while n > 0 {
            let m = (n - 1) % 26
            s = String(UnicodeScalar(UInt8(65 + m))) + s
            n = (n - 1) / 26
        }
        return s
    }

    private static func numberText(_ d: Double) -> String {
        d == d.rounded() && abs(d) < 1e15 ? String(Int64(d)) : String(d)
    }

    private static func inline(_ ref: String, _ text: String, style: String = "") -> String {
        #"<c r="\#(ref)"\#(style) t="inlineStr"><is><t xml:space="preserve">\#(escape(text))</t></is></c>"#
    }

    private static func sheetXML(_ sheet: Sheet) -> String {
        let cols = sheet.columns.enumerated().map { #"<col min="\#($0.offset + 1)" max="\#($0.offset + 1)" width="\#(numberText($0.element.width > 0 ? $0.element.width : 14))" customWidth="1"/>"# }.joined()
        let colsXML = sheet.columns.isEmpty ? "" : "<cols>\(cols)</cols>"
        let header = "<row r=\"1\">" + sheet.columns.enumerated().map { inline("\(columnLetter($0.offset))1", $0.element.header, style: #" s="1""#) }.joined() + "</row>"
        let body = sheet.rows.enumerated().map { r, row -> String in
            let rn = r + 2
            let cells = row.enumerated().map { i, cell -> String in
                let ref = "\(columnLetter(i))\(rn)"
                switch cell {
                case .empty: return ""
                case .text(let t): return t.isEmpty ? "" : inline(ref, t)
                case .number(let d): return d.isFinite ? #"<c r="\#(ref)"><v>\#(numberText(d))</v></c>"# : ""
                }
            }.joined()
            return #"<row r="\#(rn)">\#(cells)</row>"#
        }.joined()
        return #"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>"#
            + #"<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">"#
            + #"<sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>"#
            + #"<sheetFormatPr defaultRowHeight="15"/>\#(colsXML)<sheetData>\#(header)\#(body)</sheetData></worksheet>"#
    }

    /// Two cell styles: 0 = body (wrap, top), 1 = header (bold white on carrot orange).
    private static let stylesXML = #"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>"#
        + #"<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">"#
        + #"<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font></fonts>"#
        + #"<fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FFE8722C"/></patternFill></fill></fills>"#
        + #"<borders count="1"><border/></borders>"#
        + #"<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>"#
        + #"<cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0" applyAlignment="1"><alignment vertical="top" wrapText="1"/></xf>"#
        + #"<xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1" applyAlignment="1"><alignment vertical="center"/></xf></cellXfs>"#
        + #"<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>"#

    // MARK: Zip (stored, no compression)

    private static let crcTable: [UInt32] = (0..<256).map { n -> UInt32 in
        var c = UInt32(n)
        for _ in 0..<8 { c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1) }
        return c
    }

    static func crc32(_ bytes: Data) -> UInt32 {
        var c: UInt32 = 0xFFFFFFFF
        for b in bytes { c = (c >> 8) ^ crcTable[Int((c ^ UInt32(b)) & 0xFF)] }
        return c ^ 0xFFFFFFFF
    }

    private static func u16(_ n: Int) -> [UInt8] { [UInt8(n & 0xFF), UInt8((n >> 8) & 0xFF)] }
    private static func u32(_ n: UInt32) -> [UInt8] { (0..<4).map { UInt8((n >> UInt32(8 * $0)) & 0xFF) } }

    private static func zipStored(_ files: [(name: String, data: Data)]) -> Data {
        var out = Data()
        var central = Data()
        for f in files {
            let name = Data(f.name.utf8)
            let crc = crc32(f.data)
            let size = UInt32(f.data.count)
            let offset = UInt32(out.count)
            out.append(contentsOf: u32(0x04034b50) + u16(20) + u16(0x0800) + u16(0) + u16(0) + u16(0x21) + u32(crc) + u32(size) + u32(size) + u16(name.count) + u16(0))
            out.append(name); out.append(f.data)
            central.append(contentsOf: u32(0x02014b50) + u16(20) + u16(20) + u16(0x0800) + u16(0) + u16(0) + u16(0x21) + u32(crc) + u32(size) + u32(size)
                           + u16(name.count) + u16(0) + u16(0) + u16(0) + u16(0) + u32(0) + u32(offset))
            central.append(name)
        }
        let cdStart = UInt32(out.count)
        out.append(central)
        out.append(contentsOf: u32(0x06054b50) + u16(0) + u16(0) + u16(files.count) + u16(files.count) + u32(UInt32(central.count)) + u32(cdStart) + u16(0))
        return out
    }
}
