import SwiftUI

struct DeviceManagementView: View {
    @EnvironmentObject var bleManager: BLEManager
    @Environment(\.dismiss) private var dismiss
    @State private var savedDevices: [SavedDevice] = []
    @State private var isDeleting = false
    @State private var showingDeleteAlert = false
    @State private var deviceToDelete: SavedDevice?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if savedDevices.isEmpty {
                    EmptyDevicesView()
                } else {
                    List {
                        ForEach(Array(savedDevices.enumerated()), id: \.element.id) { index, device in
                            DeviceItemView(
                                device: device,
                                canMoveUp: index > 0,
                                canMoveDown: index < savedDevices.count - 1,
                                isDeleting: isDeleting,
                                onDelete: { showDeleteAlert(for: device) },
                                onMoveUp: { moveDevice(device, direction: .up) },
                                onMoveDown: { moveDevice(device, direction: .down) }
                            )
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle(NSLocalizedString("manage_paired_devices", comment: "Manage Paired Devices"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("back", comment: "Back")) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadSavedDevices()
            }
            .alert(NSLocalizedString("delete_device", comment: "Delete Device"),
                   isPresented: $showingDeleteAlert,
                   presenting: deviceToDelete) { device in
                Button(NSLocalizedString("cancel", comment: "Cancel"), role: .cancel) {
                    deviceToDelete = nil
                }
                Button(NSLocalizedString("delete", comment: "Delete"), role: .destructive) {
                    deleteDevice(device)
                }
            } message: { device in
                Text(String(format: NSLocalizedString("delete_device_confirmation", comment: "Delete device confirmation"), device.name))
            }
        }
    }

    private func loadSavedDevices() {
        savedDevices = bleManager.getSavedDevices()
    }

    private func showDeleteAlert(for device: SavedDevice) {
        deviceToDelete = device
        showingDeleteAlert = true
    }

    private func deleteDevice(_ device: SavedDevice) {
        isDeleting = true
        bleManager.deleteDevice(device.address)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            loadSavedDevices()
            isDeleting = false
            deviceToDelete = nil
        }
    }

    private func moveDevice(_ device: SavedDevice, direction: MoveDirection) {
        guard let currentIndex = savedDevices.firstIndex(where: { $0.id == device.id }) else { return }

        let newIndex: Int
        switch direction {
        case .up:
            newIndex = max(0, currentIndex - 1)
        case .down:
            newIndex = min(savedDevices.count - 1, currentIndex + 1)
        }

        if newIndex != currentIndex {
            savedDevices.move(fromOffsets: IndexSet(integer: currentIndex), toOffset: newIndex > currentIndex ? newIndex + 1 : newIndex)

            // Update the order in BLE manager
            let newOrder = savedDevices.map { $0.address }
            bleManager.reorderDevices(newOrder)
        }
    }
}

// MARK: - Supporting Views

struct EmptyDevicesView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "bluetooth.slash")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text(NSLocalizedString("no_paired_devices", comment: "No Paired Devices"))
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.primary)

            Text(NSLocalizedString("no_paired_devices_description", comment: "No paired devices description"))
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct DeviceItemView: View {
    let device: SavedDevice
    let canMoveUp: Bool
    let canMoveDown: Bool
    let isDeleting: Bool
    let onDelete: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Device Info
            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(device.address)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Action Buttons
            HStack(spacing: 8) {
                // Move Up Button
                Button(action: onMoveUp) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(canMoveUp ? .blue : .gray)
                }
                .disabled(!canMoveUp || isDeleting)

                // Move Down Button
                Button(action: onMoveDown) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(canMoveDown ? .blue : .gray)
                }
                .disabled(!canMoveDown || isDeleting)

                // Delete Button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.red)
                }
                .disabled(isDeleting)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

// MARK: - Supporting Types

enum MoveDirection {
    case up, down
}

// MARK: - Preview
#if DEBUG
struct DeviceManagementView_Previews: PreviewProvider {
    static var previews: some View {
        DeviceManagementView()
            .environmentObject(BLEManager())
    }
}
#endif