import Foundation

/// Represents a saved/paired Bluetooth Low Energy device
struct SavedDevice: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let address: String
    let dateAdded: Date
    var connectionPriority: Int
    var accessCode: String

    init(name: String, address: String, connectionPriority: Int = 0, accessCode: String = "") {
        self.id = UUID()
        self.name = name
        self.address = address
        self.dateAdded = Date()
        self.connectionPriority = connectionPriority
        self.accessCode = accessCode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        address = try container.decode(String.self, forKey: .address)
        dateAdded = try container.decode(Date.self, forKey: .dateAdded)
        connectionPriority = try container.decode(Int.self, forKey: .connectionPriority)
        accessCode = try container.decodeIfPresent(String.self, forKey: .accessCode) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(address, forKey: .address)
        try container.encode(dateAdded, forKey: .dateAdded)
        try container.encode(connectionPriority, forKey: .connectionPriority)
        try container.encode(accessCode, forKey: .accessCode)
    }

    static func == (lhs: SavedDevice, rhs: SavedDevice) -> Bool {
        return lhs.address == rhs.address
    }

    // Custom coding keys to ensure proper serialization
    enum CodingKeys: String, CodingKey {
        case id, name, address, dateAdded, connectionPriority, accessCode
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