import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_classic_bluetooth/flutter_classic_bluetooth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/order.dart';
import '../models/order_item.dart';
import 'printer_service.dart';

enum PrinterRole { receipt, labels }

enum LabelPrinterLanguage { tspl, cpcl }

class BluetoothPrinterService extends ChangeNotifier {
  BluetoothPrinterService._();

  static final BluetoothPrinterService instance = BluetoothPrinterService._();
  static const _receiptAddressKey = 'commune_receipt_printer_address';
  static const _receiptNameKey = 'commune_receipt_printer_name';
  static const _labelsAddressKey = 'commune_labels_printer_address';
  static const _labelsNameKey = 'commune_labels_printer_name';
  static const _labelsLanguageKey = 'commune_labels_printer_language';

  final FlutterClassicBluetooth _bluetooth = FlutterClassicBluetooth();
  final Map<PrinterRole, BtcConnection> _connections = {};
  String? _receiptAddress;
  String? _receiptName;
  String? _labelsAddress;
  String? _labelsName;
  LabelPrinterLanguage _labelLanguage = LabelPrinterLanguage.tspl;
  bool _initialized = false;

  bool isConnected(PrinterRole role) => _connections[role]?.isConnected ?? false;

  String? deviceName(PrinterRole role) =>
      role == PrinterRole.receipt ? _receiptName : _labelsName;

  LabelPrinterLanguage get labelLanguage => _labelLanguage;

  String connectionSummary(PrinterRole role) {
    final name = deviceName(role);
    if (isConnected(role)) return 'Connected: ${name ?? 'Bluetooth printer'}';
    return name == null ? 'No printer connected' : 'Saved: $name (disconnected)';
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    final preferences = await SharedPreferences.getInstance();
    _receiptAddress = preferences.getString(_receiptAddressKey);
    _receiptName = preferences.getString(_receiptNameKey);
    _labelsAddress = preferences.getString(_labelsAddressKey);
    _labelsName = preferences.getString(_labelsNameKey);
    _labelLanguage = LabelPrinterLanguage.values.firstWhere(
      (language) => language.name == preferences.getString(_labelsLanguageKey),
      orElse: () => LabelPrinterLanguage.tspl,
    );
    notifyListeners();

    if (_receiptAddress == null && _labelsAddress == null) return;
    try {
      final paired = await _bluetooth.getPairedDevices();
      for (final role in PrinterRole.values) {
        final address = role == PrinterRole.receipt
            ? _receiptAddress
            : _labelsAddress;
        if (address == null) continue;
        final device = paired.where((item) => item.address == address).firstOrNull;
        if (device != null) {
          _connections[role] = await _bluetooth.connect(address: address);
        }
      }
    } catch (_) {
      // The saved device can be unavailable or Bluetooth permission can be missing.
    }
    notifyListeners();
  }

  Future<void> connect(PrinterRole role, BtcDevice device, {
    LabelPrinterLanguage? language,
  }) async {
    final permission = await _bluetooth.requestPermissions(
      permissions: {BtcPermission.connect},
    );
    if (permission != BtcPermissionStatus.granted &&
        permission != BtcPermissionStatus.notRequired) {
      throw StateError('Bluetooth permission is required to connect a printer.');
    }

    if (device.bondState != BtcBondState.bonded) {
      final paired = await _bluetooth.bondDevice(device.address);
      if (!paired) throw StateError('Pairing with ${device.displayName} failed.');
    }

    await disconnect(role, clearSaved: false, notify: false);
    final connection = await _bluetooth.connect(
      address: device.address,
      timeout: const Duration(seconds: 15),
    );
    _connections[role] = connection;

    final preferences = await SharedPreferences.getInstance();
    if (role == PrinterRole.receipt) {
      _receiptAddress = device.address;
      _receiptName = device.displayName;
      await preferences.setString(_receiptAddressKey, device.address);
      await preferences.setString(_receiptNameKey, device.displayName);
    } else {
      _labelsAddress = device.address;
      _labelsName = device.displayName;
      await preferences.setString(_labelsAddressKey, device.address);
      await preferences.setString(_labelsNameKey, device.displayName);
      if (language != null) _labelLanguage = language;
      await preferences.setString(_labelsLanguageKey, _labelLanguage.name);
    }
    notifyListeners();
  }

