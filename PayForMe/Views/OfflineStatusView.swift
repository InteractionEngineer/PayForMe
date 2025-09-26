import SwiftUI

struct OfflineStatusView: View {
    @ObservedObject var manager = ProjectManager.shared
    @State private var isRetrying = false
    
    var body: some View {
        if manager.isOffline || isRetrying || (!manager.localBillsToUpload.isEmpty || !manager.localMembersToUpload.isEmpty) {
            HStack {
                if isRetrying {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Syncing...")
                        .font(.caption)
                        .foregroundColor(.blue)
                } else if manager.isOffline {
                    Image(systemName: "wifi.slash")
                        .foregroundColor(.orange)
                    Text("Offline - showing cached data")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else if !manager.localBillsToUpload.isEmpty || !manager.localMembersToUpload.isEmpty || !manager.localBillsToDelete.isEmpty || !manager.localMembersToDelete.isEmpty {
                    Image(systemName: "icloud.and.arrow.up")
                        .foregroundColor(.blue)
                    Text("Changes pending upload")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                if let lastSync = manager.lastSyncDate, !isRetrying {
                    Text("Last sync: \(formatDate(lastSync))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if !isRetrying {
                    Button("Retry") {
                        withAnimation {
                            isRetrying = true
                        }
                        manager.retryConnection()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(isRetrying ? Color.blue.opacity(0.1) : Color.orange.opacity(0.1))
            .onReceive(manager.$isOffline) { offline in
                if !offline && isRetrying {
                    withAnimation {
                        isRetrying = false
                    }
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct OfflineStatusView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            OfflineStatusView()
            Spacer()
        }
    }
}
