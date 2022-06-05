import 'package:flutter/material.dart';

class OvalClipper extends CustomClipper<Path> {
  final Rect? _ovalRect;

  OvalClipper(this._ovalRect);

  @override
  Path getClip(Size size) {
    return Path()
      ..addRect(_ovalRect!)
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..fillType = PathFillType.evenOdd;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) {
    return false;
  }
}

class OvalClipperTwo extends CustomClipper<Path> {
  final Rect? _ovalRect;

  OvalClipperTwo(this._ovalRect);

  @override
  Path getClip(Size size) {
    return Path()
      ..addRect(_ovalRect!)
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..fillType = PathFillType.evenOdd;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) {
    return false;
  }
}