//
//  ShipmentData.swift
//  Shipit
//
//  Created by Christopher Wirkus on 30.12.2025.
//

import Foundation

struct ShipmentData: Identifiable, Codable {
    let id: String
    let userUID: String
    let pickupLocation: String
    let deliveryLocation: String
    let pickupCity: String
    let deliveryCity: String
    let tripDistance: String
    let distanceUnit: String
    let cargoType: String
    let title: String
    let quantity: String
    let totalWeight: String
    let weightUnit: String
    let offersNumber: String
    let minOffer: String
    let maxOffer: String
    let currency: String
    let createdAt: String
    let pickupDate: String
    let deliveryDate: String
    let tripColor: String
    let icon: String
    let totalDimensions: String
    let shippersName: String
    let shippersSurname: String
    let shippersRating: String
    let shippersLanguage: String
}
