$webRaw = firebase apps:sdkconfig WEB 1:374362788587:web:e62317854ea9628dbae4ae | Out-String
function Get-Val($raw, $name) {
  $p = '"' + $name + '"\s*:\s*"([^"]*)"'
  if ($raw -match $p) { return $Matches[1] } else { return '' }
}
$g = Get-Content android\app\google-services.json -Raw | ConvertFrom-Json
$c = $g.client[0]
$aKey = $c.api_key[0].current_key
$aApp = $c.client_info.mobilesdk_app_id
$sender = $g.project_info.project_number
$proj = $g.project_info.project_id
$bucket = $g.project_info.storage_bucket
$wKey = Get-Val $webRaw 'apiKey'
$wApp = Get-Val $webRaw 'appId'
$wDomain = Get-Val $webRaw 'authDomain'
if ($wDomain -eq '') { $wDomain = "$proj.firebaseapp.com" }
$wBucket = Get-Val $webRaw 'storageBucket'
if ($wBucket -eq '') { $wBucket = $bucket }
$wSender = Get-Val $webRaw 'messagingSenderId'
if ($wSender -eq '') { $wSender = $sender }

$dart = @"
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('Firebase is only set up for Android and Web.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: '$wKey',
    appId: '$wApp',
    messagingSenderId: '$wSender',
    projectId: '$proj',
    authDomain: '$wDomain',
    storageBucket: '$wBucket',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: '$aKey',
    appId: '$aApp',
    messagingSenderId: '$sender',
    projectId: '$proj',
    storageBucket: '$bucket',
  );
}
"@
$dart | Out-File -Encoding ascii lib\firebase_options.dart
Select-String -Path lib\firebase_options.dart -Pattern "apiKey|appId|projectId"