import 'dart:math' as math;
import 'package:flutter/material.dart';

class ColorWheelPainter extends CustomPainter {
  final double hue;

  ColorWheelPainter(this.hue);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    for (var i = 0; i < 360; i++) {
        final double angle = i * math.pi / 180;
        final paint = Paint()
          ..color = HSVColor.fromAHSV(1.0, i.toDouble(), 1.0, 1.0).toColor()
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke;
        
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius - 5),
          angle,
          math.pi / 90,
          false,
          paint,
        );
    }

    // Draw handle
    final handleAngle = hue * math.pi / 180;
    final handlePos = Offset(
      center.dx + (radius - 5) * math.cos(handleAngle),
      center.dy + (radius - 5) * math.sin(handleAngle),
    );
    canvas.drawCircle(handlePos, 8, Paint()..color = Colors.white..style = PaintingStyle.fill);
    canvas.drawCircle(handlePos, 6, Paint()..color = HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor()..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ModernColorPicker extends StatefulWidget {
  final Color initialColor;
  final String title;
  final Function(Color) onColorSelected;

  const ModernColorPicker({
    super.key,
    required this.initialColor,
    required this.title,
    required this.onColorSelected,
  });

  @override
  State<ModernColorPicker> createState() => _ModernColorPickerState();
}

class _ModernColorPickerState extends State<ModernColorPicker> {
  late HSVColor selectedHSV;
  late TextEditingController hexController;

  final List<Color> presets = [
    Colors.red, Colors.orange, Colors.yellow, Colors.green,
    Colors.teal, Colors.blue, Colors.indigo, Colors.purple,
    Colors.pink, Colors.brown, Colors.black, Colors.white,
  ];

  @override
  void initState() {
    super.initState();
    selectedHSV = HSVColor.fromColor(widget.initialColor);
    hexController = TextEditingController(text: _colorToHex(widget.initialColor));
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  void _updateFromHex(String hex) {
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (hex.length == 6) {
      final color = Color(int.parse('FF$hex', radix: 16));
      setState(() {
        selectedHSV = HSVColor.fromColor(color);
      });
    }
  }

  void _handleWheelInteraction(Offset localPosition, Size circleSize) {
    final center = circleSize.center(Offset.zero);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    
    double angle = math.atan2(dy, dx) * 180 / math.pi;
    if (angle < 0) angle += 360;
    
    setState(() {
      selectedHSV = selectedHSV.withHue(angle);
      hexController.text = _colorToHex(selectedHSV.toColor());
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Preview Circle
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: selectedHSV.toColor(),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: selectedHSV.toColor().withOpacity(0.4), blurRadius: 15)],
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 20),
            // The Color Wheel (Hue Circle)
            GestureDetector(
              onPanUpdate: (details) => _handleWheelInteraction(details.localPosition, const Size(200, 200)),
              onPanDown: (details) => _handleWheelInteraction(details.localPosition, const Size(200, 200)),
              child: CustomPaint(
                size: const Size(200, 200),
                painter: ColorWheelPainter(selectedHSV.hue),
              ),
            ),
            const SizedBox(height: 20),
            // Saturation & Value Sliders
            Text('飽和度: ${(selectedHSV.saturation * 100).round()}%', style: const TextStyle(fontSize: 12)),
            Slider(
              value: selectedHSV.saturation,
              onChanged: (v) => setState(() {
                selectedHSV = selectedHSV.withSaturation(v);
                hexController.text = _colorToHex(selectedHSV.toColor());
              }),
            ),
            Text('亮度: ${(selectedHSV.value * 100).round()}%', style: const TextStyle(fontSize: 12)),
            Slider(
              value: selectedHSV.value,
              onChanged: (v) => setState(() {
                selectedHSV = selectedHSV.withValue(v);
                hexController.text = _colorToHex(selectedHSV.toColor());
              }),
            ),
            const SizedBox(height: 10),
            // Quick Presets
            Wrap(
              spacing: 8, runSpacing: 8,
              children: presets.map((c) => InkWell(
                onTap: () => setState(() {
                  selectedHSV = HSVColor.fromColor(c);
                  hexController.text = _colorToHex(c);
                }),
                child: CircleAvatar(radius: 12, backgroundColor: c),
              )).toList(),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: hexController,
              onChanged: _updateFromHex,
              decoration: const InputDecoration(labelText: 'HEX 色碼', border: OutlineInputBorder()),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        ElevatedButton(
          onPressed: () {
            widget.onColorSelected(selectedHSV.toColor());
            Navigator.pop(context);
          },
          child: const Text('確定套用'),
        ),
      ],
    );
  }
}

void showModernColorPicker(BuildContext context, String title, Color current, Function(Color) onSelected) {
  showDialog(
    context: context,
    builder: (ctx) => ModernColorPicker(initialColor: current, title: title, onColorSelected: onSelected),
  );
}
