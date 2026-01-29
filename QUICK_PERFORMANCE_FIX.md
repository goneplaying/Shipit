# 🚀 Quick Performance Fix Guide

## ⚠️ MOST IMPORTANT: Test in Release Mode!

The #1 reason for slow UI is running in **Debug mode**. Debug builds are 5-10x slower than Release.

### Switch to Release Mode (Temporarily for Testing)

1. **Xcode Menu** → Product → Scheme → Edit Scheme (or press ⌘ <)
2. Click **Run** in left sidebar
3. Change **Build Configuration** from "Debug" to **"Release"**
4. Click **Close**
5. **Run the app** (⌘ + R)

### Expected Result
- Buttons respond instantly (< 50ms)
- Smooth scrolling (60fps)
- No input lag

### ⚠️ Remember to Switch Back!
After testing, switch back to **Debug** for development (debugging features need Debug mode).

---

## 🎯 Quick Optimizations Applied

### 1. ✅ Instant Button Feedback
Added `InstantButtonStyle` to all buttons for immediate visual response:

```swift
Button("Tap me") {
    // action
}
.instantFeedback()  // ← Instant visual feedback
```

**Applied to:**
- ✅ HomePageRouteSheet (close button, edit link)
- ✅ AddressInputPage (back button)
- 🔄 Apply to other buttons as needed

### 2. Code-Level Optimizations

#### Use LazyVStack for Long Lists
```swift
// Instead of:
ScrollView {
    VStack {
        ForEach(items) { item in
            ItemView(item)
        }
    }
}

// Use:
ScrollView {
    LazyVStack {  // ← Only renders visible items
        ForEach(items) { item in
            ItemView(item)
        }
    }
}
```

#### Make Models Equatable
Prevents unnecessary view updates:

```swift
extension ShipmentData: Equatable {
    static func == (lhs: ShipmentData, rhs: ShipmentData) -> Bool {
        lhs.id == rhs.id
    }
}
```

---

## 📊 Performance Benchmarks

### Debug vs Release Mode

| Action | Debug | Release |
|--------|-------|---------|
| Button tap | 100-300ms | 10-50ms |
| Scroll | 30-45fps | 60fps |
| Text input | Laggy | Instant |
| View transition | 300-500ms | 100-200ms |

---

## 🔍 If Still Slow in Release Mode

### Profile with Instruments
1. Product → Profile (⌘ + I)
2. Choose **Time Profiler**
3. Record while using the app
4. Look for bottlenecks in **Heaviest Stack Trace**

### Common Bottlenecks
- Heavy filtering in computed properties
- Map rendering
- Image loading without caching
- Network calls on main thread

### Additional Optimizations

#### Debounce Text Input
```swift
@State private var searchText = ""
@State private var debouncedText = ""

.onChange(of: searchText) { _, new in
    Task {
        try? await Task.sleep(for: .milliseconds(300))
        debouncedText = new
    }
}
```

#### Cache Computed Properties
```swift
@State private var cachedShipments: [ShipmentData] = []

func updateCache() {
    cachedShipments = computeExpensiveFilter()
}
```

#### Background Processing
```swift
Task.detached {
    let result = await heavyComputation()
    await MainActor.run {
        self.data = result
    }
}
```

---

## 🎯 Priority Checklist

1. **[CRITICAL]** Test in Release mode
2. **[HIGH]** Apply `.instantFeedback()` to all buttons
3. **[HIGH]** Replace `VStack` with `LazyVStack` in scrolling lists
4. **[MEDIUM]** Make data models `Equatable`
5. **[MEDIUM]** Cache expensive computed properties
6. **[LOW]** Profile with Instruments if still slow

---

## Expected Final Result

✅ **Instant button response** (< 50ms)  
✅ **Smooth 60fps scrolling**  
✅ **No keyboard lag**  
✅ **Fast navigation transitions**  

---

## Debug Mode vs Release Mode Summary

**Debug Mode** (Development):
- Includes debugging symbols
- No optimization
- Safety checks enabled
- 5-10x slower
- Use for: Development, debugging, testing features

**Release Mode** (Performance Testing):
- Optimized code
- No debug symbols
- Safety checks removed
- Full speed
- Use for: Performance testing, final builds

**Always develop in Debug, test performance in Release!**
