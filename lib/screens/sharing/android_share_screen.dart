import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:eisenvaultappflutter/constants/colors.dart';
import 'package:eisenvaultappflutter/services/sharing/android_share_service.dart';
import 'package:eisenvaultappflutter/services/browse/browse_service_factory.dart';
import 'package:eisenvaultappflutter/models/browse_item.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';
import 'package:http/http.dart' as http;

class AndroidShareScreen extends StatefulWidget {
  const AndroidShareScreen({super.key});

  @override
  State<AndroidShareScreen> createState() => _AndroidShareScreenState();
}

class _AndroidShareScreenState extends State<AndroidShareScreen> {
  List<String> sharedFiles = [];
  Map<String, String> fileNames = {}; // Map of fileUri -> fileName
  String? sharedText;
  bool isLoading = true;
  String? error;
  
  // Folder browsing state
  List<BrowseItem> folders = [];
  List<BrowseItem> navigationStack = [];
  BrowseItem? selectedFolder;
  bool isLoadingFolders = false;
  String? folderError;
  String breadcrumb = "Select destination folder";
  
  // DMS credentials
  String? baseUrl;
  String? authToken;
  String? instanceType;
  String? customerHostname;
  
  // Upload state
  bool isUploading = false;
  String? uploadError;

  @override
  void initState() {
    super.initState();
    _loadSharedData();
    _loadDMSCredentials();
  }

  Future<void> _loadSharedData() async {
    try {
      EVLogger.info('Loading shared data in AndroidShareScreen');
      
      final sharedData = await AndroidShareService.getSharedData();
      
      if (sharedData != null) {
        setState(() {
          sharedFiles = (sharedData['files'] as List?)?.cast<String>() ?? [];
          sharedText = sharedData['text'] as String?;
          isLoading = false;
        });
        
        // Load filenames for display
        await _loadFileNames();
        
        EVLogger.info('Loaded shared data', {
          'fileCount': sharedFiles.length,
          'hasText': sharedText?.isNotEmpty == true
        });
      } else {
        setState(() {
          isLoading = false;
          error = 'No shared data found';
        });
      }
    } catch (e) {
      EVLogger.error('Failed to load shared data', {
        'error': e.toString()
      });
      
      setState(() {
        isLoading = false;
        error = 'Failed to load shared data: ${e.toString()}';
      });
    }
  }
  
  Future<void> _loadFileNames() async {
    final newFileNames = <String, String>{};
    
    for (String fileUri in sharedFiles) {
      try {
        final fileData = await AndroidShareService.getFileContent(fileUri);
        if (fileData != null) {
          final fileName = fileData['fileName'] as String;
          newFileNames[fileUri] = fileName;
        }
      } catch (e) {
        EVLogger.warning('Failed to get filename for file', {
          'fileUri': fileUri,
          'error': e.toString()
        });
        // Use a fallback filename
        newFileNames[fileUri] = fileUri.split('/').last;
      }
    }
    
    setState(() {
      fileNames = newFileNames;
    });
  }

  Future<void> _loadDMSCredentials() async {
    try {
      EVLogger.info('Loading DMS credentials from ShareActivity');
      
      final credentials = await AndroidShareService.getDMSCredentials();
      
      if (credentials != null) {
        baseUrl = credentials['baseUrl'] as String?;
        authToken = credentials['authToken'] as String?;
        instanceType = credentials['instanceType'] as String?;
        customerHostname = credentials['customerHostname'] as String?;
        
        EVLogger.info('Loaded DMS credentials', {
          'hasBaseUrl': baseUrl != null,
          'hasAuthToken': authToken != null,
          'instanceType': instanceType
        });
        
        if (baseUrl != null && authToken != null && instanceType != null) {
          _loadFolders();
        } else {
          setState(() {
            folderError = 'DMS credentials incomplete. Please log in to the main app first.';
          });
        }
      } else {
        setState(() {
          folderError = 'DMS credentials not found. Please log in to the main app first.';
        });
      }
    } catch (e) {
      EVLogger.error('Failed to load DMS credentials', {
        'error': e.toString()
      });
      setState(() {
        folderError = 'Failed to load DMS credentials: ${e.toString()}';
      });
    }
  }

