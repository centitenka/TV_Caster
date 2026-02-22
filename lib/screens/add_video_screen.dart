import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/video_provider.dart';
import '../providers/rule_provider.dart';
import '../models/video_source.dart';
import '../services/local_media_service.dart';
import '../services/video_parser_service.dart';

class AddVideoScreen extends StatefulWidget {
  const AddVideoScreen({super.key});

  @override
  State<AddVideoScreen> createState() => _AddVideoScreenState();
}

class _AddVideoScreenState extends State<AddVideoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final LocalMediaService _localMediaService = LocalMediaService();

  bool _isParsing = false;
  List<Map<String, dynamic>> _parsedResults = [];
  String? _selectedRuleId;
  LocalImportResult? _selectedLocalImport;

  bool get _isLocalMode {
    final uri = Uri.tryParse(_urlController.text.trim());
    return uri?.scheme == 'file';
  }

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('添加视频'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // URL输入
              TextFormField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: '视频链接',
                  hintText: '输入视频网页URL、直链，或选择本地视频',
                  prefixIcon: const Icon(Icons.link),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.paste),
                    onPressed: _pasteUrl,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.url,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入视频链接';
                  }
                  final uri = Uri.tryParse(value);
                  final scheme = uri?.scheme.toLowerCase();
                  if (scheme != 'http' &&
                      scheme != 'https' &&
                      scheme != 'file') {
                    return '请输入有效的URL，或选择本地视频';
                  }
                  return null;
                },
                onChanged: (value) {
                  final nowLocal = Uri.tryParse(value.trim())?.scheme == 'file';
                  if (!nowLocal && _selectedLocalImport != null) {
                    setState(() {
                      _selectedLocalImport = null;
                    });
                  }
                  if (nowLocal && _parsedResults.isNotEmpty) {
                    setState(() {
                      _parsedResults = [];
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              _buildLocalImportSection(),
              const SizedBox(height: 16),

              // 规则选择
              Consumer<RuleProvider>(
                builder: (context, ruleProvider, child) {
                  return DropdownButtonFormField<String?>(
                    value: _selectedRuleId,
                    decoration: InputDecoration(
                      labelText: '解析规则（可选）',
                      prefixIcon: const Icon(Icons.rule),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('自动检测'),
                      ),
                      ...ruleProvider.enabledRules.map((rule) {
                        return DropdownMenuItem(
                          value: rule.id,
                          child: Text(rule.name),
                        );
                      }),
                    ],
                    onChanged: _isLocalMode
                        ? null
                        : (value) {
                            setState(() {
                              _selectedRuleId = value;
                            });
                          },
                  );
                },
              ),
              const SizedBox(height: 16),

              // 解析按钮
              ElevatedButton.icon(
                onPressed: (_isParsing || _isLocalMode) ? null : _parseVideo,
                icon: _isParsing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_fix_high),
                label: Text(
                  _isLocalMode ? '本地文件无需解析' : (_isParsing ? '解析中...' : '自动解析'),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 解析结果
              if (_parsedResults.isNotEmpty) ...[
                const Text(
                  '解析结果',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ..._parsedResults.map((result) => _buildResultCard(result)),
              ],

              // 手动输入
              const Divider(height: 32),
              const Text(
                '手动输入',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: '视频名称',
                  hintText: '输入视频名称',
                  prefixIcon: const Icon(Icons.title),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                decoration: InputDecoration(
                  labelText: '描述（可选）',
                  hintText: '输入视频描述',
                  prefixIcon: const Icon(Icons.description),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _saveVideo,
                icon: const Icon(Icons.save),
                label: const Text('保存视频'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocalImportSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '本地文件导入',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickFromGallery,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('从图库选择'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickFromFileManager,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('从文件管理器选择'),
                ),
              ),
            ],
          ),
          if (_selectedLocalImport != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '已选择本地文件：${_selectedLocalImport!.displayName} (${_formatFileSize(_selectedLocalImport!.sizeBytes)})',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> result) {
    final type = result['type'] as String;
    final url = result['url'] as String;
    final title = result['title'] as String? ?? '视频';

    IconData icon;
    Color color;

    switch (type) {
      case 'm3u8':
        icon = Icons.live_tv;
        color = Colors.orange;
        break;
      case 'mp4':
        icon = Icons.video_file;
        color = Colors.blue;
        break;
      case 'iframe':
        icon = Icons.web;
        color = Colors.purple;
        break;
      default:
        icon = Icons.video_library;
        color = Colors.green;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(
          url,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: TextButton(
          onPressed: () {
            _urlController.text = url;
            _nameController.text = title;
          },
          child: const Text('使用'),
        ),
      ),
    );
  }

  Future<void> _pasteUrl() async {
    // 实现粘贴功能
    // 需要clipboard插件
  }

  Future<void> _parseVideo() async {
    if (_isLocalMode) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isParsing = true;
    });

    try {
      final parser = VideoParserService();
      final url = _urlController.text.trim();

      List<Map<String, dynamic>> results;

      if (_selectedRuleId != null) {
        // 从 RuleProvider 获取规则对象
        final ruleProvider = context.read<RuleProvider>();
        final rule = ruleProvider.getRuleById(_selectedRuleId!);

        if (rule != null) {
          results = await parser.parseWithRule(url, rule);
        } else {
          // 如果找不到规则，退回到普通解析
          results = await parser.parseVideo(url);
        }
      } else {
        // 自动检测：先按 host 尝试匹配规则，再回退通用解析
        results = [];
        final ruleProvider = context.read<RuleProvider>();
        String? host;
        try {
          host = Uri.parse(url).host;
        } catch (_) {
          host = null;
        }

        if (host != null && host.isNotEmpty) {
          final matchedRules = ruleProvider.getRulesForHost(host);
          for (final rule in matchedRules) {
            results = await parser.parseWithRule(url, rule);
            if (results.isNotEmpty) {
              break;
            }
          }
        }

        if (results.isEmpty) {
          results = await parser.parseVideo(url);
        }
      }

      if (!mounted) return;

      setState(() {
        _parsedResults = results;
        _isParsing = false;
      });

      if (results.isNotEmpty) {
        // 自动填充第一个结果
        final first = results.first;
        if (first['url'] != null) {
          _urlController.text = first['url'];
        }
        if (_nameController.text.isEmpty && first['title'] != null) {
          _nameController.text = first['title'];
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isParsing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('解析失败: $e')),
      );
    }
  }

  void _saveVideo() {
    if (!_formKey.currentState!.validate()) return;

    final isLocal = _isLocalMode;
    final video = VideoSource(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim().isEmpty
          ? '未命名视频'
          : _nameController.text.trim(),
      url: _urlController.text.trim(),
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      createdAt: DateTime.now(),
      ruleId: isLocal ? null : _selectedRuleId,
    );

    context.read<VideoProvider>().addVideo(video);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('视频已保存')),
      );
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final result = await _localMediaService.pickFromGalleryAndImport();
      if (!mounted || result == null) return;

      _applyLocalImportResult(result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败: $e')),
      );
    }
  }

  Future<void> _pickFromFileManager() async {
    try {
      final result = await _localMediaService.pickFromFileManagerAndImport();
      if (!mounted || result == null) return;

      _applyLocalImportResult(result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败: $e')),
      );
    }
  }

  void _applyLocalImportResult(LocalImportResult result) {
    setState(() {
      _selectedLocalImport = result;
      _parsedResults = [];
      _selectedRuleId = null;
      _urlController.text = result.fileUri;
      if (_nameController.text.trim().isEmpty ||
          _nameController.text.trim() == '未命名视频') {
        _nameController.text = result.displayName;
      }
    });
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(2)} GB';
  }
}
