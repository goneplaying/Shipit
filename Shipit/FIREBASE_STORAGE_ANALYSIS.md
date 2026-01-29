# Firebase Storage Analysis for Shipit App

## Current Configuration

### ✅ Already Configured:
- **Storage Bucket**: `shipit-user-accounts.firebasestorage.app`
- **Firebase Storage SDK**: Added to project dependencies
- **Project ID**: `shipit-user-accounts`
- **Location**: Configured in Firebase Console

### 📦 Package Status:
- FirebaseStorage package is included in `project.pbxproj`
- Ready to use - just need to import and implement

---

## Firebase Storage Structure

### 1. **Bucket Organization**

Firebase Storage uses a hierarchical file system structure. Recommended structure for Shipit:

```
shipit-user-accounts.firebasestorage.app/
├── users/
│   └── {userId}/
│       ├── profile/
│       │   ├── avatar.jpg
│       │   ├── documents/
│       │   │   ├── id_front.jpg
│       │   │   ├── id_back.jpg
│       │   │   └── license.pdf
│       │   └── company/
│       │       ├── logo.png
│       │       └── registration_certificate.pdf
│       └── shipments/
│           └── {shipmentId}/
│               ├── photos/
│               │   ├── pickup_photo_1.jpg
│               │   ├── delivery_photo_1.jpg
│               │   └── damage_report_1.jpg
│               ├── documents/
│               │   ├── invoice.pdf
│               │   ├── receipt.pdf
│               │   └── customs_form.pdf
│               └── signatures/
│                   ├── pickup_signature.png
│                   └── delivery_signature.png
├── carriers/
│   └── {carrierId}/
│       ├── vehicles/
│       │   └── {vehicleId}/
│       │       ├── registration.jpg
│       │       ├── insurance.pdf
│       │       └── photos/
│       └── documents/
│           ├── license.pdf
│           └── certifications/
└── shippers/
    └── {shipperId}/
        ├── company_logo.png
        └── documents/
            └── business_license.pdf
```

### 2. **File Path Patterns**

**User Profile Images:**
- Path: `users/{userId}/profile/avatar.jpg`
- Max Size: 5MB
- Allowed Types: jpg, png, webp

**Shipment Photos:**
- Path: `users/{userId}/shipments/{shipmentId}/photos/{timestamp}_{index}.jpg`
- Max Size: 10MB per photo
- Allowed Types: jpg, png

**Documents:**
- Path: `users/{userId}/documents/{documentType}_{timestamp}.pdf`
- Max Size: 20MB
- Allowed Types: pdf, jpg, png

---

## Security Rules Structure

### Recommended Storage Rules:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    
    // Helper function to check if user is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Helper function to check if user owns the resource
    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }
    
    // User profile files
    match /users/{userId}/{allPaths=**} {
      // Users can only access their own files
      allow read, write: if isOwner(userId);
    }
    
    // Carrier-specific files
    match /carriers/{carrierId}/{allPaths=**} {
      allow read: if isAuthenticated();
      allow write: if isOwner(carrierId);
    }
    
    // Shipper-specific files
    match /shippers/{shipperId}/{allPaths=**} {
      allow read: if isAuthenticated();
      allow write: if isOwner(shipperId);
    }
    
    // Shipment files - accessible by both carrier and shipper
    match /shipments/{shipmentId}/{allPaths=**} {
      allow read: if isAuthenticated() && 
        (resource.metadata.carrierId == request.auth.uid || 
         resource.metadata.shipperId == request.auth.uid);
      allow write: if isAuthenticated() && 
        (request.resource.metadata.carrierId == request.auth.uid || 
         request.resource.metadata.shipperId == request.auth.uid);
    }
  }
}
```

---

## Use Cases for Shipit App

### 1. **User Profile Management**
- **Profile Avatar**: User profile pictures
- **Identity Documents**: ID cards, passports for verification
- **Company Documents**: Business licenses, registration certificates

### 2. **Shipment Management**
- **Pickup Photos**: Photos taken at pickup location
- **Delivery Photos**: Proof of delivery
- **Damage Reports**: Photos of damaged goods
- **Invoices & Receipts**: PDF documents
- **Signatures**: Digital signatures for pickup/delivery

### 3. **Carrier-Specific**
- **Vehicle Photos**: Truck/car images
- **Vehicle Documents**: Registration, insurance
- **Driver License**: License verification

### 4. **Shipper-Specific**
- **Company Logo**: Branding images
- **Product Images**: Items being shipped
- **Packaging Photos**: Before shipping

---

## Implementation Example

### StorageService.swift (Recommended Structure)

```swift
import Foundation
import FirebaseStorage
import FirebaseAuth
import UIKit

