//
//  MapboxMapView.swift
//  Shipit
//
//  Created by Christopher Wirkus on 30.12.2025.
//

import SwiftUI
import MapboxMaps
import CoreLocation
import UIKit
import Combine

struct MapboxMapView: UIViewRepresentable {
    @Binding var centerCoordinate: CLLocationCoordinate2D
    @Binding var zoomLevel: Double
    @Binding var routeCoordinates: [CLLocationCoordinate2D]
    @Binding var routeColor: String
    var userLocation: CLLocationCoordinate2D?
    var startCoordinate: CLLocationCoordinate2D? // Start of route for POI marker
    var useSecondaryPOI: Bool = false // Use secondary POI images (poi-start-secondary, poi-destination-secondary)
    var allPickupCoordinates: [CLLocationCoordinate2D] = [] // All pickup locations to display
    var multipleRoutes: [[CLLocationCoordinate2D]] = [] // Multiple separate routes to display (thick lines for selected)
    var previewRoutes: [[CLLocationCoordinate2D]] = [] // Preview routes (thin lines for unselected)
    var bookmarkedRoutes: [[CLLocationCoordinate2D]] = [] // Bookmarked routes (primary color, 2px width)
    var onMapTapped: ((CLLocationCoordinate2D) -> Void)?
    var onPickupMarkerTapped: ((CLLocationCoordinate2D) -> Void)? // Callback when pickup marker is tapped
    var cameraPadding: UIEdgeInsets? = nil // Optional custom camera padding
    var scaleBarPosition: OrnamentPosition = .topLeft // Scale bar position
    @ObservedObject private var mapSettings = MapSettingsManager.shared
    
