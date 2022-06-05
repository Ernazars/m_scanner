import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_native_image/flutter_native_image.dart';
import 'package:web_socket_channel/io.dart';

class ShowBottomSheet {
  static void showMyBottomSheet(
      {required BuildContext context,
      required dynamic path,
      required double x,
      required double y,
      required Size size,
      double padding = 40,
      required IOWebSocketChannel channel,
      required double appbarHeight,
      required Function onTap}) async {
    File image = File(path);
    var decodedImage = await decodeImageFromList(image.readAsBytesSync());
    double width = ((180 / size.width) * decodedImage.width);
    double height =
        ((180 / (size.height - appbarHeight)) * decodedImage.height);
    double originX = (x / size.width) * decodedImage.width;
    double originY = (y / size.height) * decodedImage.height;
    File croppedFile = await FlutterNativeImage.cropImage(
        path, originY.toInt(), originX.toInt(), height.toInt(), width.toInt());
    File compressedFile = await FlutterNativeImage.compressImage(
      croppedFile.path,
      quality: 25,
    );
    Uint8List img = await compressedFile.readAsBytes();
    log("size ${croppedFile.lengthSync()}");
    log("size ${compressedFile.lengthSync()}");
    showModalBottomSheet(
        isScrollControlled: true,
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(30),
          ),
        ),
        clipBehavior: Clip.antiAliasWithSaveLayer,
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        builder: (context) => Container(
              width: size.width,
              padding: EdgeInsets.only(left: padding, right: padding, top: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                      decoration: BoxDecoration(boxShadow: [
                        BoxShadow(
                          color: const Color(0xff1B1B1B).withOpacity(0.16),
                          spreadRadius: 0,
                          blurRadius: 20,
                          offset: const Offset(4, 4),
                        ),
                      ], borderRadius: BorderRadius.circular(4)),
                      width: size.width - 32,
                      child: Image.file(
                        compressedFile,
                        fit: BoxFit.cover,
                      )),
                  const SizedBox(
                    height: 16,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      InkWell(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: Container(
                          height: 48,
                          width: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xffDC5656),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    const Color(0xff0C0C0C).withOpacity(0.21),
                                spreadRadius: 0,
                                blurRadius: 11,
                                offset: const Offset(2, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.clear,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 20,
                      ),
                      InkWell(
                        onTap: () {
                          channel.sink.add(img);
                          onTap();
                        },
                        child: Container(
                          height: 48,
                          width: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xff6DC13E),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    const Color(0xff0C0C0C).withOpacity(0.21),
                                spreadRadius: 0,
                                blurRadius: 11,
                                offset: const Offset(2, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                          ),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(
                    height: 40,
                  )
                ],
              ),
            ));
  }
}
