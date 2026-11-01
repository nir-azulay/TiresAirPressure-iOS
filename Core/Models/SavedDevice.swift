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
        id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        let rawName = (try? container.decode(String.self, forKey: .name))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        name = rawName.isEmpty ? "esp32-AirUpDownController" : rawName
        address = (try? container.decode(String.self, forKey: .address)) ?? ""
        dateAdded = (try? container.decode(Date.self, forKey: .dateAdded)) ?? Date()
        connectionPriority = max(0, (try? container.decode(Int.self, forKey: .connectionPriority)) ?? 0)
        let rawCode = (try? container.decodeIfPresent(String.self, forKey: .accessCode)) ?? ""
        accessCode = String(rawCode.prefix(32))
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
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return []
        }
        guard let decoded = try? JSONDecoder().decode([SavedDevice].self, from: data) else {
            // Corrupted data in UserDefaults — reset to clean empty array
            save([])
            return []
        }

        var seenAddresses = Set<String>()
        var valid: [SavedDevice] = []
        var needsRepair = false

        for var dev in decoded.sorted(by: { $0.connectionPriority < $1.connectionPriority }) {
            let trimmedAddr = dev.address.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedAddr.isEmpty, UUID(uuidString: trimmedAddr) != nil, !seenAddresses.contains(trimmedAddr) else {
                needsRepair = true
                continue
            }
            seenAddresses.insert(trimmedAddr)
            if dev.accessCode.count > 32 {
                dev.accessCode = String(dev.accessCode.prefix(32))
                needsRepair = true
            }
            if dev.connectionPriority != valid.count {
                dev.connectionPriority = valid.count
                needsRepair = true
            }
            valid.append(dev)
            if valid.count >= 2 {
                if decoded.count > 2 { needsRepair = true }
                break
            }
        }

        if needsRepair {
            save(valid)
        }
        return valid
    }

    static func save(_ devices: [SavedDevice]) {
        guard let data = try? JSONEncoder().encode(devices) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }
}