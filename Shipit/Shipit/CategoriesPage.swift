//
//  CategoriesPage.swift
//  Shipit
//
//  Created by Christopher Wirkus on 30.12.2025.
//

import SwiftUI

enum CargoCategory: String, CaseIterable {
    // Parcel & Palletized Goods
    case parcels = "Parcels"
    case pallets = "Pallets"
    case ltl = "Less-Than-Truckload (LTL)"
    case ftl = "Full Truckload (FTL)"
    
    // Freight & Commercial Loads
    case shippingContainers = "Shipping Containers"
    case dumperTruckLoads = "Dumper Truck Loads"
    case bulkCommercialLoads = "Bulk Commercial Loads"
    case otherFreightLoads = "Other Freight Loads"
    
    // Fragile & Valuable Goods
    case musicalInstruments = "Musical Instruments"
    case glassware = "Glasware"
    case art = "Art"
    case antiques = "Antiques"
    case otherFragileGoods = "Other Fragile Goods"
    
    // Equipment & Appliances
    case industrialEquipment = "Industrial Equipment"
    case householdAppliances = "Household Appliances"
    case customerElectronics = "Customer Electronics"
    case sportEquipment = "Sport Equipment"
    case gardenEquipment = "Garden Equipment"
    case officeEquipment = "Office Equipment & Supplies"
    case otherEquipment = "Other Equipment"
    
    // Furniture & Household Moves
    case furniture = "Furniture"
    case removals = "Removals"
    
    // Vehicles & Mobility
    case cars = "Cars"
    case classicCars = "Classic Cars"
    case motorcycles = "Motorcycles"
    case bicycles = "Bicycles"
    case quadBikes = "Quad Bikes & ATVs"
    case tractors = "Tractors & Farm Machinery"
    case constructionVehicles = "Construction & Plant Vehicles"
    case caravans = "Caravans & Campers"
    case trailers = "Trailers"
    case vehicleAccessories = "Vehicle Accessories & Parts"
    case otherVehicles = "Other Vehicles"
    
    // Construction & Raw Materials
    case buildingMaterials = "Building Materials"
    case rawMaterials = "Raw & Structural Materials"
    
    // Liquid & Bulk Materials
    case liquidMaterials = "Liquid Materials"
    case bulkMaterials = "Bulk Materials"
    
    // Food & Temperature-Sensitive Goods
    case foodProducts = "Food Products"
    case frozenGoods = "Frozen Goods"
    
    // Living Cargo
    case pets = "Pets"
    case otherLivingCargo = "Other Living Cargo"
    
    // Boats & Oversized Cargo
    case boats = "Boats & Watercraft"
    case oversizedCargo = "Oversized Cargo"
    
    // Other
    case other = "Other"
    
    var group: CategoryGroup {
        switch self {
        case .parcels, .pallets, .ltl, .ftl:
            return .parcelPalletized
        case .shippingContainers, .dumperTruckLoads, .bulkCommercialLoads, .otherFreightLoads:
            return .freightCommercial
        case .musicalInstruments, .glassware, .art, .antiques, .otherFragileGoods:
            return .fragileValuable
        case .industrialEquipment, .householdAppliances, .customerElectronics, .sportEquipment, .gardenEquipment, .officeEquipment, .otherEquipment:
            return .equipmentAppliances
        case .furniture, .removals:
            return .furnitureHousehold
        case .cars, .classicCars, .motorcycles, .bicycles, .quadBikes, .tractors, .constructionVehicles, .caravans, .trailers, .vehicleAccessories, .otherVehicles:
            return .vehiclesMobility
        case .buildingMaterials, .rawMaterials:
            return .constructionRaw
        case .liquidMaterials, .bulkMaterials:
            return .liquidBulk
        case .foodProducts, .frozenGoods:
            return .foodTemperature
        case .pets, .otherLivingCargo:
            return .livingCargo
        case .boats, .oversizedCargo:
            return .boatsOversized
        case .other:
            return .other
        }
    }
}

enum CategoryGroup: String, CaseIterable {
    case parcelPalletized = "Parcel & Palletized Goods"
    case freightCommercial = "Freight & Commercial Loads"
    case fragileValuable = "Fragile & Valuable Goods"
    case equipmentAppliances = "Equipment & Appliances"
    case furnitureHousehold = "Furniture & Household Moves"
    case vehiclesMobility = "Vehicles & Mobility"
    case constructionRaw = "Construction & Raw Materials"
    case liquidBulk = "Liquid & Bulk Materials"
    case foodTemperature = "Food & Temperature-Sensitive Goods"
    case livingCargo = "Living Cargo"
    case boatsOversized = "Boats & Oversized Cargo"
    case other = "Other"
    
    var categories: [CargoCategory] {
        switch self {
        case .parcelPalletized:
            return [.parcels, .pallets, .ltl, .ftl]
        case .freightCommercial:
            return [.shippingContainers, .dumperTruckLoads, .bulkCommercialLoads, .otherFreightLoads]
        case .fragileValuable:
            return [.musicalInstruments, .glassware, .art, .antiques, .otherFragileGoods]
        case .equipmentAppliances:
            return [.industrialEquipment, .householdAppliances, .customerElectronics, .sportEquipment, .gardenEquipment, .officeEquipment, .otherEquipment]
        case .furnitureHousehold:
            return [.furniture, .removals]
        case .vehiclesMobility:
            return [.cars, .classicCars, .motorcycles, .bicycles, .quadBikes, .tractors, .constructionVehicles, .caravans, .trailers, .vehicleAccessories, .otherVehicles]
        case .constructionRaw:
            return [.buildingMaterials, .rawMaterials]
        case .liquidBulk:
            return [.liquidMaterials, .bulkMaterials]
        case .foodTemperature:
            return [.foodProducts, .frozenGoods]
        case .livingCargo:
            return [.pets, .otherLivingCargo]
        case .boatsOversized:
            return [.boats, .oversizedCargo]
        case .other:
            return [.other]
        }
    }
}

