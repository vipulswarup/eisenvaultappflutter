package com.eisenvault.eisenvaultappflutter

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.*

class ShareActivity : FlutterActivity() {
    private val CHANNEL = "com.eisenvault.eisenvaultappflutter/share"
    private var sharedFiles: List<Uri> = emptyList()
    private var sharedText: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        Log.d("ShareActivity", "ShareActivity created")
        
        // Handle the incoming intent
        handleShareIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        Log.d("ShareActivity", "New intent received")
        handleShareIntent(intent)
    }
    
    override fun getInitialRoute(): String {
        return "/share"
    }

    private fun handleShareIntent(intent: Intent) {
        val action = intent.action
        val type = intent.type
        
        Log.d("ShareActivity", "Intent action: $action, type: $type")
        
        when (action) {
            Intent.ACTION_SEND -> {
                if (type?.startsWith("text/") == true) {
                    // Handle text sharing
                    sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
                    Log.d("ShareActivity", "Shared text: $sharedText")
                } else {
                    // Handle single file sharing
                    val uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                    if (uri != null) {
                        sharedFiles = listOf(uri)
                        Log.d("ShareActivity", "Shared single file: $uri")
                    }
                }
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                // Handle multiple file sharing
                val uris = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
                if (uris != null) {
                    sharedFiles = uris
                    Log.d("ShareActivity", "Shared multiple files: ${uris.size} files")
                }
            }
        }
        
        // Store shared data for Flutter to access
        storeSharedData()
    }

    private fun storeSharedData() {
        val sharedPrefs = getSharedPreferences("eisenvault_shared", MODE_PRIVATE)
        val editor = sharedPrefs.edit()
        
        // Store file URIs as strings
        val fileUris = sharedFiles.map { it.toString() }
        editor.putStringSet("shared_files", fileUris.toSet())
        
        // Store shared text
        if (sharedText != null) {
            editor.putString("shared_text", sharedText)
        }
        
        // Store timestamp
        editor.putLong("share_timestamp", System.currentTimeMillis())
        
        editor.apply()
        
        Log.d("ShareActivity", "Stored shared data: ${fileUris.size} files, text: ${sharedText != null}")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSharedData" -> {
                    val sharedPrefs = getSharedPreferences("eisenvault_shared", MODE_PRIVATE)
                    val fileUris = sharedPrefs.getStringSet("shared_files", emptySet())?.toList() ?: emptyList()
                    val sharedText = sharedPrefs.getString("shared_text", null)
                    val timestamp = sharedPrefs.getLong("share_timestamp", 0)
                    
                    val sharedData = mapOf(
                        "files" to fileUris,
                        "text" to sharedText,
                        "timestamp" to timestamp
                    )
                    
                    Log.d("ShareActivity", "Returning shared data: $sharedData")
                    result.success(sharedData)
                }
                "clearSharedData" -> {
                    val sharedPrefs = getSharedPreferences("eisenvault_shared", MODE_PRIVATE)
                    sharedPrefs.edit().clear().apply()
                    Log.d("ShareActivity", "Cleared shared data")
                    result.success(null)
                }
                "finishShareActivity" -> {
                    Log.d("ShareActivity", "Finishing ShareActivity")
                    finish()
                    result.success(null)
                }
                "getDMSCredentials" -> {
                    val sharedPrefs = getSharedPreferences("eisenvault_dms_credentials", MODE_PRIVATE)
                    val credentials = mapOf(
                        "baseUrl" to sharedPrefs.getString("baseUrl", null),
                        "authToken" to sharedPrefs.getString("authToken", null),
                        "instanceType" to sharedPrefs.getString("instanceType", null),
                        "customerHostname" to sharedPrefs.getString("customerHostname", null)
                    )
                    
                    Log.d("ShareActivity", "Returning DMS credentials: ${credentials.keys}")
                    result.success(credentials)
                }
                "saveDMSCredentials" -> {
                    val baseUrl = call.argument<String>("baseUrl")
                    val authToken = call.argument<String>("authToken")
                    val instanceType = call.argument<String>("instanceType")
                    val customerHostname = call.argument<String>("customerHostname")
                    
                    val sharedPrefs = getSharedPreferences("eisenvault_dms_credentials", MODE_PRIVATE)
                    val editor = sharedPrefs.edit()
                    
                    baseUrl?.let { editor.putString("baseUrl", it) }
                    authToken?.let { editor.putString("authToken", it) }
                    instanceType?.let { editor.putString("instanceType", it) }
                    customerHostname?.let { editor.putString("customerHostname", it) }
                    
                    editor.apply()
                    
                    Log.d("ShareActivity", "Saved DMS credentials: baseUrl=${baseUrl != null}, authToken=${authToken != null}, instanceType=$instanceType")
                    result.success(null)
                }
                "getFileContent" -> {
                    val fileUri = call.argument<String>("fileUri")
                    if (fileUri != null) {
                        try {
                            val contentResolver = contentResolver
                            val uri = android.net.Uri.parse(fileUri)
                            val inputStream = contentResolver.openInputStream(uri)
                            
                            if (inputStream != null) {
                                val bytes = inputStream.readBytes()
                                inputStream.close()
                                
                                // Get the filename from the content URI
                                var fileName = "unknown_file"
                                try {
                                    val cursor = contentResolver.query(uri, null, null, null, null)
                                    if (cursor != null) {
                                        val nameIndex = cursor.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                                        if (nameIndex >= 0 && cursor.moveToFirst()) {
                                            val displayName = cursor.getString(nameIndex)
                                            if (displayName != null && displayName.isNotEmpty()) {
                                                fileName = displayName
                                            }
                                        }
                                        cursor.close()
                                    }
                                } catch (e: Exception) {
                                    Log.w("ShareActivity", "Could not get filename, using default: ${e.message}")
                                }
                                
                                val resultMap = mapOf(
                                    "content" to bytes,
                                    "fileName" to fileName
                                )
                                
                                Log.d("ShareActivity", "Read file content: ${bytes.size} bytes, filename: $fileName from $fileUri")
                                result.success(resultMap)
                            } else {
                                Log.e("ShareActivity", "Could not open input stream for: $fileUri")
                                result.error("FILE_ERROR", "Could not read file content", null)
                            }
                        } catch (e: Exception) {
                            Log.e("ShareActivity", "Error reading file content: ${e.message}")
                            result.error("FILE_ERROR", "Error reading file: ${e.message}", null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "File URI is null", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