class StorageService: ObservableObject {
    static let shared = StorageService()
    private let storage = Storage.storage()
    
    // Upload user profile avatar
    func uploadProfileAvatar(userId: String, image: UIImage) async throws -> URL {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw StorageError.invalidImage
        }
        
        let ref = storage.reference()
            .child("users")
            .child(userId)
            .child("profile")
            .child("avatar.jpg")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.customMetadata = [
            "userId": userId,
            "uploadedAt": ISO8601DateFormatter().string(from: Date())
        ]
        
        _ = try await ref.putDataAsync(imageData, metadata: metadata)
        return try await ref.downloadURL()
    }
    
    // Upload shipment photo
    func uploadShipmentPhoto(
        userId: String,
        shipmentId: String,
        image: UIImage,
        photoType: String
    ) async throws -> URL {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw StorageError.invalidImage
        }
        
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileName = "\(photoType)_\(timestamp).jpg"
        
        let ref = storage.reference()
            .child("users")
            .child(userId)
            .child("shipments")
            .child(shipmentId)
            .child("photos")
            .child(fileName)
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.customMetadata = [
            "userId": userId,
            "shipmentId": shipmentId,
            "photoType": photoType,
            "uploadedAt": ISO8601DateFormatter().string(from: Date())
        ]
        
        _ = try await ref.putDataAsync(imageData, metadata: metadata)
        return try await ref.downloadURL()
    }
    
    // Download file URL
    func getDownloadURL(path: String) async throws -> URL {
        let ref = storage.reference().child(path)
        return try await ref.downloadURL()
    }
    
    // Delete file
    func deleteFile(path: String) async throws {
        let ref = storage.reference().child(path)
        try await ref.delete()
    }
    
    // List files in a directory
    func listFiles(path: String) async throws -> [StorageReference] {
        let ref = storage.reference().child(path)
        let result = try await ref.listAll()
        return result.items
    }
}

enum StorageError: Error {
    case invalidImage
    case uploadFailed
    case downloadFailed
    case unauthorized
}
```

---

## Storage Rules Best Practices

### 1. **File Size Limits**
- Profile images: 5MB max
- Shipment photos: 10MB max
- Documents: 20MB max

### 2. **File Type Validation**
- Images: jpg, png, webp only
- Documents: pdf only
- Enforce in both client and rules

### 3. **Metadata Usage**
- Store userId, shipmentId, timestamps
- Use for filtering and security
- Helps with organization

### 4. **Path Structure**
- Use userId in path for security
- Organize by feature (profile, shipments, etc.)
- Use timestamps for unique filenames

---

## Integration Points in Current App

### 1. **ProfilePage.swift**
- Add avatar upload functionality
- Display uploaded profile picture
- Upload identity documents

### 2. **ShipmentsPage.swift**
- Upload shipment photos
- Attach documents to shipments
- View shipment gallery

### 3. **CompleteProfileView.swift**
- Optional: Upload profile picture during setup
- Upload verification documents

### 4. **ExchangePage.swift / JobsPage.swift** (Carrier)
- Upload vehicle photos
- Upload driver license
- Upload vehicle documents

---

## Monitoring & Analytics

### Key Metrics to Track:
1. **Storage Usage**: Total bytes stored
2. **Upload Count**: Number of files uploaded
3. **Download Count**: Number of files downloaded
4. **Bandwidth**: Data transfer usage
5. **Error Rate**: Failed uploads/downloads

### Firebase Console:
- Navigate to Storage → Usage tab
- View real-time metrics
- Set up alerts for unusual activity

---

## Next Steps

1. ✅ FirebaseStorage SDK is already added
2. ⏳ Create StorageService.swift
3. ⏳ Configure Storage Security Rules in Firebase Console
4. ⏳ Implement file upload in ProfilePage
5. ⏳ Implement file upload in ShipmentsPage
6. ⏳ Add image picker functionality
7. ⏳ Test upload/download flows

---

## Security Considerations

1. **Always validate file types** on client and server
2. **Enforce file size limits** to prevent abuse
3. **Use user-specific paths** for isolation
4. **Implement proper authentication** checks
5. **Use metadata** for additional security context
6. **Regularly audit** storage rules
7. **Monitor usage** for unusual patterns
