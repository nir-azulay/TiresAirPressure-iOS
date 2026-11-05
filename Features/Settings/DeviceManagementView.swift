import SwiftUI

struct DeviceManagementView: View {
    @EnvironmentObject var bleManager: BLEManager
    @Environment(\.dismiss) private var dismiss
    @State private var savedDevices: [SavedDevice] = []
    @State private var isDeleting = false
    @State private var showingDeleteAlert = false
    @State private var deviceToDelete: SavedDevice?

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                if savedDevices.isEmpty {
                    EmptyDevicesView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
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
                        .padding(16)
                    }
                }
            }
        }
        .navigationTitle(L("manage_paired_devices", comment: "Manage Paired Devices"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppColors.navBarBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
        .onAppear {
            loadSavedDevices()
        }
        .alert(L("delete_device", comment: "Delete Device"),
               isPresented: $showingDeleteAlert,
               presenting: deviceToDelete) { device in
            Button(L("cancel", comment: "Cancel"), role: .cancel) {
                deviceToDelete = nil
            }
            Button(L("delete", comment: "Delete"), role: .destructive) {
                deleteDevice(device)
            }
        } message: { device in
            Text(String(format: L("delete_device_confirmation", comment: "Delete device confirmation"), device.name))
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

            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 56))
                .foregroundColor(AppColors.primary.opacity(0.8))

            Text(L("no_paired_devices", comment: "No Paired Devices"))
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            Text(L("no_paired_devices_description", comment: "No paired devices description"))
                .font(.system(size: 15))
                .foregroundColor(AppColors.textSecondary)
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
            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(device.address)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 12) {
                Button(action: onMoveUp) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(canMoveUp ? AppColors.primary : Color.white.opacity(0.2))
                }
                .disabled(!canMoveUp || isDeleting)

                Button(action: onMoveDown) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(canMoveDown ? AppColors.primary : Color.white.opacity(0.2))
                }
                .disabled(!canMoveDown || isDeleting)

                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColors.stopRed)
                }
                .disabled(isDeleting)
            }
        }
        .padding(14)
        .background(AppColors.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

// MARK: - Supporting Types

enum MoveDirection {
    case up, down
}

#if DEBUG
struct DeviceManagementView_Previews: PreviewProvider {
    static var previews: some View {
        DeviceManagementView()
            .environmentObject(BLEManager())
    }
}
#endif
