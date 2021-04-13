package com.otaupgradehandler.ota_upgrade_handler

import android.Manifest
import android.app.Activity
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.util.Log
import androidx.annotation.NonNull
import androidx.annotation.RequiresApi
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.*


/** OtaUpgradeHandlerPlugin */
class OtaUpgradeHandlerPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel: MethodChannel
  private lateinit var context: Context
  private lateinit var activity: Activity

  override fun onAttachedToEngine(
          @NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding
  ) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "ota_upgrade_handler")
    channel.setMethodCallHandler(this)
    context = flutterPluginBinding.applicationContext
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    if (call.method == "getPlatformVersion") {
      result.success("Android ${android.os.Build.VERSION.RELEASE}")
    } else if (call.method == "externalFilesDir") {
      result.success(context.getExternalFilesDir(null).toString())
      //result.success(context.filesDir.toString())
    } else if (call.method == "installApk") {

      Log.d("OTA_UPGRADE_HANDLER", "Install apk-File started")
      val apkFileName = call.argument<String>("apkFileName")
    
      if (apkFileName.isNullOrEmpty()) {
        result.error("NO_APK_FILENAME_PROVIDED", "Please set an apk.-Filename", null)
      }
      Log.d("OTA_UPGRADE_HANDLER", "apk-Filename: $apkFileName")

      val fullApkPath = context.getExternalFilesDir(null).toString() + "/" + apkFileName
      //val fullApkPath = context.filesDir.toString() + "/" + apkFileName

      Log.d("OTA_UPGRADE_HANDLER", "FullApkPath: $fullApkPath")





      if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP) {
        Log.d("OTA_UPGRADE_HANDLER", "Greater than LOLLIPOP")
     

          installPackageWithIntent(context, "installApkUpdateWithUpgradeHandler", context.packageName, fullApkPath)
         
          result.success("New app version was installed")

      } else {
        result.error(
                "MIN_ANDROID_LOLLIPOP_REQUIRED", "Your Android Version is too old to update", null)
      }


    } else {
      result.notImplemented()
    }
  }

  fun installPackageWithIntent(
          context: Context,
          installSessionId: String?,
          packageName: String?,
          fullApkPath: String
  ) {
    //TRIGGER APK INSTALLATION
    val intent: Intent
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
      val providerAuth = context.getPackageName().toString() + "." + "otaupgradehandler_provider"
      val file = File(fullApkPath);
      val apkUri: Uri = FileProvider.getUriForFile(context, providerAuth, file)

      context.grantUriPermission(context.getPackageName(),apkUri,Intent.FLAG_GRANT_READ_URI_PERMISSION );
      val auxFile = File(apkUri.path)
      Log.d("OTA_UPGRADE_HANDLER", "Uri path ${apkUri.path}")
      Log.d("OTA_UPGRADE_HANDLER", "auxFileLength ${auxFile.length().toString()}")
      Log.d("OTA_UPGRADE_HANDLER", "providerAuth ${providerAuth.toString()}")
      
      Log.d("OTA_UPGRADE_HANDLER", "ApkUri ${apkUri.toString()}")
      Log.d("OTA_UPGRADE_HANDLER", "FileSize ${file.length().toString()}")
      

      //AUTHORITY NEEDS TO BE THE SAME ALSO IN MANIFEST
      //val apkUri: Uri = FileProvider.getUriForFile(context, providerAuth, downloadedFile)
      intent = Intent(Intent.ACTION_INSTALL_PACKAGE)
      intent.setData(apkUri)
      intent.setFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
              .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

      val intent = Intent(Intent.ACTION_VIEW)
      intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
      intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
      intent.putExtra(Intent.EXTRA_NOT_UNKNOWN_SOURCE, true)
      intent.data = apkUri


    } else {
      val fileUri: Uri = Uri.parse("file://$fullApkPath")
      Log.d("OTA_UPGRADE_HANDLER", "File Uri ${fileUri.toString()}")
      intent = Intent(Intent.ACTION_VIEW)
      intent.flags = Intent.FLAG_ACTIVITY_CLEAR_TOP
      intent.setDataAndType(
              fileUri,
              "\"application/vnd.android.package-archive\""
      )
    }
    context.startActivity(intent)
    Log.d("OTA_UPGRADE_HANDLER", "Started install activity")
  }


  @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
  @Throws(IOException::class)
  fun installPackageWithPackageManager(
          context: Context,
          installSessionId: String?,
          packageName: String?,
          apkStream: InputStream
  ) {
    val packageManger = context.packageManager
    val packageInstaller = packageManger.packageInstaller
    val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
    params.setAppPackageName(packageName)
   
    var session: PackageInstaller.Session? = null
    try {
      val sessionId = packageInstaller.createSession(params)
      session = packageInstaller.openSession(sessionId)
      Log.d("OTA_UPGRADE_HANDLER", "OpenSession")
      val out: OutputStream = session.openWrite(installSessionId!!, 0, -1)
      Log.d("OTA_UPGRADE_HANDLER", "OutputStream created")
      val buffer = ByteArray(1024)
      var length: Int = 0
      var count = 0
      while (apkStream.read(buffer).also({ length = it }) != -1) {
        Log.d("OTA_UPGRADE_HANDLER", "Apk Stream Read" + count + "length " + length)
        out.write(buffer, 0, length)
        count += length
      }
      session.fsync(out)
      out.close()
      Log.d("OTA_UPGRADE_HANDLER", "OutputStream closed")
      val intent = Intent(Intent.ACTION_PACKAGE_ADDED)
      session.commit(
              PendingIntent.getBroadcast(context, sessionId, intent, PendingIntent.FLAG_UPDATE_CURRENT)
                      .intentSender)
    } catch (e: IOException) {
      Log.e("OTA_UPGRADE_HANDLER", e.message.toString())
    } finally {
      session?.close()
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onDetachedFromActivity() {
    TODO("Not yet implemented")
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    TODO("Not yet implemented")
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivityForConfigChanges() {
    TODO("Not yet implemented")
  }
}
