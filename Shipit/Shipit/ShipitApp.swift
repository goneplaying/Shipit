//
//  ShipitApp.swift
//  Shipit
//
//  Created by Christopher Wirkus on 30.12.2025.
//

import SwiftUI
import MapboxMaps
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("🚀 [DEBUG] AppDelegate: application didFinishLaunchingWithOptions called")
        
        // Set window background color FIRST to prevent white flash
        UIWindow.appearance().backgroundColor = Colors.primaryUIColor
        print("🎨 [DEBUG] AppDelegate: Window background color set to orange")
        
        // Set Mapbox access token globally using MapboxOptions
        let accessToken = "pk.eyJ1IjoiY2hyaXN0b3BoZXJ3aXJrdXMiLCJhIjoiY21qdWJqYnVhMm5reTNmc2V5a3NtemR5MiJ9.-4UTKY4b26DD8boXDC0upw"
        MapboxOptions.accessToken = accessToken
        print("✅ Mapbox access token set programmatically: \(String(accessToken.prefix(20)))...")
        
        // Set global tint color to secondary color
        UIView.appearance().tintColor = Colors.secondaryUIColor
        UIWindow.appearance().tintColor = Colors.secondaryUIColor
        
        // Load shipment data at app startup
        ShipmentDataManager.shared.loadData()
        print("✅ Shipment data loading started at app launch")
        
        print("✅ [DEBUG] Supabase will be used for authentication and database")
        
        return true
    }
}

@main
struct ShipitApp: App {
    // register app delegate for app setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authService = SupabaseAuthService.shared
    @StateObject private var shipmentDataManager = ShipmentDataManager.shared
    @StateObject private var splashScreenState = SplashScreenStateManager()
    @ObservedObject private var appSettings = AppSettingsManager.shared
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                // Always have orange background to prevent white screen
                Colors.primary
                    .ignoresSafeArea(.all)
                
                // Show LaunchScreenView first
                if splashScreenState.state != .finished {
                    LaunchScreenView()
                        .environmentObject(splashScreenState)
                        .task {
                            print("📱 [DEBUG] ShipitApp: LaunchScreenView is being displayed (state: \(splashScreenState.state))")
                            await splashScreenState.dismiss()
                        }
                        .onAppear {
                            print("👁️ [DEBUG] ShipitApp: LaunchScreenView appeared on screen")
                        }
                } else {
                    // After splash screen, check if user is logged in
                    if authService.isAuthenticated {
                        // User is logged in - check if they've completed welcome flow
                        if !ProfileData.shared.hasCompletedWelcome {
                            // First time login - show WelcomePage to choose
                            WelcomePage()
                                .environmentObject(authService)
                                .environmentObject(shipmentDataManager)
                                .transition(.opacity)
                                .onAppear {
                                    print("👁️ [DEBUG] ShipitApp: WelcomePage appeared (first time login)")
                                }
                        } else if ProfileData.shared.selectedTab == 1 || appSettings.lastActiveHomePage == .carrier {
                            // User selected Carrier
                            HomePageCarrier()
                                .environmentObject(authService)
                                .environmentObject(shipmentDataManager)
                                .transition(.opacity)
                                .onAppear {
                                    print("👁️ [DEBUG] ShipitApp: HomePageCarrier appeared (user logged in)")
                                }
                        } else {
                            // User selected Shipper (default)
                            HomePageShipper()
                                .environmentObject(authService)
                                .environmentObject(shipmentDataManager)
                                .transition(.opacity)
                                .onAppear {
                                    print("👁️ [DEBUG] ShipitApp: HomePageShipper appeared (user logged in)")
                                }
                        }
                    } else {
                        // User is not logged in - show PhoneNumberPage
                        PhoneNumberPage()
                            .environmentObject(authService)
                            .environmentObject(shipmentDataManager)
                            .transition(.opacity)
                            .onAppear {
                                print("👁️ [DEBUG] ShipitApp: PhoneNumberPage appeared on screen")
                            }
                    }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: splashScreenState.state)
            .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
            .onAppear {
                print("📱 [DEBUG] ShipitApp: WindowGroup body appeared, initial state: \(splashScreenState.state)")
                print("👤 [DEBUG] ShipitApp: Auth state - user: \(authService.user?.id.uuidString ?? "nil")")
            }
        }
    }
}
