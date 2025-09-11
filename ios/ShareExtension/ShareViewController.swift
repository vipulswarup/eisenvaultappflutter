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
    private let fileCountLabel = UILabel()
    private let folderSelectionView = UIView()
    private let breadcrumbLabel = UILabel()
    private let folderTableView = UITableView()
    private let backButton = UIButton(type: .system)
    private let selectedDestinationView = UIView()
    private let selectedDestinationLabel = UILabel()
    private let changeDestinationButton = UIButton(type: .system)
    private let createFolderButton = UIButton(type: .system)
    private let scrollIndicatorView = UIView()
    private let scrollIndicatorLabel = UILabel()
    
    // MARK: - Properties
    private var sharedItems: [NSExtensionItem] = []
    private var selectedFolder: String = "Select destination..."
    private var selectedFolderId: String = ""
    private var fileCount: Int = 0
    private var availableFolders: [(id: String, name: String)] = []
    private var navigationStack: [(id: String, name: String)] = []
    private var currentFolderId: String? = nil
    private var sites: [(id: String, name: String)] = []
    private var folders: [(id: String, name: String)] = []
    private var selectedIndexPath: IndexPath? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("🔍 DEBUG: ShareViewController viewDidLoad called")
        setupUI()
        loadSharedContent()
        loadDMSSettings()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Update scroll indicator after layout changes
        updateScrollIndicator()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        print("🔍 DEBUG: Setting up Share Extension UI")
        view.backgroundColor = UIColor(red: 0.956, green: 0.918, blue: 0.824, alpha: 1.0) // paletteBackground
        
        // Title
        titleLabel.text = "Upload to EisenVault"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textAlignment = .center
        titleLabel.textColor = UIColor(red: 0.698, green: 0.290, blue: 0.231, alpha: 1.0) // paletteButton
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        // File Count Label
        fileCountLabel.font = UIFont.systemFont(ofSize: 14)
        fileCountLabel.textAlignment = .center
        fileCountLabel.textColor = UIColor(red: 0.133, green: 0.133, blue: 0.133, alpha: 1.0) // paletteTextDark
        fileCountLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(fileCountLabel)
        
        // Folder Selection View
        folderSelectionView.backgroundColor = UIColor.white
        folderSelectionView.layer.cornerRadius = 8
        folderSelectionView.layer.shadowColor = UIColor.black.cgColor
        folderSelectionView.layer.shadowOffset = CGSize(width: 0, height: 1)
        folderSelectionView.layer.shadowOpacity = 0.05
        folderSelectionView.layer.shadowRadius = 2
        folderSelectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(folderSelectionView)
        
        // Breadcrumb Label
        breadcrumbLabel.text = "Select destination..."
        breadcrumbLabel.font = UIFont.systemFont(ofSize: 16)
        breadcrumbLabel.textColor = UIColor(red: 0.133, green: 0.133, blue: 0.133, alpha: 1.0) // paletteTextDark
        breadcrumbLabel.translatesAutoresizingMaskIntoConstraints = false
        folderSelectionView.addSubview(breadcrumbLabel)
        
        // Back Button
        backButton.setTitle("← Back", for: .normal)
        backButton.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        backButton.setTitleColor(UIColor(red: 0.698, green: 0.290, blue: 0.231, alpha: 1.0), for: .normal) // paletteButton
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.addTarget(self, action: #selector(goBack), for: .touchUpInside)
        backButton.isHidden = true
        folderSelectionView.addSubview(backButton)
        
        // Folder Table View
        folderTableView.delegate = self
        folderTableView.dataSource = self
        folderTableView.backgroundColor = UIColor.clear
        folderTableView.separatorStyle = .none
        folderTableView.showsVerticalScrollIndicator = true
        folderTableView.indicatorStyle = .default
        folderTableView.translatesAutoresizingMaskIntoConstraints = false
        folderSelectionView.addSubview(folderTableView)
        
        // Selected Destination View
        selectedDestinationView.backgroundColor = UIColor(red: 0.456, green: 0.718, blue: 0.627, alpha: 0.1) // paletteAccent with 10% opacity
        selectedDestinationView.layer.cornerRadius = 8
        selectedDestinationView.layer.borderWidth = 1
        selectedDestinationView.layer.borderColor = UIColor(red: 0.456, green: 0.718, blue: 0.627, alpha: 1.0).cgColor // paletteAccent
        selectedDestinationView.translatesAutoresizingMaskIntoConstraints = false
        selectedDestinationView.isHidden = true
        view.addSubview(selectedDestinationView)
        
        // Selected Destination Label
        selectedDestinationLabel.text = "Selected: No destination"
        selectedDestinationLabel.font = UIFont.boldSystemFont(ofSize: 16)
        selectedDestinationLabel.textColor = UIColor(red: 0.133, green: 0.133, blue: 0.133, alpha: 1.0) // paletteTextDark
        selectedDestinationLabel.translatesAutoresizingMaskIntoConstraints = false
        selectedDestinationView.addSubview(selectedDestinationLabel)
        
        // Change Destination Button
        changeDestinationButton.setTitle("Change", for: .normal)
        changeDestinationButton.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        changeDestinationButton.setTitleColor(UIColor(red: 0.698, green: 0.290, blue: 0.231, alpha: 1.0), for: .normal) // paletteButton
        changeDestinationButton.translatesAutoresizingMaskIntoConstraints = false
        changeDestinationButton.addTarget(self, action: #selector(changeDestination), for: .touchUpInside)
        selectedDestinationView.addSubview(changeDestinationButton)
        
        // Setup create folder button
        createFolderButton.setTitle("+ Create Folder", for: .normal)
        createFolderButton.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        createFolderButton.setTitleColor(UIColor(red: 0.698, green: 0.290, blue: 0.231, alpha: 1.0), for: .normal) // paletteButton
        createFolderButton.backgroundColor = UIColor(red: 0.698, green: 0.290, blue: 0.231, alpha: 0.1) // paletteButton with 10% opacity
        createFolderButton.layer.cornerRadius = 6
        createFolderButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        createFolderButton.translatesAutoresizingMaskIntoConstraints = false
        createFolderButton.addTarget(self, action: #selector(createFolder), for: .touchUpInside)
        folderSelectionView.addSubview(createFolderButton)
        
        // Scroll Indicator View
        scrollIndicatorView.backgroundColor = UIColor(red: 0.956, green: 0.918, blue: 0.824, alpha: 0.9) // paletteBackground with 90% opacity
        scrollIndicatorView.layer.cornerRadius = 4
        scrollIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        scrollIndicatorView.isHidden = true
        folderSelectionView.addSubview(scrollIndicatorView)
        
        // Scroll Indicator Label
        scrollIndicatorLabel.text = "↓ Scroll for more folders"
        scrollIndicatorLabel.font = UIFont.systemFont(ofSize: 12)
        scrollIndicatorLabel.textColor = UIColor(red: 0.698, green: 0.290, blue: 0.231, alpha: 1.0) // paletteButton
        scrollIndicatorLabel.textAlignment = .center
        scrollIndicatorLabel.translatesAutoresizingMaskIntoConstraints = false
        scrollIndicatorView.addSubview(scrollIndicatorLabel)
        
        // Upload Button
        uploadButton.setTitle("Upload Files", for: .normal)
        uploadButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        uploadButton.backgroundColor = UIColor(red: 0.698, green: 0.290, blue: 0.231, alpha: 1.0) // paletteButton
        uploadButton.setTitleColor(.white, for: .normal)
        uploadButton.layer.cornerRadius = 8
        uploadButton.translatesAutoresizingMaskIntoConstraints = false
        uploadButton.addTarget(self, action: #selector(uploadFiles), for: .touchUpInside)
        view.addSubview(uploadButton)
        
        // Cancel Button
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        cancelButton.setTitleColor(UIColor(red: 0.133, green: 0.133, blue: 0.133, alpha: 1.0), for: .normal) // paletteTextDark
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.addTarget(self, action: #selector(cancelUpload), for: .touchUpInside)
        view.addSubview(cancelButton)
        
        // Progress View
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.isHidden = true
        progressView.progressTintColor = UIColor(red: 0.698, green: 0.290, blue: 0.231, alpha: 1.0) // paletteButton
        view.addSubview(progressView)
        
        // Status Label
        statusLabel.text = "Ready to upload"
        statusLabel.font = UIFont.systemFont(ofSize: 14)
        statusLabel.textAlignment = .center
        statusLabel.textColor = UIColor(red: 0.133, green: 0.133, blue: 0.133, alpha: 1.0) // paletteTextDark
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
            
            // Folder Selection View - Dynamic height based on available space
            folderSelectionView.topAnchor.constraint(equalTo: fileCountLabel.bottomAnchor, constant: 20),
            folderSelectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            folderSelectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            folderSelectionView.heightAnchor.constraint(greaterThanOrEqualToConstant: 280),
            folderSelectionView.heightAnchor.constraint(lessThanOrEqualToConstant: 450),
            
            // Selected Destination View
            selectedDestinationView.topAnchor.constraint(equalTo: folderSelectionView.bottomAnchor, constant: 15),
            selectedDestinationView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            selectedDestinationView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            selectedDestinationView.heightAnchor.constraint(equalToConstant: 50),
            
            // Breadcrumb Label
            breadcrumbLabel.topAnchor.constraint(equalTo: folderSelectionView.topAnchor, constant: 15),
            breadcrumbLabel.leadingAnchor.constraint(equalTo: folderSelectionView.leadingAnchor, constant: 15),
            breadcrumbLabel.trailingAnchor.constraint(equalTo: backButton.leadingAnchor, constant: -10),
            
            // Back Button
            backButton.topAnchor.constraint(equalTo: folderSelectionView.topAnchor, constant: 15),
            backButton.trailingAnchor.constraint(equalTo: folderSelectionView.trailingAnchor, constant: -15),
            backButton.heightAnchor.constraint(equalToConstant: 20),
            
            // Create Folder Button
            createFolderButton.topAnchor.constraint(equalTo: breadcrumbLabel.bottomAnchor, constant: 10),
            createFolderButton.trailingAnchor.constraint(equalTo: folderSelectionView.trailingAnchor, constant: -15),
            createFolderButton.heightAnchor.constraint(equalToConstant: 32),
            
            // Folder Table View
            folderTableView.topAnchor.constraint(equalTo: createFolderButton.bottomAnchor, constant: 8),
            folderTableView.leadingAnchor.constraint(equalTo: folderSelectionView.leadingAnchor, constant: 15),
            folderTableView.trailingAnchor.constraint(equalTo: folderSelectionView.trailingAnchor, constant: -15),
            folderTableView.bottomAnchor.constraint(equalTo: scrollIndicatorView.topAnchor, constant: -8),
            
            // Scroll Indicator View
            scrollIndicatorView.leadingAnchor.constraint(equalTo: folderSelectionView.leadingAnchor, constant: 15),
            scrollIndicatorView.trailingAnchor.constraint(equalTo: folderSelectionView.trailingAnchor, constant: -15),
            scrollIndicatorView.bottomAnchor.constraint(equalTo: folderSelectionView.bottomAnchor, constant: -15),
            scrollIndicatorView.heightAnchor.constraint(equalToConstant: 24),
            
            // Scroll Indicator Label
            scrollIndicatorLabel.centerXAnchor.constraint(equalTo: scrollIndicatorView.centerXAnchor),
            scrollIndicatorLabel.centerYAnchor.constraint(equalTo: scrollIndicatorView.centerYAnchor),
            
            // Selected Destination Label
            selectedDestinationLabel.centerYAnchor.constraint(equalTo: selectedDestinationView.centerYAnchor),
            selectedDestinationLabel.leadingAnchor.constraint(equalTo: selectedDestinationView.leadingAnchor, constant: 15),
            selectedDestinationLabel.trailingAnchor.constraint(equalTo: changeDestinationButton.leadingAnchor, constant: -10),
            
            // Change Destination Button
            changeDestinationButton.centerYAnchor.constraint(equalTo: selectedDestinationView.centerYAnchor),
            changeDestinationButton.trailingAnchor.constraint(equalTo: selectedDestinationView.trailingAnchor, constant: -15),
            changeDestinationButton.widthAnchor.constraint(equalToConstant: 60),
            
            // Upload Button
            uploadButton.topAnchor.constraint(equalTo: selectedDestinationView.bottomAnchor, constant: 20),
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
        print("🔍 DEBUG: Loading shared content")
        guard let extensionContext = self.extensionContext else {
            print("🔍 DEBUG: No extension context available")
            return
        }
        
        sharedItems = extensionContext.inputItems.compactMap { $0 as? NSExtensionItem }
        print("🔍 DEBUG: Found \(sharedItems.count) shared items")
        
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
        
        // Initially disable upload button until folder is selected
        if selectedFolderId.isEmpty {
            uploadButton.isEnabled = false
            uploadButton.alpha = 0.5
        }
    }
    
    // MARK: - Actions
    @objc private func goBack() {
        if navigationStack.count > 1 {
            navigationStack.removeLast()
            let previousLevel = navigationStack.last!
            currentFolderId = previousLevel.id
            breadcrumbLabel.text = previousLevel.name
            loadFoldersForCurrentLevel()
        } else {
            // Go back to sites/departments
            navigationStack.removeAll()
            currentFolderId = nil
            breadcrumbLabel.text = "Select destination..."
            loadSites()
        }
        
        backButton.isHidden = navigationStack.isEmpty
        folderTableView.reloadData()
        updateScrollIndicator()
    }
    
    @objc private func changeDestination() {
        // Reset selection and go back to folder browsing
        selectedFolderId = ""
        selectedFolder = "Select destination..."
        selectedIndexPath = nil
        selectedDestinationView.isHidden = true
        uploadButton.isEnabled = false
        uploadButton.alpha = 0.5
        statusLabel.text = "Ready to upload"
        statusLabel.textColor = UIColor(red: 0.133, green: 0.133, blue: 0.133, alpha: 1.0)
        
        // Go back to sites if we're deep in navigation
        if navigationStack.count > 1 {
            navigationStack.removeAll()
            currentFolderId = nil
            breadcrumbLabel.text = "Select destination..."
            loadSites()
        }
        
        folderTableView.reloadData()
        updateScrollIndicator()
    }
    
    @objc private func createFolder() {
        // Check if we have a current folder to create in
        guard let parentFolderId = currentFolderId else {
            showAlert(title: "Error", message: "Please navigate to a folder first to create a subfolder.")
            return
        }
        
        // Show input dialog for folder name
        let alert = UIAlertController(title: "Create Folder", message: "Enter folder name:", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "Folder name"
            textField.autocapitalizationType = .words
        }
        
        let createAction = UIAlertAction(title: "Create", style: .default) { [weak self] _ in
            guard let self = self,
                  let folderName = alert.textFields?.first?.text,
                  !folderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return
            }
            
            self.performCreateFolder(name: folderName.trimmingCharacters(in: .whitespacesAndNewlines), parentId: parentFolderId)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        alert.addAction(createAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
    
    private func performCreateFolder(name: String, parentId: String) {
        // Load DMS settings
        guard let userDefaults = UserDefaults(suiteName: "group.com.eisenvault.eisenvaultappflutter"),
              let baseUrl = userDefaults.string(forKey: "DMSBaseUrl"),
              let authToken = userDefaults.string(forKey: "DMSAuthToken"),
              let instanceType = userDefaults.string(forKey: "DMSInstanceType") else {
            showAlert(title: "Error", message: "DMS credentials not found. Please log in to the main app first.")
            return
        }
        
        // Check permissions first
        checkCreatePermission(for: parentId, baseUrl: baseUrl, authToken: authToken, instanceType: instanceType) { [weak self] hasPermission in
            DispatchQueue.main.async {
                if hasPermission {
                    self?.createFolderInDMS(name: name, parentId: parentId, baseUrl: baseUrl, authToken: authToken, instanceType: instanceType)
                } else {
                    self?.showAlert(title: "Permission Denied", message: "You don't have permission to create folders in this location.")
                }
            }
        }
    }
    
    private func checkCreatePermission(for nodeId: String, baseUrl: String, authToken: String, instanceType: String, completion: @escaping (Bool) -> Void) {
        let url: URL
        
        if instanceType.lowercased() == "angora" {
            // Angora: Check node permissions
            url = URL(string: "\(baseUrl)/api/nodes/\(nodeId)/permissions")!
        } else {
            // Classic: Check allowableOperations
            url = URL(string: "\(baseUrl)/api/-default-/public/alfresco/versions/1/nodes/\(nodeId)?include=allowableOperations")!
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(authToken, forHTTPHeaderField: "Authorization")
        
        if instanceType.lowercased() == "angora" {
            request.setValue("web", forHTTPHeaderField: "x-portal")
            if let customerHostname = UserDefaults(suiteName: "group.com.eisenvault.eisenvaultappflutter")?.string(forKey: "DMSCustomerHostname") {
                request.setValue(customerHostname, forHTTPHeaderField: "x-customer-hostname")
            }
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(false)
                return
            }
            
            if instanceType.lowercased() == "angora" {
                // Check Angora permissions
                if let permissions = json["permissions"] as? [String: Any] {
                    let canCreate = permissions["can_create_folder"] as? Bool == true ||
                                   permissions["create_folder"] as? Bool == true ||
                                   permissions["can_create_document"] as? Bool == true ||
                                   permissions["create_document"] as? Bool == true
                    completion(canCreate)
        } else {
                    completion(false)
                }
            } else {
                // Check Classic allowableOperations
                if let entry = json["entry"] as? [String: Any],
                   let allowableOperations = entry["allowableOperations"] as? [String] {
                    let canCreate = allowableOperations.contains("create")
                    completion(canCreate)
                } else {
                    completion(false)
                }
            }
        }.resume()
    }
    
    private func createFolderInDMS(name: String, parentId: String, baseUrl: String, authToken: String, instanceType: String) {
        let url: URL
        var requestBody: [String: Any]
        
        if instanceType.lowercased() == "angora" {
            // Angora: POST /api/folders
            url = URL(string: "\(baseUrl)/api/folders")!
            requestBody = [
                "name": name,
                "parent_id": parentId
            ]
        } else {
            // Classic: POST /api/-default-/public/alfresco/versions/1/nodes/{parentId}/children
            url = URL(string: "\(baseUrl)/api/-default-/public/alfresco/versions/1/nodes/\(parentId)/children")!
            requestBody = [
                "name": name,
                "nodeType": "cm:folder"
            ]
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(authToken, forHTTPHeaderField: "Authorization")
        
        if instanceType.lowercased() == "angora" {
            request.setValue("web", forHTTPHeaderField: "x-portal")
            if let customerHostname = UserDefaults(suiteName: "group.com.eisenvault.eisenvaultappflutter")?.string(forKey: "DMSCustomerHostname") {
                request.setValue(customerHostname, forHTTPHeaderField: "x-customer-hostname")
            }
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            showAlert(title: "Error", message: "Failed to create request: \(error.localizedDescription)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 201 {
                        self?.showAlert(title: "Success", message: "Folder '\(name)' created successfully!")
                        // Refresh the current folder to show the new folder
                        self?.loadFoldersForCurrentLevel()
                    } else {
                        let errorMessage = String(data: data ?? Data(), encoding: .utf8) ?? "Unknown error"
                        self?.showAlert(title: "Error", message: "Failed to create folder: \(errorMessage)")
                    }
                } else {
                    self?.showAlert(title: "Error", message: "Failed to create folder: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }.resume()
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @objc private func uploadFiles() {
        guard fileCount > 0 else { return }
        
        uploadButton.isEnabled = false
        uploadButton.alpha = 0.5
        progressView.isHidden = false
        progressView.progress = 0.0
        statusLabel.text = "Starting upload..."
        
        // Perform real upload
        performRealUpload()
    }
    
    @objc private func cancelUpload() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
    
    // MARK: - Real Upload Implementation
    private func performRealUpload() {
        guard let extensionContext = self.extensionContext else {
            print("🔍 DEBUG: No extension context available for upload")
            return
        }
        
        guard let userDefaults = UserDefaults(suiteName: "group.com.eisenvault.eisenvaultappflutter"),
              let baseUrl = userDefaults.string(forKey: "DMSBaseUrl"),
              let authToken = userDefaults.string(forKey: "DMSAuthToken"),
              let instanceType = userDefaults.string(forKey: "DMSInstanceType") else {
            print("🔍 DEBUG: Missing DMS credentials for upload")
            statusLabel.text = "Error: Missing DMS credentials"
            statusLabel.textColor = UIColor.red
            return
        }
        
        // Only handle Classic DMS for now
        guard instanceType.lowercased() == "classic" else {
            print("🔍 DEBUG: Only Classic DMS supported for upload")
            statusLabel.text = "Error: Only Classic DMS supported"
            statusLabel.textColor = UIColor.red
                        return
                    }
                    
        statusLabel.text = "Preparing files..."
        progressView.progress = 0.0
        
        // Process all shared items
        var totalFiles = 0
        var processedFiles = 0
        
        // Count total files first
        for item in sharedItems {
            if let attachments = item.attachments {
                totalFiles += attachments.count
            }
        }
        
        print("🔍 DEBUG: Starting upload of \(totalFiles) files to folder: \(selectedFolderId)")
        
        // Process each item
        for item in sharedItems {
            guard let attachments = item.attachments else { continue }
            
            for attachment in attachments {
                attachment.loadItem(forTypeIdentifier: attachment.registeredTypeIdentifiers.first ?? "public.data") { [weak self] data, error in
                    DispatchQueue.main.async {
                    if let error = error {
                            print("🔍 DEBUG: Error loading attachment: \(error)")
                            processedFiles += 1
                            self?.updateUploadProgress(processed: processedFiles, total: totalFiles)
                        return
                    }
                    
                        guard let data = data else {
                            print("🔍 DEBUG: No data for attachment")
                            processedFiles += 1
                            self?.updateUploadProgress(processed: processedFiles, total: totalFiles)
                            return
                        }
                        
                        // Upload this file
                        self?.uploadFile(data: data, attachment: attachment, baseUrl: baseUrl, authToken: authToken) { success in
                    DispatchQueue.main.async {
                                processedFiles += 1
                                self?.updateUploadProgress(processed: processedFiles, total: totalFiles)
                                
                                if processedFiles >= totalFiles {
                                    if success {
                                        self?.completeUpload()
                                    } else {
                                        self?.handleUploadError()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func uploadFile(data: Any, attachment: NSItemProvider, baseUrl: String, authToken: String, completion: @escaping (Bool) -> Void) {
        // Get file name and data
        var fileName = "uploaded_file"
        var fileData: Data?
        
        if let url = data as? URL {
            fileName = url.lastPathComponent
            do {
                fileData = try Data(contentsOf: url)
            } catch {
                print("🔍 DEBUG: Error reading file data: \(error)")
                completion(false)
                return
            }
        } else if let data = data as? Data {
            fileData = data
            // Try to get filename from attachment
            if let suggestedName = attachment.suggestedName {
                fileName = suggestedName
            }
        } else if let image = data as? UIImage {
            fileData = image.jpegData(compressionQuality: 0.8)
            fileName = "image_\(Date().timeIntervalSince1970).jpg"
        } else {
            print("🔍 DEBUG: Unsupported data type: \(type(of: data))")
            completion(false)
            return
        }
        
        guard let uploadData = fileData else {
            print("🔍 DEBUG: No file data to upload")
            completion(false)
            return
        }
        
        print("🔍 DEBUG: Uploading file: \(fileName) (\(uploadData.count) bytes)")
        
        // Create upload URL for Classic DMS
        let uploadUrlString = "\(baseUrl)/api/-default-/public/alfresco/versions/1/nodes/\(selectedFolderId)/children"
        
        guard let uploadUrl = URL(string: uploadUrlString) else {
            print("🔍 DEBUG: Invalid upload URL: \(uploadUrlString)")
            completion(false)
            return
        }
        
        // Create multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        
        // Add file data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"filedata\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(uploadData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add other required fields
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"destination\"\r\n\r\n".data(using: .utf8)!)
        body.append("workspace://SpacesStore/\(selectedFolderId)\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"upload-directory\"\r\n\r\n".data(using: .utf8)!)
        body.append("true\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        // Create request
        var request = URLRequest(url: uploadUrl)
        request.httpMethod = "POST"
        request.setValue(authToken, forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("\(body.count)", forHTTPHeaderField: "Content-Length")
        request.httpBody = body
        
        // Perform upload
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("🔍 DEBUG: Upload error: \(error)")
                completion(false)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🔍 DEBUG: Upload response status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 201 || httpResponse.statusCode == 200 {
                    print("🔍 DEBUG: File uploaded successfully: \(fileName)")
                    completion(true)
                } else {
                    print("🔍 DEBUG: Upload failed with status: \(httpResponse.statusCode)")
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        print("🔍 DEBUG: Upload response: \(responseString)")
                    }
                    completion(false)
                }
            } else {
                print("🔍 DEBUG: No HTTP response received")
                completion(false)
            }
        }.resume()
    }
    
    private func updateUploadProgress(processed: Int, total: Int) {
        let progress = Float(processed) / Float(total)
        progressView.progress = progress
        
        if processed < total {
            statusLabel.text = "Uploading \(processed)/\(total) files..."
        } else {
            statusLabel.text = "Upload complete!"
        }
    }
    
    private func handleUploadError() {
        statusLabel.text = "Upload failed"
        statusLabel.textColor = UIColor.red
        uploadButton.isEnabled = true
        uploadButton.alpha = 1.0
        progressView.isHidden = true
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
    
    // MARK: - DMS Integration
    private func loadDMSSettings() {
        guard let userDefaults = UserDefaults(suiteName: "group.com.eisenvault.eisenvaultappflutter") else {
            print("🔍 DEBUG: Failed to access App Groups UserDefaults")
            loadDefaultFolders()
            return
        }
        
        print("🔍 DEBUG: Checking App Groups for DMS credentials...")
        
        // Load DMS credentials and settings from App Groups
        if let baseUrl = userDefaults.string(forKey: "DMSBaseUrl"),
           let authToken = userDefaults.string(forKey: "DMSAuthToken"),
           let instanceType = userDefaults.string(forKey: "DMSInstanceType") {
            
            print("🔍 DEBUG: Found DMS credentials - BaseURL: \(baseUrl), InstanceType: \(instanceType)")
            print("🔍 DEBUG: AuthToken length: \(authToken.count) characters")
            loadDMSFolders(baseUrl: baseUrl, authToken: authToken, instanceType: instanceType)
        } else {
            print("🔍 DEBUG: No DMS settings found in App Groups")
            print("🔍 DEBUG: Available keys: \(userDefaults.dictionaryRepresentation().keys)")
            loadDefaultFolders()
        }
    }
    
    private func loadDMSFolders(baseUrl: String, authToken: String, instanceType: String) {
        // Create URL for fetching folders
        let urlString: String
        if instanceType.lowercased() == "angora" {
            urlString = "\(baseUrl)/api/folders"
        } else {
            // Classic/Alfresco - get sites first, then document libraries
            urlString = "\(baseUrl)/api/-default-/public/alfresco/versions/1/sites"
        }
        
        guard let url = URL(string: urlString) else {
            print("🔍 DEBUG: Invalid URL: \(urlString)")
            loadDefaultFolders()
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue(authToken, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if instanceType.lowercased() == "angora" {
            request.setValue("web", forHTTPHeaderField: "x-portal")
            if let customerHostname = UserDefaults(suiteName: "group.com.eisenvault.eisenvaultappflutter")?.string(forKey: "DMSCustomerHostname") {
                request.setValue(customerHostname, forHTTPHeaderField: "x-customer-hostname")
            }
        }
        
        print("🔍 DEBUG: Making network request to: \(urlString)")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("🔍 DEBUG: Error loading DMS folders: \(error)")
                    self?.loadDefaultFolders()
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("🔍 DEBUG: HTTP Response status: \(httpResponse.statusCode)")
                }
                
                guard let data = data else {
                    print("🔍 DEBUG: No data received")
                    self?.loadDefaultFolders()
                        return
                    }
                    
                print("🔍 DEBUG: Received \(data.count) bytes of data")
                
                do {
                    if instanceType.lowercased() == "angora" {
                        self?.parseAngoraFolders(data: data)
                    } else {
                        self?.parseClassicSites(data: data, baseUrl: baseUrl, authToken: authToken)
                    }
            } catch {
                    print("🔍 DEBUG: Error parsing DMS response: \(error)")
                    self?.loadDefaultFolders()
                }
            }
        }.resume()
    }
    
    private func parseAngoraFolders(data: Data) {
        do {
            print("🔍 DEBUG: Parsing Angora folders response...")
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("🔍 DEBUG: JSON keys: \(json.keys)")
                if let folders = json["folders"] as? [[String: Any]] {
                    print("🔍 DEBUG: Found \(folders.count) folders in response")
                    
                    sites = folders.compactMap { folder in
                        guard let id = folder["id"] as? String,
                              let name = folder["name"] as? String else { 
                            print("🔍 DEBUG: Skipping folder with missing id/name: \(folder)")
                            return nil 
                        }
                        print("🔍 DEBUG: Adding site: \(name) (id: \(id))")
                        return (id: id, name: name)
                    }
                    
                    print("🔍 DEBUG: Loaded \(sites.count) Angora sites")
                    loadSites()
                } else {
                    print("🔍 DEBUG: No 'folders' key found in response")
                    loadDefaultFolders()
                }
            } else {
                print("🔍 DEBUG: Failed to parse JSON response")
                loadDefaultFolders()
            }
        } catch {
            print("🔍 DEBUG: Error parsing Angora folders: \(error)")
            loadDefaultFolders()
        }
    }
    
    private func parseClassicSites(data: Data, baseUrl: String, authToken: String) {
        do {
            print("🔍 DEBUG: Parsing Classic sites response...")
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("🔍 DEBUG: JSON keys: \(json.keys)")
                if let list = json["list"] as? [String: Any],
                   let entries = list["entries"] as? [[String: Any]] {
                    
                    print("🔍 DEBUG: Found \(entries.count) site entries")
                    sites = []
                    
                    for entry in entries {
                        if let site = entry["entry"] as? [String: Any],
                           let siteId = site["id"] as? String,
                           let siteTitle = site["title"] as? String {
                            
                            print("🔍 DEBUG: Adding site: \(siteTitle) (id: \(siteId))")
                            sites.append((id: siteId, name: siteTitle))
                        }
                    }
                    
                    print("🔍 DEBUG: Loaded \(sites.count) Classic sites")
                    loadSites()
                } else {
                    print("🔍 DEBUG: No 'list.entries' found in response")
                    loadDefaultFolders()
                }
            } else {
                print("🔍 DEBUG: Failed to parse JSON response")
                loadDefaultFolders()
            }
            } catch {
            print("🔍 DEBUG: Error parsing Classic sites: \(error)")
            loadDefaultFolders()
        }
    }
    
    private func loadDocumentLibrary(siteId: String, siteTitle: String, baseUrl: String, authToken: String) {
        let urlString = "\(baseUrl)/api/-default-/public/alfresco/versions/1/sites/\(siteId)/containers"
        
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.setValue(authToken, forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let list = json["list"] as? [String: Any],
                      let entries = list["entries"] as? [[String: Any]] else { return }
                
                for entry in entries {
                    if let container = entry["entry"] as? [String: Any],
                       let folderId = container["folderId"] as? String,
                       folderId == "documentLibrary",
                       let containerId = container["id"] as? String {
                        
                        self?.availableFolders.append((id: containerId, name: "\(siteTitle) - Documents"))
                        print("🔍 DEBUG: Added document library for \(siteTitle)")
                        break
                    }
                }
            }
        }.resume()
    }
    
    private func loadSites() {
        folders = sites
        breadcrumbLabel.text = "Select destination..."
        backButton.isHidden = true
        folderTableView.reloadData()
        updateScrollIndicator()
        print("🔍 DEBUG: Loaded \(sites.count) sites for browsing")
    }
    
    private func updateScrollIndicator() {
        // Show scroll indicator if there are more folders than can fit in the visible area
        // Assuming each row is ~44pt and we have space for about 5-6 rows in the new height
        let visibleRows = Int(folderTableView.frame.height / 44)
        let shouldShowIndicator = folders.count > max(visibleRows, 4)
        scrollIndicatorView.isHidden = !shouldShowIndicator
        
        if shouldShowIndicator {
            scrollIndicatorLabel.text = "↓ Scroll for more folders (\(folders.count) total)"
        }
    }
    
    private func loadFoldersForCurrentLevel() {
        guard let userDefaults = UserDefaults(suiteName: "group.com.eisenvault.eisenvaultappflutter"),
              let baseUrl = userDefaults.string(forKey: "DMSBaseUrl"),
              let authToken = userDefaults.string(forKey: "DMSAuthToken"),
              let instanceType = userDefaults.string(forKey: "DMSInstanceType") else {
            print("🔍 DEBUG: Missing DMS credentials for loading subfolders")
            return
        }
        
        // Only handle Classic DMS for now
        guard instanceType.lowercased() == "classic" else {
            print("🔍 DEBUG: Only Classic DMS supported for subfolder browsing")
            return
        }
        
        if let currentId = currentFolderId {
            // Load containers for a site or children for a container
            loadClassicSubfolders(baseUrl: baseUrl, authToken: authToken, parentId: currentId)
        } else {
            // Load sites
            loadClassicSites(baseUrl: baseUrl, authToken: authToken)
        }
    }
    
    private func loadClassicSites(baseUrl: String, authToken: String) {
        let urlString = "\(baseUrl)/api/-default-/public/alfresco/versions/1/sites"
        
        guard let url = URL(string: urlString) else {
            print("🔍 DEBUG: Invalid sites URL: \(urlString)")
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue(authToken, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("🔍 DEBUG: Loading Classic sites from: \(urlString)")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("🔍 DEBUG: Error loading sites: \(error)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("🔍 DEBUG: Sites HTTP Response status: \(httpResponse.statusCode)")
                }
                
                guard let data = data else {
                    print("🔍 DEBUG: No sites data received")
                    return
                }
                
                print("🔍 DEBUG: Received \(data.count) bytes of sites data")
                self?.parseClassicSitesResponse(data: data)
            }
        }.resume()
    }
    
    private func loadClassicSubfolders(baseUrl: String, authToken: String, parentId: String) {
        // Check if this is a site (needs containers) or a container (needs children)
        let urlString: String
        
        // Try containers first (for sites)
        let containersUrl = "\(baseUrl)/api/-default-/public/alfresco/versions/1/sites/\(parentId)/containers"
        let childrenUrl = "\(baseUrl)/api/-default-/public/alfresco/versions/1/nodes/\(parentId)/children?include=path,properties,allowableOperations"
        
        // We'll try containers first, then fall back to children
        urlString = containersUrl
        
        guard let url = URL(string: urlString) else {
            print("🔍 DEBUG: Invalid subfolders URL: \(urlString)")
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue(authToken, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("🔍 DEBUG: Loading Classic subfolders from: \(urlString)")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("🔍 DEBUG: Error loading subfolders: \(error)")
                    // Try children endpoint as fallback
                    self?.loadClassicChildren(baseUrl: baseUrl, authToken: authToken, parentId: parentId)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("🔍 DEBUG: Subfolders HTTP Response status: \(httpResponse.statusCode)")
                    
                    if httpResponse.statusCode == 404 {
                        // Try children endpoint as fallback
                        self?.loadClassicChildren(baseUrl: baseUrl, authToken: authToken, parentId: parentId)
                        return
                    }
                }
                
                guard let data = data else {
                    print("🔍 DEBUG: No subfolders data received")
                    return
                }
                
                print("🔍 DEBUG: Received \(data.count) bytes of subfolders data")
                self?.parseClassicContainersResponse(data: data)
            }
        }.resume()
    }
    
    private func loadClassicChildren(baseUrl: String, authToken: String, parentId: String) {
        let urlString = "\(baseUrl)/api/-default-/public/alfresco/versions/1/nodes/\(parentId)/children?include=path,properties,allowableOperations"
        
        guard let url = URL(string: urlString) else {
            print("🔍 DEBUG: Invalid children URL: \(urlString)")
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue(authToken, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("🔍 DEBUG: Loading Classic children from: \(urlString)")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("🔍 DEBUG: Error loading children: \(error)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("🔍 DEBUG: Children HTTP Response status: \(httpResponse.statusCode)")
                }
                
                guard let data = data else {
                    print("🔍 DEBUG: No children data received")
                    return
                }
                
                print("🔍 DEBUG: Received \(data.count) bytes of children data")
                self?.parseClassicChildrenResponse(data: data)
            }
        }.resume()
    }
    
    private func loadDefaultFolders() {
        sites = [
            (id: "default", name: "Default Folder"),
            (id: "documents", name: "Documents"),
            (id: "images", name: "Images"),
            (id: "videos", name: "Videos")
        ]
        
        loadSites()
        print("🔍 DEBUG: Loaded default folders")
    }
    
    private func parseClassicSitesResponse(data: Data) {
        do {
            print("🔍 DEBUG: Parsing Classic sites response...")
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("🔍 DEBUG: JSON keys: \(json.keys)")
                if let list = json["list"] as? [String: Any],
                   let entries = list["entries"] as? [[String: Any]] {
                    
                    print("🔍 DEBUG: Found \(entries.count) site entries")
                    sites = []
                    
                    for entry in entries {
                        if let site = entry["entry"] as? [String: Any],
                           let siteId = site["id"] as? String,
                           let siteTitle = site["title"] as? String {
                            
                            print("🔍 DEBUG: Adding site: \(siteTitle) (id: \(siteId))")
                            sites.append((id: siteId, name: siteTitle))
                        }
                    }
                    
                    print("🔍 DEBUG: Loaded \(sites.count) Classic sites")
                    loadSites()
                } else {
                    print("🔍 DEBUG: No 'list.entries' found in sites response")
                    loadDefaultFolders()
                }
            } else {
                print("🔍 DEBUG: Failed to parse sites JSON response")
                loadDefaultFolders()
            }
            } catch {
            print("🔍 DEBUG: Error parsing Classic sites: \(error)")
            loadDefaultFolders()
        }
    }
    
    private func parseClassicContainersResponse(data: Data) {
        do {
            print("🔍 DEBUG: Parsing Classic containers response...")
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("🔍 DEBUG: JSON keys: \(json.keys)")
                if let list = json["list"] as? [String: Any],
                   let entries = list["entries"] as? [[String: Any]] {
                    
                    print("🔍 DEBUG: Found \(entries.count) container entries")
                    folders = []
                    
                    for entry in entries {
                        if let container = entry["entry"] as? [String: Any],
                           let containerId = container["id"] as? String {
                            
                            let containerName = container["folderId"] as? String ?? container["title"] as? String ?? "Container"
                            print("🔍 DEBUG: Adding container: \(containerName) (id: \(containerId))")
                            folders.append((id: containerId, name: containerName))
                        }
                    }
                    
                    print("🔍 DEBUG: Loaded \(folders.count) Classic containers")
                    folderTableView.reloadData()
                    updateScrollIndicator()
                } else {
                    print("🔍 DEBUG: No 'list.entries' found in containers response")
                }
            } else {
                print("🔍 DEBUG: Failed to parse containers JSON response")
            }
        } catch {
            print("🔍 DEBUG: Error parsing Classic containers: \(error)")
        }
    }
    
    private func parseClassicChildrenResponse(data: Data) {
        do {
            print("🔍 DEBUG: Parsing Classic children response...")
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("🔍 DEBUG: JSON keys: \(json.keys)")
                if let list = json["list"] as? [String: Any],
                   let entries = list["entries"] as? [[String: Any]] {
                    
                    print("🔍 DEBUG: Found \(entries.count) children entries")
                    folders = []
                    
                    for entry in entries {
                        if let child = entry["entry"] as? [String: Any],
                           let childId = child["id"] as? String,
                           let childName = child["name"] as? String {
                            
                            // Only include folders, not files
                            let isFolder = child["isFolder"] as? Bool ?? false
                            if isFolder {
                                print("🔍 DEBUG: Adding folder: \(childName) (id: \(childId))")
                                folders.append((id: childId, name: childName))
                            } else {
                                print("🔍 DEBUG: Skipping file: \(childName)")
                            }
                        }
                    }
                    
                    print("🔍 DEBUG: Loaded \(folders.count) Classic folders")
                    folderTableView.reloadData()
                    updateScrollIndicator()
                } else {
                    print("🔍 DEBUG: No 'list.entries' found in children response")
                }
            } else {
                print("🔍 DEBUG: Failed to parse children JSON response")
            }
        } catch {
            print("🔍 DEBUG: Error parsing Classic children: \(error)")
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
            "folderId": selectedFolderId,
            "fileCount": fileCount,
            "timestamp": Date().timeIntervalSince1970,
            "status": "completed"
        ]
        
        userDefaults.set(uploadData, forKey: "UploadData")
        userDefaults.synchronize()
        
        print("🔍 DEBUG: Upload data saved to App Groups")
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate
extension ShareViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return folders.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "FolderCell")
        let folder = folders[indexPath.row]
        
        cell.textLabel?.text = folder.name
        cell.textLabel?.font = UIFont.systemFont(ofSize: 16)
        cell.textLabel?.textColor = UIColor(red: 0.133, green: 0.133, blue: 0.133, alpha: 1.0) // paletteTextDark
        cell.selectionStyle = .none // Disable default selection
        
        // Clear any existing accessory view first
        cell.accessoryView = nil
        cell.accessoryType = .none
        
        // Check if this is the selected folder
        let isSelected = selectedIndexPath == indexPath
        
        if isSelected {
            // Highlight selected cell
            cell.backgroundColor = UIColor(red: 0.456, green: 0.718, blue: 0.627, alpha: 0.2) // paletteAccent with 20% opacity
            cell.layer.cornerRadius = 6
            
            // Show checkmark icon for selected folder
            cell.imageView?.image = UIImage(systemName: "checkmark.circle.fill")
            cell.imageView?.tintColor = UIColor(red: 0.456, green: 0.718, blue: 0.627, alpha: 1.0) // paletteAccent
            
            // Show "Selected" text
            let label = UILabel()
            label.text = "Selected"
            label.font = UIFont.systemFont(ofSize: 12)
            label.textColor = UIColor(red: 0.456, green: 0.718, blue: 0.627, alpha: 1.0) // paletteAccent
            label.sizeToFit()
            cell.accessoryView = label
        } else {
            // Normal cell appearance
            cell.backgroundColor = UIColor.clear
            
            // Add folder icon
            cell.imageView?.image = UIImage(systemName: "folder")
            cell.imageView?.tintColor = UIColor(red: 0.698, green: 0.290, blue: 0.231, alpha: 1.0) // paletteButton
            
            // Add selection button
            let button = UIButton(type: .system)
            button.setTitle("Select", for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 12)
            button.setTitleColor(UIColor(red: 0.698, green: 0.290, blue: 0.231, alpha: 1.0), for: .normal) // paletteButton
            button.backgroundColor = UIColor(red: 0.698, green: 0.290, blue: 0.231, alpha: 0.1) // paletteButton with 10% opacity
            button.layer.cornerRadius = 4
            button.contentEdgeInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
            button.tag = indexPath.row
            button.addTarget(self, action: #selector(selectFolderAtIndex(_:)), for: .touchUpInside)
            button.sizeToFit()
            cell.accessoryView = button
        }
        
        return cell
    }
    
    @objc private func selectFolderAtIndex(_ sender: UIButton) {
        let indexPath = IndexPath(row: sender.tag, section: 0)
        let folder = folders[indexPath.row]
        
        // Select this folder as destination
        selectedFolder = folder.name
        selectedFolderId = folder.id
        selectedIndexPath = indexPath
        
        // Show confirmation UI
        selectedDestinationLabel.text = "Selected: \(folder.name)"
        selectedDestinationView.isHidden = false
        
        // Enable upload button
        uploadButton.isEnabled = true
        uploadButton.alpha = 1.0
        statusLabel.text = "Ready to upload to \(folder.name)"
        statusLabel.textColor = UIColor(red: 0.698, green: 0.290, blue: 0.231, alpha: 1.0) // paletteButton
        
        // Reload table to show selection
        folderTableView.reloadData()
        updateScrollIndicator()
        
        print("🔍 DEBUG: Selected folder for upload: \(folder.name) (id: \(folder.id))")
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let folder = folders[indexPath.row]
        
        // Tapping the row navigates into the folder (browse subfolders)
        navigationStack.append((id: folder.id, name: folder.name))
        currentFolderId = folder.id
        breadcrumbLabel.text = folder.name
        backButton.isHidden = false
        
        // Load subfolders for the next level
        loadFoldersForCurrentLevel()
        
        print("🔍 DEBUG: Navigating into folder: \(folder.name) (id: \(folder.id))")
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44
    }
}