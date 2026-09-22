import Foundation

/// Optional guide-only checkpoints, independent of tsk008's conversation database.
/// The caller must obtain opt-in before save; opening a temporary guide never writes.
actor WalkthroughStore {
    enum StoreError: Error { case consentRequired, invalidFile, tooManyGuides, staleWrite }
    let directory: URL
    private let files = FileManager.default
    private var deletedIDs: Set<UUID> = []

    init(directory: URL) { self.directory = directory.standardizedFileURL.resolvingSymlinksInPath() }

    static func applicationDirectory() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Cursy/Guides", isDirectory: true)
    }

    func save(_ checkpoint: WalkthroughSession.Checkpoint, consent: Bool) throws {
        guard consent else { throw StoreError.consentRequired }
        guard !deletedIDs.contains(checkpoint.id) else { throw StoreError.staleWrite }
        _ = try WalkthroughSession(checkpoint: checkpoint)
        let data = try JSONEncoder().encode(checkpoint)
        guard data.count <= 1_000_000 else { throw StoreError.invalidFile }
        if !files.fileExists(atPath: directory.path) {
            try files.createDirectory(at: directory, withIntermediateDirectories: true,
                                      attributes: [.posixPermissions: 0o700])
        }
        let url = file(for: checkpoint.id)
        let existing = try guideFiles()
        guard existing.contains(url) || existing.count < 20 else { throw StoreError.tooManyGuides }
        // Fail closed on a future/corrupt prior file, rather than silently replacing it.
        if files.fileExists(atPath: url.path) {
            let previous = try load(url)
            guard previous.revision <= checkpoint.revision,
                  previous.goal == checkpoint.goal,
                  (previous.verificationUsage ?? [:]).allSatisfy({
                      (checkpoint.verificationUsage?[$0.key] ?? 0) >= $0.value
                  }) else {
                throw StoreError.staleWrite
            }
        }
        try data.write(to: url, options: .atomic)
        try files.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    func loadAll() throws -> [WalkthroughSession.Checkpoint] {
        try guideFiles().map { try load($0) }
    }

    func delete(_ id: UUID) throws {
        deletedIDs.insert(id)
        let url = file(for: id)
        if files.fileExists(atPath: url.path) { try files.removeItem(at: url) }
    }

    private func file(for id: UUID) -> URL {
        directory.appendingPathComponent(id.uuidString).appendingPathExtension("json")
    }

    private func guideFiles() throws -> [URL] {
        guard files.fileExists(atPath: directory.path) else { return [] }
        let urls = try files.contentsOfDirectory(at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey], options: [.skipsHiddenFiles])
            .filter { $0.pathExtension == "json" }
        guard urls.count <= 20 else { throw StoreError.tooManyGuides }
        return urls
    }

    private func load(_ url: URL) throws -> WalkthroughSession.Checkpoint {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              (values.fileSize ?? Int.max) <= 1_000_000,
              UUID(uuidString: url.deletingPathExtension().lastPathComponent) != nil else { throw StoreError.invalidFile }
        let data = try Data(contentsOf: url)
        let checkpoint = try JSONDecoder().decode(WalkthroughSession.Checkpoint.self, from: data)
        guard file(for: checkpoint.id).standardizedFileURL.path == url.standardizedFileURL.path else { throw StoreError.invalidFile }
        _ = try WalkthroughSession(checkpoint: checkpoint)
        return checkpoint
    }
}
