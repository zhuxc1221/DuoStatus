import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let ink = NSColor(calibratedRed: 0.16, green: 0.18, blue: 0.19, alpha: 1)
let green = NSColor(calibratedRed: 0.18, green: 0.55, blue: 0.42, alpha: 1)
func curve(_ points: [CGFloat], width: CGFloat, color: NSColor) {
    let p = NSBezierPath()
    p.move(to: NSPoint(x: points[0], y: points[1]))
    p.curve(to: NSPoint(x: points[6], y: points[7]), controlPoint1: NSPoint(x: points[2], y: points[3]), controlPoint2: NSPoint(x: points[4], y: points[5]))
    p.lineWidth = width; p.lineCapStyle = .round
    color.setStroke(); p.stroke()
}
func mark() {
    curve([330,688,230,592,230,432,330,336], width: 44, color: ink)
    curve([694,336,794,432,794,592,694,688], width: 44, color: ink)
    curve([371,455,455,375,569,375,653,455], width: 34, color: ink)
    curve([421,509,476,457,548,457,603,509], width: 34, color: ink)
    curve([470,563,495,539,529,539,554,563], width: 34, color: ink)
    ink.setFill(); NSBezierPath(ovalIn: NSRect(x: 494, y: 590, width: 36, height: 36)).fill()
    let bolt = NSBezierPath()
    bolt.move(to: NSPoint(x: 526, y: 650))
    for point in [(488.0,695.0),(508.0,695.0),(498.0,732.0),(544.0,678.0),(522.0,678.0)] { bolt.line(to: NSPoint(x: point.0, y: point.1)) }
    bolt.close(); green.setFill(); bolt.fill()
}
func logo() {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.13)
    shadow.shadowBlurRadius = 23; shadow.shadowOffset = NSSize(width: 0, height: -14); shadow.set()
    let tile = NSBezierPath(roundedRect: NSRect(x: 88, y: 80, width: 848, height: 848), xRadius: 190, yRadius: 190)
    NSColor.white.setFill(); tile.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: .white, ending: NSColor(calibratedRed: 0.94, green: 0.93, blue: 0.90, alpha: 1))!.draw(in: tile, angle: 90)
    ink.withAlphaComponent(0.07).setStroke(); tile.lineWidth = 1.5; tile.stroke()
    mark()
}
func text(_ s: String, x: CGFloat, y: CGFloat, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = ink) {
    (s as NSString).draw(at: NSPoint(x: x,y: y), withAttributes: [.font: NSFont.systemFont(ofSize: size,weight: weight), .foregroundColor: color])
}
func transform(x: CGFloat, y: CGFloat, scale: CGFloat, _ body: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let t = NSAffineTransform(); t.translateX(by: x,yBy: y); t.scale(by: scale); t.concat()
    body(); NSGraphicsContext.restoreGraphicsState()
}
func wifi(x: CGFloat, y: CGFloat, color: NSColor) {
    curve([x-15,y-5,x-6,y-14,x+6,y-14,x+15,y-5],width: 3.5,color: color)
    curve([x-10,y+1,x-4,y-5,x+4,y-5,x+10,y+1],width: 3.5,color: color)
    curve([x-5,y+7,x-2,y+4,x+2,y+4,x+5,y+7],width: 3.5,color: color)
    color.setFill(); NSBezierPath(ovalIn: NSRect(x:x-2,y:y+11,width:4,height:4)).fill()
}
func menuIcon(x: CGFloat, y: CGFloat, size: CGFloat) {
    transform(x:x,y:y,scale:size/32) {
        let color = NSColor.white
        let cg = NSGraphicsContext.current!.cgContext
        cg.saveGState()
        cg.addRect(NSRect(x:0,y:0,width:32,height:32))
        cg.addRect(NSRect(x:6,y:-1,width:20,height:10.5))
        cg.clip(using:.evenOdd)
        let center = NSPoint(x:16,y:14.3)
        for (end,alpha) in [(405.0,0.28),(351.0,1.0)] {
            cg.setStrokeColor(color.withAlphaComponent(alpha).cgColor)
            cg.setLineWidth(1.7); cg.setLineCap(.round)
            cg.addArc(center:center,radius:13.2,startAngle:135 * .pi/180,endAngle:end * .pi/180,clockwise:false)
            cg.strokePath()
        }
        cg.restoreGState()
        text("80",x:8.0,y:0,size:8,weight:.bold,color:color)
        let p = NSBezierPath(); p.move(to:NSPoint(x:23.5,y:1.2))
        for q in [(19.5,5.0),(22.0,5.0),(21.0,8.2),(24.0,3.5),(22.0,3.5)] { p.line(to:NSPoint(x:q.0,y:q.1)) }
        p.close(); color.setFill(); p.fill()
        transform(x:16,y:13,scale:0.40) { wifi(x:0,y:0,color:color) }
        text("拼",x:12,y:20.5,size:8,weight:.semibold,color:color)
    }
}
func overview(chinese: Bool) {
    NSColor(calibratedRed:0.973,green:0.969,blue:0.953,alpha:1).setFill(); NSRect(x:0,y:0,width:1600,height:740).fill()
    text("DuoStatus",x:80,y:64,size:64,weight:.semibold)
    text(chinese ? "三个状态，一个位置。" : "Three signals. One spot.",x:83,y:153,size:29,color:ink.withAlphaComponent(0.65))
    transform(x:1270,y:24,scale:0.25) { logo() }
    let card = NSBezierPath(roundedRect:NSRect(x:80,y:268,width:1440,height:350),xRadius:34,yRadius:34)
    NSColor.white.setFill(); card.fill()
    ink.withAlphaComponent(0.07).setStroke(); card.lineWidth=1; card.stroke()
    text(chinese ? "合并前" : "Before",x:130,y:301,size:22,weight:.medium,color:ink.withAlphaComponent(0.55))
    text(chinese ? "合并后" : "After",x:890,y:301,size:22,weight:.medium,color:ink.withAlphaComponent(0.55))
    for x in [CGFloat(130),CGFloat(890)] {
        let bar=NSBezierPath(roundedRect:NSRect(x:x,y:365,width:580,height:112),xRadius:23,yRadius:23)
        NSColor(calibratedRed:0.20,green:0.24,blue:0.29,alpha:1).setFill(); bar.fill()
    }
    text("拼",x:291,y:394,size:27,weight:.semibold,color:.white)
    wifi(x:378,y:412,color:.white)
    let battery=NSBezierPath(roundedRect:NSRect(x:448,y:397,width:62,height:29),xRadius:6,yRadius:6)
    NSColor.white.withAlphaComponent(0.93).setFill(); battery.fill()
    NSColor.white.withAlphaComponent(0.6).setFill(); NSBezierPath(roundedRect:NSRect(x:512,y:405,width:4,height:13),xRadius:2,yRadius:2).fill()
    text("80",x:457,y:394,size:23,weight:.semibold,color:NSColor(calibratedRed:0.20,green:0.24,blue:0.29,alpha:1))
    menuIcon(x:1157,y:384,size:66)
    text("→",x:767,y:392,size:42,weight:.light,color:ink.withAlphaComponent(0.45))
    text(chinese ? "输入法、Wi‑Fi 与电池，分别占位" : "Input source, Wi-Fi and battery",x:130,y:514,size:23)
    text(chinese ? "合为一个，空出两格" : "Combined, with two spots to spare",x:890,y:514,size:23)
    text(chinese ? "数字电量  ·  接电闪电  ·  输入法状态  ·  原生 Wi‑Fi 面板" : "Battery level  ·  Power indicator  ·  Input source  ·  Native Wi-Fi panel",x:80,y:664,size:23,color:ink.withAlphaComponent(0.60))
}
final class Canvas:NSView {
    var drawBody:()->Void = {}
    override var isFlipped:Bool {true}
    override func draw(_ dirtyRect:NSRect) {drawBody()}
}
func png(_ relative:String,width:Int,height:Int,logicalWidth:CGFloat,logicalHeight:CGFloat,draw:@escaping()->Void)throws {
    let view=Canvas(frame:NSRect(x:0,y:0,width:logicalWidth,height:logicalHeight)); view.drawBody=draw
    guard let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:width,pixelsHigh:height,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0) else {fatalError("Cannot allocate image")}
    bitmap.size=view.bounds.size
    view.cacheDisplay(in:view.bounds,to:bitmap)
    guard let data=bitmap.representation(using:.png,properties:[:]) else {fatalError("Cannot render image")}
    let decoded = NSBitmapImageRep(data:data)!
    precondition(decoded.pixelsWide == width && decoded.pixelsHigh == height)
    precondition((decoded.colorAt(x:width/2,y:height/2)?.alphaComponent ?? 0) > 0.99)
    let target=root.appendingPathComponent(relative)
    try FileManager.default.createDirectory(at:target.deletingLastPathComponent(),withIntermediateDirectories:true)
    try data.write(to:target)
}
let _ = NSApplication.shared
try png("assets/logo/duostatus-icon.png",width:1024,height:1024,logicalWidth:1024,logicalHeight:1024,draw:logo)
for pointSize in [16,32,128,256,512] {
    for scale in [1,2] {
        let suffix = scale == 2 ? "@2x" : ""
        try png(".build/DuoStatus.iconset/icon_\(pointSize)x\(pointSize)\(suffix).png",width:pointSize*scale,height:pointSize*scale,logicalWidth:1024,logicalHeight:1024,draw:logo)
    }
}
try png("docs/media/overview-en.png",width:1600,height:740,logicalWidth:1600,logicalHeight:740) {overview(chinese:false)}
try png("docs/media/overview-zh.png",width:1600,height:740,logicalWidth:1600,logicalHeight:740) {overview(chinese:true)}
print("Rendered original logo, iconset and privacy-safe documentation illustrations")
