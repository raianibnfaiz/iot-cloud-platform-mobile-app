import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/widget.dart' as app_widget;

class Interactive3DWidget extends StatefulWidget {
  final app_widget.Widget widget;
  final bool isPreviewMode;
  final bool value;
  final Function(bool)? onValueChanged;

  const Interactive3DWidget({
    Key? key,
    required this.widget,
    required this.isPreviewMode,
    required this.value,
    this.onValueChanged,
  }) : super(key: key);

  @override
  State<Interactive3DWidget> createState() => _Interactive3DWidgetState();
}

class _Interactive3DWidgetState extends State<Interactive3DWidget> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late bool _value;
  double _sliderValue = 50.0;
  String _textValue = '';
  Color _selectedColor = Colors.blue;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  
  // Cache parsed widget config
  late Map<String, dynamic> _widgetConfig;
  late String _widgetType;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
    _parseWidgetConfig();
    
    // Initialize animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic)
    );
    
    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.125).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOutQuad)
    );
  }

  void _parseWidgetConfig() {
    try {
      _widgetConfig = json.decode(widget.widget.image);
      _widgetType = _widgetConfig['type'] ?? '3d_switch';
      
      // Initialize widget-specific values
      if (_widgetType == '3d_slider') {
        final state = _widgetConfig['state'];
        if (state != null) {
          _sliderValue = (state['default_value'] ?? 50).toDouble();
        }
      } else if (_widgetType == '3d_text_input' || _widgetType == '3d_number_input') {
        final state = _widgetConfig['state'];
        if (state != null) {
          _textValue = state['default_text'] ?? '';
        }
      } else if (_widgetType == '3d_color_picker') {
        final state = _widgetConfig['state'];
        if (state != null) {
          _selectedColor = HexColor.fromHex(state['default_color'] ?? '#2196F3');
        }
      }
    } catch (e) {
      debugPrint('Error parsing widget config: $e');
      _widgetConfig = {};
      _widgetType = '3d_switch';
    }
  }

  @override
  void didUpdateWidget(Interactive3DWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      setState(() {
        _value = widget.value;
      });
    }
    
    if (oldWidget.widget.image != widget.widget.image) {
      _parseWidgetConfig();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleSwitch() {
    if (!widget.isPreviewMode) return;
    
    setState(() {
      _value = !_value;
    });
    
    // Play animation
    if (_value) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
    
    // Provide haptic feedback if specified
    final hapticFeedback = _getHapticFeedback('on_toggle');
    _provideHapticFeedback(hapticFeedback);
    
    widget.onValueChanged?.call(_value);
  }
  
  void _updateSliderValue(double value) {
    if (!widget.isPreviewMode) return;
    
    setState(() {
      _sliderValue = value;
    });
    
    // Provide haptic feedback if specified
    final hapticFeedback = _getHapticFeedback('on_drag');
    _provideHapticFeedback(hapticFeedback);
    
    // For slider, we convert to boolean based on threshold
    final boolValue = _sliderValue > 50;
    widget.onValueChanged?.call(boolValue);
  }
  
  void _handleButtonPress() {
    if (!widget.isPreviewMode) return;
    
    // Animate button press
    _animationController.forward().then((_) {
      _animationController.reverse();
    });
    
    // Provide haptic feedback if specified
    final hapticFeedback = _getHapticFeedback('on_press');
    _provideHapticFeedback(hapticFeedback);
    
    // For button, we toggle the value
    setState(() {
      _value = !_value;
    });
    
    widget.onValueChanged?.call(_value);
  }
  
  String _getHapticFeedback(String key) {
    try {
      if (_widgetConfig.containsKey('feedback') && 
          _widgetConfig['feedback'].containsKey('haptic') && 
          _widgetConfig['feedback']['haptic'].containsKey(key)) {
        return _widgetConfig['feedback']['haptic'][key];
      }
    } catch (e) {
      debugPrint('Error getting haptic feedback: $e');
    }
    return 'medium';
  }
  
  void _provideHapticFeedback(String intensity) {
    switch (intensity) {
      case 'light':
        HapticFeedback.lightImpact();
        break;
      case 'medium':
        HapticFeedback.mediumImpact();
        break;
      case 'heavy':
        HapticFeedback.heavyImpact();
        break;
      case 'error':
        HapticFeedback.vibrate();
        break;
      default:
        HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => widget.isPreviewMode ? setState(() {
        _isHovered = true;
        _animationController.forward(from: 0.0);
      }) : null,
      onExit: (_) => widget.isPreviewMode ? setState(() {
        _isHovered = false;
        _animationController.reverse();
      }) : null,
      child: GestureDetector(
        onTap: widget.isPreviewMode ? 
          _widgetType == '3d_button' ? _handleButtonPress : _toggleSwitch : null,
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.scale(
              scale: _isHovered ? _scaleAnimation.value : 1.0,
              child: Stack(
                children: [
                  _buildWidgetByType(),
                  if (!widget.isPreviewMode)
                    Container(
                      width: _getWidgetSize().width,
                      height: _getWidgetSize().height,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'Configure',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }
        ),
      ),
    );
  }
  
  Size _getWidgetSize() {
    switch (_widgetType) {
      case '3d_slider':
        return const Size(180, 80);
      case '3d_gauge':
        return const Size(120, 120);
      case '3d_color_picker':
        return const Size(150, 150);
      case '3d_text_input':
      case '3d_number_input':
        return const Size(150, 60);
      case '3d_button':
      case '3d_toggle_button':
      case '3d_switch':
      default:
        return const Size(100, 100);
    }
  }
  
  Widget _buildWidgetByType() {
    switch (_widgetType) {
      case '3d_slider':
        return _buildSlider();
      case '3d_gauge':
        return _buildGauge();
      case '3d_color_picker':
        return _buildColorPicker();
      case '3d_text_input':
        return _buildTextInput();
      case '3d_number_input':
        return _buildNumberInput();
      case '3d_button':
        return _buildButton();
      case '3d_toggle_button':
        return _buildToggleButton();
      case '3d_switch':
      default:
        return _buildSwitch();
    }
  }
  
  Widget _buildSwitch() {
    // Extract colors from widget config
    final appearance = _widgetConfig['appearance'] ?? {};
    final colors = appearance['colors'] ?? {};
    
    final baseColor = HexColor.fromHex(colors['base'] ?? '#303F9F');
    final onColor = HexColor.fromHex(colors['switch_on'] ?? '#4CAF50');
    final offColor = HexColor.fromHex(colors['switch_off'] ?? '#F44336');
    final handleColor = HexColor.fromHex(colors['handle'] ?? '#E0E0E0');
    
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: _value ? onColor : offColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          if (_isHovered)
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Center(
        child: Transform.rotate(
          angle: _value ? _rotationAnimation.value * 2 * 3.14159 : 0,
          child: Icon(
            _value ? Icons.toggle_on : Icons.toggle_off,
            color: Colors.white,
            size: 48,
          ),
        ),
      ),
    );
  }
  
  Widget _buildSlider() {
    // Extract colors from widget config
    final appearance = _widgetConfig['appearance'] ?? {};
    final colors = appearance['colors'] ?? {};
    
    final trackColor = HexColor.fromHex(colors['track'] ?? '#E0E0E0');
    final handleColor = HexColor.fromHex(colors['handle'] ?? '#2196F3');
    final activeTrackColor = HexColor.fromHex(colors['active_track'] ?? '#BBDEFB');
    
    // Extract state from widget config
    final state = _widgetConfig['state'] ?? {};
    final minValue = (state['min_value'] ?? 0).toDouble();
    final maxValue = (state['max_value'] ?? 100).toDouble();
    final step = (state['step'] ?? 1).toDouble();
    
    // Ensure slider value is within bounds
    double currentValue = _sliderValue;
    if (currentValue < minValue) currentValue = minValue;
    if (currentValue > maxValue) currentValue = maxValue;
    
    return Container(
      width: 180,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          if (_isHovered)
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Value display
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                '${currentValue.round()}',
                style: TextStyle(
                  color: handleColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Slider
            SizedBox(
              height: 40,
              child: SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: activeTrackColor,
                  inactiveTrackColor: trackColor,
                  thumbColor: handleColor,
                  overlayColor: handleColor.withOpacity(0.2),
                  trackHeight: 6,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                ),
                child: Slider(
                  value: currentValue,
                  min: minValue,
                  max: maxValue,
                  divisions: ((maxValue - minValue) / step).round(),
                  onChanged: widget.isPreviewMode ? _updateSliderValue : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildGauge() {
    // Extract colors from widget config
    final appearance = _widgetConfig['appearance'] ?? {};
    final colors = appearance['colors'] ?? {};
    
    final dialColor = HexColor.fromHex(colors['dial'] ?? '#FAFAFA');
    final needleColor = HexColor.fromHex(colors['needle'] ?? '#F44336');
    
    // Extract state from widget config
    final state = _widgetConfig['state'] ?? {};
    final minValue = (state['min_value'] ?? 0).toDouble();
    final maxValue = (state['max_value'] ?? 100).toDouble();
    final value = _sliderValue;
    
    // Calculate angle for needle (0 to 270 degrees)
    final angle = (value - minValue) / (maxValue - minValue) * 270;
    
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: dialColor,
        shape: BoxShape.circle,
        boxShadow: [
          if (_isHovered)
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Gauge background
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: dialColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300, width: 2),
            ),
          ),
          
          // Gauge needle
          Transform.rotate(
            angle: (angle - 135) * 3.14159 / 180, // Convert to radians and adjust starting position
            child: Container(
              height: 50,
              width: 2,
              decoration: BoxDecoration(
                color: needleColor,
                borderRadius: BorderRadius.circular(1),
              ),
              alignment: Alignment.topCenter,
            ),
          ),
          
          // Center point
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: needleColor,
              shape: BoxShape.circle,
            ),
          ),
          
          // Value text
          Positioned(
            bottom: 20,
            child: Text(
              value.round().toString(),
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildColorPicker() {
    // Extract colors from widget config
    final appearance = _widgetConfig['appearance'] ?? {};
    final colors = appearance['colors'] ?? {};
    
    final backgroundColor = HexColor.fromHex(colors['background'] ?? '#FFFFFF');
    final borderColor = HexColor.fromHex(colors['border'] ?? '#BDBDBD');
    
    // Extract preset colors
    final interaction = _widgetConfig['interaction'] ?? {};
    final presets = interaction['presets'] ?? {};
    final presetColors = presets['colors'] ?? [
      '#F44336', '#2196F3', '#4CAF50', '#FFEB3B', '#9C27B0', '#FF9800'
    ];
    
    return Container(
      width: 150,
      height: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          if (_isHovered)
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Selected color display
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _selectedColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: _selectedColor.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Color presets
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: List.generate(
              presetColors.length > 6 ? 6 : presetColors.length,
              (index) {
                final color = HexColor.fromHex(presetColors[index]);
                return GestureDetector(
                  onTap: widget.isPreviewMode ? () {
                    setState(() {
                      _selectedColor = color;
                    });
                    // For color picker, we convert to boolean based on brightness
                    final boolValue = color.computeLuminance() < 0.5;
                    widget.onValueChanged?.call(boolValue);
                  } : null,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTextInput() {
    // Extract colors from widget config
    final appearance = _widgetConfig['appearance'] ?? {};
    final colors = appearance['colors'] ?? {};
    
    final backgroundColor = HexColor.fromHex(colors['background'] ?? '#FFFFFF');
    final textColor = HexColor.fromHex(colors['text'] ?? '#212121');
    final borderColor = HexColor.fromHex(colors['border'] ?? '#BDBDBD');
    final placeholderColor = HexColor.fromHex(colors['placeholder'] ?? '#9E9E9E');
    
    // Extract state from widget config
    final state = _widgetConfig['state'] ?? {};
    final placeholder = state['placeholder'] ?? 'Enter text...';
    
    return Container(
      width: 150,
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isHovered ? Colors.blue : borderColor,
          width: _isHovered ? 2 : 1,
        ),
        boxShadow: [
          if (_isHovered)
            BoxShadow(
              color: Colors.blue.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Center(
        child: TextField(
          enabled: widget.isPreviewMode,
          controller: TextEditingController(text: _textValue),
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: placeholder,
            hintStyle: TextStyle(color: placeholderColor),
          ),
          onChanged: (value) {
            setState(() {
              _textValue = value;
            });
            // For text input, we convert to boolean based on whether text is empty
            final boolValue = value.isNotEmpty;
            widget.onValueChanged?.call(boolValue);
          },
        ),
      ),
    );
  }
  
  Widget _buildNumberInput() {
    // Extract colors from widget config
    final appearance = _widgetConfig['appearance'] ?? {};
    final colors = appearance['colors'] ?? {};
    
    final backgroundColor = HexColor.fromHex(colors['background'] ?? '#FFFFFF');
    final textColor = HexColor.fromHex(colors['text'] ?? '#212121');
    final borderColor = HexColor.fromHex(colors['border'] ?? '#BDBDBD');
    final buttonColor = HexColor.fromHex(colors['buttons'] ?? '#2196F3');
    
    // Extract state from widget config
    final state = _widgetConfig['state'] ?? {};
    final minValue = state['min_value'] ?? -100;
    final maxValue = state['max_value'] ?? 100;
    final step = state['step'] ?? 1;
    
    return Container(
      width: 150,
      height: 60,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
        boxShadow: [
          if (_isHovered)
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        children: [
          // Decrement button
          GestureDetector(
            onTap: widget.isPreviewMode ? () {
              final newValue = _sliderValue - step;
              if (newValue >= minValue) {
                setState(() {
                  _sliderValue = newValue;
                });
                // For number input, we convert to boolean based on positive/negative
                final boolValue = newValue > 0;
                widget.onValueChanged?.call(boolValue);
              }
            } : null,
            child: Container(
              width: 40,
              height: 60,
              decoration: BoxDecoration(
                color: buttonColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(7),
                  bottomLeft: Radius.circular(7),
                ),
              ),
              child: const Icon(Icons.remove, color: Colors.white),
            ),
          ),
          
          // Value display
          Expanded(
            child: Center(
              child: Text(
                _sliderValue.round().toString(),
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          
          // Increment button
          GestureDetector(
            onTap: widget.isPreviewMode ? () {
              final newValue = _sliderValue + step;
              if (newValue <= maxValue) {
                setState(() {
                  _sliderValue = newValue;
                });
                // For number input, we convert to boolean based on positive/negative
                final boolValue = newValue > 0;
                widget.onValueChanged?.call(boolValue);
              }
            } : null,
            child: Container(
              width: 40,
              height: 60,
              decoration: BoxDecoration(
                color: buttonColor,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(7),
                  bottomRight: Radius.circular(7),
                ),
              ),
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildButton() {
    // Extract colors from widget config
    final appearance = _widgetConfig['appearance'] ?? {};
    final colors = appearance['colors'] ?? {};
    
    final buttonColor = HexColor.fromHex(colors['button'] ?? '#2196F3');
    final textColor = HexColor.fromHex(colors['text'] ?? '#FFFFFF');
    final shadowColor = HexColor.fromHex(colors['shadow'] ?? '#1976D2');
    
    // Extract state from widget config
    final state = _widgetConfig['state'] ?? {};
    final label = state['label'] ?? 'PRESS';
    
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: buttonColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withOpacity(0.5),
            blurRadius: 8,
            offset: const Offset(0, 4),
            spreadRadius: _animationController.value * -2 + 2,
          ),
        ],
      ),
      child: Transform.scale(
        scale: 1.0 - (_animationController.value * 0.05),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildToggleButton() {
    // Extract colors from widget config
    final appearance = _widgetConfig['appearance'] ?? {};
    final colors = appearance['colors'] ?? {};
    
    final activeColor = HexColor.fromHex(colors['active'] ?? '#4CAF50');
    final inactiveColor = HexColor.fromHex(colors['inactive'] ?? '#F44336');
    final textColor = HexColor.fromHex(colors['text'] ?? '#FFFFFF');
    
    // Extract state from widget config
    final state = _widgetConfig['state'] ?? {};
    final labels = state['labels'] ?? {};
    final onLabel = labels['on'] ?? 'ON';
    final offLabel = labels['off'] ?? 'OFF';
    
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: _value ? activeColor : inactiveColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          if (_isHovered)
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _value ? Icons.check_circle : Icons.cancel,
              color: textColor,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              _value ? onLabel : offLabel,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper extension to convert hex color strings to Color objects
extension HexColor on Color {
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 7) {
      buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
    } else {
      buffer.write(hexString.replaceFirst('#', ''));
    }
    return Color(int.parse(buffer.toString(), radix: 16));
  }
} 