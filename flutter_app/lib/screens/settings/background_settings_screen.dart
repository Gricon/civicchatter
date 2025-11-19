import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/civic_chatter_app_bar.dart';
import 'dart:convert';
import 'dart:math' as math;

class BackgroundSettingsScreen extends StatefulWidget {
  const BackgroundSettingsScreen({super.key});

  @override
  State<BackgroundSettingsScreen> createState() =>
      _BackgroundSettingsScreenState();
}

class _BackgroundSettingsScreenState extends State<BackgroundSettingsScreen> {
  final ImagePicker _picker = ImagePicker();
  String _backgroundType = 'color'; // 'color', 'gradient', 'image'
  Color _solidColor = const Color(0xFFF5F5F5);
  Color _gradientStartColor = const Color(0xFF667eea);
  Color _gradientEndColor = const Color(0xFF764ba2);
  double _gradientAngle = 135.0; // Gradient angle in degrees (0-360)
  String? _backgroundImagePath;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _backgroundType = prefs.getString('background_type') ?? 'color';
      _solidColor = Color(prefs.getInt('background_solid_color') ?? 0xFFF5F5F5);
      _gradientStartColor =
          Color(prefs.getInt('background_gradient_start') ?? 0xFF667eea);
      _gradientEndColor =
          Color(prefs.getInt('background_gradient_end') ?? 0xFF764ba2);
      _gradientAngle = prefs.getDouble('background_gradient_angle') ?? 135.0;
      _backgroundImagePath = prefs.getString('background_image_path');
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('background_type', _backgroundType);
    await prefs.setInt('background_solid_color', _solidColor.toARGB32());
    await prefs.setInt(
        'background_gradient_start', _gradientStartColor.toARGB32());
    await prefs.setInt('background_gradient_end', _gradientEndColor.toARGB32());
    await prefs.setDouble('background_gradient_angle', _gradientAngle);
    if (_backgroundImagePath != null) {
      await prefs.setString('background_image_path', _backgroundImagePath!);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Background settings saved!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        // Read image as bytes and convert to base64
        final bytes = await image.readAsBytes();
        final base64Image = base64Encode(bytes);

        setState(() {
          _backgroundImagePath = base64Image;
          _backgroundType = 'image';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Convert angle in degrees to Alignment pair
  AlignmentGeometry _angleToAlignment(double angle, {bool isBegin = true}) {
    // Normalize angle to 0-360
    final normalizedAngle = angle % 360;
    // Convert to radians
    final radians = normalizedAngle * math.pi / 180;

    if (isBegin) {
      return Alignment(
        -1 * math.cos(radians),
        -1 * math.sin(radians),
      );
    } else {
      return Alignment(
        1 * math.cos(radians),
        1 * math.sin(radians),
      );
    }
  }

  Widget _buildColorPicker(
      String label, Color currentColor, Function(Color) onColorChanged) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildColorOption(
                    const Color(0xFFF5F5F5), currentColor, onColorChanged),
                _buildColorOption(
                    const Color(0xFFFFFFFF), currentColor, onColorChanged),
                _buildColorOption(
                    const Color(0xFF0b1220), currentColor, onColorChanged),
                _buildColorOption(
                    const Color(0xFF1a1a2e), currentColor, onColorChanged),
                _buildColorOption(
                    const Color(0xFF16213e), currentColor, onColorChanged),
                _buildColorOption(
                    const Color(0xFF0f3460), currentColor, onColorChanged),
                _buildColorOption(
                    const Color(0xFF533483), currentColor, onColorChanged),
                _buildColorOption(
                    const Color(0xFF667eea), currentColor, onColorChanged),
                _buildColorOption(
                    const Color(0xFF764ba2), currentColor, onColorChanged),
                _buildColorOption(
                    const Color(0xFFf093fb), currentColor, onColorChanged),
                _buildColorOption(
                    const Color(0xFF4facfe), currentColor, onColorChanged),
                _buildColorOption(
                    const Color(0xFF00f2fe), currentColor, onColorChanged),
                _buildColorOption(
                    const Color(0xFF43e97b), currentColor, onColorChanged),
                _buildColorOption(
                    const Color(0xFF38f9d7), currentColor, onColorChanged),
                _buildColorOption(
                    const Color(0xFFfa709a), currentColor, onColorChanged),
                _buildColorOption(
                    const Color(0xFFfee140), currentColor, onColorChanged),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorOption(
      Color color, Color currentColor, Function(Color) onColorChanged) {
    final isSelected = color.toARGB32() == currentColor.toARGB32();
    return InkWell(
      onTap: () => onColorChanged(color),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey[300]!,
            width: isSelected ? 3 : 1,
          ),
        ),
        child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
      ),
    );
  }

