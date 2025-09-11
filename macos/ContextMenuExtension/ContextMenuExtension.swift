import Cocoa
import FinderSync

class ContextMenuExtension: FIFinderSync {
    
    override init() {
        super.init()
        
        // Monitor the user's Desktop and Documents folders
        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let documentsURL = FileManager.default.urls(for: .documentsDirectory, in: .userDomainMask).first!
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        
        FIFinderSyncController.default().directoryURLs = [desktopURL, documentsURL, downloadsURL]
    }
    
    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        // Only show menu for context menu (not toolbar)
        guard menuKind == .contextualMenuForItems else { return nil }
        
        // Check if context menu integration is enabled
        guard isContextMenuEnabled() else { return nil }
        
        let menu = NSMenu()
        let menuItem = NSMenuItem(title: "Upload to EisenVault", action: #selector(uploadToEisenVault), keyEquivalent: "")
        menuItem.target = self
        menu.addItem(menuItem)
        
        return menu
    }
    
    @objc func uploadToEisenVault() {
        guard let selectedItems = FIFinderSyncController.default().selectedItemURLs(),
              !selectedItems.isEmpty else { return }
        
        // Process selected files and folders
        var filePaths: [String] = []
        
        for url in selectedItems {
            if url.hasDirectoryPath {
                // Recursively collect files from folder
                filePaths.append(contentsOf: collectFilesFromFolder(url))
            } else {
                // Add single file
                filePaths.append(url.path)
            }
        }
        
        // Escape special characters in file paths
        let escapedPaths = filePaths.map { escapeFileName($0) }
        
        // Launch EisenVault app with file paths
        launchEisenVaultWithFiles(escapedPaths)
    }
    
    private func collectFilesFromFolder(_ folderURL: URL) -> [String] {
        var files: [String] = []
        
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(at: folderURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
        
        while let fileURL = enumerator?.nextObject() as? URL {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                if resourceValues.isRegularFile == true {
                    files.append(fileURL.path)
                }
            } catch {
                print("Error checking file: \(error)")
            }
        }
        
        return files
    }
    
    private func escapeFileName(_ filePath: String) -> String {
        let fileName = (filePath as NSString).lastPathComponent
        let fileExtension = (fileName as NSString).pathExtension
        let nameWithoutExtension = (fileName as NSString).deletingPathExtension
        
        // Replace special characters with underscore
        let invalidCharacters = CharacterSet(charactersIn: "<>:\"|?*")
        let escapedName = nameWithoutExtension.components(separatedBy: invalidCharacters).joined(separator: "_")
        
        if !fileExtension.isEmpty {
            return "\(escapedName).\(fileExtension)"
        } else {
            return escapedName
        }
    }
    
    private func launchEisenVaultWithFiles(_ filePaths: [String]) {
        // Create URL scheme with file paths
        var urlString = "eisenvault://upload"
        
        if !filePaths.isEmpty {
            let encodedPaths = filePaths.map { $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? $0 }
            urlString += "?files=" + encodedPaths.joined(separator: ",")
        }
        
        guard let url = URL(string: urlString) else {
            print("Failed to create URL: \(urlString)")
            return
        }
        
        // Launch the app
        NSWorkspace.shared.open(url)
    }
    
    private func isContextMenuEnabled() -> Bool {
        // Check UserDefaults for context menu setting
        let userDefaults = UserDefaults.standard
        return userDefaults.bool(forKey: "EisenVaultContextMenuEnabled")
    }
}
