import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../models/template.dart';
import '../../models/widget.dart' as app_widget;
import '../../models/virtual_pin.dart';
import '../../providers/playground_provider.dart';
import '../../providers/widget_provider.dart';
import '../../widgets/base_screen.dart';
import '../../components/draggable_widget_component.dart';
import '../../services/template_service.dart';
import '../../services/toast_service.dart';
import 'template_preview_screen.dart';
import 'pin_settings_screen.dart';

class TemplatePlaygroundScreen extends StatefulWidget {
  final Template template;

  const TemplatePlaygroundScreen({super.key, required this.template});

  @override
  State<TemplatePlaygroundScreen> createState() =>
      _TemplatePlaygroundScreenState();
}

class _TemplatePlaygroundScreenState extends State<TemplatePlaygroundScreen> {
  final _templateService = TemplateService();
  bool _isSaving = false;
  bool _isPreviewMode = false;

  // Track used virtual pins
  Set<int> _usedPins = {};

  @override
  void initState() {
    super.initState();
    // Load existing widgets after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExistingWidgets();
      _updateUsedPins();
    });
  }

  void _loadExistingWidgets() {
    final playgroundProvider = context.read<PlaygroundProvider>();
    final widgetProvider = context.read<WidgetProvider>();

    debugPrint('Loading widgets from template: ${widget.template.templateId}');
    debugPrint(
      'Template widget list count: ${widget.template.widgetList.length}',
    );

    // Load each widget from the template's widget list
    for (final templateWidget in widget.template.widgetList) {
      debugPrint(
        'Loading widget ${templateWidget.name} with position: x=${templateWidget.position?.x}, y=${templateWidget.position?.y}',
      );
      debugPrint(
        'Widget ID: ${templateWidget.widgetId}, Template Widget ID: ${templateWidget.id}',
      );
      debugPrint(
        'Pin config for widget: ${templateWidget.pinConfig.map((p) => 'virtualPin: ${p.virtualPin}, value: ${p.value}, id: ${p.id}').toList()}',
      );

      // Ensure we have a valid widget ID
      String widgetId = templateWidget.widgetId;
      if (widgetId.isEmpty || widgetId == "null") {
        widgetId =
            'widget_${DateTime.now().millisecondsSinceEpoch}_${templateWidget.name.replaceAll(' ', '_')}';
        debugPrint('Generated new widget ID: $widgetId for empty or null ID');
      }

      // Find the corresponding widget from the widget provider
      final matchingWidget = widgetProvider.widgets.firstWhere(
        (w) => w.id == widgetId,
        orElse: () {
          debugPrint('Creating fallback widget for: $widgetId');
          return app_widget.Widget(
            id: widgetId,
            name: templateWidget.name,
            image: templateWidget.image,
            pinRequired: templateWidget.pinRequired,
            pinConfig:
                templateWidget.toWidgetPinConfig().map((pin) {
                  // Ensure pin IDs are not empty
                  if (pin.id.isEmpty) {
                    return pin.copyWith(
                      id:
                          'pin_${DateTime.now().millisecondsSinceEpoch}_${pin.virtualPin}',
                    );
                  }
                  return pin;
                }).toList(),
            position: app_widget.Position(
              x: templateWidget.position?.x ?? 20.0,
              y: templateWidget.position?.y ?? 20.0,
            ),
            configuration: templateWidget.configuration,
          );
        },
      );

      // Create a new widget with the template's pin configuration
      final widgetWithPins = matchingWidget.copyWith(
        pinConfig:
            templateWidget.toWidgetPinConfig().map((pin) {
              // Ensure pin IDs are not empty
              if (pin.id.isEmpty) {
                return pin.copyWith(
                  id:
                      'pin_${DateTime.now().millisecondsSinceEpoch}_${pin.virtualPin}',
                );
              }
              return pin;
            }).toList(),
      );

      debugPrint('Adding widget to playground: ${widgetWithPins.name}');
      debugPrint(
        'Final pin config: ${widgetWithPins.pinConfig.map((p) => 'virtualPin: ${p.virtualPin}, value: ${p.value}, id: ${p.id}').toList()}',
      );

      // Add the widget to the playground with its saved position and pin configuration
      playgroundProvider.addWidget(
        widgetWithPins,
        position: app_widget.Position(
          x: templateWidget.position?.x ?? 20.0,
          y: templateWidget.position?.y ?? 20.0,
        ),
      );

      // Update used pins set
      _usedPins.addAll(templateWidget.pinConfig.map((pin) => pin.virtualPin));
    }
  }

  // Update the set of used pins
  void _updateUsedPins() {
    final playgroundProvider = context.read<PlaygroundProvider>();
    _usedPins = playgroundProvider.widgets.fold<Set<int>>(
      {},
      (pins, widget) =>
          pins..addAll(widget.widget.pinConfig.map((pin) => pin.virtualPin)),
    );
  }

  // Find the first n available virtual pins
  List<VirtualPin> _findAvailablePins(int count) {
    debugPrint(
      'Finding $count available pins from template ${widget.template.templateId}',
    );

    // Get the current state of used pins from the playground provider
    _updateUsedPins();

    debugPrint('Currently used pins: $_usedPins');

    // Sort virtual pins by pin_id to ensure we assign from the top
    final sortedPins = List<VirtualPin>.from(widget.template.virtual_pins)
      ..sort((a, b) => a.pin_id.compareTo(b.pin_id));

    debugPrint(
      'Available template pins sorted: ${sortedPins.map((p) => '${p.pin_id} (${p.id})').toList()}',
    );

    // Get the current template's virtual pins that are not used
    final availablePins =
        sortedPins
            .where((pin) => !_usedPins.contains(pin.pin_id) && !pin.is_used)
            .toList();

    debugPrint(
      'Found ${availablePins.length} available pins: ${availablePins.map((p) => '${p.pin_id} (${p.id})').toList()}',
    );

    if (availablePins.length < count) {
      throw Exception(
        'Not enough available pins. Need $count pins but only ${availablePins.length} available.',
      );
    }

    final selectedPins = availablePins.take(count).toList();
    debugPrint(
      'Selected pins: ${selectedPins.map((p) => '${p.pin_id} (${p.id})').toList()}',
    );

    return selectedPins;
  }

  void _showPinSettings(app_widget.Widget widgetToEdit) {
    debugPrint('=== Opening pin settings ===');
    debugPrint('Widget ID: ${widgetToEdit.id}');
    debugPrint(
      'Current pin configs: ${widgetToEdit.pinConfig.map((p) => 'virtualPin: ${p.virtualPin}, value: ${p.value}, id: ${p.id}').toList()}',
    );

    // Get provider instance before navigation
    final playgroundProvider = context.read<PlaygroundProvider>();

    // Find the actual positioned widget instance
    final positionedWidget = playgroundProvider.widgets.firstWhere(
      (w) => w.id == widgetToEdit.id || w.widget.id == widgetToEdit.id,
      orElse: () {
        debugPrint('Error: Could not find widget in playground');
        ToastService.error(context, message: 'Error: Widget not found');
        throw Exception('Widget not found in playground');
      },
    );

    debugPrint('Found positioned widget. ID: ${positionedWidget.id}');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: playgroundProvider),
              ],
              child: PinSettingsScreen(
                widget: positionedWidget.widget,
                template: widget.template,
                onSave: (updatedPinConfig) {
                  debugPrint('=== Saving pin config from settings ===');
                  debugPrint('Widget ID: ${positionedWidget.id}');
                  debugPrint(
                    'Updated pin config: ${updatedPinConfig.map((p) => 'virtualPin: ${p.virtualPin}, value: ${p.value}, id: ${p.id}').toList()}',
                  );
                  playgroundProvider.updateWidgetPinConfig(
                    positionedWidget.id,
                    updatedPinConfig,
                  );
                  _updateUsedPins();
                },
              ),
            ),
      ),
    );
  }

  // Check if a widget is a 3D widget based on its image field
  bool _is3DWidget(String image) {
    try {
      if (image.startsWith('{')) {
        final config = jsonDecode(image);
        return config is Map &&
            config.containsKey('type') &&
            config['type'].toString().contains('3d');
      }
    } catch (e) {
      debugPrint('Error checking if widget is 3D: $e');
    }
    return false;
  }

  void _showWidgetPicker(BuildContext context) {
    // Get the provider instances before showing the bottom sheet
    final playgroundProvider = context.read<PlaygroundProvider>();
    final widgetProvider = context.read<WidgetProvider>();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (bottomSheetContext) => DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            builder:
                (context, scrollController) => Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Controllers',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      Expanded(
                        child: Consumer<WidgetProvider>(
                          builder: (context, provider, child) {
                            if (provider.isLoading) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            if (provider.error != null) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Error: ${provider.error}',
                                      style: const TextStyle(color: Colors.red),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: () {
                                        provider.clearError();
                                        provider.refreshWidgets();
                                      },
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              );
                            }

                            if (provider.widgets.isEmpty) {
                              return const Center(
                                child: Text('No widgets available'),
                              );
                            }

                            return ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: provider.widgets.length,
                              itemBuilder: (context, index) {
                                final widget = provider.widgets[index];
                                final is3D = _is3DWidget(widget.image);

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: ListTile(
                                    leading: Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).primaryColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child:
                                          is3D
                                              ? Icon(
                                                Icons.view_in_ar,
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).primaryColor,
                                              )
                                              : widget.image.startsWith('http')
                                              ? Image.network(
                                                widget.image,
                                                width: 24,
                                                height: 24,
                                                errorBuilder: (
                                                  context,
                                                  error,
                                                  stackTrace,
                                                ) {
                                                  return Icon(
                                                    Icons.widgets_outlined,
                                                    color:
                                                        Theme.of(
                                                          context,
                                                        ).primaryColor,
                                                  );
                                                },
                                              )
                                              : Icon(
                                                Icons.widgets_outlined,
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).primaryColor,
                                              ),
                                    ),
                                    title: Text(widget.name),
                                    subtitle: Text(
                                      is3D
                                          ? '3D Interactive Widget (${widget.pinRequired} pins)'
                                          : '${widget.pinRequired} pins required',
                                    ),
                                    onTap: () {
                                      try {
                                        final size =
                                            MediaQuery.of(context).size;
                                        // Find available pins for the widget
                                        final availablePins =
                                            _findAvailablePins(
                                              widget.pinRequired,
                                            );

                                        // Initialize pins with available virtual pins
                                        final pins = List.generate(
                                          widget.pinRequired,
                                          (index) {
                                            final virtualPin =
                                                availablePins[index];
                                            debugPrint(
                                              'Assigning virtual pin ${virtualPin.pin_id} (${virtualPin.id}) to widget ${widget.name}',
                                            );
                                            return app_widget.PinConfig(
                                              virtualPin: virtualPin.pin_id,
                                              value: virtualPin.value,
                                              id:
                                                  virtualPin
                                                      .id, // Use the template's virtual pin ID
                                            );
                                          },
                                        );

                                        final newWidget = widget.copyWith(
                                          position: app_widget.Position(
                                            x: size.width / 2 - 50,
                                            y: size.height / 2 - 50,
                                          ),
                                          pinConfig: pins,
                                        );

                                        playgroundProvider.addWidget(newWidget);
                                        _updateUsedPins();
                                        Navigator.pop(context);

                                        // Always show pin settings after adding widget, even for 3D widgets
                                        // This ensures users can configure pins before interacting
                                        _showPinSettings(newWidget);
                                      } catch (e) {
                                        ToastService.error(
                                          context,
                                          message: e.toString().replaceAll(
                                            'Exception: ',
                                            '',
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  Future<void> _saveTemplate() async {
    final playgroundProvider = context.read<PlaygroundProvider>();
    final widgetProvider = context.read<WidgetProvider>();

    if (playgroundProvider.widgets.isEmpty) {
      ToastService.warning(
        context,
        message: 'Add at least one widget to save the template',
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // First fetch the current template state
      debugPrint('Fetching current template state...');
      final currentTemplate = await _templateService.getTemplate(
        widget.template.templateId,
      );
      debugPrint('Current template state:');
      debugPrint('Template ID: ${currentTemplate.templateId}');
      debugPrint(
        'Widget list: ${currentTemplate.widgetList.map((w) => {'widget_id': w.widgetId, 'name': w.name, 'pinConfig': w.pinConfig.map((p) => p.id).toList()}).toList()}',
      );
      debugPrint(
        'Virtual pins in use: ${currentTemplate.virtual_pins.where((p) => p.is_used).map((p) => p.pin_id).toList()}',
      );

      debugPrint('Creating widget list for template update...');
      debugPrint(
        'Template virtual pins: ${currentTemplate.virtual_pins.map((p) => '${p.pin_id} (${p.id})').toList()}',
      );

      // Track which pins are used by widgets
      Set<String> usedPinIds =
          {}; // Store pin IDs (MongoDB ObjectIds), not pin_id (virtual pin numbers)

      final widgetList =
          playgroundProvider.widgets
              .map((positionedWidget) {
                try {
                  // Skip widgets with empty or null IDs
                  if (positionedWidget.widget.id.isEmpty ||
                      positionedWidget.widget.id == "null") {
                    debugPrint(
                      'Skipping widget with empty or null ID: ${positionedWidget.widget.name}',
                    );
                    return null;
                  }

                  // Check if the widget_id is a valid MongoDB ObjectId (24 hex characters)
                  final isValidObjectId =
                      positionedWidget.widget.id.length == 24 &&
                      RegExp(
                        r'^[0-9a-f]{24}$',
                      ).hasMatch(positionedWidget.widget.id);

                  debugPrint(
                    'Widget ID: ${positionedWidget.widget.id}, isValidObjectId: $isValidObjectId',
                  );

                  // Get the required pin count for this widget
                  final requiredPinCount = positionedWidget.widget.pinRequired;
                  debugPrint(
                    'Widget ${positionedWidget.widget.name} requires $requiredPinCount pins',
                  );

                  // Find a matching widget from the server to use its ID
                  String widgetId;
                  if (isValidObjectId) {
                    // If it's already a valid ObjectId, use it
                    widgetId = positionedWidget.widget.id;
                  } else {
                    // Find a matching widget from the server by name
                    final matchingWidget = widgetProvider.widgets.firstWhere(
                      (w) => w.name == positionedWidget.widget.name,
                      orElse: () {
                        // Always return a non-null widget
                        return widgetProvider.widgets.isNotEmpty
                            ? widgetProvider.widgets.first
                            : app_widget.Widget(
                              id: "67c534217747ddabd5a1b357", // Push button ID
                              name: "Push button",
                              image: "led_switch.png",
                              pinRequired: 1,
                              pinConfig: [],
                            );
                      },
                    );

                    widgetId = matchingWidget.id;
                    debugPrint(
                      'Using widget ID: ${matchingWidget.id} for ${positionedWidget.widget.name}',
                    );
                  }

                  // Map each widget's pin configuration to template virtual pins
                  // IMPORTANT: We need to ensure we only use the exact number of pins required by the widget
                  final pinConfigIds =
                      positionedWidget.widget.pinConfig
                          .take(
                            requiredPinCount,
                          ) // Only take the required number of pins
                          .map((pin) {
                            try {
                              // Find the corresponding virtual pin in the template by pin_id
                              final templatePin = currentTemplate.virtual_pins
                                  .firstWhere(
                                    (vPin) => vPin.pin_id == pin.virtualPin,
                                    orElse: () {
                                      debugPrint(
                                        'Failed to find virtual pin ${pin.virtualPin} in template pins',
                                      );
                                      // Find any available pin from the template
                                      final availablePin = currentTemplate
                                          .virtual_pins
                                          .firstWhere(
                                            (vPin) => !vPin.is_used,
                                            orElse:
                                                () =>
                                                    currentTemplate
                                                        .virtual_pins
                                                        .first,
                                          );
                                      debugPrint(
                                        'Using fallback pin ${availablePin.pin_id} (${availablePin.id})',
                                      );
                                      return availablePin;
                                    },
                                  );

                              // Add this pin ID to the used pins set
                              usedPinIds.add(templatePin.id);

                              debugPrint(
                                'Mapped pin ${pin.virtualPin} to template pin ID: ${templatePin.id}',
                              );
                              return templatePin
                                  .id; // Just return the MongoDB ObjectId of the pin
                            } catch (e) {
                              debugPrint('Error mapping pin config: $e');
                              // Provide a fallback pin with a valid ID from the template
                              final fallbackPin =
                                  currentTemplate.virtual_pins.first;

                              // Add this pin ID to the used pins set
                              usedPinIds.add(fallbackPin.id);

                              return fallbackPin
                                  .id; // Just return the MongoDB ObjectId of the pin
                            }
                          })
                          .toList();

                  debugPrint(
                    'Widget ${positionedWidget.widget.name} using pin IDs: $pinConfigIds',
                  );

                  // Create a simplified TemplateWidget with just the required fields
                  return TemplateWidget(
                    widgetId: widgetId, // Use a valid widget ID from the server
                    name: positionedWidget.widget.name,
                    image: positionedWidget.widget.image,
                    pinRequired: requiredPinCount,
                    // Create PinConfig objects with just the ID (the API will only use the ID)
                    pinConfig:
                        pinConfigIds
                            .map(
                              (id) => PinConfig(
                                virtualPin:
                                    0, // This won't be used in the API request
                                value:
                                    0, // This won't be used in the API request
                                id: id, // This is the only field that matters for the API request
                              ),
                            )
                            .toList(),
                    id: positionedWidget.id,
                    position: Position(
                      x: positionedWidget.position.x,
                      y: positionedWidget.position.y,
                    ),
                    configuration: {}, // Not needed for the API request
                  );
                } catch (e) {
                  debugPrint('Error processing widget for template: $e');
                  // Return null instead of a widget with empty ID
                  return null;
                }
              })
              .where((widget) => widget != null) // Filter out null widgets
              .cast<TemplateWidget>() // Cast to the correct type
              .toList();

      debugPrint(
        'Saving template ${widget.template.templateId} with ${widgetList.length} widgets',
      );

      // Update the virtual_pins list to mark used pins
      final updatedVirtualPins =
          currentTemplate.virtual_pins.map((pin) {
            // If this pin's ID is in our used pins set, mark it as used
            if (usedPinIds.contains(pin.id)) {
              debugPrint('Marking pin ${pin.pin_id} (${pin.id}) as used');
              return VirtualPin(
                id: pin.id,
                pin_id: pin.pin_id,
                pin_name: pin.pin_name,
                value: pin.value,
                min_value: pin.min_value,
                max_value: pin.max_value,
                is_used: true, // Mark as used
              );
            }
            return pin;
          }).toList();

      // Make sure we're using the same virtual_pins from the current template
      Template templateToUpdate = Template(
        id: widget.template.id,
        templateName: widget.template.templateName,
        templateId: widget.template.templateId,
        widgetList: widgetList,
        virtual_pins:
            updatedVirtualPins, // Use updated pins with correct is_used flags
      );

      final updatedTemplate = await _templateService.updateTemplate(
        templateToUpdate,
        widgetList,
      );

      debugPrint(
        'Template updated successfully: ${updatedTemplate.templateName}',
      );

      if (mounted) {
        ToastService.success(context, message: 'Template saved successfully!');
      }
    } catch (e) {
      debugPrint('Error saving template: $e');
      if (mounted) {
        ToastService.error(
          context,
          message: e.toString().replaceAll('Exception: ', ''),
        );
      }
    }

    if (mounted) {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _updateWidgetPosition(String widgetId, Offset newPosition) {
    debugPrint('=== Updating widget position ===');
    debugPrint('Widget ID: $widgetId');
    debugPrint('New position: $newPosition');

    final playgroundProvider = context.read<PlaygroundProvider>();
    final existingWidget = playgroundProvider.widgets.firstWhere(
      (w) => w.id == widgetId, // Use exact instance ID match
      orElse: () {
        debugPrint('Widget not found by exact ID: $widgetId');
        // Fallback to base widget ID if needed
        return playgroundProvider.widgets.firstWhere(
          (w) => w.widget.id == widgetId,
          orElse: () {
            debugPrint('Widget not found by widget.id either: $widgetId');
            return playgroundProvider.widgets.first;
          },
        );
      },
    );

    debugPrint(
      'Found widget. Current pin configs: ${existingWidget.widget.pinConfig.map((p) => 'virtualPin: ${p.virtualPin}, value: ${p.value}, id: ${p.id}').toList()}',
    );

    // Create updated widget with new position while preserving ALL existing properties
    final updatedWidget = existingWidget.copyWith(
      position: app_widget.Position(x: newPosition.dx, y: newPosition.dy),
      // Preserve ALL widget properties including pin configuration
      widget: existingWidget.widget,
    );

    debugPrint(
      'After position update pin configs: ${updatedWidget.widget.pinConfig.map((p) => 'virtualPin: ${p.virtualPin}, value: ${p.value}, id: ${p.id}').toList()}',
    );

    playgroundProvider.updateWidget(updatedWidget);
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: "Template ${widget.template.templateName}",
      actions: [
        IconButton(
          icon: const Icon(Icons.save),
          onPressed: _isSaving ? null : () => _saveTemplate(),
        ),
        IconButton(
          icon: Icon(_isPreviewMode ? Icons.edit : Icons.play_arrow),
          onPressed: () {
            if (_isPreviewMode) {
              setState(() {
                _isPreviewMode = false;
              });
            } else {
              // Create a template with current widget positions
              final playgroundProvider = context.read<PlaygroundProvider>();
              final previewTemplate = Template(
                id: widget.template.id,
                templateName: widget.template.templateName,
                templateId: widget.template.templateId,
                widgetList:
                    playgroundProvider.widgets
                        .map(
                          (w) => TemplateWidget(
                            widgetId: w.widget.id,
                            name: w.widget.name,
                            image: w.widget.image,
                            pinRequired: w.widget.pinRequired,
                            pinConfig:
                                w.widget.pinConfig
                                    .map(
                                      (p) => PinConfig(
                                        virtualPin: p.virtualPin,
                                        value: p.value,
                                        id: p.id,
                                      ),
                                    )
                                    .toList(),
                            id: w.id,
                            position: Position(
                              x: w.position.x,
                              y: w.position.y,
                            ),
                            configuration: w.configuration,
                          ),
                        )
                        .toList(),
                virtual_pins: widget.template.virtual_pins,
              );

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) =>
                          TemplatePreviewScreen(template: previewTemplate),
                ),
              );
            }
          },
        ),
      ],
      body: Consumer<PlaygroundProvider>(
        builder: (context, playgroundProvider, child) {
          return Stack(
            children: [
              // Background grid
              CustomPaint(painter: GridPainter(), size: Size.infinite),
              // Widgets
              ...playgroundProvider.widgets.map((positionedWidget) {
                return Positioned(
                  left: positionedWidget.position.x,
                  top: positionedWidget.position.y,
                  child: DraggableWidgetComponent(
                    key: ValueKey(positionedWidget.id),
                    positionedWidget: positionedWidget,
                    isPreviewMode: _isPreviewMode,
                    onTap: () {
                      if (!_isPreviewMode) {
                        _showPinSettings(positionedWidget.widget);
                      }
                    },
                    onPositionChanged: (newPosition) {
                      _updateWidgetPosition(
                        positionedWidget.id,
                        Offset(newPosition.x, newPosition.y),
                      );
                    },
                    onRemove: () {
                      playgroundProvider.removeWidget(positionedWidget.id);
                      _updateUsedPins();
                    },
                  ),
                );
              }).toList(),
              // Add widget button
              if (!_isPreviewMode)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton(
                    onPressed: () => _showWidgetPicker(context),
                    child: const Icon(Icons.add),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.grey.withOpacity(0.2)
          ..strokeWidth = 1;

    const spacing = 20.0;

    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }

    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
