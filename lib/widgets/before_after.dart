import 'dart:typed_data';
import 'package:flutter/material.dart';

class BeforeAfterSlider extends StatefulWidget {
  final Uint8List before;
  final Uint8List after;

  const BeforeAfterSlider({
    super.key,
    required this.before,
    required this.after,
  });

  @override
  State<BeforeAfterSlider> createState() => _BeforeAfterSliderState();
}

class _BeforeAfterSliderState extends State<BeforeAfterSlider> {
  double position = 0.5;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            setState(() {
              position = (position + details.delta.dx / width).clamp(0.0, 1.0);
            });
          },
          onTapDown: (details) {
            setState(() {
              position = (details.localPosition.dx / width).clamp(0.0, 1.0);
            });
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(widget.before, fit: BoxFit.contain),
                ClipRect(
                  clipper: _RightClipper(position),
                  child: Image.memory(widget.after, fit: BoxFit.contain),
                ),
                Align(
                  alignment: Alignment(position * 2 - 1, 0),
                  child: Container(
                    width: 2,
                    color: Colors.white,
                    child: const SizedBox.expand(),
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: _Tag('AVANT'),
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: _Tag('APRÈS'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RightClipper extends CustomClipper<Rect> {
  final double position;
  _RightClipper(this.position);

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(size.width * position, 0, size.width, size.height);

  @override
  bool shouldReclip(_RightClipper oldClipper) =>
      oldClipper.position != position;
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag(this.text);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
