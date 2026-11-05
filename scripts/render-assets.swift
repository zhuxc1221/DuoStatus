import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let ink = NSColor(calibratedRed: 0.16, green: 0.18, blue: 0.19, alpha: 1)
func curve(_ points: [CGFloat], width: CGFloat, color: NSColor) {
    let p = NSBezierPath()
    p.move(to: NSPoint(x: points[0], y: points[1]))
    p.curve(to: NSPoint(x: points[6], y: points[7]), controlPoint1: NSPoint(x: points[2], y: points[3]), controlPoint2: NSPoint(x: points[4], y: points[5]))
    p.lineWidth = width; p.lineCapStyle = .round
    color.setStroke(); p.stroke()
}
func mark(color: NSColor = ink) {
    transform(x:64,y:64,scale:7) {
        curve([34,99,15,82,15,46,34,29], width:6, color:color)
        curve([94,29,113,46,113,82,94,99], width:6, color:color)
        curve([34,29,50,12,78,12,94,29], width:6, color:color)
        curve([44,59,55,48,73,48,84,59], width:5.5, color:color)
        curve([52,71,59,64,69,64,76,71], width:5.5, color:color)
        color.setFill(); NSBezierPath(ovalIn:NSRect(x:61,y:80,width:6,height:6)).fill()
    }
}
func logo() {
    NSColor(calibratedWhite:0.085,alpha:1).setFill()
    NSBezierPath(roundedRect:NSRect(x:88,y:80,width:848,height:848),xRadius:190,yRadius:190).fill()
    mark(color:.white)
}
func text(_ s: String, x: CGFloat, y: CGFloat, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = ink) {
    (s as NSString).draw(at: NSPoint(x: x,y: y), withAttributes: [.font: NSFont.systemFont(ofSize: size,weight: weight), .foregroundColor: color])
}
func transform(x: CGFloat, y: CGFloat, scale: CGFloat, _ body: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let t = NSAffineTransform(); t.translateX(by: x,yBy: y); t.scale(by: scale); t.concat()
    body(); NSGraphicsContext.restoreGraphicsState()
}
func symbol(_ name: String, rect: NSRect, color: NSColor, weight: NSFont.Weight = .regular) {
    guard let image = NSImage(systemSymbolName:name, accessibilityDescription:nil) else { return }
    let configuration = NSImage.SymbolConfiguration(pointSize:rect.height, weight:weight).applying(.init(paletteColors:[color]))
    (image.withSymbolConfiguration(configuration) ?? image).draw(in:rect,from:.zero,operation:.sourceOver,fraction:1,respectFlipped:true,hints:nil)
}
func menuIcon(x: CGFloat, y: CGFloat, size: CGFloat, color: NSColor = .white, input: String = "拼") {
    transform(x:x,y:y,scale:size/32) {
        let font = NSFont.monospacedDigitSystemFont(ofSize:8,weight:.bold)
        let attrs: [NSAttributedString.Key:Any] = [.font:font,.foregroundColor:color]
        let number = "80" as NSString
        let measured = number.size(withAttributes:attrs)
        let start = (32 - measured.width - 5.5) / 2
        let header = NSRect(x:start,y:0,width:measured.width+5.5,height:measured.height)
        let cg = NSGraphicsContext.current!.cgContext
        cg.saveGState()
        cg.addRect(NSRect(x:0,y:0,width:32,height:30))
        cg.addRect(header.insetBy(dx:-1,dy:-0.5))
        cg.clip(using:.evenOdd)
        for (end,alpha) in [(405.0,0.28),(351.0,1.0)] {
            cg.setStrokeColor(color.withAlphaComponent(alpha).cgColor)
            cg.setLineWidth(1.7); cg.setLineCap(.round)
            cg.addArc(center:NSPoint(x:16,y:14.3),radius:13.2,startAngle:135 * .pi/180,endAngle:end * .pi/180,clockwise:false)
            cg.strokePath()
        }
        cg.restoreGState()
        number.draw(at:NSPoint(x:start,y:0),withAttributes:attrs)
        symbol("bolt.fill",rect:NSRect(x:start+measured.width+1,y:1.2,width:4.5,height:7),color:color,weight:.bold)
        symbol("wifi",rect:NSRect(x:8.7,y:9.05,width:14.6,height:10.5),color:color,weight:.semibold)
        let inputAttributes: [NSAttributedString.Key:Any] = [.font:NSFont.systemFont(ofSize:8,weight:.semibold),.foregroundColor:color]
        let inputText = input as NSString
        inputText.draw(at:NSPoint(x:16-inputText.size(withAttributes:inputAttributes).width/2,y:19.5),withAttributes:inputAttributes)
    }
}
func overview(chinese: Bool) {
    let ground = NSColor(calibratedWhite:0.065,alpha:1)
    let muted = NSColor(calibratedWhite:0.67,alpha:1)
    let dark = NSColor(calibratedWhite:0.12,alpha:1)
    ground.setFill(); NSRect(x:0,y:0,width:1600,height:800).fill()
    text(chinese ? "三个状态。" : "Three signals.",x:88,y:88,size:80,weight:.medium,color:.white)
    text(chinese ? "一个位置。" : "One small space.",x:88,y:182,size:80,weight:.medium,color:.white)
    text(chinese ? "电量、Wi‑Fi 与输入法，合在一起。" : "Battery, Wi-Fi and input source, together.",x:92,y:310,size:25,color:muted)
    menuIcon(x:1080,y:114,size:280,input:chinese ? "拼" : "A")
    text(chinese ? "少一点占位，多一点空间。" : "Less in the bar. More room for you.",x:92,y:476,size:23,color:.white)
    text("3 → 1",x:1424,y:478,size:22,color:muted)
    NSColor(calibratedWhite:0.96,alpha:1).setFill()
    NSBezierPath(roundedRect:NSRect(x:88,y:524,width:1424,height:88),xRadius:14,yRadius:14).fill()
    symbol("apple.logo",rect:NSRect(x:120,y:553,width:23,height:26),color:dark)
    text("Finder",x:166,y:551,size:24,weight:.semibold,color:dark)
    text(chinese ? "文件" : "File",x:270,y:553,size:22,color:dark)
    text(chinese ? "编辑" : "Edit",x:354,y:553,size:22,color:dark)
    text(chinese ? "显示" : "View",x:438,y:553,size:22,color:dark)
    symbol("play.circle",rect:NSRect(x:1128,y:552,width:28,height:28),color:dark)
    menuIcon(x:1202,y:537,size:66,color:dark,input:chinese ? "拼" : "A")
    symbol("switch.2",rect:NSRect(x:1322,y:554,width:28,height:24),color:dark)
    text("14:10",x:1384,y:550,size:25,weight:.medium,color:dark)
    text(chinese ? "原生 Wi‑Fi 面板  ·  Option 查看详情  ·  输入法即时更新" : "Native Wi-Fi panel  ·  Option-click details  ·  Live input source",x:92,y:675,size:23,color:muted)
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
try png("docs/media/overview-en.png",width:1600,height:800,logicalWidth:1600,logicalHeight:800) {overview(chinese:false)}
try png("docs/media/overview-zh.png",width:1600,height:800,logicalWidth:1600,logicalHeight:800) {overview(chinese:true)}
print("Rendered original logo, iconset and privacy-safe documentation illustrations")
