part of '../main.dart';

/// Shared local chat presentation for the customer and support employee.
class ChatTranscript extends StatelessWidget {
  final List<Map<String, dynamic>> entries;
  final bool staff;
  const ChatTranscript({super.key, required this.entries, this.staff = false});

  String _time(Object? value) {
    final parsed = value is String ? DateTime.tryParse(value)?.toLocal() : null;
    if (parsed == null) return '';
    return '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext c) {
    if (entries.isEmpty) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.all(28),
        child: Text('Пока нет сообщений. Напишите, чем мы можем помочь.',
            textAlign: TextAlign.center, style: TextStyle(color: secondary)),
      ));
    }
    return LayoutBuilder(
        builder: (context, constraints) => ListView.builder(
              reverse: true,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              itemCount: entries.length,
              itemBuilder: (c, i) {
                final m = entries[entries.length - 1 - i];
                final outgoing =
                    staff ? m['sender'] == 'Поддержка' : m['sender'] == 'Вы';
                final time = _time(m['time']);
                final bubble = Align(
                  alignment:
                      outgoing ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints:
                        BoxConstraints(maxWidth: constraints.maxWidth * .82),
                    margin: const EdgeInsets.only(bottom: 9),
                    padding: const EdgeInsets.fromLTRB(13, 10, 13, 8),
                    decoration: BoxDecoration(
                      color: outgoing ? const Color(0xffd5e7df) : Colors.white,
                      borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(17),
                          topRight: const Radius.circular(17),
                          bottomLeft: Radius.circular(outgoing ? 17 : 4),
                          bottomRight: Radius.circular(outgoing ? 4 : 17)),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x0d1b342c),
                            blurRadius: 5,
                            offset: Offset(0, 2))
                      ],
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(m['text']?.toString() ?? '',
                              style: const TextStyle(fontSize: 15, color: ink)),
                          if (time.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(time,
                                style: const TextStyle(
                                    fontSize: 10, color: secondary)),
                          ],
                        ]),
                  ),
                );
                if (MediaQuery.disableAnimationsOf(c)) return bubble;
                return TweenAnimationBuilder<double>(
                  key: ValueKey('${m['time'] ?? i}-${m['sender']}'),
                  duration: const Duration(milliseconds: 220),
                  tween: Tween(begin: 0, end: 1),
                  builder: (_, value, child) => Opacity(
                      opacity: value,
                      child: Transform.translate(
                          offset: Offset(0, 6 * (1 - value)), child: child)),
                  child: bubble,
                );
              },
            ));
  }
}

class ChatComposer extends StatelessWidget {
  final TextEditingController controller;
  final String label, button;
  final bool busy;
  final VoidCallback send;
  const ChatComposer(
      {super.key,
      required this.controller,
      required this.label,
      required this.button,
      required this.busy,
      required this.send});
  @override
  Widget build(BuildContext c) => SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        color: Colors.white,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
              child: TextField(
                  controller: controller,
                  enabled: !busy,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 1000,
                  decoration: InputDecoration(
                      labelText: label,
                      hintText: 'Напишите сообщение',
                      counterText: '',
                      filled: true,
                      fillColor: const Color(0xfff4f5f4),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none)))),
          const SizedBox(width: 4),
          TextButton(
              onPressed: busy ? null : send,
              child: Text(button, textAlign: TextAlign.center)),
        ]),
      ));
}
