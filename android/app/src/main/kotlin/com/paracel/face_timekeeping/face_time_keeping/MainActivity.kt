package com.example.face_time_keeping
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity()



// import android.graphics.BitmapFactory
// import android.os.Build

// import com.paracel.face_timekeeping.face_time_keeping.domain.ImageVectorUseCase
// import com.paracel.face_timekeeping.face_time_keeping.data.FaceImageRecord
// import io.flutter.embedding.android.FlutterActivity
// import io.flutter.embedding.engine.FlutterEngine
// import io.flutter.plugin.common.MethodChannel
// import kotlinx.coroutines.CoroutineScope
// import kotlinx.coroutines.Dispatchers
// import kotlinx.coroutines.launch
// import kotlinx.coroutines.withContext
// import org.koin.android.ext.android.inject
// import androidx.core.net.toUri
// import android.util.Log
// import com.paracel.face_timekeeping.face_time_keeping.data.ObjectBoxStore
// import com.paracel.face_timekeeping.face_time_keeping.di.AppModule
// import org.koin.android.ext.koin.androidContext
// import org.koin.core.context.startKoin

// class MainActivity : FlutterActivity() {

//     private val METHOD_CHANNEL = "com.paracel.face_native/methods"


//     private val imageVectorUseCase: ImageVectorUseCase by inject()


//     override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
//         super.configureFlutterEngine(flutterEngine)
//         android.util.Log.d("NativeDemo", "APPLICATION_ID=")
//         // 1) MethodChannel: one-off requests/replies
//         MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
//             .setMethodCallHandler { call, result ->
//                 when (call.method) {
//                     "initObjectBox" ->{
//                         val tenantKey = call.argument<String>("tenantKey")
//                         if (tenantKey != null) {
//                             val initSuccess = ObjectBoxStore.init(this, tenantKey)
//                             if (initSuccess) {
//                                 // Only initialize Koin if ObjectBox init was successful and Koin is not already started
//                                 try {
//                                     if (org.koin.core.context.GlobalContext.getOrNull() == null) {
//                                         startKoin {
//                                             androidContext(this@MainActivity)
//                                             modules(AppModule().module)
//                                         }
//                                     }
//                                     result.success(true)
//                                 } catch (e: Exception) {
//                                     Log.e("MainActivity", "Failed to initialize Koin", e)
//                                     result.error("INIT_KOIN_ERROR", "Failed to initialize dependency injection: ${e.message}", null)
//                                 }
//                             } else {
//                                 result.error("INIT_OBJECT_BOX_ERROR", "Failed to initialize ObjectBox", null)
//                             }
//                         } else {
//                             result.error("INIT_OBJECT_BOX_ERROR", "Tenant key is required", null)
//                         }
//                     }
//                     "getFaceImageRecordByListEmpId" -> {
//                         val empIdList = call.argument<List<Long>>("empIdList")
//                         if (empIdList != null) {
//                             val records = imageVectorUseCase.getFaceImageRecordByListEmpId(empIdList)
//                             val recordsMap = records.map { record ->
//                                 mapOf(
//                                     "empId" to record.empId,
//                                         "personName" to record.personName,
//                                         "faceEmbedding" to record.faceEmbedding?.toList()
//                                 )
//                             }
//                             result.success(recordsMap)
//                         } else {
//                             result.error("GET_FACE_IMAGE_RECORD_BY_LIST_EMP_ID_ERROR", "EmpId list is required", null)
//                         }
//                     }
//                     "getPlatformVersion" -> {
//                         val version = "Android ${Build.VERSION.RELEASE} (SDK ${Build.VERSION.SDK_INT})"
//                         result.success(version)
//                     }
//                     "getCount" -> {
//                         try {
//                             val count = imageVectorUseCase.getCount()
//                             result.success(count)
//                         } catch (e: Exception) {
//                             result.error("GET_COUNT_ERROR", e.message, null)
//                         }
//                     }
//                     "addAllRecords" -> {
//                         try {
//                             val imageMaps = call.argument<List<Map<String, Any?>>>("records")
//                             val records = imageMaps
//                                 ?.mapNotNull { map ->
//                                     val empId = (map["empId"] as? Number)?.toLong() ?: 0L
//                                     val personName = map["personName"] as? String
//                                     val faceEmbeddingList = map["faceEmbedding"] as? List<*>
//                                     val faceEmbedding = faceEmbeddingList
//                                         ?.mapNotNull { it as? Number }
//                                         ?.map { it.toFloat() }
//                                         ?.toFloatArray()
//                                     if (personName != null && faceEmbedding != null) {
//                                         FaceImageRecord(
//                                             empId = empId,
//                                             personName = personName,
//                                             faceEmbedding = faceEmbedding
//                                         )
//                                     } else {
//                                         null
//                                     }
//                                 }
//                             if (records != null) {
//                                 imageVectorUseCase.addAllRecords(records)
//                                 result.success(true)
//                             } else {
//                                 result.error("ADD_ALL_RECORDS_ERROR", "Invalid records data", null)
//                             }
//                         } catch (e: Exception) {
//                             result.error("ADD_ALL_RECORDS_ERROR", e.message, null)
//                         }
//                     }
//                     "getAllImages" -> {
//                         try {
//                             val images = imageVectorUseCase.getAllImages()
//                             val imageList = images
//                                 .filter {  it.personName != null && it.faceEmbedding != null }
//                                 .map { image ->
//                                     mapOf(
//                                         "empId" to image.empId,
//                                         "personName" to image.personName,
//                                         "faceEmbedding" to image.faceEmbedding
//                                     )
//                                 }
//                             result.success(imageList)
//                         } catch (e: Exception) {
//                             result.error("GET_ALL_IMAGES_ERROR", e.message, null)
//                         }
//                     }
//                     "getDatabaseSizeInBytes" -> {
//                         try {
//                             val sizeInBytes = imageVectorUseCase.getDatabaseSizeInBytes()
//                             result.success(sizeInBytes)
//                         } catch (e: Exception) {
//                             result.error("GET_DATABASE_SIZE_ERROR", e.message, null)
//                         }
//                     }
//                     "clearAllImages" -> {
//                         try {
//                             imageVectorUseCase.clearAllImages()
//                             result.success(true)
//                         } catch (e: Exception) {
//                             result.error("CLEAR_IMAGES_ERROR", e.message, null)
//                         }
//                     }
//                     "addImage" -> {
//                         val empId = call.argument<Int>("empId")?.toLong() // Using empId but called personId for compatibility
//                         val personName = call.argument<String>("personName")
//                         val imageUri = call.argument<String>("imageUri")
//      Log.d("NativeDemo", "addImage called with empId=$empId, personName=$personName, imageUri=$imageUri")
//                         if (empId != null && personName != null && imageUri != null) {
//                             CoroutineScope(Dispatchers.IO).launch {
//                                 try {
//                                     val uri = imageUri.toUri()
//                                         val addResult = imageVectorUseCase.addImage(empId, personName, uri)
//                                     withContext(Dispatchers.Main) {
//                                         if (addResult.isSuccess) {
//                                             result.success(addResult.getOrNull())
//                                         } else {
//                                             result.error("ADD_IMAGE_ERROR", addResult.exceptionOrNull()?.message, null)
//                                         }
//                                     }
//                                 } catch (e: Exception) {
//                                     withContext(Dispatchers.Main) {
//                                         result.error("ADD_IMAGE_ERROR", e.message, null)
//                                     }
//                                 }
//                             }
//                         } else {
//                             result.error("INVALID_ARGUMENTS", "PersonId, personName, and imageUri are required", null)
//                         }
//                     }
//                     "recognizeFace" -> {
//                         val imageBytes = call.argument<ByteArray>("imageBytes")

