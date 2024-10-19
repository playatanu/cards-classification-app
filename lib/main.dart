import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tflite/flutter_tflite.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'dart:developer' as devtools;

Future<void> main() async {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  File? filePath;
  String outputText = '';
  List<CameraDescription> cameras = [];
  CameraController? cameraController;
  bool isFontCamera = true;

  FlutterTts flutterTts = FlutterTts();

  @override
  void initState() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky,
        overlays: [SystemUiOverlay.bottom]);
    _tfLteInit();
    _setupCameraContoller();
    super.initState();
  }

  @override
  void dispose() {
    Tflite.close();
    super.dispose();
  }

  // Load tfLite Model
  Future<void> _tfLteInit() async {
    String? res = await Tflite.loadModel(
        model: "assets/cards_models_float32.tflite",
        labels: "assets/cards_models_labels.txt",
        numThreads: 1, // defaults to 1
        isAsset:
            true, // defaults to true, set to false to load resources outside assets
        useGpuDelegate:
            false // defaults to false, set to true to use GPU delegate
        );

    devtools.log(res!);
  }

  // Setup Camera Controller
  Future<void> _setupCameraContoller() async {
    List<CameraDescription> cameras = await availableCameras();

    if (cameras.isNotEmpty) {
      setState(() {
        cameras = cameras;
        cameraController = CameraController(
            isFontCamera ? cameras.first : cameras.last, ResolutionPreset.max);
      });

      cameraController?.initialize().then((_) {
        if (!mounted) {
          return;
        }
        setState(() {});
      }).catchError((Object e) {
        devtools.log(e.toString());
      });
    }
  }

  // Switch Camera
  void switchCamera() {
    if (isFontCamera) {
      isFontCamera = false;
    } else {
      isFontCamera = true;
    }
    _setupCameraContoller();
    devtools.log("camera switched!");
  }

  // Take Pic
  void takePicture() async {
    setState(() {
      outputText = '';
    });

    final XFile image = await cameraController!.takePicture();

    var recognitions = await Tflite.runModelOnImage(
        path: image.path, // required
        imageMean: 0.0, // defaults to 117.0
        imageStd: 255.0, // defaults to 1.0
        numResults: 1, // defaults to 5
        threshold: 0.2, // defaults to 0.1
        asynch: true // defaults to true
        );

    if (recognitions == null) {
      setState(() {
        outputText = 'recognitions is Null';
      });
      devtools.log("recognitions is Null");
      return;
    }

    devtools.log(recognitions.toString());

    if (recognitions.isEmpty) {
      flutterTts.speak('recognitions is empty');
      setState(() {
        outputText = 'recognitions is empty';
      });
      devtools.log("recognitions is empty");
      return;
    }

    double confidence = recognitions[0]['confidence'] * 100;
    String label = recognitions[0]['label'].toString();
    flutterTts.speak(label);

    setState(() {
      outputText = '$label ${confidence.toStringAsFixed(2)} %';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (cameraController == null) {
      return const Scaffold(
          body: Center(child: Text('Camera Controller is null')));
    }

    return Scaffold(
      body: Stack(children: [
        SizedBox(
          height: double.infinity,
          child: CameraPreview(
            cameraController!,
          ),
        ),
        Positioned(
          bottom: MediaQuery.of(context).size.height / 3,
          child: Container(
              height: MediaQuery.of(context).size.height,
              width: MediaQuery.of(context).size.width,
              margin: const EdgeInsets.symmetric(vertical: 20.0),
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Center(
                  child: Text(
                outputText,
                style: TextStyle(
                  fontSize: 20,
                  background: Paint()
                    ..color = const Color.fromARGB(80, 255, 255, 255),
                ),
              ))),
        ),
        Positioned(
          bottom: 0,
          child: Container(
              width: MediaQuery.of(context).size.width,
              margin: const EdgeInsets.symmetric(vertical: 20.0),
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 50,
                  ),
                  IconButton(
                    onPressed: takePicture,
                    style: IconButton.styleFrom(
                      iconSize: 65,
                      backgroundColor: const Color.fromARGB(80, 255, 255, 255),
                    ),
                    icon: const Icon(Icons.circle_outlined),
                    color: Colors.black,
                  ),
                  IconButton(
                    onPressed: switchCamera,
                    iconSize: 20,
                    style: IconButton.styleFrom(
                        backgroundColor:
                            const Color.fromARGB(80, 255, 255, 255)),
                    icon: const Icon(Icons.cameraswitch_outlined),
                    color: Colors.black,
                  ),
                ],
              )),
        ),
      ]),
    );
  }
}
