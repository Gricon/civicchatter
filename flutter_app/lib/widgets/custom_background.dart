import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:typed_data';

class CustomBackground extends StatefulWidget {
  final Widget child;

  const CustomBackground({super.key, required this.child});

  @override
  State<CustomBackground> createState() => _CustomBackgroundState();
}

class _CustomBackgroundState extends State<CustomBackground> {
  // Static cache to avoid reloading on every navigation
  static String? _cachedBackgroundType;
  static Color? _cachedSolidColor;
  static Color? _cachedGradientStartColor;
  static Color? _cachedGradientEndColor;
  static String? _cachedBackgroundImagePath;
  static bool _hasLoadedOnce = false;

  String _backgroundType = 'default';
  Color _solidColor = const Color(0xFFF5F5F5);
  Color _gradientStartColor = const Color(0xFF667eea);
  Color _gradientEndColor = const Color(0xFF764ba2);
  String? _backgroundImagePath;

  @override
  void initState() {
    super.initState();
    // Use cached values if available
    if (_hasLoadedOnce) {
      _backgroundType = _cachedBackgroundType ?? 'default';
      _solidColor = _cachedSolidColor ?? const Color(0xFFF5F5F5);
      _gradientStartColor =
          _cachedGradientStartColor ?? const Color(0xFF667eea);
      _gradientEndColor = _cachedGradientEndColor ?? const Color(0xFF764ba2);
      _backgroundImagePath = _cachedBackgroundImagePath;
    }
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final newBackgroundType = prefs.getString('background_type') ?? 'default';
    final newSolidColor =
        Color(prefs.getInt('background_solid_color') ?? 0xFFF5F5F5);
    final newGradientStartColor =
        Color(prefs.getInt('background_gradient_start') ?? 0xFF667eea);
    final newGradientEndColor =
        Color(prefs.getInt('background_gradient_end') ?? 0xFF764ba2);
    final newBackgroundImagePath = prefs.getString('background_image_path');

    // Update cache
    _cachedBackgroundType = newBackgroundType;
    _cachedSolidColor = newSolidColor;
    _cachedGradientStartColor = newGradientStartColor;
    _cachedGradientEndColor = newGradientEndColor;
    _cachedBackgroundImagePath = newBackgroundImagePath;
    _hasLoadedOnce = true;

    if (mounted) {
      setState(() {
        _backgroundType = newBackgroundType;
        _solidColor = newSolidColor;
        _gradientStartColor = newGradientStartColor;
        _gradientEndColor = newGradientEndColor;
        _backgroundImagePath = newBackgroundImagePath;
      });
    }
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
        if (_backgroundImagePath != null && _backgroundImagePath!.isNotEmpty) {
          try {
            // Decode base64 image
            final Uint8List bytes = base64Decode(_backgroundImagePath!);
            background = Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: MemoryImage(bytes),
                  fit: BoxFit.cover,
                ),
              ),
            );
          } catch (e) {
            // If decoding fails, use solid color fallback
            background = Container(
              decoration: BoxDecoration(
                color: _solidColor,
              ),
            );
          }
        } else {
          background = Container(
            decoration: BoxDecoration(
              color: _solidColor,
            ),
          );
        }
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
