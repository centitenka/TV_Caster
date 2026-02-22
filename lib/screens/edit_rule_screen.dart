import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/rule_provider.dart';
import '../models/parser_rule.dart';

class EditRuleScreen extends StatefulWidget {
  final ParserRule? rule;

  const EditRuleScreen({
    super.key,
    this.rule,
  });

  @override
  State<EditRuleScreen> createState() => _EditRuleScreenState();
}

class _EditRuleScreenState extends State<EditRuleScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.rule?.name ?? '');
  late final _hostController = TextEditingController(text: widget.rule?.host ?? '');
  late final _descController = TextEditingController(text: widget.rule?.description ?? '');
  
  late List<RuleItem> _rules;
  bool _isEnabled = true;

  @override
  void initState() {
    super.initState();
    _rules = widget.rule?.rules.toList() ?? [];
    _isEnabled = widget.rule?.isEnabled ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.rule != null;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '编辑规则' : '新建规则'),
        actions: [
          TextButton(
            onPressed: _saveRule,
            child: const Text('保存'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 基本信息
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: '规则名称',
                hintText: '例如：Bilibili解析',
                prefixIcon: const Icon(Icons.label),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入规则名称';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _hostController,
              decoration: InputDecoration(
                labelText: 'Host',
                hintText: '例如：bilibili.com 或 *（通用）',
                prefixIcon: const Icon(Icons.link),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入Host';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _descController,
              decoration: InputDecoration(
                labelText: '描述（可选）',
                hintText: '规则的简要说明',
                prefixIcon: const Icon(Icons.description),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            
            // 启用开关
            SwitchListTile(
              title: const Text('启用规则'),
              value: _isEnabled,
              onChanged: (value) {
                setState(() {
                  _isEnabled = value;
                });
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            
            const Divider(height: 32),
            
            // 规则项
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'XPath规则',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: _addRuleItem,
                  icon: const Icon(Icons.add),
                  label: const Text('添加'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            ..._rules.asMap().entries.map((entry) {
              final index = entry.key;
              final rule = entry.value;
              return _RuleItemCard(
                rule: rule,
                index: index,
                onEdit: () => _editRuleItem(index),
                onDelete: () => _deleteRuleItem(index),
              );
            }),
            
            if (_rules.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.rule_folder_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '暂无规则项',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _addRuleItem,
                        child: const Text('添加规则项'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _addRuleItem() {
    _showRuleItemDialog();
  }

  void _editRuleItem(int index) {
    _showRuleItemDialog(index: index, item: _rules[index]);
  }

  void _deleteRuleItem(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条规则项吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _rules.removeAt(index);
              });
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showRuleItemDialog({int? index, RuleItem? item}) {
    final nameController = TextEditingController(text: item?.name ?? '');
    final xpathController = TextEditingController(text: item?.xpath ?? '');
    final attrController = TextEditingController(text: item?.attribute ?? '');
    final regexController = TextEditingController(text: item?.regex ?? '');
    final replaceController = TextEditingController(text: item?.replacement ?? '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item == null ? '添加规则项' : '编辑规则项'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '名称',
                  hintText: '例如：video',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: xpathController,
                decoration: const InputDecoration(
                  labelText: 'XPath',
                  hintText: '//video/@src',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: attrController,
                decoration: const InputDecoration(
                  labelText: '属性（可选）',
                  hintText: '例如：src',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: regexController,
                decoration: const InputDecoration(
                  labelText: '正则表达式（可选）',
                  hintText: r'''["\']([^"\']+)["\']''',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: replaceController,
                decoration: const InputDecoration(
                  labelText: '替换（可选）',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final newItem = RuleItem(
                name: nameController.text,
                xpath: xpathController.text,
                attribute: attrController.text.isEmpty ? null : attrController.text,
                regex: regexController.text.isEmpty ? null : regexController.text,
                replacement: replaceController.text.isEmpty ? null : replaceController.text,
              );
              
              setState(() {
                if (index != null) {
                  _rules[index] = newItem;
                } else {
                  _rules.add(newItem);
                }
              });
              
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _saveRule() {
    if (!_formKey.currentState!.validate()) return;
    
    if (_rules.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少添加一条规则项')),
      );
      return;
    }
    
    final rule = ParserRule(
      id: widget.rule?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      host: _hostController.text.trim(),
      rules: _rules,
      isEnabled: _isEnabled,
      createdAt: widget.rule?.createdAt ?? DateTime.now(),
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
    );
    
    final provider = context.read<RuleProvider>();
    
    if (widget.rule != null) {
      provider.updateRule(rule);
    } else {
      provider.addRule(rule);
    }
    
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('规则已保存')),
    );
  }
}

class _RuleItemCard extends StatelessWidget {
  final RuleItem rule;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RuleItemCard({
    required this.rule,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: Text('${index + 1}'),
        ),
        title: Text(rule.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              rule.xpath,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            if (rule.regex != null)
              Text(
                'Regex: ${rule.regex}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
