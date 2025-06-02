import 'package:flutter/material.dart';
import '../../models/template.dart';
import '../../models/widget.dart' as app_widget;
import '../../models/virtual_pin.dart';
import '../../widgets/base_screen.dart';
import '../../services/toast_service.dart';
import '../../services/template_service.dart';
import 'package:provider/provider.dart';
import '../../providers/playground_provider.dart';

class PinSettingsScreen extends StatefulWidget {
  final app_widget.Widget widget;
  final Template template;
  final Function(List<app_widget.PinConfig>) onSave;

  const PinSettingsScreen({
    super.key,
    required this.widget,
    required this.template,
    required this.onSave,
  });

  @override
  State<PinSettingsScreen> createState() => _PinSettingsScreenState();
}

class _PinSettingsScreenState extends State<PinSettingsScreen> {
  late List<app_widget.PinConfig> _pinConfigs;
  bool _hasChanges = false;
  Set<int> _usedPins = {};
  final _templateService = TemplateService();
  bool _isLoading = true;
  List<VirtualPin> _virtualPins = [];

  @override
  void initState() {
    super.initState();
    debugPrint('=== PinSettingsScreen initState ===');
    debugPrint('Widget ID: ${widget.widget.id}');
    debugPrint(
      'Initial pin configs: ${widget.widget.pinConfig.map((p) => 'virtualPin: ${p.virtualPin}, value: ${p.value}, id: ${p.id}').toList()}',
    );

    // Create a copy of pin configs for editing
    _pinConfigs = List.from(widget.widget.pinConfig);

    // Get all used pins from other widgets (excluding the current widget)
    _usedPins =
        widget.template.widgetList
            .where(
              (w) => w.widgetId != widget.widget.id,
            ) // Exclude current widget
            .expand((w) => w.pinConfig)
            .map((p) => p.virtualPin)
            .toSet();

    debugPrint('Current widget ID: ${widget.widget.id}');
    debugPrint('Used pins (excluding current widget): $_usedPins');

    // Fetch virtual pins from API
    _fetchVirtualPins();
  }

  Future<void> _fetchVirtualPins() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Fetch virtual pins from API
      _virtualPins = await _templateService.getVirtualPins(
        widget.template.templateId,
      );

      debugPrint('Fetched ${_virtualPins.length} virtual pins from API');

      // Get the current widget's instance ID to distinguish between identical widgets
      final String currentWidgetInstanceId = widget.widget.id;
      debugPrint('Current widget instance ID: $currentWidgetInstanceId');

      // Clear used pins and rebuild it from scratch
      _usedPins.clear();

      // Get all widgets from the template
      final playgroundProvider = context.read<PlaygroundProvider>();
      final allWidgets = playgroundProvider.widgets;

      // Update used pins based on all widgets in the playground
      for (final positionedWidget in allWidgets) {
        // Skip the current widget being edited
        if (positionedWidget.widget.id == currentWidgetInstanceId ||
            positionedWidget.id == currentWidgetInstanceId) {
          debugPrint('Skipping current widget when collecting used pins');
          continue;
        }

        // Add pins from other widgets to the used pins set
        for (final pinConfig in positionedWidget.widget.pinConfig) {
          _usedPins.add(pinConfig.virtualPin);
          debugPrint(
            'Adding used pin ${pinConfig.virtualPin} from widget ${positionedWidget.id}',
          );
        }
      }

      debugPrint('Updated used pins from template widgets: $_usedPins');

      // Initialize pins with unique virtual pins if not already set
      List<int> availablePins =
          _virtualPins
              .where(
                (p) =>
                    !_usedPins.contains(p.pin_id) ||
                    _pinConfigs.any((config) => config.virtualPin == p.pin_id),
              )
              .map((p) => p.pin_id)
              .toList();

      debugPrint('Available pins for assignment: $availablePins');

