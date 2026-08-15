import 'package:flutter/material.dart';
import '../services/app_service.dart';

class DnsConfigPanel extends StatefulWidget {
  final AppService service;
  
  const DnsConfigPanel({super.key, required this.service});

  @override
  State<DnsConfigPanel> createState() => _DnsConfigPanelState();
}

class _DnsConfigPanelState extends State<DnsConfigPanel> {
  final _tokenController = TextEditingController();
  final _zoneController = TextEditingController();
  final _recordController = TextEditingController();
  final _intervalController = TextEditingController();
  
  bool _enabled = false;
  bool _singleIp = true;
  bool _updateAaaa = false;
  bool _loading = false;
  DnsUpdaterStatus? _status;
  bool _configLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _zoneController.dispose();
    _recordController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final config = await widget.service.getDnsConfig();
    if (config != null && mounted) {
      setState(() {
        _tokenController.text = config.cfApiToken;
        _zoneController.text = config.zoneName;
        _recordController.text = config.recordName;
        _intervalController.text = config.intervalSecs.toString();
        _singleIp = config.singleIp;
        _updateAaaa = config.updateAaaa;
        _enabled = config.enabled;
        _configLoaded = true;
      });
    }
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    final status = await widget.service.getDnsStatus();
    if (mounted) {
      setState(() {
        _status = status;
      });
    }
  }

  Future<void> _save() async {
    if (_loading) return;
    setState(() => _loading = true);

    final config = DnsUpdaterConfig(
      cfApiToken: _tokenController.text,
      zoneName: _zoneController.text,
      recordName: _recordController.text,
      intervalSecs: int.tryParse(_intervalController.text) ?? 60,
      singleIp: _singleIp,
      updateAaaa: _updateAaaa,
      enabled: _enabled,
    );

    final success = await widget.service.updateDnsConfig(config);
    
    if (mounted) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? 'DNS 配置已保存' : 'DNS 配置保存失败')),
      );
      _refreshStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRunning = _status?.running ?? false;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              children: [
                Icon(Icons.dns, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                const Text('DNS 更新器', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                const Spacer(),
                // 开关
                Switch.adaptive(
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
          
          if (_enabled) ...[
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // API Token
                  TextField(
                    controller: _tokenController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Cloudflare API Token',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Zone Name + Record Name
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _zoneController,
                          decoration: const InputDecoration(
                            labelText: 'Zone 名称',
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _recordController,
                          decoration: const InputDecoration(
                            labelText: '记录名称',
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // 间隔 + 选项
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _intervalController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '更新间隔 (秒)',
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          children: [
                            _buildSwitchRow('单 IP', _singleIp, (v) => setState(() => _singleIp = v)),
                            _buildSwitchRow('AAAA', _updateAaaa, (v) => setState(() => _updateAaaa = v)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // 保存按钮
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _save,
                      icon: _loading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save, size: 16),
                      label: Text(_loading ? '保存中...' : '保存并启动'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  
                  // 状态信息
                  if (_status != null) ...[
                    const SizedBox(height: 8),
                    _buildStatusInfo(),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSwitchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          const Spacer(),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusInfo() {
    final status = _status!;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: (status.running ? Colors.green : Colors.grey).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                status.running ? Icons.check_circle : Icons.stop_circle,
                size: 14,
                color: status.running ? Colors.green[400] : Colors.grey[400],
              ),
              const SizedBox(width: 4),
              Text(
                status.running ? '运行中' : '已停止',
                style: TextStyle(
                  fontSize: 11,
                  color: status.running ? Colors.green[400] : Colors.grey[400],
                ),
              ),
              if (status.lastUpdate != null) ...[
                const Spacer(),
                Text(
                  '上次更新: ${status.lastUpdate}',
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
              ],
            ],
          ),
          if (status.lastARecord != null)
            Text('A: ${status.lastARecord}', style: TextStyle(fontSize: 10, color: Colors.grey[400])),
          if (status.lastAaaaRecord != null)
            Text('AAAA: ${status.lastAaaaRecord}', style: TextStyle(fontSize: 10, color: Colors.grey[400])),
          if (status.error != null)
            Text('错误: ${status.error}', style: TextStyle(fontSize: 10, color: Colors.red[400])),
        ],
      ),
    );
  }
}
