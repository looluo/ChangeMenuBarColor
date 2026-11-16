import Cocoa

// probe_wallpaper.swift <jpg> <stripHeightPx> [r g b]
// Dumps rows 0..strip+4 at x=10% and x=90%. With r g b (the expected strip color),
// exits non-zero if a strip row drifts >12/channel or row strip+4 still matches it.

let args = CommandLine.arguments
guard args.count >= 3, let img = NSImage(contentsOfFile: args[1]),
      let rep = NSBitmapImageRep(data: img.tiffRepresentation!), let strip = Int(args[2]) else {
    print("usage: probe_wallpaper.swift <jpg> <stripHeightPx> [r g b]")
    exit(2)
}
let expect: (Double, Double, Double)? = args.count >= 6 ? (Double(args[3])!, Double(args[4])!, Double(args[5])!) : nil
let w = rep.pixelsWide, h = rep.pixelsHigh
print("jpg: \(w)x\(h), expected strip: \(strip)px" + (expect.map { String(format: " rgb(%.0f,%.0f,%.0f)", $0.0, $0.1, $0.2) } ?? ""))

func near(_ a: (Double, Double, Double), _ b: (Double, Double, Double)) -> Bool {
    abs(a.0 - b.0) <= 12 && abs(a.1 - b.1) <= 12 && abs(a.2 - b.2) <= 12
}

var pass = true
for y in 0...min(strip + 4, h - 1) {
    let row = (0..<2).map { pct -> (Int, (Double, Double, Double)) in
        let x = Int(Double(w) * (pct == 0 ? 0.1 : 0.9))
        let c = rep.colorAt(x: x, y: y)!
        return (x, (c.redComponent * 255, c.greenComponent * 255, c.blueComponent * 255))
    }
    let line = row.map { String(format: "x=%d (%3.0f,%3.0f,%3.0f)", $0.0, $0.1.0, $0.1.1, $0.1.2) }.joined(separator: "  ")
    var ok = true
    if let e = expect {
        let inStrip = y < strip
        let matches = row.contains { near($0.1, e) }
        ok = inStrip ? row.allSatisfy({ near($0.1, e) }) : !matches
        if !ok { pass = false }
    }
    print(String(format: "y=%3d  %@  %@", y, line, expect == nil ? "" : (ok ? "OK" : "FAIL")))
}
print(expect == nil ? "(dump only)" : (pass ? "PASS" : "FAIL"))
exit(expect == nil ? 0 : (pass ? 0 : 1))
