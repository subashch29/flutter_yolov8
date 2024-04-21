import 'dart:developer';

import 'package:camera/camera.dart';
import 'package:flutter_tflite/flutter_tflite.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

class ScanController extends GetxController {
  @override
  void onInit() {
    super.onInit();
    initCamera();
    initTFLite();
  }

  @override
  void dispose() {
    super.dispose();
    cameraController.dispose();
  }

  late CameraController cameraController;
  late List<CameraDescription> cameras;

  var isCameraInitialized = false.obs;
  var cameraCount = 0;

  var x = 0.0;
  var y = 0.0;
  var h = 0.0;
  var w = 0.0;
  var label = "";

  initCamera() async {
    if (await Permission.camera.request().isGranted) {
      cameras = await availableCameras();
      //for front camera use cameras[1 ]
      cameraController = CameraController(cameras[0], ResolutionPreset.max);
      await cameraController.initialize().then((value) {
        cameraController.startImageStream((image) {
          cameraCount++;
          if (cameraCount % 10 == 0) {
            cameraCount = 0;
            objectDetector(image);
          }
          update();
        });
      });
      isCameraInitialized(true);
      update();
    } else {
      log("Permission Denied");
    }
  }

  initTFLite() async {
    await Tflite.loadModel(
        model: "assets/model_main.tflite",
        // labels: "assets/labels_main.txt",
        isAsset: true);
  }

  bool isModelRunning = false;

  objectDetector(CameraImage image) async {
    if (isModelRunning) {
      return; // Skip if model is already running
    }
    isModelRunning = true;

    try {
      var detector = await Tflite.detectObjectOnFrame(
          bytesList: image.planes.map((e) {
            return e.bytes;
          }).toList(),
          model: "YOLO",
          imageHeight: image.height,
          imageWidth: image.width,
          imageMean: 0,
          imageStd: 255.0,
          numResultsPerClass: 1,
          threshold: 0.2,
          asynch: true);

      if (detector != null) {
        var ourDetectedObject = detector.first;
        if (ourDetectedObject['confidenceInClass'] * 100 > 45) {
          label = ourDetectedObject['detectedClass'].toString();
          log("label is $label");
          log(ourDetectedObject['confidenceInClass'].toString());
          h = ourDetectedObject['rect']['h'];
          w = ourDetectedObject['rect']['w'];
          x = ourDetectedObject['rect']['x'];
          y = ourDetectedObject['rect']['y'];
        }
        update();
        log("Result is $detector");
      } else {
        Tflite.close(); // Close the interpreter after processing
      }
    } catch (e) {
      log("Error during inference: $e");
    } finally {
      isModelRunning = false;
    }
  }
}