//                         if (imageBytes != null) {
//                             CoroutineScope(Dispatchers.IO).launch {
//                                 try {

//                                     val bitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)

//                                     val (metrics, recognitionResults) = imageVectorUseCase.getNearestPersonName(bitmap)

//                                     // Convert results to map for Flutter
//                                     val resultsMap = recognitionResults.map { result ->
//                                         mapOf(
//                                             "employeeId" to result.empId,
//                                             "personName" to result.personName,
//                                             "boundingBox" to mapOf(
//                                                 "left" to result.boundingBox.left,
//                                                 "top" to result.boundingBox.top,
//                                                 "right" to result.boundingBox.right,
//                                                 "bottom" to result.boundingBox.bottom
//                                             ),
//                                             "spoofResult" to result.spoofResult?.let { spoof ->
//                                                 mapOf(
//                                                     "isSpoof" to spoof.isSpoof,
//                                                     "score" to spoof.score,
//                                                     "timeMillis" to spoof.timeMillis
//                                                 )
//                                             }
//                                         )
//                                     }

//                                     val responseMap = mapOf(
//                                         "results" to resultsMap,
//                                         "metrics" to metrics?.let { m ->
//                                             mapOf(
//                                                 "timeFaceDetection" to m.timeFaceDetection,
//                                                 "timeFaceEmbedding" to m.timeFaceEmbedding,
//                                                 "timeVectorSearch" to m.timeVectorSearch,
//                                                 "timeFaceSpoofDetection" to m.timeFaceSpoofDetection
//                                             )
//                                         }
//                                     )

//                                     withContext(Dispatchers.Main) {
//                                         result.success(responseMap)
//                                     }
//                                 } catch (e: Exception) {
//                                     withContext(Dispatchers.Main) {
//                                         result.error("RECOGNIZE_FACE_ERROR", e.message, null)
//                                     }
//                                 }
//                             }
//                         } else {
//                             result.error("INVALID_ARGUMENTS", "base64Image is required", null)
//                         }
//                     }
//                     "removeImages" -> {
//                         val empId = call.argument<Int>("empId")?.toLong() // Using empId but called personId for compatibility

//                         if (empId != null) {
//                             try {
//                                 imageVectorUseCase.removeImages(empId)
//                                 result.success(true)
//                             } catch (e: Exception) {
//                                 result.error("REMOVE_IMAGES_ERROR", e.message, null)
//                             }
//                         } else {
//                             result.error("INVALID_ARGUMENTS", "PersonId is required", null)
//                         }
//                     }
//                     else -> result.notImplemented()
//                 }
//             }
//     }


// }
