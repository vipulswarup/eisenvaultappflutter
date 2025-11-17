# EisenVault Windows Requirements

## System Requirements
- Windows 10 or later
- Minimum 4GB RAM
- 500MB free disk space

## Installation and Setup
1. Download and install EisenVault from the Microsoft Store
2. Launch the application normally (no administrator privileges required)

## File Access
EisenVault uses standard user directories for all file operations:
- Application data is stored in your user profile directory
- Database files are stored in app-specific user directories
- Secure storage uses Windows user credential store
- File browsing uses standard Windows file dialogs

## Troubleshooting
If you encounter permission-related issues:
1. Ensure you have standard user permissions on your Windows account
2. Check Windows Security settings for any blocked permissions
3. Verify that file access permissions are properly configured

## Security Note
EisenVault follows security best practices:
- All sensitive data is encrypted at rest
- Network communications are secured using TLS
- No administrator privileges required
- All file operations use user-accessible directories 