import 'dart:convert';

LivenessDetectionLabelModel livenessDetectionLabelModelFromJson(String str) =>
    LivenessDetectionLabelModel.fromJson(json.decode(str));

String livenessDetectionLabelModelToJson(LivenessDetectionLabelModel data) =>
    json.encode(data.toJson());

class LivenessDetectionLabelModel {
  String? lookUp;
  String? lookDown;
  String? lookLeft;
  String? lookRight;
  String? straightFace;
  String? smile;
  String? blink;

  LivenessDetectionLabelModel({
    this.lookUp,
    this.lookDown,
    this.lookLeft,
    this.lookRight,
    this.straightFace,
    this.smile,
    this.blink,
  });

  factory LivenessDetectionLabelModel.fromJson(Map<String, dynamic> json) =>
      LivenessDetectionLabelModel(
        lookUp: json["lookUp"],
        lookDown: json["lookDown"],
        lookLeft: json["lookLeft"],
        lookRight: json["lookRight"],
        straightFace: json["straightFace"],
        smile: json["smile"],
        blink: json["blink"],
      );

  Map<String, dynamic> toJson() => {
        "lookUp": lookUp,
        "lookDown": lookDown,
        "lookLeft": lookLeft,
        "lookRight": lookRight,
        "straightFace": straightFace,
        "smile": smile,
        "blink": blink,
      };
}
