import 'package:flutter/material.dart';

abstract class AppService extends ChangeNotifier {
  StatusData? get status;
  ConfigData? get config;
  bool get connected;
  bool get isLoading;
  bool get isRunning;

  Future<void> fetchStatus();
  Future<void> fetchConfig();
  Future<bool> startService({
    String? ipFile,
    List<String>? ipContent,
    String? http,
    int? delayLimit,
    double? tlr,
    int? ips,
    int? threads,
    int? tlsPort,
    int? httpPort,
    List<String>? colo,
    String? addr,
    int? maxStickySlots,
    List<String>? customIps,
    List<String>? domains,
  });
  Future<bool> stopService();
  Future<List<LogEntry>> fetchLogs();
  Future<bool> clearLogs();

  // DNS 更新器
  Future<DnsUpdaterConfig?> getDnsConfig();
  Future<bool> updateDnsConfig(DnsUpdaterConfig config);
  Future<DnsUpdaterStatus?> getDnsStatus();
}

class StatusData {
  final bool running;
  final int uptimeSecs;
  final int nextHealthCheck;
  final int healthCheckInterval;
  final int primaryCount;
  final int primaryTarget;
  final int backupCount;
  final int backupTarget;
  final List<String> stickyIps;
  final List<IpInfo> primaryIps;
  final List<IpInfo> backupIps;

  StatusData({
    required this.running,
    required this.uptimeSecs,
    required this.nextHealthCheck,
    required this.healthCheckInterval,
    required this.primaryCount,
    required this.primaryTarget,
    required this.backupCount,
    required this.backupTarget,
    required this.stickyIps,
    required this.primaryIps,
    required this.backupIps,
  });

  factory StatusData.stopped() {
    return StatusData(
      running: false,
      uptimeSecs: 0,
      nextHealthCheck: 0,
      healthCheckInterval: 0,
      primaryCount: 0,
      primaryTarget: 0,
      backupCount: 0,
      backupTarget: 0,
      stickyIps: const [],
      primaryIps: const [],
      backupIps: const [],
    );
  }

  factory StatusData.fromJson(Map<String, dynamic> json) {
    return StatusData(
      running: json['running'] as bool,
      uptimeSecs: json['uptime_secs'] as int,
      nextHealthCheck: json['next_health_check'] as int,
      healthCheckInterval: json['health_check_interval'] as int,
      primaryCount: json['primary_count'] as int,
      primaryTarget: json['primary_target'] as int,
      backupCount: json['backup_count'] as int,
      backupTarget: json['backup_target'] as int,
      stickyIps: (json['sticky_ips'] as List).cast<String>(),
      primaryIps: (json['primary_ips'] as List)
          .map((e) => IpInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      backupIps: (json['backup_ips'] as List)
          .map((e) => IpInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class IpInfo {
  final String ip;
  final String? colo;
  final double delay;
  final double loss;
  final int samples;

  IpInfo({
    required this.ip,
    this.colo,
    required this.delay,
    required this.loss,
    required this.samples,
  });

  factory IpInfo.fromJson(Map<String, dynamic> json) {
    return IpInfo(
      ip: json['ip'] as String,
      colo: json['colo'] as String?,
      delay: (json['delay'] as num).toDouble(),
      loss: (json['loss'] as num).toDouble(),
      samples: json['samples'] as int,
    );
  }
}

class LogEntry {
  final String timestamp;
  final String level;
  final String message;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
  });

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      timestamp: json['timestamp'] as String,
      level: json['level'] as String,
      message: json['message'] as String,
    );
  }
}

class ConfigData {
  final String addr;
  final int delayLimit;
  final double tlr;
  final int ips;
  final int threads;
  final int tlsPort;
  final int httpPort;
  final List<String>? colo;
  final String http;
  final String ipFile;
  final int maxStickySlots;
  final List<String>? customIps;
  final List<String>? domains;

  ConfigData({
    required this.addr,
    required this.delayLimit,
    required this.tlr,
    required this.ips,
    required this.threads,
    required this.tlsPort,
    required this.httpPort,
    this.colo,
    required this.http,
    required this.ipFile,
    required this.maxStickySlots,
    this.customIps,
    this.domains,
  });

  factory ConfigData.fromJson(Map<String, dynamic> json) {
    return ConfigData(
      addr: json['addr'] as String,
      delayLimit: json['delay_limit'] as int,
      tlr: (json['tlr'] as num).toDouble(),
      ips: json['ips'] as int,
      threads: json['threads'] as int,
      tlsPort: json['tls_port'] as int,
      httpPort: json['http_port'] as int,
      colo: (json['colo'] as List?)?.cast<String>(),
      http: json['http'] as String,
      ipFile: json['ip_file'] as String,
      maxStickySlots: json['max_sticky_slots'] as int,
      customIps: (json['custom_ips'] as List?)?.cast<String>(),
      domains: (json['domains'] as List?)?.cast<String>(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ConfigData) return false;
    return addr == other.addr &&
        delayLimit == other.delayLimit &&
        tlr == other.tlr &&
        ips == other.ips &&
        threads == other.threads &&
        tlsPort == other.tlsPort &&
        httpPort == other.httpPort &&
        http == other.http &&
        ipFile == other.ipFile &&
        maxStickySlots == other.maxStickySlots &&
        _listEquals(colo, other.colo);
  }

  static bool _listEquals(List<String>? a, List<String>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        addr,
        delayLimit,
        tlr,
        ips,
        threads,
        tlsPort,
        httpPort,
        http,
        ipFile,
        maxStickySlots,
        colo,
      );
}

class DnsUpdaterConfig {
  final String cfApiToken;
  final String zoneName;
  final String recordName;
  final int intervalSecs;
  final bool singleIp;
  final bool updateAaaa;
  final bool enabled;

  DnsUpdaterConfig({
    this.cfApiToken = '',
    this.zoneName = 'example.com',
    this.recordName = 'cf.example.com',
    this.intervalSecs = 60,
    this.singleIp = true,
    this.updateAaaa = false,
    this.enabled = false,
  });

  factory DnsUpdaterConfig.fromJson(Map<String, dynamic> json) {
    return DnsUpdaterConfig(
      cfApiToken: json['cf_api_token'] as String? ?? '',
      zoneName: json['zone_name'] as String? ?? 'example.com',
      recordName: json['record_name'] as String? ?? 'cf.example.com',
      intervalSecs: json['interval_secs'] as int? ?? 60,
      singleIp: json['single_ip'] as bool? ?? true,
      updateAaaa: json['update_aaaa'] as bool? ?? false,
      enabled: json['enabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'cf_api_token': cfApiToken,
    'zone_name': zoneName,
    'record_name': recordName,
    'interval_secs': intervalSecs,
    'single_ip': singleIp,
    'update_aaaa': updateAaaa,
    'enabled': enabled,
  };
}

class DnsUpdaterStatus {
  final bool running;
  final String? lastUpdate;
  final String? lastARecord;
  final String? lastAaaaRecord;
  final String? error;

  DnsUpdaterStatus({
    this.running = false,
    this.lastUpdate,
    this.lastARecord,
    this.lastAaaaRecord,
    this.error,
  });

  factory DnsUpdaterStatus.fromJson(Map<String, dynamic> json) {
    return DnsUpdaterStatus(
      running: json['running'] as bool? ?? false,
      lastUpdate: json['last_update'] as String?,
      lastARecord: json['last_a_record'] as String?,
      lastAaaaRecord: json['last_aaaa_record'] as String?,
      error: json['error'] as String?,
    );
  }
}