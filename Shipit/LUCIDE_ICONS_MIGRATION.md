# Lucide Icons Migration

All icons in the project have been migrated from SF Symbols to Lucide icons.

## Current Status

✅ All `Image(systemName:)` and `Label(systemImage:)` usages have been replaced with `LucideIcon` views
✅ `IconHelper` has been updated with Lucide icon name mappings
✅ `LucideIcon` SwiftUI component has been created

## Implementation

The project now uses a `LucideIcon` SwiftUI view component that:
- Accepts Lucide icon names (e.g., "home", "user", "settings")
- Provides a fallback to SF Symbols until the Lucide package is added
- Supports customizable size and color

## Adding the Lucide Icons Package

To use actual Lucide icons (instead of SF Symbol fallbacks), add the package:

1. Open Xcode
2. Go to **File** > **Add Packages...**
3. Enter the repository URL: `https://github.com/JakubMazur/lucide-icons-swift`
4. Select the version and add to your project
5. Update `LucideIcon.swift` to use the package's API:

```swift
import LucideIcons

extension UIImage {
    convenience init?(lucideId: String) {
        // Use the package's implementation
        if let image = UIImage(lucideId: lucideId) {
            self.init(cgImage: image.cgImage!)
        } else {
            return nil
        }
    }
}
```

## Icon Mappings

SF Symbols have been mapped to Lucide icons:
- `house.fill` → `home`
- `person` → `user`
- `gearshape` → `settings`
- `questionmark.circle` → `help-circle`
- `info.circle` → `info`
- `arrow.right.square` → `log-out`
- `chevron.down` → `chevron-down`
- `chevron.left` → `chevron-left`
- `chevron.right` → `chevron-right`
- `map.fill` → `map`
- `arrow.triangle.2.circlepath` → `refresh-cw`
- `briefcase.fill` → `briefcase`
- `shippingbox.fill` → `package`
- `arrow.up.arrow.down` → `arrow-up-down`
- `slider.horizontal.3` → `sliders-horizontal`
- `bookmark.fill` → `bookmark`
- `location.circle` → `map-pin`
- `checkmark` → `check`
- `plus` → `plus`
- `xmark` → `x`
- `eye` → `eye`
- `eye.slash` → `eye-off`
- `square` → `square`
- `checkmark.square.fill` → `check-square`

## Files Updated

- `IconHelper.swift` - Updated with Lucide icon names
- `LucideIcon.swift` - New SwiftUI component for Lucide icons
- `HomePage.swift` - All tab icons updated
- `ExchangePage.swift` - Toolbar icons updated
- `ProfilePage.swift` - Menu item icons updated
- `RequestCard.swift` - Card icons updated
- `RequestCardSlider.swift` - Bookmark icon updated
- `ShipmentsPage.swift` - Plus icon updated
- `CategoriesPage.swift` - Checkmark icon updated
- `ExchangeSortingPage.swift` - Checkmark icons updated
- `UserDetailsPage.swift` - Chevron icon updated
- `CompleteProfileView.swift` - Icons updated
- `RegistrationConfirmationPage.swift` - Close icon updated
- `TermsConditionsView.swift` - Close icon updated
- `RegisterPage.swift` - Eye and checkbox icons updated
- `LoginPage.swift` - Eye icon updated

## Usage

Use Lucide icons throughout the app:

```swift
// Simple icon
LucideIcon(IconHelper.home, size: 20)

// With custom color
LucideIcon(IconHelper.settings, size: 16, color: Colors.primary)

// In a Label
Label {
    Text("Settings")
} icon: {
    LucideIcon(IconHelper.settings, size: 16)
}
```
