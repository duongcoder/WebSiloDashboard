import 'package:flutter/material.dart';
import '../models/controller.dart';

class ControllerModule extends StatefulWidget {
  final List<Controller> controllers;
  const ControllerModule({super.key, required this.controllers});

  @override
  State<ControllerModule> createState() => _ControllerModuleState();
}

class _ControllerModuleState extends State<ControllerModule> {
  bool _editingId = false;
  bool _editingIp = false;
  bool _editingPort = false;
  bool _editingSn = false;

  late TextEditingController _controllerIdController;
  late TextEditingController _controllerIpController;
  late TextEditingController _controllerPortController;
  late TextEditingController _controllerSnController;

  @override
  void initState() {
    super.initState();
    _controllerIdController = TextEditingController();
    _controllerIpController = TextEditingController();
    _controllerPortController = TextEditingController();
    _controllerSnController = TextEditingController();
  }

  @override
  void dispose() {
    _controllerIdController.dispose();
    _controllerIpController.dispose();
    _controllerPortController.dispose();
    _controllerSnController.dispose();
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
      mainAxisSize: MainAxisSize.min,
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
    final ctrl = widget.controllers.isNotEmpty ? widget.controllers.first : null;
    if (ctrl == null) return const SizedBox.shrink();

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
            controller: _controllerIdController,
            value: ctrl.controllerId,
            editing: _editingId,
            onTapEdit: () {
              _controllerIdController.text = ctrl.controllerId;
              setState(() => _editingId = true);
            },
            onSubmit: () => setState(() {
              if (_controllerIdController.text.isNotEmpty &&
                  _controllerIdController.text != ctrl.controllerId) {
                ctrl.controllerId = _controllerIdController.text;
              }
              _editingId = false;
            }),
            onCancel: () => setState(() => _editingId = false),
          ),
          const SizedBox(height: 6),
          _buildEditableRow(
            label: 'IP',
            controller: _controllerIpController,
            value: ctrl.ip,
            editing: _editingIp,
            onTapEdit: () {
              _controllerIpController.text = ctrl.ip;
              setState(() => _editingIp = true);
            },
            onSubmit: () => setState(() {
              if (_controllerIpController.text.isNotEmpty &&
                  _controllerIpController.text != ctrl.ip) {
                ctrl.ip = _controllerIpController.text;
              }
              _editingIp = false;
            }),
            onCancel: () => setState(() => _editingIp = false),
          ),
          const SizedBox(height: 6),
          _buildEditableRow(
            label: 'Port',
            controller: _controllerPortController,
            value: ctrl.port.toString(),
            editing: _editingPort,
            onTapEdit: () {
              _controllerPortController.text = ctrl.port.toString();
              setState(() => _editingPort = true);
            },
            onSubmit: () => setState(() {
              if (_controllerPortController.text.isNotEmpty) {
                final parsed = int.tryParse(_controllerPortController.text);
                if (parsed != null && parsed != ctrl.port) {
                  ctrl.port = parsed;
                }
              }
              _editingPort = false;
            }),
            onCancel: () => setState(() => _editingPort = false),
          ),
          const SizedBox(height: 6),
          _buildEditableRow(
            label: 'SN',
            controller: _controllerSnController,
            value: ctrl.serialNumber,
            editing: _editingSn,
            onTapEdit: () {
              _controllerSnController.text = ctrl.serialNumber;
              setState(() => _editingSn = true);
            },
            onSubmit: () => setState(() {
              if (_controllerSnController.text.isNotEmpty &&
                  _controllerSnController.text != ctrl.serialNumber) {
                ctrl.serialNumber = _controllerSnController.text;
              }
              _editingSn = false;
            }),
            onCancel: () => setState(() => _editingSn = false),
          ),
        ],
      ),
    );
  }
}
