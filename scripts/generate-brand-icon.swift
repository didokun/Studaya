// Prepare iOS assets from the approved artistic master without altering its design.
// DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift -module-cache-path /tmp/studaya-brand-module-cache scripts/generate-brand-icon.swift
import AppKit
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let source = root.appendingPathComponent("Branding/Studaya-artwork.png")
let image = NSImage(contentsOf: source)!
let context = CGContext(data:nil,width:1024,height:1024,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)!
context.interpolationQuality = .high
context.draw(image.cgImage(forProposedRect:nil,context:nil,hints:nil)!,in:CGRect(x:0,y:0,width:1024,height:1024))
let png = NSBitmapImageRep(cgImage:context.makeImage()!).representation(using:.png,properties:[:])!
let assets = root.appendingPathComponent("Studaya/Assets.xcassets")
try png.write(to:assets.appendingPathComponent("AppIcon.appiconset/Studaya.png"))
try png.write(to:assets.appendingPathComponent("Logo.imageset/Logo.png"))
