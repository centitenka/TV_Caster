import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dlna_provider.dart';
import '../models/dlna_device.dart';

class DLNADevicesScreen extends StatelessWidget {
  const DLNADevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DLNA设备'),
        actions: [
          Consumer<DLNAProvider>(
            builder: (context, provider, child) {
              return IconButton(
                icon: Icon(
                  provider.isSearching ? Icons.stop : Icons.refresh,
                ),
                onPressed: () {
                  if (provider.isSearching) {
                    provider.stopSearch();
                  } else {
                    provider.startSearch();
                  }
                },
              );
            },
          ),
        ],
      ),
      body: Consumer<DLNAProvider>(
        builder: (context, provider, child) {
          if (provider.errorMessage != null) {
            return _buildErrorView(context, provider);
          }

          final devices = provider.devices;
          
          if (devices.isEmpty) {
            return _buildEmptyView(context, provider);
          }

          return RefreshIndicator(
            onRefresh: () async {
              provider.startSearch();
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 海信电视优先显示
                if (provider.hisenseDevices.isNotEmpty) ...[
                  _buildSectionTitle('海信电视', Icons.tv),
                  ...provider.hisenseDevices.map(
                    (device) => _DeviceCard(
                      device: device,
                      isSelected: provider.selectedDevice?.id == device.id,
                      onTap: () => provider.selectDevice(device),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // 其他设备
                if (provider.devices.length > provider.hisenseDevices.length) ...[
                  _buildSectionTitle('其他设备', Icons.devices_other),
                  ...provider.devices
                      .where((d) => !d.isHisenseTV)
                      .map(
                        (device) => _DeviceCard(
                          device: device,
                          isSelected: provider.selectedDevice?.id == device.id,
                          onTap: () => provider.selectDevice(device),
                        ),
                      ),
                ],
              ],
            ),
          );
        },
      ),
      floatingActionButton: Consumer<DLNAProvider>(
        builder: (context, provider, child) {
          return FloatingActionButton.extended(
            onPressed: () {
              if (provider.isSearching) {
                provider.stopSearch();
              } else {
                provider.startSearch();
              }
            },
            icon: Icon(provider.isSearching ? Icons.stop : Icons.search),
            label: Text(provider.isSearching ? '停止搜索' : '搜索设备'),
            backgroundColor: provider.isSearching
                ? Colors.red
                : Theme.of(context).colorScheme.primary,
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView(BuildContext context, DLNAProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cast_connected_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '未发现设备',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击搜索按钮查找同网络的DLNA设备',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          if (provider.isSearching)
            const CircularProgressIndicator()
          else
            ElevatedButton.icon(
              onPressed: () => provider.startSearch(),
              icon: const Icon(Icons.search),
              label: const Text('开始搜索'),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, DLNAProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(
            '出错了',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            provider.errorMessage ?? '未知错误',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => provider.clearError(),
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final DLNADeviceModel device;
  final bool isSelected;
  final VoidCallback onTap;

  const _DeviceCard({
    required this.device,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              )
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 设备图标
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _getDeviceColor().withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getDeviceIcon(),
                  size: 28,
                  color: _getDeviceColor(),
                ),
              ),
              const SizedBox(width: 16),
              // 设备信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            device.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (device.isHisenseTV)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '海信',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      device.deviceTypeShort,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      device.urlBase,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // 选中标记
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getDeviceIcon() {
    switch (device.deviceTypeShort) {
      case 'MediaRenderer':
        return Icons.cast_connected;
      case 'MediaServer':
        return Icons.storage;
      case 'InternetGatewayDevice':
        return Icons.router;
      case 'BasicDevice':
        return Icons.device_hub;
      default:
        return device.isHisenseTV ? Icons.tv : Icons.device_unknown;
    }
  }

  Color _getDeviceColor() {
    if (device.isHisenseTV) return Colors.blue;
    switch (device.deviceTypeShort) {
      case 'MediaRenderer':
        return Colors.green;
      case 'MediaServer':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
