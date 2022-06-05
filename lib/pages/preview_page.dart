import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mega_scanner/pages/captures_page.dart';

class PreviewPage extends StatelessWidget {
  const PreviewPage({
    required this.imageFile,
    required this.fileList,
    Key? key,
  }) : super(key: key);

  final File imageFile;
  final List<File> fileList;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextButton(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => CapturesPage(
                      imageFileList: fileList,
                    ),
                  ),
                );
              },
              child: const Text('Go to all captures'),
              style: TextButton.styleFrom(
                primary: Colors.black,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: Image.file(imageFile),
          ),
        ],
      ),
    );
  }
}
