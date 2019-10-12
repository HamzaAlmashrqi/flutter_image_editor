import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_editor_example/const/resource.dart';
import 'package:image_editor/image_editor.dart';
import 'package:image_picker/image_picker.dart';
import 'package:oktoast/oktoast.dart';

class AdvancedPage extends StatefulWidget {
  @override
  _AdvancedPageState createState() => _AdvancedPageState();
}

class _AdvancedPageState extends State<AdvancedPage> {
  final editorKey = GlobalKey<ExtendedImageEditorState>();

  ImageProvider provider;

  @override
  void initState() {
    super.initState();
    provider = AssetImage(R.ASSETS_ICON_PNG);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Use extended_image library"),
          actions: <Widget>[
            IconButton(
              icon: Icon(Icons.photo),
              onPressed: _pick,
            ),
            IconButton(
              icon: Icon(Icons.check),
              onPressed: crop,
            ),
          ],
        ),
        body: Container(
          height: double.infinity,
          child: Column(
            children: <Widget>[
              AspectRatio(
                aspectRatio: 1,
                child: buildImage(),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _buildFunctions());
  }

  Widget buildImage() {
    return ExtendedImage(
      image: provider,
      height: 400,
      width: 400,
      extendedImageEditorKey: editorKey,
      mode: ExtendedImageMode.editor,
      fit: BoxFit.contain,
      initEditorConfigHandler: (state) {
        return EditorConfig(
          maxScale: 8.0,
          cropRectPadding: EdgeInsets.all(20.0),
          hitTestSize: 20.0,
          cropAspectRatio: 1,
        );
      },
    );
  }

  Widget _buildFunctions() {
    return BottomNavigationBar(
      items: <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Icon(Icons.flip),
          title: Text("Flip"),
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.rotate_left),
          title: Text("Rotate left"),
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.rotate_right),
          title: Text("Rotate right"),
        ),
      ],
      onTap: (index) {
        switch (index) {
          case 0:
            flip();
            break;
          case 1:
            rotate(false);
            break;
          case 2:
            rotate(true);
            break;
        }
      },
      currentIndex: 0,
      selectedItemColor: Theme.of(context).primaryColor,
      unselectedItemColor: Theme.of(context).primaryColor,
    );
  }

  void crop() async {
    final state = editorKey.currentState;
    final rect = state.getCropRect();
    final action = state.editAction;
    final radian = action.rotateAngle;

    final flipHorizontal = action.flipY;
    final flipVertical = action.flipX;
    final img = await getImageFromEditorKey(editorKey);

    ImageEditorOption option = ImageEditorOption();

    option.addOption(
        FlipOption(horizontal: flipHorizontal, vertical: flipVertical));
    if (action.hasRotateAngle) {
      option.addOption(RotateOption.radian(radian));
    }
    option.addOption(ClipOption.fromRect(rect));

    print(json.encode(option.toJson()));

    final start = DateTime.now();
    final result = await ImageEditor.editImage(
      image: img,
      imageEditorOption: option,
    );

    final diff = DateTime.now().difference(start);

    print("image_editor time : $diff");
    showToast("handle duration: $diff",
        duration: Duration(seconds: 5), dismissOtherToast: true);

    showPreviewDialog(result);
  }

  void flip() {
    editorKey.currentState.flip();
  }

  static Future<Uint8List> getImageFromEditorKey(
      GlobalKey<ExtendedImageEditorState> editorKey) async {
    Uint8List result;
    final provider =
        editorKey.currentState.widget.extendedImageState.imageProvider;
    if (provider is AssetImage) {
      ByteData byteData;
      if (provider.package == null) {
        byteData = await rootBundle.load(provider.assetName);
      } else {
        byteData = await rootBundle
            .load("packages/${provider.package}/${provider.assetName}");
      }
      result = byteData.buffer.asUint8List();
    } else if (provider is FileImage) {
      result = provider.file.readAsBytesSync();
    } else if (provider is MemoryImage) {
      result = provider.bytes;
    } else if (provider is NetworkImage) {
      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(provider.url));
      for (final key in provider.headers.keys) {
        final value = provider.headers[key];
        req.headers.add(key, value);
      }
      final response = await req.close();
      final listList = await response.toList();
      List<int> tmp = [];
      for (final list in listList) {
        tmp.addAll(list);
      }
      result = Uint8List.fromList(tmp);
      client.close();
    } else if (provider is ExtendedNetworkImageProvider) {
      final file = await getCachedImageFile(provider.url);
      if (file != null) {
        result = file.readAsBytesSync();
      } else {
        final client = HttpClient();
        final req = await client.getUrl(Uri.parse(provider.url));
        for (final key in provider.headers.keys) {
          final value = provider.headers[key];
          req.headers.add(key, value);
        }
        final response = await req.close();
        final listList = await response.toList();
        List<int> tmp = [];
        for (final list in listList) {
          tmp.addAll(list);
        }
        result = Uint8List.fromList(tmp);
        client.close();
      }
    } else {
      result = (await editorKey.currentState.image.toByteData())
          .buffer
          .asUint8List();
    }

    return result;
  }

  rotate(bool right) {
    editorKey.currentState.rotate(right: right);
  }

  void showPreviewDialog(Uint8List image) {
    showDialog(
      context: context,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          color: Colors.grey.withOpacity(0.5),
          child: Center(
            child: SizedBox.fromSize(
              size: Size.square(200),
              child: Container(
                color: Colors.white,
                child: Image.memory(image),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _pick() async {
    final result = await ImagePicker.pickImage(source: ImageSource.gallery);
    if (result != null) {
      provider = FileImage(result);
      setState(() {});
    }
  }
}