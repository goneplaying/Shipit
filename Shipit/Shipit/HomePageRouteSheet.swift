//
//  HomePageRouteSheet.swift
//  Shipit
//
//  Created on 29.01.2026.
//

import SwiftUI

struct HomePageRouteSheet: View {
    @Binding var isPresented: Bool
    
    // Route data
    var fromCity: String
    var toCity: String
    var distance: String
    var onEditRoute: () -> Void
    var onDeleteRoute: () -> Void
    
    var body: some View {
        sheetHeader
    }
    
    // MARK: - Sheet Header
    
    private var sheetHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            // Left side - Text content
            VStack(alignment: .leading, spacing: 2) {
                // Top line with "Your route" and distance
                HStack {
                    Text("Your route")
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: "#6C6C6C"))
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text(distance)
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: "#6C6C6C"))
                        Text("km")
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: "#6C6C6C"))
                    }
                }
                
                // City names
                VStack(alignment: .leading, spacing: -2) {
                    Text(fromCity)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(hex: "#141414"))
                        .lineLimit(1)
                    
                    Text(toCity)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(hex: "#141414"))
                        .lineLimit(1)
                }
            }
            
            // Right side - Interactive elements
            VStack(alignment: .trailing, spacing: 8) {
                // Close button (deletes route)
                Button(action: {
                    HapticFeedback.light()
                    onDeleteRoute()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#F4F4F4"))
                            .frame(width: 40, height: 40)
                        
                        LucideIcon(IconHelper.close, size: 24, color: Colors.text)
                    }
                }
                .instantFeedback()
                
                // Edit route link
                Button(action: {
                    HapticFeedback.light()
                    onEditRoute()
                }) {
                    Text("Edit route")
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: "#222222"))
                        .underline()
                }
                .instantFeedback()
                .padding(.top, 14)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 16)
    }
}

// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var isPresented = true
    
    return Text("Background Content")
        .sheet(isPresented: $isPresented) {
            HomePageRouteSheet(
                isPresented: $isPresented,
                fromCity: "Philadelphia",
                toCity: "Washington",
                distance: "136",
                onEditRoute: {
                    print("Edit route tapped")
                },
                onDeleteRoute: {
                    print("Delete route tapped")
                }
            )
        }
}
