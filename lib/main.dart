import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}
enum GridDemoTileStyle {
  imageOnly,
  oneLine,
  twoLine
}

typedef BannerTapCallback = void Function(Photo photo);
const double _kMinFlingVelocity = 800.0;
const String _kGalleryAssetsPackage = 'flutter_gallery_assets';
class Photo {
  Photo({
    this.assetName,
    this.assetPackage,
    this.title,
    this.caption,
    this.isFavorite = false,
  });

  final String? assetName;
  final String? assetPackage;
  final String? title;
  final String? caption;

  bool isFavorite;
  String? get tag => assetName; // Assuming that all asset names are unique.

  bool get isValid => assetName != null && title != null && caption != null;
}

class _GridTitleText extends StatelessWidget {
  const _GridTitleText(this.text);

  final String? text;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(text!),
    );
  }
}
class GridDemoPhotoItem extends StatelessWidget {
  GridDemoPhotoItem({
    Key? key,
    required this.photo,
    required this.tileStyle,
    required this.onBannerTap,
  }) : assert(photo.isValid),
        super(key: key);

  final Photo photo;
  final GridDemoTileStyle tileStyle;
  final BannerTapCallback onBannerTap; // User taps on the photo's header or footer.

  void showPhoto(BuildContext context) {
    Navigator.push(context, MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return Scaffold(
            appBar: AppBar(
              title: Text(photo.title!),
            ),
            body: SizedBox.expand(
              child: Hero(
                tag: photo.tag!,
                child: GridPhotoViewer(photo: photo),
              ),
            ),
          );
        }
    ));
  }

  @override
  Widget build(BuildContext context) {
    final Widget image = Semantics(
      label: '${photo.title} - ${photo.caption}',
      child: GestureDetector(
        onTap: () { showPhoto(context); },
        child: Hero(
          key: Key(photo.assetName!),
          tag: photo.tag!,
          child: Image.asset(
            photo.assetName!,
            package: photo.assetPackage,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );

    final IconData icon = photo.isFavorite ? Icons.star : Icons.star_border;

    switch (tileStyle) {
      case GridDemoTileStyle.imageOnly:
        return image;

      case GridDemoTileStyle.oneLine:
        return GridTile(
          header: GestureDetector(
            onTap: () { onBannerTap(photo); },
            child: GridTileBar(
              title: _GridTitleText(photo.title),
              backgroundColor: Colors.black45,
              leading: Icon(
                icon,
                color: Colors.white,
              ),
            ),
          ),
          child: image,
        );

      case GridDemoTileStyle.twoLine:
        return GridTile(
          footer: GestureDetector(
            onTap: () { onBannerTap(photo); },
            child: GridTileBar(
              backgroundColor: Colors.black45,
              title: _GridTitleText(photo.title),
              subtitle: _GridTitleText(photo.caption),
              trailing: Icon(
                icon,
                color: Colors.white,
              ),
            ),
          ),
          child: image,
        );
    }
  }
}
class GridPhotoViewer extends StatefulWidget {
  const GridPhotoViewer({ Key? key, this.photo }) : super(key: key);

  final Photo? photo;

  @override
  State<GridPhotoViewer> createState() => _GridPhotoViewerState();
}
class _GridPhotoViewerState extends State<GridPhotoViewer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _flingAnimation;
  Offset _offset = Offset.zero;
  double _scale = 1.0;
  late Offset _normalizedOffset;
  late double _previousScale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this)
      ..addListener(_handleFlingAnimation);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // The maximum offset value is 0,0. If the size of this renderer's box is w,h
  // then the minimum offset value is w - _scale * w, h - _scale * h.
  Offset _clampOffset(Offset offset) {
    final Size size = context.size!;
    final Offset minOffset = Offset(size.width, size.height) * (1.0 - _scale);
    return Offset(
      offset.dx.clamp(minOffset.dx, 0.0),
      offset.dy.clamp(minOffset.dy, 0.0),
    );
  }

  void _handleFlingAnimation() {
    setState(() {
      _offset = _flingAnimation.value;
    });
  }

  void _handleOnScaleStart(ScaleStartDetails details) {
    setState(() {
      _previousScale = _scale;
      _normalizedOffset = (details.focalPoint - _offset) / _scale;
      // The fling animation stops if an input gesture starts.
      _controller.stop();
    });
  }

  void _handleOnScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      _scale = (_previousScale * details.scale).clamp(1.0, 4.0);
      // Ensure that image location under the focal point stays in the same place despite scaling.
      _offset = _clampOffset(details.focalPoint - _normalizedOffset * _scale);
    });
  }

  void _handleOnScaleEnd(ScaleEndDetails details) {
    final double magnitude = details.velocity.pixelsPerSecond.distance;
    if (magnitude < _kMinFlingVelocity)
      return;
    final Offset direction = details.velocity.pixelsPerSecond / magnitude;
    final double distance = (Offset.zero & context.size!).shortestSide;
    _flingAnimation = _controller.drive(Tween<Offset>(
      begin: _offset,
      end: _clampOffset(_offset + direction * distance),
    ));
    _controller
      ..value = 0.0
      ..fling(velocity: magnitude / 1000.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleStart: _handleOnScaleStart,
      onScaleUpdate: _handleOnScaleUpdate,
      onScaleEnd: _handleOnScaleEnd,
      child: ClipRect(
        child: Transform(
          transform: Matrix4.identity()
            ..translate(_offset.dx, _offset.dy)
            ..scale(_scale),
          child: Image.asset(
            widget.photo!.assetName!,
            package: widget.photo!.assetPackage,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  GridDemoTileStyle _tileStyle = GridDemoTileStyle.twoLine;
  final _messangerKey = GlobalKey<ScaffoldMessengerState>();
  List<Photo> photos = <Photo>[
    Photo(
      assetName: 'places/master_bedroom.png',
      assetPackage: _kGalleryAssetsPackage,
      title: 'Master bedroom',
      caption: 'Stay time : 8h',
    ),
    Photo(
      assetName: 'places/second_bedroom.png',
      assetPackage: _kGalleryAssetsPackage,
      title: 'Second bedroom',
      caption: 'Stay time : 0h',
    ),
    Photo(
      assetName: 'places/study.png',
      assetPackage: _kGalleryAssetsPackage,
      title: 'Study',
      caption: 'Stay time : 6h',
    ),
    Photo(
      assetName: 'places/parlor.png',
      assetPackage: _kGalleryAssetsPackage,
      title: 'Parlor',
      caption: 'Stay time : 2h',
    ),
    Photo(
      assetName: 'places/kitchen.png',
      assetPackage: _kGalleryAssetsPackage,
      title: 'Kitchen',
      caption: 'Stay time : 2h',
    ),
    Photo(
      assetName: 'places/bathroom.png',
      assetPackage: _kGalleryAssetsPackage,
      title: 'Bathroom',
      caption: 'Stay time : 1h',
    ),
  ];

  void changeTileStyle(GridDemoTileStyle value) {
    // setState(() {
    //   _tileStyle = value;
    // });
  }

  @override
  Widget build(BuildContext context) {
    const title = 'Smart home';

    return MaterialApp(
      title: title,
      scaffoldMessengerKey: _messangerKey,
      home: Scaffold(
        appBar: AppBar(
          title: const Text(title),
        ),
        body: GridView.count(
          // Create a grid with 2 columns. If you change the scrollDirection to
          // horizontal, this produces 2 rows.
          crossAxisCount: 2,
          // Generate 100 widgets that display their index in the List.
          children: photos.map<Widget>((Photo photo) {
            return GridDemoPhotoItem(
              photo: photo,
              tileStyle: _tileStyle,
              onBannerTap: (Photo photo) {
                // setState(() {
                //   photo.isFavorite = !photo.isFavorite;
                // });
              },
            );
          }).toList(),
        ),
          floatingActionButton: FloatingActionButton.extended(
            icon: Icon(Icons.clean_hands),
            label: Text("Predict"),
            onPressed: () {
              const snackBar = SnackBar(content: Text('Study time too long, please take a break!'));

              _messangerKey.currentState!.showSnackBar(snackBar);},
        ),
      ),
    );
  }
}

class MyHomePage extends StatelessWidget {
  final String title;

  const MyHomePage({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: const Center(
        child: MyButton(),
      ),
    );
  }
}

class MyButton extends StatelessWidget {
  const MyButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // The InkWell wraps the custom flat button widget.
    return InkWell(
      // When the user taps the button, show a snackbar.
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Tap'),
        ));
      },
      child: const Padding(
        padding: EdgeInsets.all(12.0),
        child: Text('Flat Button'),
      ),
    );
  }
}