    func makeUIView(context: Context) -> MapView {
        // Verify access token is set (either in Info.plist or programmatically via MapboxOptions)
        if MapboxOptions.accessToken.isEmpty {
            print("⚠️ Warning: Mapbox access token is not set. Please set it via MapboxOptions.accessToken in app delegate.")
        } else {
            print("✅ Mapbox access token is configured: \(String(MapboxOptions.accessToken.prefix(20)))...")
        }
        
        // Initialize map view with camera and style options
        var cameraOptions = CameraOptions(
            center: centerCoordinate,
            zoom: zoomLevel
        )
        // Use custom padding if provided, otherwise default to bottom padding for slider
        cameraOptions.padding = cameraPadding ?? UIEdgeInsets(top: 0, left: 0, bottom: 200, right: 0)
        
        // Create MapInitOptions with custom style
        let customStyleURI = StyleURI(rawValue: "mapbox://styles/christopherwirkus/cmjvf4rey005n01se4eidflls") ?? StyleURI.streets
        let mapInitOptions = MapInitOptions(
            cameraOptions: cameraOptions,
            styleURI: customStyleURI
        )
        
        // Use a default frame size to avoid Mapbox initialization errors
        let screenWidth = UIScreen.main.bounds.width
        let screenScale = UIScreen.main.scale
        
        let safeSize: CGFloat = max(screenWidth > 0 ? screenWidth : 375, 375)
        let defaultFrame = CGRect(x: 0, y: 0, width: safeSize, height: safeSize)
        
        let mapView = MapView(frame: defaultFrame, mapInitOptions: mapInitOptions)
        
        // Enable built-in user location puck with custom secondary color
        let secondaryUIColor = Colors.secondaryUIColor
        
        // Create a custom puck image using the secondary color
        let puckSize: CGFloat = 20
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: puckSize, height: puckSize))
        let customPuckImage = renderer.image { context in
            let rect = CGRect(x: 0, y: 0, width: puckSize, height: puckSize)
            
            // White outer border
            UIColor.white.setFill()
            context.cgContext.fillEllipse(in: rect)
            
            // Secondary color inner circle
            secondaryUIColor.setFill()
            let innerRect = rect.insetBy(dx: 3, dy: 3)
            context.cgContext.fillEllipse(in: innerRect)
        }
        
        // Create a simple bearing (arrow) image
        let bearingSize: CGFloat = 24
        let bearingRenderer = UIGraphicsImageRenderer(size: CGSize(width: bearingSize, height: bearingSize))
        let customBearingImage = bearingRenderer.image { context in
            let center = CGPoint(x: bearingSize / 2, y: bearingSize / 2)
            let path = UIBezierPath()
            // Triangle pointing up
            path.move(to: CGPoint(x: center.x, y: 0))
            path.addLine(to: CGPoint(x: center.x - 7, y: 10))
            path.addLine(to: CGPoint(x: center.x + 7, y: 10))
            path.close()
            
            secondaryUIColor.setFill()
            path.fill()
        }
        
        var puckConfig = Puck2DConfiguration(topImage: customPuckImage, bearingImage: customBearingImage)
        puckConfig.scale = .constant(1.0)
        mapView.location.options.puckType = .puck2D(puckConfig)
        
        // Ensure the view has a valid content scale factor immediately
        let validScale = screenScale > 0 && screenScale.isFinite ? screenScale : 2.0
        mapView.contentScaleFactor = validScale
        
        // Configure scale bar position and visibility after map is loaded
        DispatchQueue.main.async {
            mapView.ornaments.options.scaleBar.visibility = mapSettings.showScaleBar ? .visible : .hidden
            mapView.ornaments.options.scaleBar.position = scaleBarPosition
            
            // Hide compass
            mapView.ornaments.options.compass.visibility = .hidden
            
            if scaleBarPosition == .bottomLeft {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    let mapWidth = mapView.frame.width
                    let horizontalOffset = (mapWidth / 2) - 40
                    mapView.ornaments.options.scaleBar.margins = CGPoint(x: horizontalOffset, y: 10)
                }
            }
        }
        
        // Store reference for updates
        context.coordinator.mapView = mapView
        
        // Add tap gesture recognizer for POI interaction
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapTap(_:)))
        tapGesture.numberOfTapsRequired = 1
        tapGesture.numberOfTouchesRequired = 1
        mapView.addGestureRecognizer(tapGesture)
        
        // Wait for style to load before adding route layer, POI marker, and user location
        mapView.mapboxMap.onStyleLoaded.observeNext { _ in
            context.coordinator.setupRouteLayer(mapView: mapView, color: self.routeColor)
            context.coordinator.setupMultipleRoutesLayer(mapView: mapView, color: self.routeColor)
            context.coordinator.setupPreviewRoutesLayer(mapView: mapView)
            context.coordinator.setupBookmarkedRoutesLayer(mapView: mapView)
            
            // Add pickup POI marker layer with route color
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                context.coordinator.setupPOIMarker(mapView: mapView, routeColor: self.routeColor, useSecondary: self.useSecondaryPOI)
                context.coordinator.setupDestinationPOIMarker(mapView: mapView, routeColor: self.routeColor, useSecondary: self.useSecondaryPOI)
                
                // Setup multiple pickup markers if provided
                if !self.allPickupCoordinates.isEmpty {
                    context.coordinator.setupAllPickupMarkers(mapView: mapView, coordinates: self.allPickupCoordinates, routeColor: self.routeColor)
                }
            }
        }.store(in: &context.coordinator.cancellables)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MapView, context: Context) {
        // Ensure map view has a valid size and content scale factor
        let currentWidth = mapView.frame.width
        let currentHeight = mapView.frame.height
        let screenScale = UIScreen.main.scale
        let validScreenScale = (screenScale > 0 && screenScale.isFinite && !screenScale.isNaN) ? screenScale : 2.0
        
        let hasInvalidSize = currentWidth <= 64 || currentHeight <= 64 || 
                            currentWidth.isNaN || currentHeight.isNaN ||
                            currentWidth.isInfinite || currentHeight.isInfinite ||
                            !currentWidth.isFinite || !currentHeight.isFinite
        
        if hasInvalidSize {
            let screenWidth = UIScreen.main.bounds.width
            let defaultSize = max(screenWidth, 375)
            let safeSize: CGFloat = (defaultSize.isFinite && !defaultSize.isNaN) ? defaultSize : 375
            mapView.frame = CGRect(x: 0, y: 0, width: safeSize, height: safeSize)
        }
        
        let currentScale = mapView.contentScaleFactor
        let hasInvalidScale = currentScale.isNaN || currentScale.isInfinite || 
                             currentScale <= 0 || !currentScale.isFinite
        
        if hasInvalidScale {
            mapView.contentScaleFactor = validScreenScale
        }
        
        // Only update camera position if centerCoordinate or zoomLevel actually changed
        let centerChanged = context.coordinator.lastCenterCoordinate == nil || 
            context.coordinator.lastCenterCoordinate?.latitude != centerCoordinate.latitude ||
            context.coordinator.lastCenterCoordinate?.longitude != centerCoordinate.longitude
        
        let zoomChanged = context.coordinator.lastZoomLevel == nil ||
            context.coordinator.lastZoomLevel != zoomLevel
        
        if centerChanged || zoomChanged {
            var cameraOptions = CameraOptions(
                center: centerCoordinate,
                zoom: zoomLevel
            )
            cameraOptions.padding = cameraPadding ?? UIEdgeInsets(top: 0, left: 0, bottom: 200, right: 0)
            mapView.mapboxMap.setCamera(to: cameraOptions)
            context.coordinator.lastCenterCoordinate = centerCoordinate
            context.coordinator.lastZoomLevel = zoomLevel
        }
        
        // Update scale bar visibility if setting changed
        if context.coordinator.lastScaleBarVisible != mapSettings.showScaleBar {
            mapView.ornaments.options.scaleBar.visibility = mapSettings.showScaleBar ? .visible : .hidden
            context.coordinator.lastScaleBarVisible = mapSettings.showScaleBar
        }
        
        // Ensure compass is always hidden
        mapView.ornaments.options.compass.visibility = .hidden
        
        // Update route if coordinates or color changed
        let routeChanged = context.coordinator.lastRouteCoordinates.count != routeCoordinates.count ||
            !routeCoordinates.isEmpty && (context.coordinator.lastRouteCoordinates.isEmpty ||
            zip(context.coordinator.lastRouteCoordinates, routeCoordinates).contains { $0.latitude != $1.latitude || $0.longitude != $1.longitude })
        
        if routeChanged || context.coordinator.lastRouteColor != routeColor {
            context.coordinator.updateRoute(mapView: mapView, coordinates: routeCoordinates, color: routeColor)
            context.coordinator.lastRouteCoordinates = routeCoordinates
            context.coordinator.lastRouteColor = routeColor
        }
        
        // Update POI icon colors if route color changed or useSecondaryPOI changed
        if context.coordinator.lastRouteColor != routeColor || context.coordinator.lastUseSecondaryPOI != useSecondaryPOI {
            context.coordinator.updatePOIColor(mapView: mapView, routeColor: routeColor, useSecondary: useSecondaryPOI)
            context.coordinator.updateDestinationPOIColor(mapView: mapView, routeColor: routeColor, useSecondary: useSecondaryPOI)
            context.coordinator.updateAllPickupMarkersColor(mapView: mapView, routeColor: routeColor)
            context.coordinator.lastUseSecondaryPOI = useSecondaryPOI
        }
        
        // Update all pickup markers if coordinates changed
        if context.coordinator.lastAllPickupCoordinates != allPickupCoordinates {
            context.coordinator.updateAllPickupMarkers(mapView: mapView, coordinates: allPickupCoordinates, routeColor: routeColor)
            context.coordinator.lastAllPickupCoordinates = allPickupCoordinates
        }
        
        // Update multiple routes if changed
        if context.coordinator.lastMultipleRoutes != multipleRoutes {
            context.coordinator.updateMultipleRoutes(mapView: mapView, routes: multipleRoutes, color: routeColor)
            context.coordinator.lastMultipleRoutes = multipleRoutes
        }
        
        // Update preview routes if changed
        if context.coordinator.lastPreviewRoutes != previewRoutes {
            context.coordinator.updatePreviewRoutes(mapView: mapView, routes: previewRoutes)
            context.coordinator.lastPreviewRoutes = previewRoutes
        }
        
        // Update bookmarked routes if changed
        if context.coordinator.lastBookmarkedRoutes != bookmarkedRoutes {
            context.coordinator.updateBookmarkedRoutes(mapView: mapView, routes: bookmarkedRoutes)
            context.coordinator.lastBookmarkedRoutes = bookmarkedRoutes
        }
        
        // Use provided startCoordinate if available, otherwise use first route coordinate
        let targetStartCoordinate: CLLocationCoordinate2D?
        if let startCoord = startCoordinate {
            targetStartCoordinate = startCoord
        } else if !routeCoordinates.isEmpty {
            targetStartCoordinate = routeCoordinates.first
        } else {
            targetStartCoordinate = nil
        }
        
        // Helper function to compare coordinates by value
        func coordinatesEqual(_ coord1: CLLocationCoordinate2D?, _ coord2: CLLocationCoordinate2D?) -> Bool {
            switch (coord1, coord2) {
            case (nil, nil):
                return true
            case (nil, _), (_, nil):
                return false
            case (let c1?, let c2?):
                return abs(c1.latitude - c2.latitude) < 0.0001 && abs(c1.longitude - c2.longitude) < 0.0001
            }
        }
        
        // Update pickup POI marker if start coordinate changed
        if !coordinatesEqual(context.coordinator.lastStartCoordinate, targetStartCoordinate) {
            context.coordinator.updatePOIMarker(mapView: mapView, coordinate: targetStartCoordinate)
            context.coordinator.lastStartCoordinate = targetStartCoordinate
        }
        
        // Always ensure destination POI marker is at the end of the route (only if route exists)
        if !routeCoordinates.isEmpty && mapView.mapboxMap.isStyleLoaded {
            let endCoord = routeCoordinates.last
            if context.coordinator.lastEndCoordinate != endCoord || context.coordinator.lastEndCoordinate == nil {
                context.coordinator.updateDestinationPOIMarker(mapView: mapView, coordinate: endCoord)
                context.coordinator.lastEndCoordinate = endCoord
            }
        } else if !routeCoordinates.isEmpty && !mapView.mapboxMap.isStyleLoaded {
            mapView.mapboxMap.onStyleLoaded.observeNext { _ in
                let startCoord = routeCoordinates.first
                let endCoord = routeCoordinates.last
                context.coordinator.updatePOIMarker(mapView: mapView, coordinate: startCoord)
                context.coordinator.updateDestinationPOIMarker(mapView: mapView, coordinate: endCoord)
                context.coordinator.lastStartCoordinate = startCoord
                context.coordinator.lastEndCoordinate = endCoord
            }.store(in: &context.coordinator.cancellables)
        } else {
            // Clear destination marker if route is empty
            if context.coordinator.lastEndCoordinate != nil {
                if mapView.mapboxMap.isStyleLoaded {
                    context.coordinator.updateDestinationPOIMarker(mapView: mapView, coordinate: nil)
                }
                context.coordinator.lastEndCoordinate = nil
            }
        }
    }
    
    func dismantleUIView(_ mapView: MapView, coordinator: Coordinator) {
        coordinator.cancellables.removeAll()
        coordinator.animationDisplayLink?.invalidate()
        coordinator.animationDisplayLink = nil
        coordinator.animatedPickupMarkerDisplayLink?.invalidate()
        coordinator.animatedPickupMarkerDisplayLink = nil
        coordinator.mapView = nil
        coordinator.animationMapView = nil
        coordinator.animatedPickupMarkerMapView = nil
        coordinator.lastRouteCoordinates.removeAll()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject {
        var parent: MapboxMapView
        var mapView: MapView?
        var lastRouteCoordinates: [CLLocationCoordinate2D] = []
        var lastMultipleRoutes: [[CLLocationCoordinate2D]] = []
        var lastPreviewRoutes: [[CLLocationCoordinate2D]] = []
        var lastBookmarkedRoutes: [[CLLocationCoordinate2D]] = []
        var lastRouteColor: String = ""
        var lastUseSecondaryPOI: Bool = false
        var lastCenterCoordinate: CLLocationCoordinate2D?
        var lastZoomLevel: Double?
        var lastUserLocation: CLLocationCoordinate2D?
        var lastStartCoordinate: CLLocationCoordinate2D?
        var lastEndCoordinate: CLLocationCoordinate2D?
        var lastScaleBarVisible: Bool = true
        var currentPOISize: Double = 1.1
        var isAnimatingPOI: Bool = false
        var animationDisplayLink: CADisplayLink?
        var animationStartTime: CFTimeInterval = 0
        var animationFromScale: Double = 1.1
        var animationToScale: Double = 1.1
        var animationDuration: TimeInterval = 0.4
        var animationMapView: MapView?
        
        let routeSourceId = "route-source"
        let routeLayerId = "route-layer"
        let multipleRoutesSourceId = "multiple-routes-source"
        let multipleRoutesLayerId = "multiple-routes-layer"
        let previewRoutesSourceId = "preview-routes-source"
        let previewRoutesLayerId = "preview-routes-layer"
        let bookmarkedRoutesSourceId = "bookmarked-routes-source"
        let bookmarkedRoutesLayerId = "bookmarked-routes-layer"
        let poiSourceId = "poi-start-source"
        let poiLayerId = "poi-start-layer"
        let poiDestinationSourceId = "poi-destination-source"
        let poiDestinationLayerId = "poi-destination-layer"
        let allPickupMarkersSourceId = "all-pickup-markers-source"
        let allPickupMarkersLayerId = "all-pickup-markers-layer"
        let previewRoutesPOISourceId = "preview-routes-poi-source"
        let previewRoutesPOILayerId = "preview-routes-poi-layer"
        let bookmarkedRoutesPOISourceId = "bookmarked-routes-poi-source"
        let bookmarkedRoutesPOILayerId = "bookmarked-routes-poi-layer"
        let selectedRoutesPOISourceId = "selected-routes-poi-source"
        let selectedRoutesPOILayerId = "selected-routes-poi-layer"
        
        let animatedPickupMarkerSourceId = "animated-pickup-marker-source"
        let animatedPickupMarkerLayerId = "animated-pickup-marker-layer"
        var isAnimatingPickupMarker: Bool = false
        var animatedPickupMarkerCoordinate: CLLocationCoordinate2D?
        var currentAnimatedPickupMarkerSize: Double = 1.1
        var animatedPickupMarkerFromScale: Double = 1.1
        var animatedPickupMarkerToScale: Double = 1.1
        var animatedPickupMarkerDuration: TimeInterval = 0.4
        var animatedPickupMarkerStartTime: CFTimeInterval = 0
        var animatedPickupMarkerMapView: MapView?
        var animatedPickupMarkerDisplayLink: CADisplayLink?
        
        var lastAllPickupCoordinates: [CLLocationCoordinate2D] = []
        var cancellables: Set<AnyCancellable> = []
        
        init(parent: MapboxMapView) {
            self.parent = parent
            super.init()
        }
        
        func setupRouteLayer(mapView: MapView, color: String) {
            guard mapView.mapboxMap.isStyleLoaded else {
                mapView.mapboxMap.onStyleLoaded.observeNext { _ in
                    self.setupRouteLayer(mapView: mapView, color: color)
                }.store(in: &cancellables)
                return
            }
            
            if mapView.mapboxMap.sourceExists(withId: routeSourceId) {
                if lastRouteColor != color {
                    let routeColor = UIColor(hex: color) ?? Colors.primaryUIColor
                    try? mapView.mapboxMap.updateLayer(withId: routeLayerId, type: LineLayer.self) { layer in
                        layer.lineColor = .constant(StyleColor(routeColor))
                    }
                    lastRouteColor = color
                }
                return
            }
            
            var routeSource = GeoJSONSource(id: routeSourceId)
            routeSource.data = .geometry(.lineString(LineString([])))
            try? mapView.mapboxMap.addSource(routeSource)
            
            var routeLayer = LineLayer(id: routeLayerId, source: routeSourceId)
            let routeColor = UIColor(hex: color) ?? Colors.primaryUIColor
            routeLayer.lineColor = .constant(StyleColor(routeColor))
            routeLayer.lineWidth = .constant(4.0)
            routeLayer.lineCap = .constant(LineCap.round)
            routeLayer.lineJoin = .constant(LineJoin.round)
            
            // Add below multiple routes layer to ensure selected routes appear on top
            if mapView.mapboxMap.layerExists(withId: multipleRoutesLayerId) {
                try? mapView.mapboxMap.addLayer(routeLayer, layerPosition: .below(multipleRoutesLayerId))
            } else if mapView.mapboxMap.layerExists(withId: previewRoutesLayerId) {
                try? mapView.mapboxMap.addLayer(routeLayer, layerPosition: .below(previewRoutesLayerId))
            } else {
                try? mapView.mapboxMap.addLayer(routeLayer)
            }
            lastRouteColor = color
        }
        
        func updateRoute(mapView: MapView, coordinates: [CLLocationCoordinate2D], color: String) {
            if !mapView.mapboxMap.sourceExists(withId: routeSourceId) {
                setupRouteLayer(mapView: mapView, color: color)
            }
            mapView.mapboxMap.updateGeoJSONSource(withId: routeSourceId, geoJSON: .geometry(.lineString(LineString(coordinates))))
            
            if lastRouteColor != color {
                let routeUIColor = UIColor(hex: color) ?? Colors.primaryUIColor
                try? mapView.mapboxMap.updateLayer(withId: routeLayerId, type: LineLayer.self) { layer in
                    layer.lineColor = .constant(StyleColor(routeUIColor))
                }
                lastRouteColor = color
            }
        }
        
        func setupMultipleRoutesLayer(mapView: MapView, color: String) {
            var source = GeoJSONSource(id: multipleRoutesSourceId)
            source.data = .geometry(.multiLineString(MultiLineString([])))
            try? mapView.mapboxMap.addSource(source)
            
            var layer = LineLayer(id: multipleRoutesLayerId, source: multipleRoutesSourceId)
            layer.lineColor = .constant(StyleColor(UIColor(hex: color) ?? .blue))
            layer.lineWidth = .constant(4.0)
            layer.lineCap = .constant(.round)
            layer.lineJoin = .constant(.round)
            
            // Always add above the base route layer to ensure selected routes are visible on top
            if mapView.mapboxMap.layerExists(withId: routeLayerId) {
                try? mapView.mapboxMap.addLayer(layer, layerPosition: .above(routeLayerId))
            } else if mapView.mapboxMap.layerExists(withId: previewRoutesLayerId) {
                try? mapView.mapboxMap.addLayer(layer, layerPosition: .above(previewRoutesLayerId))
            } else {
                try? mapView.mapboxMap.addLayer(layer)
            }
        }
        
        func updateMultipleRoutes(mapView: MapView, routes: [[CLLocationCoordinate2D]], color: String) {
            if !mapView.mapboxMap.sourceExists(withId: multipleRoutesSourceId) {
                setupMultipleRoutesLayer(mapView: mapView, color: color)
            }
            mapView.mapboxMap.updateGeoJSONSource(withId: multipleRoutesSourceId, geoJSON: .geometry(.multiLineString(MultiLineString(routes))))
            updateSelectedRoutesPOIs(mapView: mapView, routes: routes)
        }
        
        func setupPreviewRoutesLayer(mapView: MapView) {
            var source = GeoJSONSource(id: previewRoutesSourceId)
            source.data = .geometry(.multiLineString(MultiLineString([])))
            try? mapView.mapboxMap.addSource(source)
            
            var layer = LineLayer(id: previewRoutesLayerId, source: previewRoutesSourceId)
            layer.lineColor = .constant(StyleColor(UIColor(hex: "#A8A8A8") ?? .lightGray))
            layer.lineWidth = .constant(1.5)
            layer.lineOpacity = .constant(1.0)
            try? mapView.mapboxMap.addLayer(layer)
        }
        
        func updatePreviewRoutes(mapView: MapView, routes: [[CLLocationCoordinate2D]]) {
            if !mapView.mapboxMap.sourceExists(withId: previewRoutesSourceId) {
                setupPreviewRoutesLayer(mapView: mapView)
            }
            mapView.mapboxMap.updateGeoJSONSource(withId: previewRoutesSourceId, geoJSON: .geometry(.multiLineString(MultiLineString(routes))))
            updatePreviewRoutesPOIs(mapView: mapView, routes: routes)
        }
        
        func setupBookmarkedRoutesLayer(mapView: MapView) {
            var source = GeoJSONSource(id: bookmarkedRoutesSourceId)
            source.data = .geometry(.multiLineString(MultiLineString([])))
            try? mapView.mapboxMap.addSource(source)
            
            var layer = LineLayer(id: bookmarkedRoutesLayerId, source: bookmarkedRoutesSourceId)
            layer.lineColor = .constant(StyleColor(Colors.primaryUIColor))
            layer.lineWidth = .constant(2.0)
            try? mapView.mapboxMap.addLayer(layer)
        }
        
        func updateBookmarkedRoutes(mapView: MapView, routes: [[CLLocationCoordinate2D]]) {
            if !mapView.mapboxMap.sourceExists(withId: bookmarkedRoutesSourceId) {
                setupBookmarkedRoutesLayer(mapView: mapView)
            }
            mapView.mapboxMap.updateGeoJSONSource(withId: bookmarkedRoutesSourceId, geoJSON: .geometry(.multiLineString(MultiLineString(routes))))
            updateBookmarkedRoutesPOIs(mapView: mapView, routes: routes)
        }
        
        func setupPOIMarker(mapView: MapView, routeColor: String = "#222222", useSecondary: Bool = false) {
            let poiImage = getPOIImage(useSecondary: useSecondary, routeColor: routeColor, isStart: true)
            try? mapView.mapboxMap.addImage(poiImage, id: "main-route-start-icon")
            
            var source = GeoJSONSource(id: poiSourceId)
            source.data = .geometry(.point(Point(CLLocationCoordinate2D(latitude: 0, longitude: 0))))
            try? mapView.mapboxMap.addSource(source)
            
            var layer = SymbolLayer(id: poiLayerId, source: poiSourceId)
            layer.iconImage = .constant(.name("main-route-start-icon"))
            layer.iconSize = .constant(1.1)
            layer.iconAnchor = .constant(.bottom)
            layer.iconAllowOverlap = .constant(true)
            try? mapView.mapboxMap.addLayer(layer)
        }
        
        func updatePOIMarker(mapView: MapView, coordinate: CLLocationCoordinate2D?) {
            if !mapView.mapboxMap.sourceExists(withId: poiSourceId) {
                setupPOIMarker(mapView: mapView, routeColor: lastRouteColor, useSecondary: lastUseSecondaryPOI)
            }
            let point = coordinate != nil ? Point(coordinate!) : Point(CLLocationCoordinate2D(latitude: 0, longitude: 0))
            mapView.mapboxMap.updateGeoJSONSource(withId: poiSourceId, geoJSON: .geometry(.point(point)))
        }
        
        func updatePOIColor(mapView: MapView, routeColor: String, useSecondary: Bool = false) {
            let poiImage = getPOIImage(useSecondary: useSecondary, routeColor: routeColor, isStart: true)
            try? mapView.mapboxMap.addImage(poiImage, id: "main-route-start-icon")
        }
        
        func setupDestinationPOIMarker(mapView: MapView, routeColor: String = "#222222", useSecondary: Bool = false) {
            let poiImage = getPOIImage(useSecondary: useSecondary, routeColor: routeColor, isStart: false)
            try? mapView.mapboxMap.addImage(poiImage, id: "main-route-destination-icon")
            
            var source = GeoJSONSource(id: poiDestinationSourceId)
            source.data = .geometry(.point(Point(CLLocationCoordinate2D(latitude: 0, longitude: 0))))
            try? mapView.mapboxMap.addSource(source)
            
            var layer = SymbolLayer(id: poiDestinationLayerId, source: poiDestinationSourceId)
            layer.iconImage = .constant(.name("main-route-destination-icon"))
            layer.iconSize = .constant(1.1)
            layer.iconAnchor = .constant(.bottom)
            layer.iconAllowOverlap = .constant(true)
            try? mapView.mapboxMap.addLayer(layer)
        }
        
        func updateDestinationPOIMarker(mapView: MapView, coordinate: CLLocationCoordinate2D?) {
            if !mapView.mapboxMap.sourceExists(withId: poiDestinationSourceId) {
                setupDestinationPOIMarker(mapView: mapView, routeColor: lastRouteColor, useSecondary: lastUseSecondaryPOI)
            }
            let point = coordinate != nil ? Point(coordinate!) : Point(CLLocationCoordinate2D(latitude: 0, longitude: 0))
            mapView.mapboxMap.updateGeoJSONSource(withId: poiDestinationSourceId, geoJSON: .geometry(.point(point)))
        }
        
        func updateDestinationPOIColor(mapView: MapView, routeColor: String, useSecondary: Bool = false) {
            let poiImage = getPOIImage(useSecondary: useSecondary, routeColor: routeColor, isStart: false)
            try? mapView.mapboxMap.addImage(poiImage, id: "main-route-destination-icon")
        }
        
        func setupAllPickupMarkers(mapView: MapView, coordinates: [CLLocationCoordinate2D], routeColor: String = "#222222") {
            let basePOIImage = UIImage(named: "poi-pickup-dark") ?? UIImage()
            let coloredPOIImage = createColoredPOIImage(originalImage: basePOIImage, backgroundColor: UIColor(hex: routeColor) ?? Colors.primaryUIColor) ?? basePOIImage
            try? mapView.mapboxMap.addImage(coloredPOIImage, id: "all-pickup-markers-icon")
            
            var source = GeoJSONSource(id: allPickupMarkersSourceId)
            source.data = .geometry(.multiPoint(MultiPoint(coordinates)))
            try? mapView.mapboxMap.addSource(source)
            
            var layer = SymbolLayer(id: allPickupMarkersLayerId, source: allPickupMarkersSourceId)
            layer.iconImage = .constant(.name("all-pickup-markers-icon"))
            layer.iconSize = .constant(1.1)
            layer.iconAnchor = .constant(.bottom)
            layer.iconAllowOverlap = .constant(true)
            try? mapView.mapboxMap.addLayer(layer)
        }
        
        func updateAllPickupMarkers(mapView: MapView, coordinates: [CLLocationCoordinate2D], routeColor: String = "#222222") {
            if !mapView.mapboxMap.sourceExists(withId: allPickupMarkersSourceId) {
                setupAllPickupMarkers(mapView: mapView, coordinates: coordinates, routeColor: routeColor)
            }
            mapView.mapboxMap.updateGeoJSONSource(withId: allPickupMarkersSourceId, geoJSON: .geometry(.multiPoint(MultiPoint(coordinates))))
        }
        
        func updateAllPickupMarkersColor(mapView: MapView, routeColor: String) {
            let basePOIImage = UIImage(named: "poi-pickup-dark") ?? UIImage()
            let coloredPOIImage = createColoredPOIImage(originalImage: basePOIImage, backgroundColor: UIColor(hex: routeColor) ?? Colors.primaryUIColor) ?? basePOIImage
            try? mapView.mapboxMap.addImage(coloredPOIImage, id: "all-pickup-markers-icon")
        }
        
        func setupRouteTypePOIs(mapView: MapView, sourceId: String, layerId: String, imageId: String, imageName: String) {
            if !mapView.mapboxMap.imageExists(withId: imageId) {
                if let poiImage = UIImage(named: imageName) {
                    try? mapView.mapboxMap.addImage(poiImage, id: imageId)
                }
            }
            
            if !mapView.mapboxMap.sourceExists(withId: sourceId) {
                var source = GeoJSONSource(id: sourceId)
                source.data = .geometry(.multiPoint(MultiPoint([])))
                try? mapView.mapboxMap.addSource(source)
            }
            
            if !mapView.mapboxMap.layerExists(withId: layerId) {
                var layer = SymbolLayer(id: layerId, source: sourceId)
                layer.iconImage = .constant(.name(imageId))
                layer.iconSize = .constant(1.1)
                layer.iconAnchor = .constant(.bottom)
                layer.iconAllowOverlap = .constant(true)
                try? mapView.mapboxMap.addLayer(layer)
            }
        }
        
        func updatePreviewRoutesPOIs(mapView: MapView, routes: [[CLLocationCoordinate2D]]) {
            if !mapView.mapboxMap.sourceExists(withId: previewRoutesPOISourceId) {
                setupRouteTypePOIs(mapView: mapView, sourceId: previewRoutesPOISourceId, layerId: previewRoutesPOILayerId, imageId: "poi-start-tertiary-icon", imageName: "poi-start-tertiary")
            }
            let starts = routes.compactMap { $0.first }
            mapView.mapboxMap.updateGeoJSONSource(withId: previewRoutesPOISourceId, geoJSON: .geometry(.multiPoint(MultiPoint(starts))))
        }
        
        func updateBookmarkedRoutesPOIs(mapView: MapView, routes: [[CLLocationCoordinate2D]]) {
            if !mapView.mapboxMap.sourceExists(withId: bookmarkedRoutesPOISourceId) {
                setupRouteTypePOIs(mapView: mapView, sourceId: bookmarkedRoutesPOISourceId, layerId: bookmarkedRoutesPOILayerId, imageId: "poi-start-primary-icon", imageName: "poi-start-primary")
            }
            let starts = routes.compactMap { $0.first }
            mapView.mapboxMap.updateGeoJSONSource(withId: bookmarkedRoutesPOISourceId, geoJSON: .geometry(.multiPoint(MultiPoint(starts))))
        }
        
        func updateSelectedRoutesPOIs(mapView: MapView, routes: [[CLLocationCoordinate2D]]) {
            if !mapView.mapboxMap.sourceExists(withId: selectedRoutesPOISourceId) {
                setupRouteTypePOIs(mapView: mapView, sourceId: selectedRoutesPOISourceId, layerId: selectedRoutesPOILayerId, imageId: "poi-start-primary-icon", imageName: "poi-start-primary")
            }
            let starts = routes.compactMap { $0.first }
            mapView.mapboxMap.updateGeoJSONSource(withId: selectedRoutesPOISourceId, geoJSON: .geometry(.multiPoint(MultiPoint(starts))))
        }
        
        private func getPOIImage(useSecondary: Bool, routeColor: String, isStart: Bool) -> UIImage {
            if useSecondary {
                return UIImage(named: isStart ? "poi-start-secondary" : "poi-destination-secondary") ?? UIImage()
            } else {
                let baseName = isStart ? "poi-pickup-dark" : "poi-destination-dark"
                let baseImage = UIImage(named: baseName) ?? UIImage()
                return createColoredPOIImage(originalImage: baseImage, backgroundColor: UIColor(hex: routeColor) ?? Colors.primaryUIColor) ?? baseImage
            }
        }
        
        func createColoredPOIImage(originalImage: UIImage, backgroundColor: UIColor) -> UIImage? {
            let size = originalImage.size
            UIGraphicsBeginImageContextWithOptions(size, false, originalImage.scale)
            defer { UIGraphicsEndImageContext() }
            guard let context = UIGraphicsGetCurrentContext() else { return nil }
            context.setFillColor(backgroundColor.cgColor)
            context.fill(CGRect(origin: .zero, size: size))
            context.setBlendMode(.multiply)
            originalImage.draw(at: .zero)
            context.setBlendMode(.normal)
            originalImage.draw(at: .zero, blendMode: .sourceIn, alpha: 0.9)
            return UIGraphicsGetImageFromCurrentImageContext()
        }
        
        @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = mapView else { return }
            let point = gesture.location(in: mapView)
            
            var closest: (coord: CLLocationCoordinate2D?, dist: CGFloat) = (nil, .greatestFiniteMagnitude)
            if let start = lastStartCoordinate {
                let p = mapView.mapboxMap.point(for: start)
                let d = hypot(point.x - p.x, point.y - p.y)
                if d < closest.dist { closest = (start, d) }
            }
            for pickup in lastAllPickupCoordinates {
                let p = mapView.mapboxMap.point(for: pickup)
                let d = hypot(point.x - p.x, point.y - p.y)
                if d < closest.dist { closest = (pickup, d) }
            }
            
            if closest.dist < 50, let c = closest.coord {
                if c.latitude == lastStartCoordinate?.latitude && c.longitude == lastStartCoordinate?.longitude {
                    // ONLY animate bounce if it's NOT a secondary POI (user requested no animation for address input route)
                    if !lastUseSecondaryPOI {
                        animatePOIBounce(mapView: mapView)
                    } else {
                        print("ℹ️ Skipping animation for secondary POI")
                    }
                } else {
                    animateSinglePickupMarkerBounce(mapView: mapView, coordinate: c)
                    parent.onPickupMarkerTapped?(c)
                }
            }
        }
        
        func animatePOIBounce(mapView: MapView) {
            if isAnimatingPOI { return }
            isAnimatingPOI = true
            animationStartTime = CACurrentMediaTime()
            animationMapView = mapView
            let dl = CADisplayLink(target: self, selector: #selector(updatePOIBounceAnimation(_:)))
            dl.add(to: .main, forMode: .common)
            animationDisplayLink = dl
        }
        
        @objc func updatePOIBounceAnimation(_ dl: CADisplayLink) {
            let elapsed = CACurrentMediaTime() - animationStartTime
            let progress = min(elapsed / 0.2, 1.0)
            let scale = progress < 0.5 ? 1.1 + (0.1 * progress * 2) : 1.2 - (0.1 * (progress - 0.5) * 2)
            try? animationMapView?.mapboxMap.updateLayer(withId: poiLayerId, type: SymbolLayer.self) { $0.iconSize = .constant(scale) }
            if progress >= 1.0 {
                isAnimatingPOI = false
                dl.invalidate()
            }
        }
        
        func animateSinglePickupMarkerBounce(mapView: MapView, coordinate: CLLocationCoordinate2D) {
            if isAnimatingPickupMarker { return }
            isAnimatingPickupMarker = true
            animatedPickupMarkerCoordinate = coordinate
            animatedPickupMarkerStartTime = CACurrentMediaTime()
            animatedPickupMarkerMapView = mapView
            setupAnimatedPickupMarker(mapView: mapView, coordinate: coordinate, routeColor: lastRouteColor)
            let dl = CADisplayLink(target: self, selector: #selector(updateAnimatedPickupMarkerBounceAnimation(_:)))
            dl.add(to: .main, forMode: .common)
            animatedPickupMarkerDisplayLink = dl
        }
        
        func setupAnimatedPickupMarker(mapView: MapView, coordinate: CLLocationCoordinate2D, routeColor: String) {
            let base = UIImage(named: "poi-pickup-dark") ?? UIImage()
            let colored = createColoredPOIImage(originalImage: base, backgroundColor: UIColor(hex: routeColor) ?? Colors.primaryUIColor) ?? base
            try? mapView.mapboxMap.addImage(colored, id: "animated-pickup-icon")
            
            var source = GeoJSONSource(id: animatedPickupMarkerSourceId)
            source.data = .geometry(.point(Point(coordinate)))
            try? mapView.mapboxMap.addSource(source)
            
            var layer = SymbolLayer(id: animatedPickupMarkerLayerId, source: animatedPickupMarkerSourceId)
            layer.iconImage = .constant(.name("animated-pickup-icon"))
            layer.iconSize = .constant(1.1)
            layer.iconAnchor = .constant(.bottom)
            try? mapView.mapboxMap.addLayer(layer, layerPosition: .above(allPickupMarkersLayerId))
        }
        
        @objc func updateAnimatedPickupMarkerBounceAnimation(_ dl: CADisplayLink) {
            let elapsed = CACurrentMediaTime() - animatedPickupMarkerStartTime
            let progress = min(elapsed / 0.2, 1.0)
            let scale = progress < 0.5 ? 1.1 + (0.1 * progress * 2) : 1.2 - (0.1 * (progress - 0.5) * 2)
            try? animatedPickupMarkerMapView?.mapboxMap.updateLayer(withId: animatedPickupMarkerLayerId, type: SymbolLayer.self) { $0.iconSize = .constant(scale) }
            if progress >= 1.0 {
                isAnimatingPickupMarker = false
                dl.invalidate()
                try? animatedPickupMarkerMapView?.mapboxMap.removeLayer(withId: animatedPickupMarkerLayerId)
                try? animatedPickupMarkerMapView?.mapboxMap.removeSource(withId: animatedPickupMarkerSourceId)
            }
        }
        
        func springAnimationWithBounce(progress: Double, dampingRatio: Double, response: Double, duration: TimeInterval) -> Double {
            let t = progress * duration
            let omega = 2.0 * .pi / response
            let beta = dampingRatio * omega
            if dampingRatio < 1.0 {
                let omegaD = omega * sqrt(1.0 - dampingRatio * dampingRatio)
                return 1.0 - exp(-beta * t) * (cos(omegaD * t) + (beta / omegaD) * sin(omegaD * t))
            }
            return 1.0 - exp(-beta * t) * (1.0 + beta * t)
        }
    }
}
