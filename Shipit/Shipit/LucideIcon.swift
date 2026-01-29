//
//  LucideIcon.swift
//  Shipit
//
//  Created on 30.12.2025.
//

import SwiftUI
import LucideIcons

/// LucideIcon provides a SwiftUI view for rendering Lucide icons
/// This component uses the lucide-icons-swift package
struct LucideIcon: View {
    let name: String
    let size: CGFloat
    let color: Color
    
    init(_ name: String, size: CGFloat = 28, color: Color = .primary) {
        self.name = name
        self.size = size
        self.color = color
    }
    
    /// Returns an Image for use in tabItem (which requires Image, not a View)
    /// Scales the image down to a reasonable size for tab bar icons
    static func image(_ name: String, size: CGFloat = 24) -> Image {
        let lucideImage = getLucideImageStatic(name: name)
        if let uiImage = lucideImage {
            // Scale down the image to match tab bar icon size
            // Tab bar icons are typically around 25-30 points, but we want them smaller
            // to match other icons in the app (24px)
            let scaledImage = scaleImageForTabBar(uiImage, targetSize: size)
            return Image(uiImage: scaledImage)
                .renderingMode(.template)
        } else {
            // Fallback to SF Symbol
            let sfSymbol = lucideToSFSymbolStatic(name)
            return Image(systemName: sfSymbol)
        }
    }
    
    /// Scale image down to appropriate size for tab bar
    private static func scaleImageForTabBar(_ image: UIImage, targetSize: CGFloat) -> UIImage {
        // Use the device scale to calculate pixel size
        let scale = UIScreen.main.scale
        let targetPixelSize = targetSize * scale
        
        // Get the actual pixel size of the source image
        let sourcePixelSize = max(image.size.width * image.scale, image.size.height * image.scale)
        
        // If the source is already close to target, return as-is
        if abs(sourcePixelSize - targetPixelSize) < 5.0 {
            return image
        }
        
        // Create a scaled-down version
        let scaledSize = CGSize(width: targetSize, height: targetSize)
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        
        let renderer = UIGraphicsImageRenderer(size: scaledSize, format: format)
        return renderer.image { context in
            context.cgContext.interpolationQuality = .high
            image.draw(in: CGRect(origin: .zero, size: scaledSize))
        }
    }
    
    private static func getLucideImageStatic(name: String) -> UIImage? {
        switch name {
        case "x": return Lucide.x
        case "eye": return Lucide.eye
        case "eye-off": return Lucide.eyeOff
        case "square": return Lucide.square
        case "check-square": return Lucide.squareCheckBig
        case "menu": return Lucide.menu
        case "user": return Lucide.user
        case "settings": return Lucide.settings
        case "help-circle": return Lucide.circleQuestionMark
        case "info": return Lucide.info
        case "log-out": return Lucide.logOut
        case "chevron-down": return Lucide.chevronDown
        case "chevron-left": return Lucide.chevronLeft
        case "chevron-right": return Lucide.chevronRight
        case "arrow-left": return Lucide.arrowLeft
        case "arrow-right": return Lucide.arrowRight
        case "home": return Lucide.house
        case "map": return Lucide.map
        case "refresh-cw": return Lucide.refreshCw
        case "briefcase": return Lucide.briefcase
        case "package": return Lucide.package
        case "arrow-up-down": return Lucide.arrowUpDown
        case "sliders-horizontal": return Lucide.slidersHorizontal
        case "bookmark": return Lucide.bookmark
        case "bookmark-check": return Lucide.bookmarkCheck
        case "map-pin": return Lucide.mapPin
        case "check": return Lucide.check
        case "plus": return Lucide.plus
        case "radius": return Lucide.radius
        case "flag": return Lucide.flag
        case "route": return Lucide.route
        case "clock": return Lucide.clock
        case "calendar-arrow-up": return Lucide.calendarArrowUp
        case "calendar-arrow-down": return Lucide.calendarArrowDown
        case "weight": return Lucide.weight
        case "ruler-dimension-line": return Lucide.rulerDimensionLine
        case "user-star": return Lucide.userStar
        case "languages": return Lucide.languages
        case "arrow-up-from-dot": return Lucide.arrowUpFromDot
        case "truck": return Lucide.truck
        case "box": return Lucide.box
        case "settings-2": return Lucide.settings2
        case "search": return Lucide.search
        case "crosshair": return Lucide.crosshair

        default: return nil
        }
    }
    