  Future<void> _loadFolders() async {
    if (baseUrl == null || authToken == null || instanceType == null) return;
    
    setState(() {
      isLoadingFolders = true;
      folderError = null;
    });
    
    try {
      final browseService = BrowseServiceFactory.getService(
        instanceType!,
        baseUrl!,
        authToken!,
      );
      
      BrowseItem parent;
      if (navigationStack.isEmpty) {
        // Load top-level folders (sites/departments) - use root as parent
        parent = BrowseItem(
          id: 'root',
          name: 'Root',
          type: 'folder',
          description: 'Root folder',
          isDepartment: false,
        );
        breadcrumb = "Select destination folder";
      } else {
        // Load subfolders for current folder
        parent = navigationStack.last;
        breadcrumb = parent.name;
      }
      
      final children = await browseService.getChildren(parent);
      
      // Filter to only show folders (not files)
      final folderChildren = children.where((item) => 
        item.type == 'folder' || item.isDepartment == true
      ).toList();
      
      setState(() {
        folders = folderChildren;
      });
    } catch (e) {
      EVLogger.error('Failed to load folders', {
        'error': e.toString()
      });
      setState(() {
        folderError = 'Failed to load folders: ${e.toString()}';
      });
    } finally {
      setState(() {
        isLoadingFolders = false;
      });
    }
  }

  void _navigateToFolder(BrowseItem folder) {
    setState(() {
      navigationStack.add(folder);
      selectedFolder = null; // Clear selection when navigating
    });
    _loadFolders();
  }

  void _goBack() {
    if (navigationStack.isNotEmpty) {
      setState(() {
        navigationStack.removeLast();
        selectedFolder = null; // Clear selection when going back
      });
      _loadFolders();
    }
  }

  void _selectFolder(BrowseItem folder) {
    setState(() {
      selectedFolder = folder;
    });
  }

  void _changeDestination() {
    setState(() {
      selectedFolder = null;
      navigationStack.clear();
    });
    _loadFolders();
  }
  
