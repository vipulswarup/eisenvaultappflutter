//
//  ShareViewController.swift
//  ShareExtension
//
//  Created by Vipul Swarup on 01/09/25.
//

import UIKit
import Social
import MobileCoreServices

class ShareViewController: UIViewController {
    
    // MARK: - UI Elements
    private let titleLabel = UILabel()
    private let uploadButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    private let progressView = UIProgressView()
    private let statusLabel = UILabel()
    private let folderButton = UIButton(type: .system)
    private let fileCountLabel = UILabel()
    
    // MARK: - Properties
    private var sharedItems: [NSExtensionItem] = []
    private var selectedFolder: String = "Default Folder"
    private var fileCount: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadSharedContent()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        
        // Title
        titleLabel.text = "Upload to EisenVault"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        // File Count Label
        fileCountLabel.font = UIFont.systemFont(ofSize: 14)
        fileCountLabel.textAlignment = .center
        fileCountLabel.textColor = UIColor.secondaryLabel
        fileCountLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(fileCountLabel)
        
        // Folder Selection
        folderButton.setTitle("📁 \(selectedFolder)", for: .normal)
        folderButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        folderButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        folderButton.layer.cornerRadius = 8
        folderButton.translatesAutoresizingMaskIntoConstraints = false
        folderButton.addTarget(self, action: #selector(selectFolder), for: .touchUpInside)
        view.addSubview(folderButton)
        
        // Upload Button
        uploadButton.setTitle("Upload Files", for: .normal)
        uploadButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        uploadButton.backgroundColor = UIColor.systemBlue
        uploadButton.setTitleColor(.white, for: .normal)
        uploadButton.layer.cornerRadius = 8
        uploadButton.translatesAutoresizingMaskIntoConstraints = false
        uploadButton.addTarget(self, action: #selector(uploadFiles), for: .touchUpInside)
        view.addSubview(uploadButton)
        
        // Cancel Button
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.addTarget(self, action: #selector(cancelUpload), for: .touchUpInside)
        view.addSubview(cancelButton)
        
        // Progress View
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.isHidden = true
        view.addSubview(progressView)
        
        // Status Label
        statusLabel.text = "Ready to upload"
        statusLabel.font = UIFont.systemFont(ofSize: 14)
        statusLabel.textAlignment = .center
        statusLabel.textColor = UIColor.secondaryLabel
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Title
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // File Count
            fileCountLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 5),
            fileCountLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            fileCountLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Folder Button
            folderButton.topAnchor.constraint(equalTo: fileCountLabel.bottomAnchor, constant: 20),
            folderButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            folderButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            folderButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Upload Button
            uploadButton.topAnchor.constraint(equalTo: folderButton.bottomAnchor, constant: 20),
            uploadButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            uploadButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            uploadButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Cancel Button
            cancelButton.topAnchor.constraint(equalTo: uploadButton.bottomAnchor, constant: 10),
            cancelButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cancelButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Progress View
            progressView.topAnchor.constraint(equalTo: cancelButton.bottomAnchor, constant: 20),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Status Label
            statusLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 10),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            statusLabel.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }
    
    // MARK: - Content Loading
    private func loadSharedContent() {
        guard let extensionContext = self.extensionContext else {
            print("🔍 DEBUG: No extension context available")
            return
        }
        
        sharedItems = extensionContext.inputItems.compactMap { $0 as? NSExtensionItem }
        
        // Count total attachments
        fileCount = sharedItems.reduce(0) { count, item in
            return count + (item.attachments?.count ?? 0)
        }
        
        updateFileCountLabel()
        print("🔍 DEBUG: Loaded \(fileCount) files for upload")
    }
    
    private func updateFileCountLabel() {
        if fileCount == 0 {
            fileCountLabel.text = "No files to upload"
            uploadButton.isEnabled = false
            uploadButton.alpha = 0.5
        } else if fileCount == 1 {
            fileCountLabel.text = "1 file ready to upload"
        } else {
            fileCountLabel.text = "\(fileCount) files ready to upload"
        }
    }
    
    // MARK: - Actions
    @objc private func selectFolder() {
        let alert = UIAlertController(title: "Select Folder", message: "Choose where to upload your files", preferredStyle: .actionSheet)
        
        let folders = ["Default Folder", "Documents", "Images", "Videos", "Recent"]
        
        for folder in folders {
            alert.addAction(UIAlertAction(title: folder, style: .default) { [weak self] _ in
                self?.selectedFolder = folder
                self?.folderButton.setTitle("📁 \(folder)", for: .normal)
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // For iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = folderButton
            popover.sourceRect = folderButton.bounds
        }
        
        present(alert, animated: true)
    }
    
    @objc private func uploadFiles() {
        guard fileCount > 0 else { return }
        
        uploadButton.isEnabled = false
        uploadButton.alpha = 0.5
        progressView.isHidden = false
        progressView.progress = 0.0
        statusLabel.text = "Starting upload..."
        
        // Simulate upload progress
        simulateUpload()
    }
    
    @objc private func cancelUpload() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
    
    // MARK: - Upload Simulation
    private func simulateUpload() {
        var progress: Float = 0.0
        let totalSteps: Float = 100.0
        
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            progress += 1.0
            
            DispatchQueue.main.async {
                self?.progressView.progress = progress / totalSteps
                
                if progress < 30 {
                    self?.statusLabel.text = "Preparing files..."
                } else if progress < 70 {
                    self?.statusLabel.text = "Uploading to \(self?.selectedFolder ?? "folder")..."
                } else if progress < 95 {
                    self?.statusLabel.text = "Processing..."
                } else {
                    self?.statusLabel.text = "Upload complete!"
                }
            }
            
            if progress >= totalSteps {
                timer.invalidate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self?.completeUpload()
                }
            }
        }
    }
    
    private func completeUpload() {
        statusLabel.text = "✅ Upload successful!"
        statusLabel.textColor = UIColor.systemGreen
        
        // Save to App Groups for main app to process
        saveUploadDataToAppGroups()
        
        // Close the extension after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }
    
    // MARK: - App Groups Integration
    private func saveUploadDataToAppGroups() {
        guard let userDefaults = UserDefaults(suiteName: "group.com.eisenvault.eisenvaultappflutter") else {
            print("🔍 DEBUG: Failed to access App Groups UserDefaults")
            return
        }
        
        let uploadData: [String: Any] = [
            "folder": selectedFolder,
            "fileCount": fileCount,
            "timestamp": Date().timeIntervalSince1970,
            "status": "completed"
        ]
        
        userDefaults.set(uploadData, forKey: "UploadData")
        userDefaults.synchronize()
        
        print("🔍 DEBUG: Upload data saved to App Groups")
    }
}