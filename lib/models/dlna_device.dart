/// DLNA设备数据模型
class DLNADeviceModel {
  final String id;
  final String name;
  final String deviceType;
  final String urlBase;
  bool isConnected;

  DLNADeviceModel({
    required this.id,
    required this.name,
    required this.deviceType,
    required this.urlBase,
    this.isConnected = false,
  });

  String get deviceTypeShort {
    if (deviceType.contains(':')) {
      return deviceType.split(':')[3];
    }
    return deviceType;
  }

  bool get isHisenseTV {
    return name.toLowerCase().contains('hisense') || 
           name.toLowerCase().contains('海信') ||
           deviceType.toLowerCase().contains('hisense');
  }

  bool get isMediaRenderer {
    return deviceTypeShort == 'MediaRenderer' || 
           deviceType.contains('MediaRenderer');
  }

  @override
  String toString() {
    return 'DLNADeviceModel{name: $name, type: $deviceTypeShort, isHisense: $isHisenseTV}';
  }
}