  void _createFolder() {
    // Get the current folder ID (parent for new folder)
    String? parentId;
    if (navigationStack.isNotEmpty) {
      parentId = navigationStack.last.id;
    } else {
      // If we're at root level, we need to find a suitable parent
      // For now, we'll show an error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please navigate to a specific folder to create a subfolder'),
          backgroundColor: EVColors.statusError,
        ),
      );
      return;
    }
    
    _showCreateFolderDialog(parentId);
  }
  
  void _showCreateFolderDialog(String parentId) {
    final TextEditingController nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Folder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter a name for the new folder:'),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Folder Name',
                border: OutlineInputBorder(),
                hintText: 'Enter folder name',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final folderName = nameController.text.trim();
              if (folderName.isNotEmpty) {
                Navigator.of(context).pop();
                _performCreateFolder(folderName, parentId);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: EVColors.paletteButton,
              foregroundColor: Colors.white,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _performCreateFolder(String folderName, String parentId) async {
    if (baseUrl == null || authToken == null || instanceType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('DMS credentials not available'),
          backgroundColor: EVColors.statusError,
        ),
      );
      return;
    }
    
    try {
      EVLogger.info('Creating folder', {
        'folderName': folderName,
        'parentId': parentId,
        'instanceType': instanceType
      });
      
      if (instanceType!.toLowerCase() == 'classic') {
        await _createFolderInClassicDMS(folderName, parentId);
      } else if (instanceType!.toLowerCase() == 'angora') {
        await _createFolderInAngoraDMS(folderName, parentId);
      } else {
        throw Exception('Unsupported DMS instance type: $instanceType');
      }
      
      // Refresh the folder list to show the new folder
      _loadFolders();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Folder "$folderName" created successfully'),
          backgroundColor: EVColors.successGreen,
        ),
      );
      
    } catch (e) {
      EVLogger.error('Failed to create folder', {
        'folderName': folderName,
        'parentId': parentId,
        'error': e.toString()
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to create folder: ${e.toString()}'),
          backgroundColor: EVColors.statusError,
        ),
      );
    }
  }
  
  Future<void> _createFolderInClassicDMS(String folderName, String parentId) async {
    final url = Uri.parse('$baseUrl/api/-default-/public/alfresco/versions/1/nodes/$parentId/children');
    
    final requestBody = {
      'name': folderName,
      'nodeType': 'cm:folder',
    };
    
    final response = await http.post(
      url,
      headers: {
        'Authorization': authToken!,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(requestBody),
    );
    
    if (response.statusCode != 201) {
      throw Exception('Create folder failed: ${response.statusCode} - ${response.body}');
    }
    
    EVLogger.info('Folder created successfully in Classic DMS', {
      'folderName': folderName,
      'parentId': parentId,
      'statusCode': response.statusCode
    });
  }
  
  Future<void> _createFolderInAngoraDMS(String folderName, String parentId) async {
    final url = Uri.parse('$baseUrl/api/folders');
    
    final requestBody = {
      'name': folderName,
      'parent_id': parentId,
    };
    
    final response = await http.post(
      url,
      headers: {
        'Authorization': authToken!,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Accept-Language': 'en',
        'x-portal': 'web',
        'x-service-name': 'service-file',
      },
      body: jsonEncode(requestBody),
    );
    
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Create folder failed: ${response.statusCode} - ${response.body}');
    }
    
    EVLogger.info('Folder created successfully in Angora DMS', {
      'folderName': folderName,
      'parentId': parentId,
      'statusCode': response.statusCode
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EVColors.paletteBackground,
      appBar: AppBar(
        title: const Text('Share to EisenVault'),
        backgroundColor: EVColors.paletteButton,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(EVColors.paletteButton),
              ),
            )
          : error != null
              ? _buildErrorView()
              : _buildContent(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: EVColors.statusError,
            ),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: EVColors.paletteTextDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: EVColors.paletteTextDark,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                await AndroidShareService.finishShareActivity();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: EVColors.paletteButton,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header - Platform-specific compact sizing
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(Platform.isIOS ? 6 : 8),
            decoration: BoxDecoration(
              color: EVColors.paletteAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: EVColors.paletteAccent.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.upload_file,
                      color: EVColors.paletteButton,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Files to Upload',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: EVColors.paletteTextDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (sharedFiles.isNotEmpty) ...[
                  Text(
                    '${sharedFiles.length} file(s) selected',
                    style: TextStyle(
                      fontSize: 14,
                      color: EVColors.paletteTextDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...sharedFiles.take(3).map((file) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          _getFileIcon(file),
                          size: 16,
                          color: EVColors.paletteButton,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            fileNames[file] ?? file.split('/').last,
                            style: TextStyle(
                              fontSize: 12,
                              color: EVColors.paletteTextDark,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  )),
                  if (sharedFiles.length > 3)
                    Text(
                      '... and ${sharedFiles.length - 3} more',
                      style: TextStyle(
                        fontSize: 12,
                        color: EVColors.paletteTextDark.withOpacity(0.7),
                      ),
                    ),
                ],
                if (sharedText?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.text_fields,
                        size: 16,
                        color: EVColors.paletteButton,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Text: ${sharedText!.length > 50 ? "${sharedText!.substring(0, 50)}..." : sharedText!}',
                          style: TextStyle(
                            fontSize: 12,
                            color: EVColors.paletteTextDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          
          SizedBox(height: Platform.isIOS ? 8 : 12),
          
          // Folder Selection Header - Platform-specific compact sizing
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(Platform.isIOS ? 8 : 12),
            decoration: BoxDecoration(
              color: EVColors.sharingHeaderBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: EVColors.paletteButton.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.folder,
                  color: EVColors.paletteButton,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    breadcrumb,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: EVColors.paletteTextDark,
                    ),
                  ),
                ),
                // Create Folder button
                TextButton.icon(
                  onPressed: _createFolder,
                  icon: Icon(
                    Icons.create_new_folder,
                    color: EVColors.paletteButton,
                    size: 18,
                  ),
                  label: Text(
                    'Create',
                    style: TextStyle(
                      fontSize: 12,
                      color: EVColors.paletteButton,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                if (navigationStack.isNotEmpty)
                  IconButton(
                    onPressed: _goBack,
                    icon: Icon(
                      Icons.arrow_back,
                      color: EVColors.paletteButton,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
          
          SizedBox(height: Platform.isIOS ? 4 : 6),
          
          // Folder Count and Scroll Indicator - Outside scrollable area
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: EVColors.sharingScrollIndicatorBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.folder_outlined,
                  size: 16,
                  color: EVColors.paletteButton,
                ),
                const SizedBox(width: 8),
                Text(
                  '${folders.length} folder${folders.length != 1 ? 's' : ''} available',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: EVColors.paletteButton,
                  ),
                ),
                const Spacer(),
                // Always show scroll indicator if there are folders
                if (folders.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.swipe_up,
                        size: 16,
                        color: EVColors.paletteButton.withOpacity(0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        folders.length > 2 ? 'Scroll to see more' : 'Tap to select',
                        style: TextStyle(
                          fontSize: 12,
                          color: EVColors.paletteButton.withOpacity(0.7),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          
          SizedBox(height: Platform.isIOS ? 4 : 6),
          
          // Folder List - Expanded scrollable area with platform-specific constraints
          Expanded(
            flex: Platform.isIOS ? 4 : 3, // Give even more space to folder list on iOS
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(
                minHeight: Platform.isIOS ? 250 : 200, // Higher minimum height on iOS
                maxHeight: Platform.isIOS 
                    ? MediaQuery.of(context).size.height * 0.6  // 60% on iOS
                    : MediaQuery.of(context).size.height * 0.5, // 50% on Android
              ),
              decoration: BoxDecoration(
                color: EVColors.sharingContainerBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: EVColors.paletteButton.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                
                  // Folder list or error/loading state
                  if (folderError != null)
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: EVColors.statusErrorBackground,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: EVColors.statusError.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: EVColors.statusError,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              folderError!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: EVColors.paletteTextDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (isLoadingFolders)
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        child: const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(EVColors.paletteButton),
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: folders.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.folder_open,
                                    size: 48,
                                    color: EVColors.paletteButton.withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No folders available',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: EVColors.paletteTextDark,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: folders.length,
                              itemBuilder: (context, index) {
                                final folder = folders[index];
                                final isSelected = selectedFolder?.id == folder.id;
                                
                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSelected ? EVColors.sharingFolderItemSelectedBackground : EVColors.sharingFolderItemBackground,
                                    borderRadius: BorderRadius.circular(8),
                                    border: isSelected ? Border.all(
                                      color: EVColors.sharingFolderItemSelectedBorder,
                                      width: 1,
                                    ) : null,
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    leading: Icon(
                                      isSelected ? Icons.check_circle : Icons.folder,
                                      color: isSelected ? EVColors.paletteAccent : EVColors.paletteButton,
                                      size: 24,
                                    ),
                                    title: Text(
                                      folder.name,
                                      style: TextStyle(
                                        color: isSelected ? EVColors.paletteAccent : EVColors.paletteTextDark,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        fontSize: 16,
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isSelected)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: EVColors.paletteAccent,
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            child: Text(
                                              'SELECTED',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: EVColors.buttonForeground,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          )
                                        else
                                          ElevatedButton(
                                            onPressed: () => _selectFolder(folder),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: EVColors.paletteButton,
                                              foregroundColor: EVColors.buttonForeground,
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                            child: Text(
                                              'Select',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          onPressed: () => _navigateToFolder(folder),
                                          icon: Icon(
                                            Icons.chevron_right,
                                            color: EVColors.paletteButton,
                                            size: 20,
                                          ),
                                        ),
                                      ],
                                    ),
                                    onTap: () => _navigateToFolder(folder),
                                  ),
                                );
                              },
                            ),
                    ),
                ],
              ),
            ),
          ),
          
          // Selected destination display
          if (selectedFolder != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: EVColors.paletteAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: EVColors.paletteAccent.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: EVColors.paletteAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Selected: ${selectedFolder!.name}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: EVColors.paletteTextDark,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _changeDestination,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Change',
                      style: TextStyle(
                        fontSize: 12,
                        color: EVColors.paletteButton,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const Spacer(),
          
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    await AndroidShareService.finishShareActivity();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: EVColors.paletteButton,
                    side: BorderSide(color: EVColors.paletteButton),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: (selectedFolder != null && !isUploading) ? _uploadFiles : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (selectedFolder != null && !isUploading) ? EVColors.paletteButton : EVColors.paletteButton.withOpacity(0.5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: isUploading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('Uploading...'),
                          ],
                        )
                      : const Text('Upload'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      default:
        return Icons.insert_drive_file;
    }
  }


  Future<void> _uploadFiles() async {
    if (selectedFolder == null || sharedFiles.isEmpty) return;
    
    setState(() {
      isUploading = true;
      uploadError = null;
    });
    
    try {
      EVLogger.info('Starting file upload', {
        'folderId': selectedFolder!.id,
        'folderName': selectedFolder!.name,
        'fileCount': sharedFiles.length
      });
      
      int successCount = 0;
      int failCount = 0;
      
      for (String fileUri in sharedFiles) {
        try {
          await _uploadSingleFile(fileUri, selectedFolder!.id);
          successCount++;
        } catch (e) {
          EVLogger.error('Failed to upload file', {
            'fileUri': fileUri,
            'error': e.toString()
          });
          failCount++;
        }
      }
      
      setState(() {
        isUploading = false;
      });
      
      if (successCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Uploaded $successCount file(s) to ${selectedFolder!.name}'),
            backgroundColor: EVColors.successGreen,
          ),
        );
      }
      
      if (failCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to upload $failCount file(s)'),
            backgroundColor: EVColors.statusError,
          ),
        );
      }
      
      // Clear shared data and finish activity
      await AndroidShareService.clearSharedData();
      await AndroidShareService.finishShareActivity();
      
    } catch (e) {
      setState(() {
        isUploading = false;
        uploadError = e.toString();
      });
      
      EVLogger.error('Upload failed', {
        'error': e.toString()
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Upload failed: ${e.toString()}'),
          backgroundColor: EVColors.statusError,
        ),
      );
    }
  }
  
  Future<void> _uploadSingleFile(String fileUri, String folderId) async {
    if (baseUrl == null || authToken == null || instanceType == null) {
      throw Exception('DMS credentials not available');
    }
    
    // Read the file content and filename from ShareActivity
    final fileData = await AndroidShareService.getFileContent(fileUri);
    if (fileData == null) {
      throw Exception('Could not read file content: $fileUri');
    }
    
    final fileBytes = fileData['content'] as List<int>;
    final fileName = fileData['fileName'] as String;
    
    EVLogger.info('Uploading file', {
      'fileName': fileName,
      'fileSize': fileBytes.length,
      'folderId': folderId
    });
    
    if (instanceType!.toLowerCase() == 'classic') {
      await _uploadToClassicDMS(fileBytes, fileName, folderId);
    } else if (instanceType!.toLowerCase() == 'angora') {
      await _uploadToAngoraDMS(fileBytes, fileName, folderId);
    } else {
      throw Exception('Unsupported DMS instance type: $instanceType');
    }
  }
  
  Future<void> _uploadToClassicDMS(List<int> fileBytes, String fileName, String folderId) async {
    final url = Uri.parse('$baseUrl/api/-default-/public/alfresco/versions/1/nodes/$folderId/children');
    
    final request = http.MultipartRequest('POST', url);
    // For Classic DMS, authToken is already in "Basic base64credentials" format
    request.headers['Authorization'] = authToken!;
    request.headers['Accept'] = 'application/json';
    // Don't set Content-Type for multipart - let the library handle it
    
    request.files.add(http.MultipartFile.fromBytes(
      'filedata',
      fileBytes,
      filename: fileName,
    ));
    
    request.fields['name'] = fileName;
    request.fields['nodeType'] = 'cm:content';
    request.fields['autoRename'] = 'true';
    
    final response = await request.send();
    
    if (response.statusCode != 201) {
      final responseBody = await response.stream.bytesToString();
      throw Exception('Upload failed: ${response.statusCode} - $responseBody');
    }
    
    EVLogger.info('File uploaded successfully to Classic DMS', {
      'fileName': fileName,
      'statusCode': response.statusCode
    });
  }
  
  Future<void> _uploadToAngoraDMS(List<int> fileBytes, String fileName, String folderId) async {
    // Use /api/uploads endpoint (same as iOS Share Extension)
    final url = Uri.parse('$baseUrl/api/uploads');
    
    // Generate a unique file ID in Angora format: parentId_fileName_fileSize_timestamp
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileId = '${folderId}_${fileName}_${fileBytes.length}_$timestamp';
    
    final request = http.MultipartRequest('POST', url);
    // For Angora DMS, authToken is just the token (no "Bearer" prefix)
    request.headers['Authorization'] = authToken!;
    request.headers['Accept'] = 'application/json';
    request.headers['Accept-Language'] = 'en';
    request.headers['x-portal'] = 'web';
    request.headers['x-service-name'] = 'service-file';
    request.headers['x-file-id'] = fileId;
    request.headers['x-file-name'] = fileName;
    request.headers['x-start-byte'] = '0';
    request.headers['x-file-size'] = fileBytes.length.toString();
    request.headers['x-resumable'] = 'true';
    request.headers['x-relative-path'] = '';
    request.headers['x-parent-id'] = folderId;
    
    if (customerHostname != null && customerHostname!.isNotEmpty) {
      request.headers['x-customer-hostname'] = customerHostname!;
    }
    
    // Don't set Content-Type for multipart - let the library handle it
    
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: fileName,
    ));
    
    final response = await request.send();
    
    if (response.statusCode != 200 && response.statusCode != 201) {
      final responseBody = await response.stream.bytesToString();
      throw Exception('Upload failed: ${response.statusCode} - $responseBody');
    }
    
    EVLogger.info('File uploaded successfully to Angora DMS', {
      'fileName': fileName,
      'folderId': folderId,
      'statusCode': response.statusCode
    });
  }
}
