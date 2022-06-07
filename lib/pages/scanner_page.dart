import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_image/flutter_native_image.dart';
import 'package:mega_scanner/widgets/oval_clipper.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/io.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage(
      {required this.wsUrl,
      required this.onSuccess,
      required this.onError,
      required this.onErrorConnectWS,
      required this.onErrorConnectWSMessage,
      Key? key})
      : super(key: key);

  final String wsUrl;
  final ValueChanged onSuccess;
  final ValueChanged onError;
  final ValueChanged onErrorConnectWS;
  final ValueChanged onErrorConnectWSMessage;

  @override
  _ScannerPageState createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> with WidgetsBindingObserver {
  List<CameraDescription> cameras = [];
  CameraController? controller;
  IOWebSocketChannel?
      channel; // = IOWebSocketChannel.connect('ws://164.92.179.69/ws/');

  // File? _imageFile;
  ValueNotifier isLoading = ValueNotifier(false);

  // Initial values
  bool _isCameraInitialized = false;
  bool _isCameraPermissionGranted = false;
  double _minAvailableExposureOffset = 0.0;
  double _maxAvailableExposureOffset = 0.0;
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  Rect? rect;
  Size? size;
  double? top;
  double? _x, _y;
  final GlobalKey _key = GlobalKey();

  // Current values
  double _currentZoomLevel = 1.0;
  double _currentExposureOffset = 0.0;
  FlashMode? _currentFlashMode;

  List<File> allFileList = [];

  final resolutionPresets = ResolutionPreset.values;

  ResolutionPreset currentResolutionPreset = ResolutionPreset.high;

  final ValueNotifier<bool> isCheck = ValueNotifier<bool>(true);

  getPermissionStatus() async {
    await Permission.camera.request();
    var status = await Permission.camera.status;

    if (status.isGranted) {
      log('Camera Permission: GRANTED');
      setState(() {
        _isCameraPermissionGranted = true;
      });
      // Set and initialize the new camera
      onNewCameraSelected(cameras[0]);
      // refreshAlreadyCapturedImages();
    } else {
      log('Camera Permission: DENIED');
    }
  }

  void _getOffset(GlobalKey key) {
    RenderBox? box = key.currentContext?.findRenderObject() as RenderBox?;
    Offset? position = box?.localToGlobal(Offset.zero);
    if (position != null) {
      _x = position.dx;
      _y = position.dy;
    }
  }

  ovalRect(double aspect) {
    double left = (size!.width - 180) / 2;
    top = (size!.width * aspect - 180) / 2;
    rect = Rect.fromLTWH(left, top!, 180, 180);
  }

  Future cropImage(String path) async {
    File image = File(path);
    var decodedImage = await decodeImageFromList(image.readAsBytesSync());
    double width = ((180 / size!.width) * decodedImage.width);
    double height = ((180 / (size!.width * controller!.value.aspectRatio)) * decodedImage.height);
    double originX = (_x! / size!.width) * decodedImage.width;
    double originY = (_y! / (size!.width * controller!.value.aspectRatio)) * decodedImage.height;
    File croppedFile = await FlutterNativeImage.cropImage(
        path, originY.toInt(), originX.toInt(), height.toInt(), width.toInt());
    File compressedFile = await FlutterNativeImage.compressImage(
      croppedFile.path,
      quality: 50,
    );
    return compressedFile;
    // return await compressedFile.readAsBytes();
  }

  // refreshAlreadyCapturedImages() async {
  //   final directory = await getApplicationDocumentsDirectory();
  //   List<FileSystemEntity> fileList = await directory.list().toList();
  //   allFileList.clear();
  //   List<Map<int, dynamic>> fileNames = [];

  //   for (var file in fileList) {
  //     if (file.path.contains('.jpg')) {
  //       allFileList.add(File(file.path));

  //       String name = file.path.split('/').last.split('.').first;
  //       fileNames.add({0: int.parse(name), 1: file.path.split('/').last});
  //     }
  //   }

  //   if (fileNames.isNotEmpty) {
  //     final recentFile = fileNames
  //         .reduce((current, next) => current[0] > next[0] ? current : next);
  //     String recentFileName = recentFile[1];

  //     _imageFile = File('${directory.path}/$recentFileName');

  //     setState(() {});
  //   }
  // }

  Future<XFile?> takePicture() async {
    final CameraController? cameraController = controller;

    if (cameraController!.value.isTakingPicture) {
      return null;
    }
    // if(channel == null) {
    //   reConnectWs();
    // }

    try {
      return await cameraController.takePicture();
    } on CameraException catch (e) {
      log('Error occured while taking picture: $e');
      return null;
    }
  }

  void resetCameraValues() async {
    _currentZoomLevel = 1.0;
    _currentExposureOffset = 0.0;
  }

  void onNewCameraSelected(CameraDescription cameraDescription) async {
    final previousCameraController = controller;

    final CameraController cameraController = CameraController(
      cameraDescription,
      currentResolutionPreset,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await previousCameraController?.dispose();

    resetCameraValues();

    if (mounted) {
      setState(() {
        controller = cameraController;
      });
    }

    cameraController.addListener(() {
      if (mounted) setState(() {});
    });

    try {
      await cameraController.initialize();
      await Future.wait([
        cameraController
            .getMinExposureOffset()
            .then((value) => _minAvailableExposureOffset = value),
        cameraController
            .getMaxExposureOffset()
            .then((value) => _maxAvailableExposureOffset = value),
        cameraController
            .getMaxZoomLevel()
            .then((value) => _maxAvailableZoom = value),
        cameraController
            .getMinZoomLevel()
            .then((value) => _minAvailableZoom = value),
      ]);

      _currentFlashMode = controller!.value.flashMode;
    } on CameraException catch (e) {
      log('Error initializing camera: $e');
    }

    if (mounted) {
      setState(() {
        _isCameraInitialized = controller!.value.isInitialized;
      });
    }
    ovalRect(controller!.value.aspectRatio);
  }

  void onViewFinderTap(TapDownDetails details, BoxConstraints constraints) {
    if (controller == null) {
      return;
    }

    final offset = Offset(
      details.localPosition.dx / constraints.maxWidth,
      details.localPosition.dy / constraints.maxHeight,
    );
    controller!.setExposurePoint(offset);
    controller!.setFocusPoint(offset);
  }

  Future show(context, String? message) {
    return showDialog(
        context: context,
        builder: (build) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0.0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(message ?? "Error"),
                  const SizedBox(
                    height: 16,
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                          color: Colors.greenAccent,
                          borderRadius: BorderRadius.circular(10)),
                      height: 48,
                      child: const Center(
                        child: Text("ok"),
                      ),
                    ),
                  )
                ],
              ),
            ))).then((value) => isLoading.value = false);
  }

  initCamera() async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      cameras = await availableCameras();
    } on CameraException catch (e) {
      log('Error in fetching the cameras: $e');
    }
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  listenWs() {
    channel!.stream.listen((message) {
      final result = json.decode(message);
      isLoading.value = false;
      if (result.containsKey('key')) {
        widget.onSuccess(result['key']);
      } else {
        widget.onError(result['error']);
      }
    },
    onDone: () {
      widget.onErrorConnectWS(()=> reConnectWs());
      channel = null;
      isCheck.value = false;
    },
    onError: (_) {
      widget.onErrorConnectWSMessage(_.toString());
    },
    cancelOnError: true);
  }

  reConnectWs(){    
      channel = IOWebSocketChannel.connect(widget.wsUrl);
      Navigator.pop(context);
      isCheck.value = true;
      listenWs();
  }

  @override
  void initState() {
    channel = IOWebSocketChannel.connect(widget.wsUrl);
    initCamera();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
    getPermissionStatus();
    super.initState();
    // channel.stream.listen((message) {
    //   final Map<String, String> result = jsonDecode(message);
    //   isLoading.value = false;
    //   if (result.containsKey('key')) {
    //     widget.onSuccess(result['key']);
    //   } else {
    //     widget.onError(result['error']);
    //   }
    // });
    listenWs();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = controller;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      onNewCameraSelected(cameraController.description);
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    size = MediaQuery.of(context).size;
    final deviceRatio = size!.width / size!.height;
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _isCameraPermissionGranted
            ? _isCameraInitialized
                ? Column(
                    children: [
                      AspectRatio(
                        aspectRatio: 1 / controller!.value.aspectRatio,
                        child: ValueListenableBuilder(
                          valueListenable: isLoading,
                          builder: (context, value, child) => Stack(
                            children: [
                              CameraPreview(
                                controller!,
                                child: LayoutBuilder(builder:
                                    (BuildContext context,
                                        BoxConstraints constraints) {
                                  return GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTapDown: (details) =>
                                        onViewFinderTap(details, constraints),
                                  );
                                }),
                              ),
                              CustomPaint(
                                child: ClipPath(
                                    clipper: OvalClipper(rect),
                                    child: Transform.scale(
                                        scale: controller!.value.aspectRatio /
                                            deviceRatio,
                                        child: Center(
                                            child: Container(
                                                color: Colors.black54)))),
                              ),
                              Center(
                                child: SizedBox(
                                  key: _key,
                                  height: 180,
                                  width: 180,
                                  child: Image.asset(
                                    'assets/images/ramka.png',
                                    color: Colors.greenAccent,
                                    width: 150,
                                    height: 150,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16.0,
                                  8.0,
                                  16.0,
                                  8.0,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    SingleChildScrollView(
                                        physics: const BouncingScrollPhysics(),
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                              16.0, 8.0, 16.0, 8.0),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              InkWell(
                                                onTap: () async {
                                                  setState(() {
                                                    _currentFlashMode =
                                                        FlashMode.off;
                                                  });
                                                  await controller!
                                                      .setFlashMode(
                                                    FlashMode.off,
                                                  );
                                                },
                                                child: Icon(
                                                  Icons.flash_off,
                                                  color: _currentFlashMode ==
                                                          FlashMode.off
                                                      ? Colors.amber
                                                      : Colors.white,
                                                ),
                                              ),
                                              InkWell(
                                                onTap: () async {
                                                  setState(() {
                                                    _currentFlashMode =
                                                        FlashMode.auto;
                                                  });
                                                  await controller!
                                                      .setFlashMode(
                                                    FlashMode.auto,
                                                  );
                                                },
                                                child: Icon(
                                                  Icons.flash_auto,
                                                  color: _currentFlashMode ==
                                                          FlashMode.auto
                                                      ? Colors.amber
                                                      : Colors.white,
                                                ),
                                              ),
                                              InkWell(
                                                onTap: () async {
                                                  setState(() {
                                                    _currentFlashMode =
                                                        FlashMode.always;
                                                  });
                                                  await controller!
                                                      .setFlashMode(
                                                    FlashMode.always,
                                                  );
                                                },
                                                child: Icon(
                                                  Icons.flash_on,
                                                  color: _currentFlashMode ==
                                                          FlashMode.always
                                                      ? Colors.amber
                                                      : Colors.white,
                                                ),
                                              ),
                                              InkWell(
                                                onTap: () async {
                                                  setState(() {
                                                    _currentFlashMode =
                                                        FlashMode.torch;
                                                  });
                                                  await controller!
                                                      .setFlashMode(
                                                    FlashMode.torch,
                                                  );
                                                },
                                                child: Icon(
                                                  Icons.highlight,
                                                  color: _currentFlashMode ==
                                                          FlashMode.torch
                                                      ? Colors.amber
                                                      : Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )),
                                    Align(
                                      alignment: Alignment.topRight,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black87,
                                          borderRadius:
                                              BorderRadius.circular(10.0),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            left: 8.0,
                                            right: 8.0,
                                          ),
                                          child:
                                              DropdownButton<ResolutionPreset>(
                                            dropdownColor: Colors.black87,
                                            underline: Container(),
                                            value: currentResolutionPreset,
                                            items: [
                                              for (ResolutionPreset preset
                                                  in resolutionPresets)
                                                DropdownMenuItem(
                                                  child: Text(
                                                    preset
                                                        .toString()
                                                        .split('.')[1]
                                                        .toUpperCase(),
                                                    style: const TextStyle(
                                                        color: Colors.white),
                                                  ),
                                                  value: preset,
                                                )
                                            ],
                                            onChanged: (value) {
                                              setState(() {
                                                currentResolutionPreset =
                                                    value!;
                                                _isCameraInitialized = false;
                                              });
                                              onNewCameraSelected(
                                                  controller!.description);
                                            },
                                            hint: const Text("Select item"),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Spacer(),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          right: 8.0, top: 16.0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(10.0),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            _currentExposureOffset
                                                    .toStringAsFixed(1) +
                                                'x',
                                            style: const TextStyle(
                                                color: Colors.black),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: RotatedBox(
                                        quarterTurns: 3,
                                        child: SizedBox(
                                          height: 30,
                                          child: Slider(
                                            value: _currentExposureOffset,
                                            min: _minAvailableExposureOffset,
                                            max: _maxAvailableExposureOffset,
                                            activeColor: Colors.white,
                                            inactiveColor: Colors.white30,
                                            onChanged: (value) async {
                                              setState(() {
                                                _currentExposureOffset = value;
                                              });
                                              await controller!
                                                  .setExposureOffset(value);
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Slider(
                                            value: _currentZoomLevel,
                                            min: _minAvailableZoom,
                                            max: _maxAvailableZoom,
                                            activeColor: Colors.white,
                                            inactiveColor: Colors.white30,
                                            onChanged: (value) async {
                                              setState(() {
                                                _currentZoomLevel = value;
                                              });
                                              await controller!
                                                  .setZoomLevel(value);
                                            },
                                          ),
                                        ),
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(right: 8.0),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.black87,
                                              borderRadius:
                                                  BorderRadius.circular(10.0),
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(8.0),
                                              child: Text(
                                                _currentZoomLevel
                                                        .toStringAsFixed(1) +
                                                    'x',
                                                style: const TextStyle(
                                                    color: Colors.white),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        // InkWell(
                                        //   onTap: _imageFile != null
                                        //       ? () {
                                        //           Navigator.of(context).push(
                                        //             MaterialPageRoute(
                                        //               builder: (context) =>
                                        //                   PreviewPage(
                                        //                 imageFile: _imageFile!,
                                        //                 fileList: allFileList,
                                        //               ),
                                        //             ),
                                        //           );
                                        //         }
                                        //       : null,
                                        //   child: Container(
                                        //     width: 60,
                                        //     height: 60,
                                        //     decoration: BoxDecoration(
                                        //       color: Colors.black,
                                        //       borderRadius:
                                        //           BorderRadius.circular(10.0),
                                        //       border: Border.all(
                                        //         color: Colors.white,
                                        //         width: 2,
                                        //       ),
                                        //       image: _imageFile != null
                                        //           ? DecorationImage(
                                        //               image: FileImage(
                                        //                   _imageFile!),
                                        //               fit: BoxFit.cover,
                                        //             )
                                        //           : null,
                                        //     ),
                                        //   ),
                                        // ),
                                        // const SizedBox(width: 32),
                                        ValueListenableBuilder(
                                          valueListenable: isCheck,
                                          builder: (context, value, child) => SizedBox(
                                          child: isCheck.value
                                            ? InkWell(
                                            onTap: () async {
                                              _getOffset(_key);
                                              XFile? rawImage =
                                                  await takePicture();
                                                if (rawImage != null) {
                                                  File imageFile = await cropImage(
                                                      rawImage.path);
                                                  imageFile.readAsBytes().then(
                                                      (bites) =>
                                                          channel!.sink.add(bites));
                                                  isLoading.value = true;
                                        
                                                  // int currentUnix = DateTime.now()
                                                  //     .millisecondsSinceEpoch;
                                        
                                                  // final directory =
                                                  //     await getApplicationDocumentsDirectory();
                                        
                                                  // String fileFormat = imageFile.path
                                                  //     .split('.')
                                                  //     .last;
                                        
                                                  // log(fileFormat);
                                        
                                                  // await imageFile.copy(
                                                  //   '${directory.path}/$currentUnix.$fileFormat',
                                                  // );
                                                  // await cropImg.copy(
                                                  //   '${directory.path}/${currentUnix}1.$cropFileFormat',
                                                  // );
                                        
                                                  // refreshAlreadyCapturedImages();
                                                }
                                            },
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: const [
                                                Icon(
                                                  Icons.circle,
                                                  color: Colors.white38,
                                                  size: 80,
                                                ),
                                                Icon(
                                                  Icons.circle,
                                                  color: Colors.white,
                                                  size: 65,
                                                ),
                                              ],
                                            ),
                                          )
                                          : const SizedBox()
                                          )
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (isLoading.value)
                                Container(
                                  width: size?.width,
                                  height: size?.height,
                                  color: Colors.black.withOpacity(0.25),
                                  child: const Center(
                                    child: CircularProgressIndicator.adaptive(),
                                  ),
                                )
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : const Center(
                    child: Text(
                      'LOADING',
                      style: TextStyle(color: Colors.white),
                    ),
                  )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(),
                  const Text(
                    'Permission denied',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      getPermissionStatus();
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        'Give permission',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
