import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/rule_provider.dart';
import '../models/parser_rule.dart';
import 'edit_rule_screen.dart';

class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('解析规则'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload),
            onPressed: () => _showExportDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: () => _showImportDialog(context),
          ),
        ],
      ),
      body: Consumer<RuleProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.rules.isEmpty) {
            return _buildEmptyView(context);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.rules.length,
            itemBuilder: (context, index) {
              final rule = provider.rules[index];
              return _RuleCard(
                rule: rule,
                onTap: () => _showRuleOptions(context, rule),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const EditRuleScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('新建规则'),
      ),
    );
  }

  Widget _buildEmptyView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.rule_folder_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '暂无规则',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右下角按钮创建规则',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  void _showRuleOptions(BuildContext context, ParserRule rule) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('编辑'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditRuleScreen(rule: rule),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(
                rule.isEnabled ? Icons.toggle_on : Icons.toggle_off,
                color: rule.isEnabled ? Colors.green : null,
              ),
              title: Text(rule.isEnabled ? '禁用' : '启用'),
              onTap: () {
                Navigator.pop(context);
                final updated = ParserRule(
                  id: rule.id,
                  name: rule.name,
                  host: rule.host,
                  rules: rule.rules,
                  headers: rule.headers,
                  isEnabled: !rule.isEnabled,
                  createdAt: rule.createdAt,
                  description: rule.description,
                );
                context.read<RuleProvider>().updateRule(updated);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context, rule);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, ParserRule rule) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除规则"${rule.name}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<RuleProvider>().removeRule(rule.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('规则已删除')),
              );
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showExportDialog(BuildContext context) {
    final provider = context.read<RuleProvider>();
    final json = provider.exportRules();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导出规则'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('复制以下JSON内容保存：'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                json,
                maxLines: 10,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showImportDialog(BuildContext context) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入规则'),
        content: TextField(
          controller: controller,
          maxLines: 10,
          decoration: const InputDecoration(
            hintText: '粘贴JSON格式的规则数据',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              try {
                context.read<RuleProvider>().importRules(controller.text);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('规则导入成功')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('导入失败: $e')),
                );
              }
            },
            child: const Text('导入'),
          ),
        ],
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  final ParserRule rule;
  final VoidCallback onTap;

  const _RuleCard({
    required this.rule,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 状态指示器
              Container(
                width: 4,
                height: 50,
                decoration: BoxDecoration(
                  color: rule.isEnabled ? Colors.green : Colors.grey,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 16),
              // 信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            rule.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (!rule.isEnabled)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '已禁用',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Host: ${rule.host}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${rule.rules.length} 条规则',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              // 箭头
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
