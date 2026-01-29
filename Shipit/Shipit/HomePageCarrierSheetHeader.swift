//
//  HomePageCarrierSheetHeader.swift
//  Shipit
//
//  Created by Christopher Wirkus on 30.12.2025.
//

import SwiftUI

// Custom view modifier for placeholder color
struct PlaceholderColorModifier: ViewModifier {
    var placeholder: String
    var placeholderColor: Color
    @Binding var text: String
    
    func body(content: Content) -> some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(.system(size: 17))
                    .foregroundColor(placeholderColor)
            }
            content
        }
    }
}

extension View {
    func placeholder(
        _ placeholder: String,
        when text: Binding<String>,
        color: Color = Color.gray
    ) -> some View {
        modifier(PlaceholderColorModifier(placeholder: placeholder, placeholderColor: color, text: text))
    }
}

struct TopRoundedRectangle: Shape {
    var cornerRadius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = min(cornerRadius, rect.height / 2, rect.width / 2)
        
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + radius), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        
        return path
    }
}

struct HomePageCarrierSheetHeader: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var onCommit: (() -> Void)? = nil
    var onTapped: (() -> Void)? = nil
    
    init(
        title: String = "Looking for a load?",
        placeholder: String = "What's your destination?",
        text: Binding<String>,
        onCommit: (() -> Void)? = nil,
        onTapped: (() -> Void)? = nil
    ) {
        self.title = title
        self.placeholder = placeholder
        self._text = text
        self.onCommit = onCommit
        self.onTapped = onTapped
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Title
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Colors.text)
                .tracking(0.38)
                .lineLimit(1)
            
            // Text Field
            HStack(spacing: 12) {
                LucideIcon(IconHelper.search, size: 24, color: Colors.textSecondary)
                    .frame(width: 24, height: 24)
                
                TextField("", text: $text)
                    .font(.system(size: 17))
                    .foregroundColor(Colors.text)
                    .placeholder(placeholder, when: $text, color: Color(hex: "#707070"))
                    .submitLabel(.search)
                    .onSubmit {
                        onCommit?()
                    }
                    .disabled(onTapped != nil) // Disable editing if tap handler is provided
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .frame(height: 48)
            .background(Colors.backgroundQuaternary)
            .cornerRadius(12)
            .contentShape(Rectangle()) // Make entire area tappable
            .onTapGesture {
                HapticFeedback.light()
                onTapped?()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Colors.background)
        .clipShape(TopRoundedRectangle(cornerRadius: 20))
    }
}

#Preview {
    HomePageCarrierSheetHeader(text: .constant(""))
}
