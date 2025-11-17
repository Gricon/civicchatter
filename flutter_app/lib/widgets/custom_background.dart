import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomBackground extends StatefulWidget {
  final Widget child;

  const CustomBackground({super.key, required this.child});

  @override
  State<CustomBackground> createState() => _CustomBackgroundState();
}

class _CustomBackgroundState extends State<CustomBackground> {
  String _backgroundType = 'default';
  Color _solidColor = const Color(0xFFF5F5F5);
  Color _gradientStartColor = const Color(0xFF667eea);
  Color _gradientEndColor = const Color(0xFF764ba2);
  String? _backgroundImagePath;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _backgroundType = prefs.getString('background_type') ?? 'default';
      _solidColor = Color(prefs.getInt('background_solid_color') ?? 0xFFF5F5F5);
      _gradientStartColor =
          Color(prefs.getInt('background_gradient_start') ?? 0xFF667eea);
      _gradientEndColor =
          Color(prefs.getInt('background_gradient_end') ?? 0xFF764ba2);
    });
  }

  @override
  Widget build(BuildContext context) {
    // If default, use theme colors
    if (_backgroundType == 'default' ||
        _backgroundType == 'color' && _solidColor.value == 0xFFF5F5F5) {
      return widget.child;
    }

    Widget background;

    switch (_backgroundType) {
      case 'color':
        background = Container(
          decoration: BoxDecoration(
            color: _solidColor,
          ),
        );
        break;
      case 'gradient':
        background = Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_gradientStartColor, _gradientEndColor],
            ),
          ),
        );
        break;
      case 'image':
        // Image background not supported on web yet
        background = Container(
          decoration: BoxDecoration(
            color: _solidColor,
          ),
        );
        break;
      default:
        background = Container();
    }

    return Stack(
      children: [
        Positioned.fill(child: background),
        widget.child,
      ],
    );
  }
}
