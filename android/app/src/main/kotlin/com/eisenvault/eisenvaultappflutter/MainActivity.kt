package com.eisenvault.eisenvaultappflutter

import android.content.Context
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.eisenvault.eisenvaultappflutter/main"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveDMSCredentials" -> {
                    val baseUrl = call.argument<String>("baseUrl")
                    val authToken = call.argument<String>("authToken")
                    val instanceType = call.argument<String>("instanceType")
                    val customerHostname = call.argument<String>("customerHostname")
                    
                    Log.d("MainActivity", "=== SAVING DMS CREDENTIALS ===")
                    Log.d("MainActivity", "baseUrl: ${baseUrl != null}")
                    Log.d("MainActivity", "authToken: ${authToken != null}")
                    Log.d("MainActivity", "instanceType: $instanceType")
                    Log.d("MainActivity", "customerHostname: $customerHostname")
                    
                    val sharedPrefs = getSharedPreferences("eisenvault_dms_credentials", Context.MODE_PRIVATE)
                    val editor = sharedPrefs.edit()
                    
                    baseUrl?.let { editor.putString("baseUrl", it) }
                    authToken?.let { editor.putString("authToken", it) }
                    instanceType?.let { editor.putString("instanceType", it) }
                    customerHostname?.let { editor.putString("customerHostname", it) }
                    
                    val success = editor.commit() // Use commit() instead of apply() for immediate write
                    
                    Log.d("MainActivity", "DMS credentials saved successfully: $success")
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
