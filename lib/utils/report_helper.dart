import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> showReportDialog(BuildContext context, String targetId, String type) async {
  final reasons = [
    'Spam or Scam',
    'Hate Speech or Harassment',
    'Inappropriate Content',
    'Misinformation',
    'Other'
  ];

  await showDialog(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Report Content'),
      children: reasons.map((reason) => SimpleDialogOption(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Text(reason),
        onPressed: () async {
          Navigator.pop(ctx); // Close dialog first
          
          try {
            await Supabase.instance.client.from('reports').insert({
              'reporter_id': Supabase.instance.client.auth.currentUser!.id,
              'target_id': targetId,
              'target_type': type,
              'reason': reason,
            });
            
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Thanks for reporting. We will review this."))
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error submitting report.")));
            }
          }
        },
      )).toList(),
    ),
  );
}