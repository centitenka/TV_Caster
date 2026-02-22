import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dlna_provider.dart';
import '../services/storage_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          // DLNA设置
          _buildSectionHeader(context, 'DLNA投屏'),
          _buildSettingTile(
            context,
            icon: Icons.cast_connected,
            title: '自动搜索海信电视',
            subtitle: '启动时自动搜索同网络的海信电视',
            trailing: Switch(
              value: true,
              onChanged: (value) {
                // 保存设置
              },
            ),
          ),
          _buildSettingTile(
            context,
            icon: Icons.high_quality,
            title: '优先使用高质量视频',
            subtitle: '自动选择最高清晰度的视频源',
            trailing: Switch(
              value: true,
              onChanged: (value) {
                // 保存设置
              },
            ),
          ),
          
          // 视频设置
          _buildSectionHeader(context, '视频解析'),
          _buildSettingTile(
            context,
            icon: Icons.auto_fix_high,
            title: '自动解析视频',
            subtitle: '添加链接时自动解析视频源',
            trailing: Switch(
              value: true,
              onChanged: (value) {
                // 保存设置
              },
            ),
          ),
          _buildSettingTile(
            context,
            icon: Icons.timer,
            title: '解析超时时间',
            subtitle: '当前: 30秒',
            onTap: () {
              _showTimeoutDialog(context);
            },
          ),
          
          // 关于
          _buildSectionHeader(context, '关于'),
          _buildSettingTile(
            context,
            icon: Icons.info,
            title: '版本信息',
            subtitle: 'v1.0.0',
          ),
          _buildSettingTile(
            context,
            icon: Icons.help,
            title: '使用帮助',
            subtitle: '了解如何使用海信投屏',
            onTap: () {
              _showHelpDialog(context);
            },
          ),
          _buildSettingTile(
            context,
            icon: Icons.delete_forever,
            title: '清除所有数据',
            subtitle: '删除所有视频、规则和设置',
            textColor: Colors.red,
            onTap: () {
              _confirmClearData(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildSettingTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: textColor),
      title: Text(title, style: TextStyle(color: textColor)),
      subtitle: Text(subtitle),
      trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right) : null),
      onTap: onTap,
    );
  }

  void _showTimeoutDialog(BuildContext context) {
    final timeouts = [10, 20, 30, 60, 120];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('解析超时时间'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: timeouts.map((seconds) {
            return RadioListTile<int>(
              title: Text('$seconds秒'),
              value: seconds,
              groupValue: 30,
              onChanged: (value) {
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('使用帮助'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '1. 添加视频',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('点击右下角"+"按钮，输入视频网页链接，应用会自动解析视频源。'),
              SizedBox(height: 12),
              Text(
                '2. 搜索设备',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('进入"设备"页面，点击"搜索设备"按钮查找同网络的海信电视。'),
              SizedBox(height: 12),
              Text(
                '3. 投屏播放',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('选择视频后点击"投屏"，选择海信电视即可开始播放。'),
              SizedBox(height: 12),
              Text(
                '4. 自定义规则',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('在"规则"页面可以创建XPath规则来解析特定网站的视频。'),
            ],
          ),
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

  void _confirmClearData(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清除'),
        content: const Text('确定要删除所有数据吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await StorageService().clearAll();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('所有数据已清除')),
                );
              }
            },
            child: const Text('清除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