  Widget _buildAnglePreset(String arrow, double angle) {
    final isSelected = (_gradientAngle - angle).abs() < 1;
    return InkWell(
      onTap: () {
        setState(() {
          _gradientAngle = angle;
        });
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            arrow,
            style: TextStyle(
              fontSize: 24,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    Widget preview;

    switch (_backgroundType) {
      case 'color':
        preview = Container(color: _solidColor);
        break;
      case 'gradient':
        preview = Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: _angleToAlignment(_gradientAngle, isBegin: true),
              end: _angleToAlignment(_gradientAngle, isBegin: false),
              colors: [_gradientStartColor, _gradientEndColor],
            ),
          ),
        );
        break;
      case 'image':
        if (_backgroundImagePath != null && _backgroundImagePath!.isNotEmpty) {
          try {
            // Decode base64 image for preview
            final bytes = base64Decode(_backgroundImagePath!);
            preview = Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: MemoryImage(bytes),
                  fit: BoxFit.cover,
                ),
              ),
            );
          } catch (e) {
            preview = Container(
              color: Colors.grey[300],
              child: Center(
                child: Text('Error loading image: $e'),
              ),
            );
          }
        } else {
          preview = Container(
            color: Colors.grey[300],
            child: const Center(
              child: Text('No image selected'),
            ),
          );
        }
        break;
      default:
        preview = Container(color: _solidColor);
    }

    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: preview,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CivicChatterAppBar(
        title: 'Background Settings',
        showBackButton: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text(
            'Background Preview',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          _buildPreview(),
          const SizedBox(height: 32),
          Text(
            'Background Type',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Card(
            child: RadioGroup<String>(
              groupValue: _backgroundType,
              onChanged: (value) {
                setState(() {
                  _backgroundType = value!;
                });
              },
              child: const Column(
                children: [
                  RadioListTile<String>(
                    value: 'color',
                    title: Text('Solid Color'),
                    subtitle: Text('Single color background'),
                    secondary: Icon(Icons.palette),
                  ),
                  Divider(height: 1),
                  RadioListTile<String>(
                    value: 'gradient',
                    title: Text('Gradient'),
                    subtitle: Text('Two-color gradient background'),
                    secondary: Icon(Icons.gradient),
                  ),
                  Divider(height: 1),
                  RadioListTile<String>(
                    value: 'image',
                    title: Text('Image'),
                    subtitle: Text('Upload your own background image'),
                    secondary: Icon(Icons.image),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          if (_backgroundType == 'color') ...[
            _buildColorPicker('Solid Color', _solidColor, (color) {
              setState(() {
                _solidColor = color;
              });
            }),
          ],
          if (_backgroundType == 'gradient') ...[
            _buildColorPicker('Gradient Start Color', _gradientStartColor,
                (color) {
              setState(() {
                _gradientStartColor = color;
              });
            }),
            const SizedBox(height: 16),
            _buildColorPicker('Gradient End Color', _gradientEndColor, (color) {
              setState(() {
                _gradientEndColor = color;
              });
            }),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.rotate_right,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Gradient Direction',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_gradientAngle.toInt()}°',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                    Slider(
                      value: _gradientAngle,
                      min: 0,
                      max: 360,
                      divisions: 72,
                      label: '${_gradientAngle.toInt()}°',
                      onChanged: (value) {
                        setState(() {
                          _gradientAngle = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildAnglePreset('→', 0),
                        _buildAnglePreset('↗', 45),
                        _buildAnglePreset('↑', 90),
                        _buildAnglePreset('↖', 135),
                        _buildAnglePreset('←', 180),
                        _buildAnglePreset('↙', 225),
                        _buildAnglePreset('↓', 270),
                        _buildAnglePreset('↘', 315),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_backgroundType == 'image') ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Upload Background Image',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Choose Image'),
                    ),
                    if (_backgroundImagePath != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Image selected',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.green,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _saveSettings,
            icon: const Icon(Icons.save),
            label: const Text('Save Background Settings'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('background_type');
              await prefs.remove('background_solid_color');
              await prefs.remove('background_gradient_start');
              await prefs.remove('background_gradient_end');
              await prefs.remove('background_gradient_angle');
              await prefs.remove('background_image_path');

              if (!mounted) return;

              setState(() {
                _backgroundType = 'color';
                _solidColor = const Color(0xFFF5F5F5);
                _gradientStartColor = const Color(0xFF667eea);
                _gradientEndColor = const Color(0xFF764ba2);
                _gradientAngle = 135.0;
                _backgroundImagePath = null;
              });

              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Background reset to default'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
            icon: const Icon(Icons.restore),
            label: const Text('Reset to Default'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}
