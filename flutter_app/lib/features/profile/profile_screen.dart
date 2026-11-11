import 'package:flutter/material.dart';

import '../../core/models/viril_state.dart';
import '../../core/state/viril_controller.dart';
import '../../core/theme/viril_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.controller});
  final VirilController controller;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _avatars = [
    '🧠', '🏋️', '🧘', '📚', '⚡', '🌱', '🏹', '🛡️', '🔥', '🎯',
    '🦉', '⛰️', '🌊', '☀️', '🧭', '💎', '🚀', '🪷', '🐺', '♟️',
  ];

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _editProfile(VirilState state) async {
    final name = TextEditingController(text: state.nickname);
    var avatar = state.avatar;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: VirilTheme.panel,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Редактировать профиль',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                TextField(controller: name, maxLength: 24,
                  decoration: const InputDecoration(labelText: 'Никнейм')),
                const SizedBox(height: 12),
                const Text('АВАТАР', style: TextStyle(
                  color: Colors.white60, fontSize: 10, letterSpacing: 1.2)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final item in _avatars)
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setSheetState(() => avatar = item),
                      child: Container(
                        width: 46, height: 46, alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: VirilTheme.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: avatar == item ? VirilTheme.blue : Colors.white12,
                            width: avatar == item ? 2 : 1,
                          ),
                        ),
                        child: Text(item, style: const TextStyle(fontSize: 23)),
                      ),
                    ),
                ]),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, child: FilledButton(
                  onPressed: () async {
                    final clean = name.text.trim();
                    if (clean.isEmpty) return;
                    await widget.controller.updateProfile(
                      nickname: clean, avatar: avatar,
                    );
                    if (sheetContext.mounted) Navigator.pop(sheetContext, true);
                  },
                  child: const Text('Сохранить изменения'),
                )),
              ],
            )),
          ),
        ),
      ),
    );
    name.dispose();
    if (result == true && mounted) _message('Профиль обновлён');
  }

  Future<void> _confirmAction({
    required String title,
    required String message,
    required String action,
    required Future<void> Function() onConfirm,
    bool destructive = false,
  }) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action, style: TextStyle(
              color: destructive ? VirilTheme.red : VirilTheme.blue,
            )),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    try {
      await onConfirm();
      if (mounted) _message('Готово');
    } catch (error) {
      if (mounted) _message('Не удалось выполнить действие: ' + error.toString());
    }
  }

  Widget _stat(String value, String label) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .055),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
      ),
      child: Column(children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.white60),
          textAlign: TextAlign.center),
      ]),
    ),
  );

  Widget _section(String title, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title.toUpperCase(), style: const TextStyle(
          color: Colors.white54, fontSize: 10, letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
        )),
        const SizedBox(height: 8),
        ...children,
      ]),
    ),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final state = widget.controller.state;
      final registered = widget.controller.isRegistered;
      final streak = state.currentStreak();
      final tag = state.data['playerTag']?.toString() ?? '';
      final diaryCount = state.diary.length;
      return Scaffold(
        appBar: AppBar(title: const Text('Профиль')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white12),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFF202B45), Color(0xFF151A2C)],
                ),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 76, height: 76, alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(23),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF243D59), Color(0xFF42365E)],
                      ),
                      border: Border.all(color: VirilTheme.blue.withValues(alpha: .4)),
                    ),
                    child: state.avatar.startsWith('http')
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Image.network(state.avatar, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 34)),
                        )
                      : Text(state.avatar, style: const TextStyle(fontSize: 35)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(state.nickname, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('#' + tag, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text('Уровень ' + state.level.toString() + ' · ' + VirilState.rankFor(state.level),
                        style: const TextStyle(color: VirilTheme.blue, fontSize: 11)),
                    ],
                  )),
                  IconButton(
                    tooltip: 'Изменить профиль',
                    onPressed: () => _editProfile(state),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ]),
                const SizedBox(height: 17),
                Row(children: [
                  _stat(state.xp.toString(), 'ОБЩИЙ XP'),
                  const SizedBox(width: 8),
                  _stat(streak.toString(), 'ДНЕЙ ПОДРЯД'),
                  const SizedBox(width: 8),
                  _stat(diaryCount.toString(), 'ЗАПИСЕЙ'),
                ]),
              ]),
            ),
            const SizedBox(height: 12),
            _section('Аккаунт', [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(registered ? Icons.verified_user : Icons.cloud_outlined,
                  color: registered ? VirilTheme.green : VirilTheme.blue),
                title: Text(registered ? 'Google подключён' : 'Гостевой аккаунт'),
                subtitle: Text(registered
                  ? 'Прогресс связан с аккаунтом'
                  : 'Подключи Google, чтобы сохранить доступ к аккаунту на других устройствах'),
              ),
              if (!registered)
                SizedBox(width: double.infinity, child: FilledButton.icon(
                  onPressed: () async {
                    try {
                      await widget.controller.linkGoogle();
                      if (mounted) _message('Запущено подключение Google');
                    } catch (error) {
                      if (mounted) _message('Не удалось подключить Google: ' + error.toString());
                    }
                  },
                  icon: const Icon(Icons.login),
                  label: const Text('Подключить Google'),
                )),
              if (registered)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.switch_account_outlined),
                  title: const Text('Сменить аккаунт'),
                  subtitle: const Text('Создать новую гостевую сессию'),
                  onTap: () => _confirmAction(
                    title: 'Сменить аккаунт?',
                    message: 'Текущий прогресс будет сохранён. После смены аккаунта откроется новый гостевой профиль.',
                    action: 'Сменить',
                    onConfirm: widget.controller.changeAccount,
                  ),
                ),
            ]),
            const SizedBox(height: 12),
            _section('Настройки', [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.language),
                title: const Text('Язык приложения'),
                trailing: DropdownButton<String>(
                  value: state.language,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'ru', child: Text('Русский')),
                    DropdownMenuItem(value: 'en', child: Text('English')),
                  ],
                  onChanged: (value) {
                    if (value != null) widget.controller.setLanguage(value);
                  },
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.volume_up_outlined),
                title: const Text('Звуки интерфейса'),
                value: state.data['sounds'] == true,
                onChanged: widget.controller.setSounds,
              ),
            ]),
            const SizedBox(height: 12),
            _section('Частые вопросы', [
              const ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('Как работает система XP?'),
                children: [Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text('Опыт начисляется за выполнение целей и действия в приложении. Уровень рассчитывается автоматически.',
                    style: TextStyle(color: Colors.white60, height: 1.45)),
                )],
              ),
              const ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('Как сохранить прогресс?'),
                children: [Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text('Гостевой прогресс хранится на устройстве. Подключи Google, чтобы связать его с аккаунтом и синхронизировать через облако.',
                    style: TextStyle(color: Colors.white60, height: 1.45)),
                )],
              ),
              const ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('Можно ли пользоваться приложением офлайн?'),
                children: [Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text('Локальные данные и сохранённые материалы доступны без интернета. Облачная синхронизация требует подключения.',
                    style: TextStyle(color: Colors.white60, height: 1.45)),
                )],
              ),
            ]),
            const SizedBox(height: 12),
            _section('Данные и безопасность', [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.restart_alt, color: VirilTheme.red),
                title: const Text('Сбросить прогресс'),
                subtitle: const Text('Удалить цели, опыт и дневник на этом устройстве'),
                onTap: () => _confirmAction(
                  title: 'Сбросить прогресс?',
                  message: 'Это действие сбросит локальный прогресс и дневник. Продолжить?',
                  action: 'Сбросить',
                  destructive: true,
                  onConfirm: widget.controller.resetProgress,
                ),
              ),
              if (registered)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.delete_forever_outlined, color: VirilTheme.red),
                  title: const Text('Удалить аккаунт'),
                  subtitle: const Text('Удаление аккаунта и связанных облачных данных'),
                  onTap: () => _confirmAction(
                    title: 'Удалить аккаунт?',
                    message: 'Удаление аккаунта нельзя отменить. Подтверди действие, только если действительно хочешь удалить аккаунт и связанные данные.',
                    action: 'Удалить',
                    destructive: true,
                    onConfirm: widget.controller.deleteAccount,
                  ),
                ),
            ]),
            const SizedBox(height: 8),
            Center(child: Text('Viril · Self Development · 2.0',
              style: TextStyle(color: Colors.white.withValues(alpha: .35), fontSize: 10))),
            if (widget.controller.lastError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(widget.controller.lastError!,
                  style: const TextStyle(color: VirilTheme.red, fontSize: 11)),
              ),
          ],
        ),
      );
    },
  );
}
