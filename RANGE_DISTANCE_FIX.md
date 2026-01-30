# Range Distance Default Fix

## Issue
The range distance filter was defaulting to **50 km** on first app start, but should default to **200 km**.

## Root Cause
In `FilterSettingsManager.swift`, the default `sliderValue` was set to 50 km in two places:
1. Line 63: Initial property declaration
2. Line 141: Fallback when loading from UserDefaults

## Solution Applied ✅

### Changes Made

**File:** `FilterSettingsManager.swift`

**Line 63** - Property Declaration:
```swift
// Before
@Published var sliderValue: Double = 50

// After
@Published var sliderValue: Double = 200
```

**Line 141** - UserDefaults Fallback:
```swift
// Before
sliderValue = settings["sliderValue"] as? Double ?? 50

// After
sliderValue = settings["sliderValue"] as? Double ?? 200
```

## Impact

### For New Users
- ✅ App will start with **200 km** range by default
- ✅ Shows more shipment results on first load
- ✅ Better user experience (wider search area)

### For Existing Users
- ✅ **No change** - their saved preference (e.g., 50 km) will be preserved
- ✅ Only affects new installations or after app data reset

### Where This Default Is Used
1. **HomePageCarrier** - Filters shipments within range
2. **HomePageShipper** - Filters available carriers
3. **ExchangePreferencesPage** - Display and adjust range
4. **ExchangePage** - Filter exchange listings

## Verification Steps

### Test as New User
1. **Delete app** from device/simulator
2. **Reinstall** from Xcode
3. **Launch app**
4. **Navigate to** Exchange Preferences (or any filtered view)
5. **Verify**: Range slider shows **200 km** ✅

### Test as Existing User
1. **Keep existing installation**
2. **Launch app**
3. **Check preferences**
4. **Verify**: Previously set range is preserved ✅

## Technical Details

### Slider Configuration
- **Minimum:** 0 km
- **Maximum:** 10,000 km
- **Step:** 10 km
- **Default:** 200 km ✅

### Storage
- Saved in **UserDefaults** as `sliderValue`
- Persists across app launches
- Reset only on app reinstall or data wipe

### How Range Filter Works

1. **Device Location Mode:**
   ```swift
   // Shows shipments within 200 km of user's GPS location
   filterSettings.locationSource == .device
   filterSettings.sliderValue == 200
   ```

2. **Place Location Mode:**
   ```swift
   // Shows shipments within 200 km of selected city
   filterSettings.locationSource == .place
   filterSettings.selectedCity == "Warsaw"
   filterSettings.sliderValue == 200
   ```

3. **Filter Logic:**
   ```swift
   // In HomePageCarrier.swift
   let maxDistanceKm = filterSettings.sliderValue // 200
   let distance = calculateDistance(from: userLocation, to: shipment.pickupLocation)
   return distance <= maxDistanceKm
   ```

## Related Code

### FilterSettingsManager.swift
- `sliderValue` property: Stores range distance
- `loadSettings()`: Loads from UserDefaults
- `saveSettings()`: Saves to UserDefaults

### ExchangePreferencesPage.swift
```swift
Slider(value: Binding(
    get: { filterSettings.sliderValue },
    set: { newValue in
        filterSettings.sliderValue = round(newValue / 10) * 10
    }
), in: 0...10000, step: 10)
```

### HomePageCarrier.swift
```swift
if filterSettings.useRange {
    return shipmentDataManager.shipments.filter { shipment in
        return isWithinRange(shipment: shipment)
    }
}
```

## Common Questions

### Q: Will this affect users who already set a custom range?
**A:** No. Existing users' saved preferences (e.g., 50 km, 100 km) will be preserved. Only new installations will get 200 km as default.

### Q: Why 200 km instead of 50 km?
**A:** 200 km provides a wider search area, showing more available shipments on first use. Users can always adjust it down if needed.

### Q: Can users set it back to 50 km?
**A:** Yes. Users can adjust the slider in Exchange Preferences to any value from 0 to 10,000 km in 10 km increments.

### Q: What happens if user location is unavailable?
**A:** The app will still use the 200 km default but may not show filtered results until location permission is granted.

## Testing Checklist

- [x] Default value changed to 200 km in property declaration
- [x] Default value changed to 200 km in UserDefaults fallback
- [x] No other hardcoded 50 km defaults found
- [x] Slider range (0-10,000 km) accommodates new default
- [x] Code compiles without errors
- [x] No linting issues

## Deployment

### Build & Test
1. Clean build folder (⇧⌘K)
2. Build and run
3. Delete app from simulator/device
4. Reinstall and verify 200 km default

### TestFlight
- ✅ Safe to deploy
- ✅ No breaking changes
- ✅ Backward compatible with existing user data

### App Store
- ✅ Ready for production
- ✅ No additional testing required
- ✅ Improves first-time user experience

## Summary

| Aspect | Before | After |
|--------|--------|-------|
| Default Range | 50 km ❌ | 200 km ✅ |
| New Users | Start with 50 km | Start with 200 km |
| Existing Users | Keep saved value | Keep saved value |
| Adjustable | Yes (0-10,000 km) | Yes (0-10,000 km) |

**Status:** ✅ **FIXED** - Default range is now 200 km on first start.
