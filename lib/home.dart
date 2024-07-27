import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_tflite/flutter_tflite.dart';
import 'package:image/image.dart' as img;
import 'dart:ui' as ui;
import 'package:flutter_vision/flutter_vision.dart';
import 'package:image_picker/image_picker.dart';

class Aidetector extends StatefulWidget {
  const Aidetector({Key? key}) : super(key: key);

  @override
  State<Aidetector> createState() => _AidetectorState();
}

class _AidetectorState extends State<Aidetector> {
  FlutterVision vision = FlutterVision();

  late List<Map<String, dynamic>> yoloResults;
  File? imageFile;
  int imageHeight = 1;
  int imageWidth = 1;
  bool isLoaded = false;
  bool detecting = false;
  bool unfitImage = false;
  bool saving = false;
  Uint8List? _croppedImageBytes;
  int? _croppedImageWidth;
  int? _croppedImageHeight;
  Uint8List? croppedImageBytes;
  GlobalKey _globalKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    loadModels().then((value) {
      setState(() {
        yoloResults = [];
        isLoaded = true;
      });
    });
  }

  @override
  void dispose() async {
    super.dispose();
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
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        leading: BackButton(),
        title: Text('AI Meat detector'),
      ),
      body: Stack(
        children: [
          detecting
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: Colors.black54,
                      ),
                      SizedBox(
                        height: 10,
                      ),
                      Text('Detecting......')
                    ],
                  ),
                )
              : imageFile != null && unfitImage == false
                  ? RepaintBoundary(
                      key: _globalKey,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(
                            imageFile!,
                          ),
                          ...displayBoxesAroundRecognizedObjects(size),
                        ],
                      ),
                    )
                  : unfitImage == true
                      ? const Center(
                          child: Text(
                              'The image is not fit for our AI detector',
                              style: TextStyle(fontWeight: FontWeight.w500)),
                        )
                      : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image,
                                size: 80,
                              ),
                              Text(
                                'Select an Image',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
          Padding(
            padding: const EdgeInsets.only(
                bottom: 10.0, left: 15, right: 15, top: 15),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Predictionhelper(Colors.green, "Fresh"),
                    Predictionhelper(Colors.yellow, "Half-Fresh"),
                    Predictionhelper(Colors.red, "Spoiled"),
                  ],
                ),
                SizedBox(
                  height: 20,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        fixedSize: Size(170, 50),
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                      ),
                      onPressed: photoSelector,
                      child: const Text(
                        "Select and Detect",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(6),
                        fixedSize: const Size(150, 45),
                        backgroundColor:
                            unfitImage == false && imageFile != null
                                ? Colors.black
                                : Colors.black45,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                      ),
                      onPressed: () async {
                        setState(() {
                          saving = true;
                        });
                        if (unfitImage == false && imageFile != null) {
                          Uint8List? imagebytes = await _capturePng();
                          if (imagebytes != null) {
                            showimage(imagebytes);
                          }
                        }
                        setState(() {
                          saving = false;
                        });
                      },
                      child: saving
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                          : const Text(
                              "Save",
                              style: TextStyle(color: Colors.white),
                            ),
                    )
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      // floatingActionButton: Padding(
      //   padding: const EdgeInsets.only(bottom: 50.0),
      //   child: FloatingActionButton(
      //     backgroundColor: Colors.black54,
      //     shape: const CircleBorder(),
      //     onPressed: () async {
      //       //await Tflite.close();
      //       Navigator.push(context,
      //           MaterialPageRoute(builder: (context) => const Livecamera()));
      //     },
      //     child: const Icon(
      //       Icons.camera_alt,
      //       color: Colors.white,
      //     ),
      //   ),
      // )
    );
  }

  Column Predictionhelper(Color bordercolor, String prediction) {
    return Column(
      children: [
        Container(
          //height: 40,
          decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(10.0)),
              border: Border.all(color: bordercolor, width: 3)),
          child: SizedBox(
            height: 70,
            width: 70,
          ),
        ),
        SizedBox(
          height: 10,
        ),
        Text(
          prediction,
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        )
      ],
    );
  }

  Future<void> loadModels() async {
    await vision.loadYoloModel(
        labels: 'assets/label.txt',
        modelPath: 'assets/yolov5.tflite',
        modelVersion: "yolov5",
        quantization: false,
        numThreads: 1,
        useGpu: false);
    await Tflite.loadModel(
        model: "assets/model.tflite",
        labels: "assets/labels.txt",
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

  void photoSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
                child: Text(
              'Select picture',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 17),
            )),
            SizedBox(
              height: 10,
            ),
            ListTile(
              titleAlignment: ListTileTitleAlignment.center,
              contentPadding: EdgeInsets.zero,
              onTap: () {
                pickImage(ImageSource.camera);
                Navigator.pop(context);
              },
              leading: Icon(
                Icons.camera_alt,
                color: Colors.black,
              ),
              title: Text('Camera'),
            ),
            SizedBox(
              height: 10,
            ),
            ListTile(
              titleAlignment: ListTileTitleAlignment.center,
              contentPadding: EdgeInsets.zero,
              onTap: () {
                pickImage(ImageSource.gallery);
                Navigator.pop(context);
              },
              leading: Icon(
                Icons.open_in_browser,
                color: Colors.black,
              ),
              title: Text('Gallery'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> pickImage(ImageSource source) async {
    setState(() {
      unfitImage = false;
    });
    final ImagePicker picker = ImagePicker();
    // Capture a photo
    final XFile? photo = await picker.pickImage(source: source);
    if (photo != null) {
      setState(() {
        imageFile = File(photo.path);
        detecting = true;
      });
      List<Map<String, dynamic>> results = await yoloOnImage();
      bool unfitdetection =
          results.every((result) => result['tag'] == 'others');

      if (results.isNotEmpty && unfitdetection == false) {
        List<Map<String, dynamic>> recognitions = await classifyImage(results);
        print(recognitions);
        setState(() {
          yoloResults = recognitions;
        });
      } else {
        setState(() {
          unfitImage = true;
        });
      }
      setState(() {
        detecting = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> yoloOnImage() async {
    yoloResults.clear();

    Uint8List byte = await imageFile!.readAsBytes();
    final image = await decodeImageFromList(byte);
    imageHeight = image.height;
    imageWidth = image.width;
    final result = await vision.yoloOnImage(
        bytesList: byte,
        imageHeight: image.height,
        imageWidth: image.width,
        iouThreshold: 0.8,
        confThreshold: 0.4,
        classThreshold: 0.5);

    // if (result.isNotEmpty) {
    //   List<Map<String, dynamic>> recognitions = await classifyImage(result);
    //   setState(() {
    //     yoloResults = result;
    //     detecting = false;
    //   });
    // }
    return result;
  }

  Future<List<Map<String, dynamic>>> classifyImage(
      List<Map<String, dynamic>> postionResults) async {
    List<Map<String, dynamic>> finalRecognition = [];

    for (var result in postionResults) {
      if (result["tag"] == "meat") {
        img.Image? croppedBytes = await cropImage(
            imageFile!,
            result["box"][0].round(),
            result["box"][1].round(),
            result["box"][2].round(),
            result["box"][3].round());

        if (croppedBytes != null) {
          setState(() {
            Uint8List croppedImageBytes =
                Uint8List.fromList(img.encodePng(croppedBytes));
          });
          print(croppedImageBytes);
          var recognitions = await Tflite.runModelOnBinary(
              binary:
                  imageToByteListFloat32(croppedBytes, 128, 0, 255), // required
              numResults: 6, // defaults to 5
              threshold: 0.05, // defaults to 0.1
              asynch: true // defaults to true
              );

          //   index: 0,
          //   label: "person",
          //   confidence: 0.629
          // }
          finalRecognition.add({
            'box': [
              result["box"][0],
              result["box"][1],
              result["box"][2],
              result["box"][3],
              result["box"][4],
            ],
            'tag': result["tag"],
            'class': recognitions![0]
          });
        }
      }
    }
    print(finalRecognition);
    return finalRecognition;
  }

  List<Widget> displayBoxesAroundRecognizedObjects(Size screen) {
    if (yoloResults.isEmpty) return [];

    double factorX = screen.width / (imageWidth);
    double imgRatio = imageWidth / imageHeight;
    double newWidth = imageWidth * factorX;
    double newHeight = newWidth / imgRatio;
    double factorY = newHeight / (imageHeight);

    double pady = (((screen.height) - newHeight) / 2) - 45;

    Color colorPick = const Color.fromARGB(255, 50, 233, 30);
    return yoloResults.map((result) {
      return Positioned(
        left: (result["box"][0] * factorX) - 5,
        top: (result["box"][1] * factorY + pady),
        width: (result["box"][2] - result["box"][0]) * factorX,
        height: (result["box"][3] - result["box"][1]) * factorY,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(10.0)),
            border: Border.all(
                color: result['class']['label'] == 'Spoiled'
                    ? Colors.red
                    : result['class']['label'] == 'Half-fresh'
                        ? Colors.yellow
                        : result['class']['label'] == 'Fresh'
                            ? Colors.green
                            : Colors.blue,
                width: 2.0),
          ),
          child: Text(
            "${result['class']['label']} ${(result['class']['confidence'] * 100).toStringAsFixed(2)}%",
            style: TextStyle(
              background: Paint()..color = colorPick,
              color: Colors.white,
            ),
          ),
        ),
      );
    }).toList();
  }

  Future<img.Image?> cropImage(
      File imageFile, int left, int top, int right, int bottom) async {
    try {
      // Read the image file as bytes
      final imageBytes = imageFile.readAsBytesSync();

      // Decode the image
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Ensure the coordinates are within the bounds of the image
      left = left.clamp(0, image.width);
      top = top.clamp(0, image.height);
      right = right.clamp(0, image.width);
      bottom = bottom.clamp(0, image.height);

      // Crop the image
      img.Image croppedImage =
          img.copyCrop(image, left, top, right - left, bottom - top);

      img.Image resizedImage =
          img.copyResize(croppedImage, height: 128, width: 128);

      // Update the cropped image dimensions
      setState(() {
        _croppedImageWidth = croppedImage.width;
        _croppedImageHeight = croppedImage.height;
      });

      // Encode the cropped image to bytes
      //final croppedBytes = img.encodePng(croppedImage);

      return resizedImage;
    } catch (e) {
      print('Error cropping image: $e');
      return null;
    }
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

  Future<Uint8List?> _capturePng() async {
    try {
      print('inside');
      RenderRepaintBoundary boundary = _globalKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();
      img.Image? im = img.decodeImage(pngBytes);
      int newHeight = im!.height - 550 - 700;
      img.Image croppedImage = img.copyCrop(im, 0, 700, im.width, newHeight);
      // Resize the image
      //img.Image resized = img.copyResize(im!, width: 500, height: 700);

      // Encode the resized image to PNG
      Uint8List resizedPngBytes =
          Uint8List.fromList(img.encodePng(croppedImage));

      print(base64Encode(pngBytes));
      return resizedPngBytes;
    } catch (e) {
      print(e);
    }
  }

  void showimage(Uint8List imagebytes) {
    showModalBottomSheet(
        context: context,
        builder: (context) => Padding(
              padding: MediaQuery.of(context).viewInsets,
              child: Container(
                  padding:
                      EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 20),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Save your prediction',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 17),
                            ),
                            Icon(
                              Icons.check_box_rounded,
                              color: Colors.green,
                              size: 30,
                            )
                          ],
                        ),
                        SizedBox(
                          height: 15,
                        ),
                        Image.memory(
                          imagebytes,
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(6),
                            fixedSize: const Size(150, 45),
                            backgroundColor: Colors.black54,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20.0),
                            ),
                          ),
                          onPressed: () async {
                            setState(() {
                              saving = true;
                            });

                            setState(() {
                              saving = false;
                            });
                          },
                          child: saving
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  "Save",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                        )
                      ],
                    ),
                  )),
            ));
  }
}
