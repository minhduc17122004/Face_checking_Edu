# Sơ đồ kiến trúc mobile và nhận diện khuôn mặt

```mermaid
flowchart TB
  %% =========================
  %% Flutter layer
  %% =========================
  subgraph FLUTTER["1. LỚP ỨNG DỤNG FLUTTER (Dart)"]
    direction TB

    subgraph UI["1.1 Giao diện và quản lý trạng thái"]
      direction LR
      Camera["FaceDetectorView<br/>(Camera Preview)"]
      CapturePolicy["Auto-capture policy<br/>1 mặt | size 30%-90% | giữ ổn định 2s"]
      Bloc["CheckingBloc / RegisterFaceBloc"]
      ImagePrep["Nén ảnh<br/>Resize ~400px, quality thấp"]

      Camera --> CapturePolicy --> Bloc --> ImagePrep
    end

    DartModel["FaceRecognitionResponse<br/>results[].studentId<br/>personName, pin, boundingBox, spoofResult<br/>metrics"]
    Bloc --> DartModel
  end

  %% =========================
  %% Channel
  %% =========================
  Channel["MethodChannel<br/>face_native.recognizeFace() / addImage()"]
  ImagePrep --> Channel
  Channel --> DartModel

  %% =========================
  %% Native layer
  %% =========================
  subgraph NATIVE["2. LỚP XỬ LÝ NATIVE - Plugin face_native"]
    direction TB

    Entry["Native entry point<br/>Android: FaceNativePlugin.kt<br/>iOS: FaceNativePlugin.swift"]
    Preprocess["Tiền xử lý ảnh<br/>xoay EXIF / chuẩn hóa orientation / decode bitmap"]
    Detect["Phát hiện và cắt khuôn mặt<br/>Android: MediaPipe BlazeFace<br/>iOS: ML Kit Vision"]

    Entry --> Preprocess --> Detect

    subgraph AI["2.1 Unified AI Pipeline"]
      direction TB
      Embed["Trích xuất embedding 128D<br/>FaceNet facenet_128.tflite<br/>FloatArray / [Float]"]
      Search["So khớp vector offline<br/>ObjectBox HNSW + cosine distance"]
      Spoof["Anti-spoofing<br/>MiniFASNet 2 scales<br/>spoof_model_scale_2_7 + scale_4_0"]
      Result["Chuẩn hóa kết quả native -> Dart<br/>studentId, personName, pin,<br/>boundingBox, spoofResult, metrics"]

      Embed --> Search --> Spoof --> Result
    end

    Detect --> Embed
  end

  Channel --> Entry
  Result --> Channel

  %% =========================
  %% Storage layer
  %% =========================
  subgraph STORAGE["3. LỚP LƯU TRỮ VÀ SO KHỚP OFFLINE"]
    direction LR

    ObjectBox[("ObjectBox Vector DB<br/>FaceImageRecord<br/>empId nội bộ = studentId<br/>faceEmbedding: 128D Float vector<br/>HNSW + Cosine")]
    Hive[("Hive DB<br/>Person, CheckInOut,<br/>PendingEduCheckIn, metadata")]
  end

  Search <--> ObjectBox
  Embed -->|"Enroll / import face<br/>lưu embedding"| ObjectBox
  Result -->|"Check-in / spoof flag / metadata"| Hive
  Bloc <--> Hive

  %% =========================
  %% Backend sync
  %% =========================
  subgraph SYNC["4. ĐỒNG BỘ DỮ LIỆU"]
    direction TB
    Workmanager["Workmanager background isolate"]
    ExportJson["Export face data JSON<br/>listFaceEmbedding: List<List<double>>"]
    Backend["Backend API<br/>face_embeddings.embedding: JSON array 128 float<br/>studentId contract"]

    Workmanager --> ExportJson --> Backend
    Backend -->|"Pull embeddings"| ExportJson
  end

  ObjectBox --> ExportJson
  ExportJson --> ObjectBox
  Hive <--> Workmanager

  %% =========================
  %% Notes
  %% =========================
  Note1["Ghi chú contract:<br/>Response nhận diện ra Dart chỉ dùng studentId.<br/>Không dùng employeeId trong recognizeFace."]
  Note2["Ghi chú nội bộ:<br/>empId vẫn tồn tại trong ObjectBox/native storage<br/>để tránh migration rủi ro."]
  Note3["Ghi chú anti-spoof:<br/>Trong code hiện tại, anti-spoof chạy sau embedding và vector search,<br/>rồi Flutter dùng spoofResult để chặn/đánh dấu check-in."]

  Result -.-> Note1
  ObjectBox -.-> Note2
  Spoof -.-> Note3

  classDef blue fill:#e8f3ff,stroke:#2f80ed,stroke-width:1px,color:#1f2937;
  classDef green fill:#edf9ef,stroke:#34a853,stroke-width:1px,color:#1f2937;
  classDef red fill:#fff0f0,stroke:#eb5757,stroke-width:1px,color:#1f2937;
  classDef yellow fill:#fff7e6,stroke:#f2994a,stroke-width:1px,color:#1f2937;
  classDef purple fill:#f7edff,stroke:#9b51e0,stroke-width:1px,color:#1f2937;
  classDef note fill:#f8fafc,stroke:#64748b,stroke-dasharray: 4 3,color:#1f2937;

  class Camera,CapturePolicy,Bloc,ImagePrep,DartModel blue;
  class Channel yellow;
  class Entry,Preprocess,Detect,Embed,Search,Spoof,Result green;
  class ObjectBox,Hive red;
  class Workmanager,ExportJson,Backend purple;
  class Note1,Note2,Note3 note;
```

## Contract nhận diện

```json
{
  "results": [
    {
      "studentId": 123,
      "personName": "Nguyen Van A",
      "pin": "...",
      "boundingBox": {
        "left": 0,
        "top": 0,
        "right": 100,
        "bottom": 100
      },
      "spoofResult": {
        "isSpoof": false,
        "score": 0.95,
        "timeMillis": 120
      }
    }
  ],
  "metrics": {
    "timeFaceDetection": 10,
    "timeFaceEmbedding": 30,
    "timeVectorSearch": 5,
    "timeFaceSpoofDetection": 120
  }
}
```