class CategoryFilterManager: ObservableObject {
    static let shared = CategoryFilterManager()
    
    @Published var selectedCategories: Set<CargoCategory> = Set(CargoCategory.allCases)
    
    private let userDefaultsKey = "selectedCategories"
    
    private init() {
        loadSettings()
    }
    
    func saveSettings() {
        let categoryStrings = selectedCategories.map { $0.rawValue }
        UserDefaults.standard.set(categoryStrings, forKey: userDefaultsKey)
    }
    
    private func loadSettings() {
        if let categoryStrings = UserDefaults.standard.array(forKey: userDefaultsKey) as? [String] {
            selectedCategories = Set(categoryStrings.compactMap { CargoCategory(rawValue: $0) })
            // If no categories were saved, default to all selected
            if selectedCategories.isEmpty {
                selectedCategories = Set(CargoCategory.allCases)
            }
        } else {
            // Default: all categories selected
            selectedCategories = Set(CargoCategory.allCases)
        }
    }
    
    var selectedCount: Int {
        selectedCategories.count
    }
    
    var totalCount: Int {
        CargoCategory.allCases.count
    }
    
    var isAllSelected: Bool {
        selectedCategories.count == CargoCategory.allCases.count
    }
    
    // Map cargoType string from sheet to CargoCategory
    static func mapCargoTypeToCategory(_ cargoType: String) -> CargoCategory? {
        let cleaned = cargoType.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleaned.isEmpty {
            return nil
        }
        
        // Direct matches first
        if let category = CargoCategory(rawValue: cleaned) {
            return category
        }
        
        let lowercased = cleaned.lowercased()
        
        // Special mappings for variations in the sheet
        switch lowercased {
        case "pianos & musical instruments", "pianos", "musical instruments", "piano":
            return .musicalInstruments
        case "glasware", "glassware", "vase", "vases":
            return .glassware
        case "container", "shipping containers", "containers":
            return .shippingContainers
        case "dumper truck loads", "dumper load":
            return .dumperTruckLoads
        case "bulk commercial loads", "bulk load":
            return .bulkCommercialLoads
        case "load":
            // Default to dumper truck loads if just "load"
            return .dumperTruckLoads
        case "freight", "other freight loads":
            return .otherFreightLoads
        case "art", "painting", "paintings":
            return .art
        case "antiques", "antique", "lamp", "lamps":
            return .antiques
        default:
            // Try partial matches for flexible matching
            if lowercased.contains("parcel") {
                return .parcels
            } else if lowercased.contains("pallet") {
                return .pallets
            } else if lowercased.contains("ltl") || lowercased.contains("less-than-truckload") {
                return .ltl
            } else if lowercased.contains("ftl") || lowercased.contains("full truckload") {
                return .ftl
            } else if lowercased.contains("dumper") {
                return .dumperTruckLoads
            } else if lowercased.contains("bulk") && lowercased.contains("commercial") {
                return .bulkCommercialLoads
            } else if lowercased.contains("musical") || lowercased.contains("piano") {
                return .musicalInstruments
            } else if lowercased.contains("glass") || lowercased.contains("glas") || lowercased.contains("vase") {
                return .glassware
            } else if lowercased.contains("antique") || lowercased.contains("lamp") {
                return .antiques
            } else if lowercased.contains("art") || lowercased.contains("painting") {
                return .art
            } else if lowercased.contains("container") {
                return .shippingContainers
            } else if lowercased.contains("freight") {
                return .otherFreightLoads
            }
            
            // If no match found, return nil (will be handled as "Other" in filter)
            return nil
        }
    }
}

struct CategoriesPage: View {
    @ObservedObject private var categoryManager = CategoryFilterManager.shared
    @State private var titleDisplayMode: NavigationBarItem.TitleDisplayMode = .large
    
    var body: some View {
        ZStack {
            Colors.backgroundQuaternary
                .ignoresSafeArea()
            
            List {
                ForEach(CategoryGroup.allCases, id: \.self) { group in
                    Section {
                        ForEach(group.categories, id: \.self) { category in
                            Button(action: {
                                if categoryManager.selectedCategories.contains(category) {
                                    categoryManager.selectedCategories.remove(category)
                                } else {
                                    categoryManager.selectedCategories.insert(category)
                                }
                                categoryManager.saveSettings()
                            }) {
                                HStack {
                                    Text(category.rawValue)
                                        .foregroundColor(Colors.text)
                                    Spacer()
                                    if categoryManager.selectedCategories.contains(category) {
                                        LucideIcon(IconHelper.checkmark, size: 22)
                                            .foregroundColor(Colors.primary)
                                    }
                                }
                            }
                            .frame(minHeight: 40)
                            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                        }
                    } header: {
                        Text(group.rawValue)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Categories")
        .navigationBarTitleDisplayMode(titleDisplayMode)
        .toolbarColorScheme(.light, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        CategoriesPage()
    }
}