  Future<void> disconnect(PrinterRole role, {
    bool clearSaved = false,
    bool notify = true,
  }) async {
    final connection = _connections.remove(role);
    if (connection != null) {
      try {
        await connection.finish();
      } finally {
        connection.dispose();
      }
    }
    if (clearSaved) {
      final preferences = await SharedPreferences.getInstance();
      if (role == PrinterRole.receipt) {
        _receiptAddress = null;
        _receiptName = null;
        await preferences.remove(_receiptAddressKey);
        await preferences.remove(_receiptNameKey);
      } else {
        _labelsAddress = null;
        _labelsName = null;
        await preferences.remove(_labelsAddressKey);
        await preferences.remove(_labelsNameKey);
      }
    }
    if (notify) notifyListeners();
  }

  Future<void> printReceipt(Order order) async {
    final connection = _connections[PrinterRole.receipt];
    if (connection == null || !connection.isConnected) {
      throw StateError('Connect a receipt printer from the POS menu first.');
    }
    final bytes = <int>[0x1B, 0x40, ...utf8.encode(PrinterService.formatReceipt(order)), 0x0A, 0x1D, 0x56, 0x41, 0x03];
    await connection.output.writeBytes(bytes);
  }

  Future<void> printLabels(Order order) async {
    final connection = _connections[PrinterRole.labels];
    if (connection == null || !connection.isConnected) {
      throw StateError('Connect a label printer from the POS menu first.');
    }

    for (final item in order.items) {
      for (var copy = 0; copy < item.qty; copy++) {
        final commands = _labelLanguage == LabelPrinterLanguage.tspl
            ? _tsplLabel(order, item, copy)
            : _cpclLabel(order, item, copy);
        await connection.output.writeBytes(utf8.encode(commands));
      }
    }
  }

  String _tsplLabel(Order order, OrderItem item, int copy) {
    final lines = _labelLines(order, item, copy);
    final commands = StringBuffer()
      ..writeln('SIZE 58 mm,30 mm')
      ..writeln('GAP 2 mm,0')
      ..writeln('DIRECTION 1')
      ..writeln('CLS');
    var y = 16;
    for (var index = 0; index < lines.length; index++) {
      final scale = index == 0 ? '1,1' : '1,1';
      commands.writeln('TEXT 16,$y,"3",0,$scale,"${_quote(lines[index])}"');
      y += index == 0 ? 30 : 25;
    }
    commands
      ..writeln('PRINT 1,1')
      ..writeln();
    return commands.toString();
  }

  String _cpclLabel(Order order, OrderItem item, int copy) {
    final lines = _labelLines(order, item, copy);
    final commands = StringBuffer()
      ..writeln('! 0 200 200 240 1')
      ..writeln('PAGE-WIDTH 464');
    var y = 16;
    for (var index = 0; index < lines.length; index++) {
      commands.writeln('TEXT 4 0 16 $y "${_quote(lines[index])}"');
      y += index == 0 ? 34 : 28;
    }
    commands
      ..writeln('FORM')
      ..writeln('PRINT')
      ..writeln();
    return commands.toString();
  }

  List<String> _labelLines(Order order, OrderItem item, int copy) {
    final ticketNo = order.ticketNo.isEmpty ? 'N/A' : order.ticketNo;
    final details = <String>[
      '${item.qty}x ${item.name.toUpperCase()}',
      if (item.style != null && item.style!.isNotEmpty)
        item.style!.toUpperCase(),
      if (item.optionsSummary.isNotEmpty) item.optionsSummary.toUpperCase(),
    ];
    return [
      'MAKE THESE DRINKS',
      'ORDER NO. $ticketNo',
      ...details,
    ];
  }

  String _quote(String value) =>
      value.replaceAll('"', "'").replaceAll(RegExp(r'[\r\n\x00-\x1F]'), ' ');
}