    private static func lucideToSFSymbolStatic(_ lucideName: String) -> String {
        let mapping: [String: String] = [
            "x": "xmark",
            "eye": "eye",
            "eye-off": "eye.slash",
            "square": "square",
            "check-square": "checkmark.square.fill",
            "menu": "line.3.horizontal",
            "user": "person",
            "settings": "gearshape",
            "help-circle": "questionmark.circle",
            "info": "info.circle",
            "log-out": "arrow.right.square",
            "chevron-down": "chevron.down",
            "chevron-left": "chevron.left",
            "chevron-right": "chevron.right",
            "arrow-left": "arrow.left",
            "arrow-right": "arrow.right",
            "home": "house.fill",
            "map": "map.fill",
            "refresh-cw": "arrow.triangle.2.circlepath",
            "briefcase": "briefcase.fill",
            "package": "shippingbox.fill",
            "arrow-up-down": "arrow.up.arrow.down",
            "sliders-horizontal": "slider.horizontal.3",
            "bookmark": "bookmark",
            "bookmark-check": "bookmark.fill",
            "map-pin": "location.circle",
            "check": "checkmark",
            "plus": "plus",
            "radius": "location.circle",
            "arrow-up-from-dot": "arrow.up.circle",
            "truck": "truck.box.fill",
            "box": "shippingbox.fill",
            "settings-2": "gearshape.2",
            "search": "magnifyingglass",
            "crosshair": "scope",
            // Additional icons from spreadsheet
            "layers": "square.stack.3d.up",
            "car-front": "car.fill",
            "car": "car.fill",
            "house": "house.fill",
            "container": "shippingbox.fill",
            "stone": "square.fill",
            "cat": "pawprint.fill",
            "motorbike": "bicycle",
            "piano": "music.note",
            "apple": "apple.fill",
            "amphora": "wineglass.fill",
            "sofa": "chair.fill"
        ]
        return mapping[lucideName] ?? "circle"
    }
    
    var body: some View {
        let lucideImage = getLucideImage(name: name)
        
        if let uiImage = lucideImage {
            // Create a properly scaled image for crisp rendering
            let scaledImage = createScaledImage(uiImage, targetSize: size)
            
            Image(uiImage: scaledImage)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundColor(color)
        } else {
            // Fallback to SF Symbol if Lucide icon not found
            fallbackIcon
        }
    }
    
    /// Create a properly scaled image at the exact pixel size for crisp rendering
    private func createScaledImage(_ image: UIImage, targetSize: CGFloat) -> UIImage {
        let scale = UIScreen.main.scale
        let targetPixelSize = targetSize * scale
        
        // Get the actual pixel size of the source image
        let sourcePixelWidth = image.size.width * image.scale
        let sourcePixelHeight = image.size.height * image.scale
        
        // If the source is already close to target size, return as-is
        if abs(sourcePixelWidth - targetPixelSize) < 2.0 && abs(sourcePixelHeight - targetPixelSize) < 2.0 {
            return image
        }
        
        // Create a new image at the exact pixel size
        let scaledSize = CGSize(width: targetSize, height: targetSize)
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        
        let renderer = UIGraphicsImageRenderer(size: scaledSize, format: format)
        return renderer.image { context in
            // Use high-quality interpolation for better results
            context.cgContext.interpolationQuality = .high
            image.draw(in: CGRect(origin: .zero, size: scaledSize))
        }
    }
    
