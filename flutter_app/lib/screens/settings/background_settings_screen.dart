import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/civic_chatter_app_bar.dart';

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
      _backgroundImagePath = prefs.getString('background_image_path');
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('background_type', _backgroundType);
    await prefs.setInt('background_solid_color', _solidColor.value);
    await prefs.setInt('background_gradient_start', _gradientStartColor.value);
    await prefs.setInt('background_gradient_end', _gradientEndColor.value);
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
        setState(() {
          _backgroundImagePath = image.path;
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
    final isSelected = color.value == currentColor.value;
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
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_gradientStartColor, _gradientEndColor],
            ),
          ),
        );
        break;
      case 'image':
        preview = _backgroundImagePath != null
            ? Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(_backgroundImagePath!),
                    fit: BoxFit.cover,
                  ),
                ),
              )
            : Container(
                color: Colors.grey[300],
                child: const Center(
                  child: Text('No image selected'),
                ),
              );
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
      appBar: CivicChatterAppBar(
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
            child: Column(
              children: [
                RadioListTile<String>(
                  value: 'color',
                  groupValue: _backgroundType,
                  onChanged: (value) {
                    setState(() {
                      _backgroundType = value!;
                    });
                  },
                  title: const Text('Solid Color'),
                  subtitle: const Text('Single color background'),
                  secondary: const Icon(Icons.palette),
                ),
                const Divider(height: 1),
                RadioListTile<String>(
                  value: 'gradient',
                  groupValue: _backgroundType,
                  onChanged: (value) {
                    setState(() {
                      _backgroundType = value!;
                    });
                  },
                  title: const Text('Gradient'),
                  subtitle: const Text('Two-color gradient background'),
                  secondary: const Icon(Icons.gradient),
                ),
                const Divider(height: 1),
                RadioListTile<String>(
                  value: 'image',
                  groupValue: _backgroundType,
                  onChanged: (value) {
                    setState(() {
                      _backgroundType = value!;
                    });
                  },
                  title: const Text('Image'),
                  subtitle: const Text('Upload your own background image'),
                  secondary: const Icon(Icons.image),
                ),
              ],
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
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('background_type');
              await prefs.remove('background_solid_color');
              await prefs.remove('background_gradient_start');
              await prefs.remove('background_gradient_end');
              await prefs.remove('background_image_path');

              setState(() {
                _backgroundType = 'color';
                _solidColor = const Color(0xFFF5F5F5);
                _gradientStartColor = const Color(0xFF667eea);
                _gradientEndColor = const Color(0xFF764ba2);
                _backgroundImagePath = null;
              });

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Background reset to default'),
                    backgroundColor: Colors.blue,
                  ),
                );
              }
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
