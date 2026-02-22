import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dlna_provider.dart';
import '../models/video_source.dart';
import '../models/dlna_device.dart';

class CastScreen extends StatefulWidget {
  final VideoSource video;

  const CastScreen({
    super.key,
    required this.video,
  });

  @override
  State<CastScreen> createState() => _CastScreenState();
}

class _CastScreenState extends State<CastScreen> {
  bool _isCasting = false;
  bool _castSuccess = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // 自动开始搜索设备
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DLNAProvider>().startSearch();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('投屏'),
      ),
      body: Consumer<DLNAProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              // 视频信息卡片
              _buildVideoInfoCard(),

              // 设备选择区域
              Expanded(
                child: _buildDeviceSelection(provider),
              ),

              // 投屏控制按钮
              _buildControlButtons(provider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVideoInfoCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.video_file,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  '当前视频',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              widget.video.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              _buildVideoSourceText(widget.video.url),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (widget.video.description != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.video.description!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceSelection(DLNAProvider provider) {
    if (provider.devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (provider.isSearching) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('正在搜索设备...'),
              const SizedBox(height: 8),
              Text(
                '请确保电视和手机在同一WiFi网络',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ] else ...[
              Icon(
                Icons.cast_connected_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              const Text('未发现设备'),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => provider.startSearch(),
                icon: const Icon(Icons.search),
                label: const Text('搜索设备'),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '选择设备',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (provider.isSearching)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: provider.devices.length,
            itemBuilder: (context, index) {
              final device = provider.devices[index];
              return _DeviceListTile(
                device: device,
                isSelected: provider.selectedDevice?.id == device.id,
                onTap: () => provider.selectDevice(device),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildControlButtons(DLNAProvider provider) {
    final selectedDevice = provider.selectedDevice;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            Row(
              children: [
                // 搜索按钮
                Expanded(
                  flex: 1,
                  child: ElevatedButton.icon(
                    onPressed: provider.isSearching
                        ? null
                        : () => provider.startSearch(),
                    icon: const Icon(Icons.search),
                    label: const Text('搜索'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      foregroundColor: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 投屏按钮
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: selectedDevice == null || _isCasting
                        ? null
                        : () => _startCast(provider),
                    icon: _isCasting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.cast),
                    label: Text(
                      _isCasting
                          ? '投屏中...'
                          : selectedDevice == null
                              ? '请选择设备'
                              : '投屏到${selectedDevice.isHisenseTV ? '海信电视' : selectedDevice.name}',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
            if (_castSuccess) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ControlButton(
                    icon: Icons.play_arrow,
                    label: '播放',
                    onPressed: () => provider.play(),
                  ),
                  _ControlButton(
                    icon: Icons.pause,
                    label: '暂停',
                    onPressed: () => provider.pause(),
                  ),
                  _ControlButton(
                    icon: Icons.stop,
                    label: '停止',
                    onPressed: () {
                      provider.stop();
                      setState(() {
                        _castSuccess = false;
                      });
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _buildVideoSourceText(String source) {
    final uri = Uri.tryParse(source);
    if (uri?.scheme != 'file') return source;

    final decoded = Uri.decodeComponent(
        uri!.pathSegments.isNotEmpty ? uri.pathSegments.last : source);
    if (decoded.isEmpty) {
      return '本地文件';
    }
    return '本地文件: $decoded';
  }

  Future<void> _startCast(DLNAProvider provider) async {
    setState(() {
      _isCasting = true;
      _errorMessage = null;
    });

    final success = await provider.castVideo(
      widget.video.url,
      title: widget.video.name,
    );

    if (!mounted) return;
    setState(() {
      _isCasting = false;
      _castSuccess = success;
      if (!success) {
        _errorMessage = provider.errorMessage ?? '投屏失败';
      }
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已成功投屏到 ${provider.selectedDevice?.name}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}

class _DeviceListTile extends StatelessWidget {
  final DLNADeviceModel device;
  final bool isSelected;
  final VoidCallback onTap;

  const _DeviceListTile({
    required this.device,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isSelected ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          device.isHisenseTV ? Icons.tv : Icons.cast,
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.grey[600],
        ),
        title: Text(device.name),
        subtitle: Text(device.deviceTypeShort),
        trailing: isSelected
            ? Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              )
            : null,
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon),
          style: IconButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            foregroundColor: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
