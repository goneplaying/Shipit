//
//  ProfilePage.swift
//  Shipit
//
//  Created by Christopher Wirkus on 30.12.2025.
//

import SwiftUI

enum MenuDestination: Hashable {
    case profile
    case settings
    case helpSupport
    case about
}

struct MenuPage: View {
    @EnvironmentObject var authService: AuthService
    @ObservedObject private var profileData = ProfileData.shared
    @State private var showLogoutConfirmation = false
    @State private var titleDisplayMode: NavigationBarItem.TitleDisplayMode = .large
    
    private var nameAndSurname: String {
        let firstName = profileData.firstName.trimmingCharacters(in: .whitespaces)
        let lastName = profileData.lastName.trimmingCharacters(in: .whitespaces)
        
        if firstName.isEmpty && lastName.isEmpty {
            return "Name and Surname"
        } else if firstName.isEmpty {
            return lastName
        } else if lastName.isEmpty {
            return firstName
        } else {
            return "\(firstName) \(lastName)"
        }
    }
    
    var body: some View {
        ZStack {
            Colors.background
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Track scroll position at the top
                    ScrollViewOffsetTracker()
                    
                    // List Content
                    VStack(spacing: 0) {
                        NavigationLink(value: MenuDestination.profile) {
                            HStack {
                                Label {
                                    Text("User Details")
                                        .foregroundColor(Colors.text)
                                } icon: {
                                    LucideIcon(IconHelper.person, size: 22, color: Colors.text)
                                }
                                Spacer()
                                LucideIcon(IconHelper.chevronRight, size: 20, color: Colors.textSecondary)
                            }
                            .frame(minHeight: 40)
                            .padding(.leading, 0)
                            .padding(.trailing, 20)
                            .padding(.vertical, 12)
                        }
                        
                        Divider()
                            .background(Colors.divider)
                        
                        NavigationLink(value: MenuDestination.settings) {
                            HStack {
                                Label {
                                    Text("Settings")
                                        .foregroundColor(Colors.text)
                                } icon: {
                                    LucideIcon(IconHelper.settings, size: 22, color: Colors.text)
                                }
                                Spacer()
                                LucideIcon(IconHelper.chevronRight, size: 20, color: Colors.textSecondary)
                            }
                            .frame(minHeight: 40)
                            .padding(.leading, 0)
                            .padding(.trailing, 20)
                            .padding(.vertical, 12)
                        }
                        
                        Divider()
                            .background(Colors.divider)
                        
                        NavigationLink(value: MenuDestination.helpSupport) {
                            HStack {
                                Label {
                                    Text("Help & Support")
                                        .foregroundColor(Colors.text)
                                } icon: {
                                    LucideIcon(IconHelper.help, size: 22, color: Colors.text)
                                }
                                Spacer()
                                LucideIcon(IconHelper.chevronRight, size: 20, color: Colors.textSecondary)
                            }
                            .frame(minHeight: 40)
                            .padding(.leading, 0)
                            .padding(.trailing, 20)
                            .padding(.vertical, 12)
                        }
                        
                        Divider()
                            .background(Colors.divider)
                        
                        NavigationLink(value: MenuDestination.about) {
                            HStack {
                                Label {
                                    Text("About")
                                        .foregroundColor(Colors.text)
                                } icon: {
                                    LucideIcon(IconHelper.about, size: 22, color: Colors.text)
                                }
                                Spacer()
                                LucideIcon(IconHelper.chevronRight, size: 20, color: Colors.textSecondary)
                            }
                            .frame(minHeight: 40)
                            .padding(.leading, 0)
                            .padding(.trailing, 20)
                            .padding(.vertical, 12)
                        }
                        
                        Divider()
                            .background(Colors.divider)
                        
                        Button(action: {
                            showLogoutConfirmation = true
                        }) {
                            HStack {
                                Label {
                                    Text("Logout")
                                        .foregroundColor(.red)
                                } icon: {
                                    LucideIcon(IconHelper.logout, size: 22, color: .red)
                                }
                                Spacer()
                                LucideIcon(IconHelper.chevronRight, size: 20, color: Colors.textSecondary)
                            }
                            .frame(minHeight: 40)
                            .padding(.leading, 0)
                            .padding(.trailing, 20)
                            .padding(.vertical, 12)
                        }
                    }
                    .background(Color.white)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                let threshold: CGFloat = -50
                let newMode: NavigationBarItem.TitleDisplayMode = value < threshold ? .inline : .large
                if titleDisplayMode != newMode {
                    titleDisplayMode = newMode
                }
            }
        }
        .navigationTitle(nameAndSurname)
        .navigationBarTitleDisplayMode(titleDisplayMode)
        .toolbarColorScheme(.light, for: .navigationBar)
        .alert("Logout", isPresented: $showLogoutConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Logout", role: .destructive) {
                do {
                    try authService.logout()
                    // HomePageShipper/HomePageCarrier will handle dismissal when user logs out
                } catch {
                    // Handle logout error if needed
                }
            }
        } message: {
            Text("Are you sure you want to logout?")
        }
        .navigationDestination(for: MenuDestination.self) { destination in
            switch destination {
            case .profile:
                UserDetailsPage()
            case .settings:
                SettingsPage()
            case .helpSupport:
                HelpSupportPage()
            case .about:
                AboutPage()
            }
        }
    }
}

#Preview {
    MenuPage()
        .environmentObject(AuthService())
}
