import 'package:flutter/material.dart';
import '../models/indicator.dart';

class IndicatorModule extends StatefulWidget {
  final List<Indicator> indicators;
  const IndicatorModule({super.key, required this.indicators});

  @override
  State<IndicatorModule> createState() => _IndicatorModuleState();
}

class _IndicatorModuleState extends State<IndicatorModule> {
  bool _editingId = false;
  bool _editingName = false;
  bool _editingPort = false;
  bool _editingBaudRate = false;

  late TextEditingController _indicatorIdController;
  late TextEditingController _indicatorNameController;
  late TextEditingController _indicatorPortController;
  late TextEditingController _indicatorBaudRateController;

  @override
  void initState() {
    super.initState();
    _indicatorIdController = TextEditingController();
    _indicatorNameController = TextEditingController();
    _indicatorPortController = TextEditingController();
    _indicatorBaudRateController = TextEditingController();
  }

  @override
  void dispose() {
    _indicatorIdController.dispose();
    _indicatorNameController.dispose();
    _indicatorPortController.dispose();
    _indicatorBaudRateController.dispose();
    super.dispose();
  }

  Widget _buildEditableRow({
    required String label,
    required TextEditingController controller,
    required String value,
    required bool editing,
    required VoidCallback onTapEdit,
    required VoidCallback onSubmit,
    required VoidCallback onCancel,
  }) {
    final labelStyle = const TextStyle(fontSize: 13, color: Colors.black54);
    final valueStyle =
        const TextStyle(fontSize: 13, fontWeight: FontWeight.w600);

    return Row(
      children: [
        Text('$label:', style: labelStyle),
        const SizedBox(width: 10),
        Flexible(
          child: editing
              ? TextField(
                  controller: controller,
                  autofocus: true,
                  style: valueStyle,
                  onSubmitted: (_) => onSubmit(),
                  onEditingComplete: onCancel,
                )
              : InkWell(
                  onTap: onTapEdit,
                  child: Text(value, style: valueStyle),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ind =
        widget.indicators.isNotEmpty ? widget.indicators.first : null;
    if (ind == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildEditableRow(
            label: 'ID',
            controller: _indicatorIdController,
            value: ind.indicatorId,
            editing: _editingId,
            onTapEdit: () {
              _indicatorIdController.text = ind.indicatorId;
              setState(() => _editingId = true);
            },
            onSubmit: () => setState(() {
              if (_indicatorIdController.text.isNotEmpty &&
                  _indicatorIdController.text != ind.indicatorId) {
                ind.indicatorId = _indicatorIdController.text;
              }
              _editingId = false;
            }),
            onCancel: () => setState(() => _editingId = false),
          ),
          const SizedBox(height: 6),
          _buildEditableRow(
            label: 'Name',
            controller: _indicatorNameController,
            value: ind.name,
            editing: _editingName,
            onTapEdit: () {
              _indicatorNameController.text = ind.name;
              setState(() => _editingName = true);
            },
            onSubmit: () => setState(() {
              if (_indicatorNameController.text.isNotEmpty &&
                  _indicatorNameController.text != ind.name) {
                ind.name = _indicatorNameController.text;
              }
              _editingName = false;
            }),
            onCancel: () => setState(() => _editingName = false),
          ),
          const SizedBox(height: 6),
          _buildEditableRow(
            label: 'Port',
            controller: _indicatorPortController,
            value: ind.port,
            editing: _editingPort,
            onTapEdit: () {
              _indicatorPortController.text = ind.port;
              setState(() => _editingPort = true);
            },
            onSubmit: () => setState(() {
              if (_indicatorPortController.text.isNotEmpty &&
                  _indicatorPortController.text != ind.port) {
                ind.port = _indicatorPortController.text;
              }
              _editingPort = false;
            }),
            onCancel: () => setState(() => _editingPort = false),
          ),
          const SizedBox(height: 6),
          _buildEditableRow(
            label: 'Baud Rate',
            controller: _indicatorBaudRateController,
            value: ind.baudRate.toString(),
            editing: _editingBaudRate,
            onTapEdit: () {
              _indicatorBaudRateController.text = ind.baudRate.toString();
              setState(() => _editingBaudRate = true);
            },
            onSubmit: () => setState(() {
              if (_indicatorBaudRateController.text.isNotEmpty) {
                final parsed = int.tryParse(_indicatorBaudRateController.text);
                if (parsed != null && parsed != ind.baudRate) {
                  ind.baudRate = parsed;
                }
              }
              _editingBaudRate = false;
            }),
            onCancel: () => setState(() => _editingBaudRate = false),
          ),
        ],
      ),
    );
  }
}