    /// Get Lucide icon by name from the package's static properties
    private func getLucideImage(name: String) -> UIImage? {
        // Map icon names to Lucide static properties
        // The package uses camelCase for property names (e.g., "eyeOff", "checkSquare")
        switch name {
        case "x": return Lucide.x
        case "eye": return Lucide.eye
        case "eye-off": return Lucide.eyeOff
        case "square": return Lucide.square
        case "check-square": return Lucide.squareCheckBig
        case "menu": return Lucide.menu
        case "user": return Lucide.user
        case "settings": return Lucide.settings
        case "help-circle": return Lucide.circleQuestionMark
        case "info": return Lucide.info
        case "log-out": return Lucide.logOut
        case "chevron-down": return Lucide.chevronDown
        case "chevron-left": return Lucide.chevronLeft
        case "chevron-right": return Lucide.chevronRight
        case "arrow-left": return Lucide.arrowLeft
        case "arrow-right": return Lucide.arrowRight
        case "home": return Lucide.house
        case "map": return Lucide.map
        case "refresh-cw": return Lucide.refreshCw
        case "briefcase": return Lucide.briefcase
        case "package": return Lucide.package
        case "arrow-up-down": return Lucide.arrowUpDown
        case "sliders-horizontal": return Lucide.slidersHorizontal
        case "bookmark": return Lucide.bookmark
        case "bookmark-check": return Lucide.bookmarkCheck
        case "map-pin": return Lucide.mapPin
        case "check": return Lucide.check
        case "plus": return Lucide.plus
        case "radius": return Lucide.radius
        case "flag": return Lucide.flag
        case "route": return Lucide.route
        case "clock": return Lucide.clock
        case "calendar-arrow-up": return Lucide.calendarArrowUp
        case "calendar-arrow-down": return Lucide.calendarArrowDown
        case "weight": return Lucide.weight
        case "ruler-dimension-line": return Lucide.rulerDimensionLine
        case "user-star": return Lucide.userStar
        case "languages": return Lucide.languages
        case "arrow-up-from-dot": return Lucide.arrowUpFromDot
        case "truck": return Lucide.truck
        case "box": return Lucide.box
        case "settings-2": return Lucide.settings2
        case "search": return Lucide.search
        case "crosshair": return Lucide.crosshair
        // Additional icons from spreadsheet
        case "layers": return Lucide.layers
        case "car-front", "car": return Lucide.carFront
        case "house": return Lucide.house
        case "container": return Lucide.container
        case "stone": return Lucide.brickWall
        case "cat": return Lucide.cat
        case "motorbike": return Lucide.bike
        case "piano": return Lucide.music
        case "apple": return Lucide.apple
        case "amphora": return Lucide.wine
        case "sofa": return Lucide.sofa
        default: return nil
        }
    }
    
    private var fallbackIcon: some View {
        // Map Lucide icon names to SF Symbols as fallback
        let sfSymbol = lucideToSFSymbol(name)
        return Image(systemName: sfSymbol)
            .font(.system(size: size))
            .foregroundColor(color)
    }
    
    /// Maps Lucide icon names to SF Symbols as a fallback
    private func lucideToSFSymbol(_ lucideName: String) -> String {
        let mapping: [String: String] = [
            "x": "xmark",
            "eye": "eye",
            "eye-off": "eye.slash",
            "square": "square",
            "check-square": "checkmark.square.fill",
            "menu": "line.3.horizontal",
            "user": "person",
            "settings": "gearshape",
            "help-circle": "questionmark.circle",
            "info": "info.circle",
            "log-out": "arrow.right.square",
            "chevron-down": "chevron.down",
            "chevron-left": "chevron.left",
            "chevron-right": "chevron.right",
            "arrow-left": "arrow.left",
            "arrow-right": "arrow.right",
            "home": "house.fill",
            "map": "map.fill",
            "refresh-cw": "arrow.triangle.2.circlepath",
            "briefcase": "briefcase.fill",
            "package": "shippingbox.fill",
            "arrow-up-down": "arrow.up.arrow.down",
            "sliders-horizontal": "slider.horizontal.3",
            "bookmark": "bookmark",
            "bookmark-check": "bookmark.fill",
            "map-pin": "location.circle",
            "check": "checkmark",
            "plus": "plus",
            "radius": "location.circle",
            "flag": "flag.fill",
            "route": "map.fill",
            "clock": "clock.fill",
            "calendar-arrow-up": "calendar.badge.plus",
            "calendar-arrow-down": "calendar.badge.minus",
            "weight": "scalemass.fill",
            "ruler-dimension-line": "ruler.fill",
            "user-star": "person.crop.circle.badge.star.fill",
            "languages": "character.book.closed.fill",
            "arrow-up-from-dot": "arrow.up.circle",
            "truck": "truck.box.fill",
            "box": "shippingbox.fill",
            "settings-2": "gearshape.2",
            "search": "magnifyingglass",
            "crosshair": "scope",
            // Additional icons from spreadsheet
            "layers": "square.stack.3d.up",
            "car-front": "car.fill",
            "car": "car.fill",
            "house": "house.fill",
            "container": "shippingbox.fill",
            "stone": "square.fill",
            "cat": "pawprint.fill",
            "motorbike": "bicycle",
            "piano": "music.note",
            "apple": "apple.fill",
            "amphora": "wineglass.fill",
            "sofa": "chair.fill"
        ]
        return mapping[lucideName] ?? "circle"
    }
}