      // Ensure each pin in this widget has a valid assignment
      for (int i = 0; i < _pinConfigs.length; i++) {
        // If pin is unassigned (0) or used by another widget, assign a new one
        if (_pinConfigs[i].virtualPin == 0 ||
            (_usedPins.contains(_pinConfigs[i].virtualPin) &&
                !_pinConfigs.any(
                  (config) =>
                      config != _pinConfigs[i] &&
                      config.virtualPin == _pinConfigs[i].virtualPin,
                ))) {
          if (i < availablePins.length) {
            final virtualPin = _virtualPins.firstWhere(
              (p) => p.pin_id == availablePins[i],
              orElse:
                  () => _virtualPins.firstWhere(
                    (p) => !_usedPins.contains(p.pin_id),
                    orElse: () => _virtualPins.first,
                  ),
            );

            debugPrint(
              'Assigning new virtual pin ${virtualPin.pin_id} (${virtualPin.id}) to config at index $i',
            );

            _pinConfigs[i] = _pinConfigs[i].copyWith(
              virtualPin: virtualPin.pin_id,
              value: virtualPin.value,
              id: virtualPin.id,
            );
          }
        }
      }

      debugPrint(
        'Final pin configs after initialization: ${_pinConfigs.map((p) => 'virtualPin: ${p.virtualPin}, value: ${p.value}, id: ${p.id}').toList()}',
      );
    } catch (e) {
      debugPrint('Error fetching virtual pins: $e');
      if (mounted) {
        ToastService.error(context, message: 'Failed to fetch virtual pins');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updatePinValue(int index, double value) async {
    debugPrint('=== Updating pin value ===');
    debugPrint('Index: $index, New value: $value');
    debugPrint('Before update: ${_pinConfigs[index]}');

    final pinConfig = _pinConfigs[index];
    final virtualPin = _virtualPins.firstWhere(
      (pin) => pin.pin_id == pinConfig.virtualPin,
      orElse:
          () => widget.template.virtual_pins.firstWhere(
            (pin) => pin.pin_id == pinConfig.virtualPin,
          ),
    );

    // Only update if value is within bounds
    if (value >= virtualPin.min_value && value <= virtualPin.max_value) {
      // Update local state
      setState(() {
        _pinConfigs[index] = _pinConfigs[index].copyWith(
          value: value.toInt(),
          // Keep the same virtual pin and id
          virtualPin: pinConfig.virtualPin,
          id: pinConfig.id,
        );
        _hasChanges = true;
      });

      debugPrint('After update: ${_pinConfigs[index]}');
      debugPrint(
        'Updated pin configs: ${_pinConfigs.map((p) => 'virtualPin: ${p.virtualPin}, value: ${p.value}, id: ${p.id}').toList()}',
      );
    } else {
      debugPrint(
        'Value $value is outside bounds (${virtualPin.min_value} - ${virtualPin.max_value})',
      );
      if (mounted) {
        ToastService.error(
          context,
          message:
              'Value must be between ${virtualPin.min_value} and ${virtualPin.max_value}',
        );
      }
    }
  }

  Future<void> _savePinConfigs() async {
    debugPrint('=== Saving pin configurations ===');
    debugPrint(
      'Pin configs being saved: ${_pinConfigs.map((p) => 'virtualPin: ${p.virtualPin}, value: ${p.value}, id: ${p.id}').toList()}',
    );

    bool hasError = false;

    // Update each pin configuration
    for (final pinConfig in _pinConfigs) {
      final virtualPin = _virtualPins.firstWhere(
        (pin) => pin.pin_id == pinConfig.virtualPin,
        orElse:
            () => widget.template.virtual_pins.firstWhere(
              (pin) => pin.pin_id == pinConfig.virtualPin,
            ),
      );

      final success = await _templateService.updateVirtualPin(
        templateId: widget.template.templateId,
        pinId: pinConfig.id,
        pinName: virtualPin.pin_name,
        value: pinConfig.value,
        minValue: virtualPin.min_value,
        maxValue: virtualPin.max_value,
        isUsed: true,
      );

      if (!success) {
        hasError = true;
        if (mounted) {
          ToastService.error(
            context,
            message: 'Failed to update pin ${pinConfig.virtualPin}',
          );
        }
        break;
      }
    }

    if (!hasError) {
      if (mounted) {
        ToastService.success(context, message: 'Pin values saved successfully');
      }
      // Pass the updated configurations back to the playground without saving template
      widget.onSave(_pinConfigs);
      debugPrint('Pin configurations saved, navigating back');
      Navigator.pop(context);
    }
  }

  void _updateVirtualPin(int index, VirtualPin newPin) {
    debugPrint('=== Updating virtual pin ===');
    debugPrint('Index: $index');
    debugPrint(
      'New pin: pin_id=${newPin.pin_id}, id=${newPin.id}, value=${newPin.value}',
    );
    debugPrint('Current config: ${_pinConfigs[index]}');

    // Check if this pin is already used by another pin in the same widget
    bool isPinUsedInSameWidget = _pinConfigs.any(
      (config) =>
          config.virtualPin == newPin.pin_id &&
          _pinConfigs.indexOf(config) != index,
    );

    if (isPinUsedInSameWidget) {
      debugPrint('Error: Pin ${newPin.pin_id} is already used in this widget');
      ToastService.error(
        context,
        message: 'This pin is already used by another pin in this widget',
      );
      return;
    }

    // Update local state with new pin assignment
    setState(() {
      _pinConfigs[index] = _pinConfigs[index].copyWith(
        virtualPin: newPin.pin_id,
        value: newPin.value, // Keep the initial value from the virtual pin
        id: newPin.id,
      );
      _hasChanges = true;
    });

    debugPrint('After update: ${_pinConfigs[index]}');
    debugPrint(
      'All pin configs after update: ${_pinConfigs.map((p) => 'virtualPin: ${p.virtualPin}, value: ${p.value}, id: ${p.id}').toList()}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: '${widget.widget.name} Pin Settings',
      actions: [
        if (_hasChanges)
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save pin values',
            onPressed: _savePinConfigs,
          ),
      ],
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _pinConfigs.length,
                itemBuilder: (context, index) {
                  final pinConfig = _pinConfigs[index];
                  final virtualPin = _virtualPins.firstWhere(
                    (pin) => pin.pin_id == pinConfig.virtualPin,
                    orElse:
                        () => widget.template.virtual_pins.firstWhere(
                          (pin) => pin.pin_id == pinConfig.virtualPin,
                        ),
                  );

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pin ${index + 1}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          // Virtual Pin Dropdown
                          DropdownButtonFormField<VirtualPin>(
                            value: virtualPin,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Select Virtual Pin',
                              border: OutlineInputBorder(),
                            ),
                            items:
                                _virtualPins.map((pin) {
                                  // A pin is considered used if:
                                  // 1. It's marked as used in the API (is_used flag)
                                  // 2. AND it's not currently assigned to this pin config
                                  final bool isUsed =
                                      pin.is_used &&
                                      pin.pin_id != pinConfig.virtualPin;

                                  return DropdownMenuItem<VirtualPin>(
                                    value: pin,
                                    enabled: !isUsed,
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              pin.pin_name,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color:
                                                    isUsed ? Colors.grey : null,
                                              ),
                                            ),
                                          ),
                                          if (isUsed) ...[
                                            const SizedBox(width: 8),
                                            const Icon(
                                              Icons.lock,
                                              size: 16,
                                              color: Colors.grey,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                            onChanged: (VirtualPin? newPin) {
                              if (newPin != null) {
                                _updateVirtualPin(index, newPin);
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          // Field Value
                          TextFormField(
                            initialValue: pinConfig.value.toString(),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Field Value',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              final newValue =
                                  int.tryParse(value) ?? pinConfig.value;
                              _updatePinValue(index, newValue.toDouble());
                            },
                          ),
                          const SizedBox(height: 16),
                          // Min Value (read-only)
                          TextFormField(
                            initialValue: virtualPin.min_value.toString(),
                            readOnly: false,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Minimum Value',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              final newValue = int.tryParse(value);
                              if (newValue != null) {
                                setState(() {
                                  _hasChanges = true;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          // Max Value (read-only)
                          TextFormField(
                            initialValue: virtualPin.max_value.toString(),
                            readOnly: false,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Maximum Value',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              final newValue = int.tryParse(value);
                              if (newValue != null) {
                                setState(() {
                                  _hasChanges = true;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          // Slider for value adjustment
                          Row(
                            children: [
                              Text('Value: ${pinConfig.value}'),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Slider(
                                  value: pinConfig.value.toDouble(),
                                  min: virtualPin.min_value.toDouble(),
                                  max: virtualPin.max_value.toDouble(),
                                  divisions:
                                      (virtualPin.max_value -
                                              virtualPin.min_value)
                                          .toInt(),
                                  label: pinConfig.value.toString(),
                                  onChanged:
                                      (value) => _updatePinValue(index, value),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
