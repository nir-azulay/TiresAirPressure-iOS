import Foundation

/// Represents a saved/paired Bluetooth Low Energy device
struct SavedDevice: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let address: String
    let dateAdded: Date
    var connectionPriority: Int

    init(name: String, address: String, connectionPriority: Int = 0) {
        self.id = UUID()
        self.name = name
        self.address = address
        self.dateAdded = Date()
        self.connectionPriority = connectionPriority
    }

    static func == (lhs: SavedDevice, rhs: SavedDevice) -> Bool {
        return lhs.address == rhs.address
    }

    // Custom coding keys to ensure proper serialization
    enum CodingKeys: String, CodingKey {
        case id, name, address, dateAdded, connectionPriority
    }
}

/// Extension to support UserDefaults storage
extension SavedDevice {
    static let userDefaultsKey = "SavedDevices"

    static func load() -> [SavedDevice] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let devices = try? JSONDecoder().decode([SavedDevice].self, from: data) else {
            return []
        }
        return devices
    }

    static func save(_ devices: [SavedDevice]) {
        guard let data = try? JSONEncoder().encode(devices) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }
}