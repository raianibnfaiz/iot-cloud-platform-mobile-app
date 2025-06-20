import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../models/template.dart';
import '../../providers/playground_provider.dart';
import '../../widgets/base_screen.dart';
import '../../services/toast_service.dart';
import 'template_playground_screen.dart';
import '../../services/template_service.dart';
import '../../services/api_service.dart';

class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key});

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  final _templateService = TemplateService();
  final _apiService = APIService();
  List<Template> _templates = [];
  bool _isLoading = true;
  String? _error;
  StreamSubscription? _templateUpdateSubscription;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
    // Listen for template updates
    _templateUpdateSubscription = _templateService.onTemplateUpdate.listen((
      updatedTemplate,
    ) {
      _updateTemplate(updatedTemplate);
    });
  }

  @override
  void dispose() {
    _templateUpdateSubscription?.cancel();
    super.dispose();
  }

  void _updateTemplate(Template updatedTemplate) {
    setState(() {
      final index = _templates.indexWhere(
        (t) => t.templateId == updatedTemplate.templateId,
      );
      if (index != -1) {
        _templates[index] = updatedTemplate;
      }
    });
  }

  Future<void> _loadTemplates() async {
    try {
      final userData = await _apiService.getUserData();
      if (userData == null) {
        setState(() {
          _error = 'User data not found';
          _isLoading = false;
        });
        return;
      }

      debugPrint("Token : ${userData['token']}");

      final templates = await _templateService.getTemplates();

      if (mounted) {
        setState(() {
          _templates = templates;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createTemplate() async {
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Create Template'),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Template Name',
                  hintText: 'Enter template name',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a template name';
                  }
                  return null;
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(context, nameController.text);
                  }
                },
                child: const Text('Create'),
              ),
            ],
          ),
    ).then((templateName) async {
      if (templateName != null) {
        try {
          setState(() {
            _isLoading = true;
            _error = null;
          });

          final userData = await _apiService.getUserData();
          if (userData == null) throw Exception('User data not found');

          await _templateService.createTemplate(templateName);
          await _loadTemplates();

          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            ToastService.success(
              context,
              message: 'Template created successfully!',
            );
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _error = e.toString().replaceAll('Exception: ', '');
              _isLoading = false;
            });
            ToastService.error(context, message: _error!);
          }
        }
      }
    });
  }

  void _showTemplateDetails(BuildContext context, Template template) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Template Details'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Template_Name', template.templateName),
                const SizedBox(height: 8),
                _buildDetailRow('Template_ID', template.templateId),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(
                      text:
                          "Template_Name=${template.templateName} \n Template_ID=${template.templateId}",
                    ),
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ToastService.success(
                      context,
                      message: 'Template Name & ID copied to clipboard!',
                    );
                  }
                },
                child: const Text('Copy'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
        Expanded(
          child: Text(value, style: const TextStyle(fontFamily: 'monospace')),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'Templates',
      actions: [
        IconButton(icon: const Icon(Icons.add), onPressed: _createTemplate),
      ],
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Error: $_error',
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isLoading = true;
                          _error = null;
                        });
                        _loadTemplates();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
              : _templates.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'No templates found',
                      style: TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _createTemplate,
                      child: const Text('Create Template'),
                    ),
                  ],
                ),
              )
              : RefreshIndicator(
                onRefresh: _loadTemplates,
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: _templates.length,
                  itemBuilder: (context, index) {
                    final template = _templates[index];
                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Stack(
                        children: [
                          InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => ChangeNotifierProvider(
                                        create: (_) => PlaygroundProvider(),
                                        child: TemplatePlaygroundScreen(
                                          template: template,
                                        ),
                                      ),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.dashboard_outlined,
                                    size: 40,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  const SizedBox(height: 12),
                                  Flexible(
                                    child: Text(
                                      template.templateName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${template.widgetList.length} widgets',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              itemBuilder:
                                  (context) => [
                                    const PopupMenuItem(
                                      value: 'details',
                                      child: Row(
                                        children: [
                                          Icon(Icons.info_outline),
                                          SizedBox(width: 8),
                                          Text('Template Details'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Delete Template', style: TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
                              onSelected: (value) {
                                if (value == 'details') {
                                  _showTemplateDetails(context, template);
                                } else if (value == 'delete') {
                                  // Show delete confirmation dialog
                                  showDialog(
                                    context: context,
                                    builder: (dialogContext) => AlertDialog(
                                      title: const Text('Delete Template'),
                                      content: Text(
                                        'Are you sure you want to delete "${template.templateName}"? '
                                        'This action cannot be undone.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(dialogContext),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.red,
                                          ),
                                          onPressed: () async {
                                            // Close the confirmation dialog
                                            Navigator.pop(dialogContext);
                                            try {
                                              setState(() => _isLoading = true);
                                              await _templateService.deleteTemplate(
                                                template.templateId,
                                              );
                                              await _loadTemplates();
                                              if (mounted) {
                                                ToastService.success(
                                                  context,
                                                  message: 'Template deleted successfully!',
                                                );
                                              }
                                            } catch (e) {
                                              if (mounted) {
                                                ToastService.error(
                                                  context,
                                                  message: e.toString().replaceAll(
                                                    'Exception: ',
                                                    '',
                                                  ),
                                                );
                                              }
                                            } finally {
                                              if (mounted) {
                                                setState(() => _isLoading = false);
                                              }
                                            }
                                          },
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
    );
  }
}
