import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TestIosPage extends StatefulWidget {
  const TestIosPage({super.key});

  @override
  State<TestIosPage> createState() => _TestIosPageState();
}

class _TestIosPageState extends State<TestIosPage> {
  static const platform = MethodChannel('thuan/battery');

  String _batteryLevel = 'Unknown';
  String _chargingStatus = 'Unknown';
  String _errorMessage = '';

  Future<void> _getBatteryLevel() async {
    try {
      setState(() {
        _errorMessage = '';
      });

      final String result = await platform.invokeMethod('getBatteryLevel');
      setState(() {
        _batteryLevel = result;
      });
      log('Battery Level: $result');
    } on PlatformException catch (e) {
      setState(() {
        _errorMessage = 'Failed to get battery level: ${e.message}';
        _batteryLevel = 'Unknown';
      });
      log('Error getting battery level: ${e.message}');
    } catch (e) {
      setState(() {
        _errorMessage = 'Unexpected error: $e';
        _batteryLevel = 'Unknown';
      });
      log('Unexpected error: $e');
    }
  }

  Future<void> _checkChargingStatus() async {
    try {
      setState(() {
        _errorMessage = '';
      });

      final String result = await platform.invokeMethod('isCharging');
      setState(() {
        _chargingStatus = result;
      });
      log('Charging Status: $result');
    } on PlatformException catch (e) {
      setState(() {
        _errorMessage = 'Failed to get charging status: ${e.message}';
        _chargingStatus = 'Unknown';
      });
      log('Error getting charging status: ${e.message}');
    } catch (e) {
      setState(() {
        _errorMessage = 'Unexpected error: $e';
        _chargingStatus = 'Unknown';
      });
      log('Unexpected error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('iOS Native Methods Test'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            _InfoCard(
              title: 'Battery Level',
              value: _batteryLevel,
              icon: Icons.battery_charging_full,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _getBatteryLevel,
              icon: const Icon(Icons.refresh),
              label: const Text('Get Battery Level'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 32),
            _InfoCard(
              title: 'Charging Status',
              value: _chargingStatus,
              icon: Icons.power,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _checkChargingStatus,
              icon: const Icon(Icons.refresh),
              label: const Text('Check Charging Status'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                await _getBatteryLevel();
                await _checkChargingStatus();
              },
              icon: const Icon(Icons.sync),
              label: const Text('Get Both'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: SelectableText.rich(
                  TextSpan(
                    children: [
                      const WidgetSpan(
                        child: Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                      ),
                      const WidgetSpan(
                        child: SizedBox(width: 8),
                      ),
                      TextSpan(
                        text: _errorMessage,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.black87,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
