import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:finalyear/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tflite/flutter_tflite.dart';
import 'dart:async';
import 'package:image/image.dart' as img;
import 'package:flutter_vision/flutter_vision.dart';

class Livecamera extends StatefulWidget {
  const Livecamera({Key? key}) : super(key: key);

  @override
  State<Livecamera> createState() => _LivecameraState();
}

class _LivecameraState extends State<Livecamera> {
  final FlutterVision vision = FlutterVision();
  late CameraController controller;
  late List<Map<String, dynamic>> yoloResults;
  CameraImage? cameraImage;
  bool isLoaded = false;
  bool isDetecting = false;

  @override
  void initState() {
    super.initState();
    init();
  }

  init() async {
    controller = CameraController(cameras[0], ResolutionPreset.max);
    controller.initialize().then((value) {
      loadYoloModel().then((value) {
        setState(() {
          isLoaded = true;
          isDetecting = false;
          yoloResults = [];
        });
      });
    });
  }

  @override
  void dispose() async {
    super.dispose();
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    if (!isLoaded) {
      return const Scaffold(
        body: Center(
          child: Text("Model not loaded, waiting for it"),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: CameraPreview(
            controller,
          ),
        ),
        ...displayBoxesAroundRecognizedObjects(size),
        Positioned(
          bottom: 75,
          width: MediaQuery.of(context).size.width,
          child: Container(
            height: 80,
            width: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  width: 5, color: Colors.white, style: BorderStyle.solid),
            ),
            child: isDetecting
                ? IconButton(
                    onPressed: () async {
                      stopDetection();
                    },
                    icon: const Icon(
                      Icons.stop,
                      color: Colors.red,
                    ),
                    iconSize: 50,
                  )
                : IconButton(
                    onPressed: () async {
                      await startDetection();
                    },
                    icon: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                    ),
                    iconSize: 50,
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> loadYoloModel() async {
    await Tflite.loadModel(
        model: "assets/yolov5.tflite",
        labels: "assets/label.txt",
        numThreads: 1, // defaults to 1
        isAsset:
            true, // defaults to true, set to false to load resources outside assets
        useGpuDelegate:
            false // defaults to false, set to true to use GPU delegate
        );
    setState(() {
      isLoaded = true;
    });
  }

  Future<void> yoloOnFrame(CameraImage cameraImage) async {
    img.Image imag = convertYUV420toImageColor(cameraImage);

    // final results = await Tflite.detectObjectOnFrame(
    //     bytesList: imageToByteListFloat32(croppedBytes!, 128, 0, 255), // required
    //     model: "YOLO",
    //     imageHeight: 640,
    //     imageWidth: 640,
    //     imageMean: 0, // defaults to 127.5
    //     imageStd: 255.0, // defaults to 127.5
    //     asynch: true // defaults to true
    //     );
    // print(results);
    // //bool unfitdetection = results.every((result) => result['tag'] == 'others');
    // if (results!.isNotEmpty) {
    //   setState(() {});
    // }
  }
  img.Image convertYUV420toImageColor(CameraImage image) {
  final int width = image.width;
  final int height = image.height;
  final int uvRowStride = image.planes[1].bytesPerRow;
  final int uvPixelStride = image.planes[1].bytesPerPixel!;

  final img.Image imgImage = img.Image(width, height);

  for (int y = 0; y < height; y++) {
    final int uvRow = (y ~/ 2) * uvRowStride;
    for (int x = 0; x < width; x++) {
      final int uvPixel = uvRow + (x ~/ 2) * uvPixelStride;

      final int yp = y * width + x;
      final int up = uvPixel;
      final int vp = uvPixel + uvRowStride ~/ 2;

      final int yValue = image.planes[0].bytes[yp];
      final int uValue = image.planes[1].bytes[up];
      final int vValue = image.planes[2].bytes[vp];

      int r = (yValue + (1.370705 * (vValue - 128))).toInt();
      int g = (yValue - (0.337633 * (uValue - 128)) - (0.698001 * (vValue - 128))).toInt();
      int b = (yValue + (1.732446 * (uValue - 128))).toInt();

      r = r.clamp(0, 255);
      g = g.clamp(0, 255);
      b = b.clamp(0, 255);

      imgImage.setPixel(x, y, img.getColor(r, g, b));
    }
  }

  return imgImage;
}
    Uint8List imageToByteListFloat32(
      img.Image image, int inputSize, double mean, double std) {
    var convertedBytes = Float32List(1 * inputSize * inputSize * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;
    for (var i = 0; i < inputSize; i++) {
      for (var j = 0; j < inputSize; j++) {
        var pixel = image.getPixel(j, i);
        buffer[pixelIndex++] = (img.getRed(pixel) - mean) / std;
        buffer[pixelIndex++] = (img.getGreen(pixel) - mean) / std;
        buffer[pixelIndex++] = (img.getBlue(pixel) - mean) / std;
      }
    }
    return convertedBytes.buffer.asUint8List();
  }

  Future<void> startDetection() async {
    setState(() {
      isDetecting = true;
    });
    if (controller.value.isStreamingImages) {
      return;
    }
    await controller.startImageStream((image) async {
      if (isDetecting) {
        cameraImage = image;
        await yoloOnFrame(image);
      }
    });
  }

  Future<void> stopDetection() async {
    setState(() {
      isDetecting = false;
      yoloResults.clear();
    });
  }

  List<Widget> displayBoxesAroundRecognizedObjects(Size screen) {
    if (yoloResults.isEmpty) return [];
    double factorX = screen.width / (cameraImage?.height ?? 1);
    double factorY = screen.height / (cameraImage?.width ?? 1);

    Color colorPick = const Color.fromARGB(255, 50, 233, 30);

    return yoloResults.map((result) {
      return Positioned(
        left: result["box"][0] * factorX,
        top: result["box"][1] * factorY,
        width: (result["box"][2] - result["box"][0]) * factorX,
        height: (result["box"][3] - result["box"][1]) * factorY,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(10.0)),
            border: Border.all(color: Colors.pink, width: 2.0),
          ),
          child: Text(
            "${result['tag']} ${(result['box'][4] * 100).toStringAsFixed(0)}%",
            style: TextStyle(
              background: Paint()..color = colorPick,
              color: Colors.white,
              fontSize: 18.0,
            ),
          ),
        ),
      );
    }).toList();
  }
}
