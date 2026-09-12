import 'package:flutter/material.dart';
import '../models/monitor.dart';
import '../db/database_helper.dart';

class AddEditMonitorScreen extends StatefulWidget {
  final Monitor? existingMonitor;
  const AddEditMonitorScreen({super.key, this.existingMonitor});

  @override
  State<AddEditMonitorScreen> createState() => _AddEditMonitorScreenState();
}

class _AddEditMonitorScreenState extends State<AddEditMonitorScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _labelController;
  late TextEditingController _senderController;
  late TextEditingController _tokenController;
  late TextEditingController _chatIdController;
  bool _isEnabled = true;
  bool _obscureToken = true;

  bool get isEditing => widget.existingMonitor != null;

  @override
  void initState() {
    super.initState();
    final m = widget.existingMonitor;
    _labelController = TextEditingController(text: m?.label ?? '');
    _senderController = TextEditingController(text: m?.senderPattern ?? '');
    _tokenController = TextEditingController(text: m?.botToken ?? '');
    _chatIdController = TextEditingController(text: m?.chatId ?? '');
    _isEnabled = m?.isEnabled ?? true;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _senderController.dispose();
    _tokenController.dispose();
    _chatIdController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final monitor = Monitor(
      id: widget.existingMonitor?.id,
      label: _labelController.text.trim(),
      senderPattern: _senderController.text.trim(),
      botToken: _tokenController.text.trim(),
      chatId: _chatIdController.text.trim(),
      isEnabled: _isEnabled,
    );

    if (isEditing) {
      await DatabaseHelper.instance.updateMonitor(monitor);
    } else {
      await DatabaseHelper.instance.insertMonitor(monitor);
    }

    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذه المراقبة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.existingMonitor?.id != null) {
      await DatabaseHelper.instance.deleteMonitor(widget.existingMonitor!.id!);
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'تعديل المراقبة' : 'مراقبة جديدة'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionTitle('اسم المراقبة'),
            TextFormField(
              controller: _labelController,
              decoration: const InputDecoration(hintText: 'مثلاً: فودافون كاش الرئيسي'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
            ),
            const SizedBox(height: 20),

            _sectionTitle('نص المرسل المراد مراقبته'),
            TextFormField(
              controller: _senderController,
              decoration: const InputDecoration(hintText: 'مثلاً: VF-Cash'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6, right: 4),
              child: Text(
                'أي رسالة SMS يحتوي اسم مرسلها على النص ده هتتحول تلقائيًا',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 20),

            _sectionTitle('Bot Token'),
            TextFormField(
              controller: _tokenController,
              obscureText: _obscureToken,
              decoration: InputDecoration(
                hintText: '123456:ABC-DEF...',
                suffixIcon: IconButton(
                  icon: Icon(_obscureToken ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscureToken = !_obscureToken),
                ),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
            ),
            const SizedBox(height: 20),

            _sectionTitle('Chat ID (جروب أو شات خاص)'),
            TextFormField(
              controller: _chatIdController,
              decoration: const InputDecoration(hintText: '-1001234567890 أو 123456789'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6, right: 4),
              child: Text(
                'ممكن تحط رقم جروب أو ID مستخدم عادي - نفس الآلية',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 20),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('تفعيل المراقبة'),
              subtitle: const Text('لو موقوفة، مش هيتم مراقبة الرسايل بتاعتها'),
              value: _isEnabled,
              onChanged: (v) => setState(() => _isEnabled = v),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _save,
              child: Text(isEditing ? 'حفظ التعديلات' : 'إضافة المراقبة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 4),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }
}
