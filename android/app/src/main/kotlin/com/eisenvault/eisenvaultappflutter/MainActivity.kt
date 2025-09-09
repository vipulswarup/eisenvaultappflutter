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
                    
                    val sharedPrefs = getSharedPreferences("eisenvault_dms_credentials", Context.MODE_PRIVATE)
                    val editor = sharedPrefs.edit()
                    
                    baseUrl?.let { editor.putString("baseUrl", it) }
                    authToken?.let { editor.putString("authToken", it) }
                    instanceType?.let { editor.putString("instanceType", it) }
                    customerHostname?.let { editor.putString("customerHostname", it) }
                    
                    editor.apply()
                    
                    Log.d("MainActivity", "Saved DMS credentials: baseUrl=${baseUrl != null}, authToken=${authToken != null}, instanceType=$instanceType")
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
