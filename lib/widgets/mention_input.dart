import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

class MentionInput extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool isMultiLine;
  final bool reverseDirection; 

  const MentionInput({
    super.key,
    required this.controller,
    required this.hintText,
    this.isMultiLine = false,
    this.reverseDirection = false,
  });

  @override
  Widget build(BuildContext context) {
    return TypeAheadField<Map<String, dynamic>>(
      // CONNECT YOUR CONTROLLER HERE
      controller: controller,
      
      // Force direction UP if we are at the bottom of the screen
      direction: reverseDirection ? VerticalDirection.up : VerticalDirection.down,
      
      hideOnEmpty: true,
      hideOnLoading: true,
      
      builder: (context, controller, focusNode) {
        return TextField(
          controller: controller, // Use the controller TypeAhead gives us
          focusNode: focusNode,
          minLines: 1,
          maxLines: isMultiLine ? 8 : 1,
          decoration: InputDecoration(
            hintText: hintText,
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
        );
      },

      suggestionsCallback: (pattern) async {
        // 1. Get exact cursor position text
        final text = controller.text;
        final selection = controller.selection;
        
        // Safety check: If no cursor, don't search
        if (selection.baseOffset < 0) return null;

        // 2. Backtrack to find the start of the current word
        int start = selection.baseOffset - 1;
        while (start >= 0 && text[start] != ' ' && text[start] != '\n') {
          start--;
        }
        start++; // Move forward to the first character of the word

        // 3. Extract the word
        final currentWord = text.substring(start, selection.baseOffset);

        // 4. Check if it is a mention tag
        if (currentWord.startsWith('@') && currentWord.length > 1) {
          final query = currentWord.substring(1); 
          
          // Debugging Print (Check your Debug Console!)
          debugPrint("Searching DB for: $query"); 

          try {
            final res = await Supabase.instance.client
                .from('profiles')
                .select('id, username, avatar_url')
                .ilike('username', '$query%')
                .limit(5);
            return List<Map<String, dynamic>>.from(res);
          } catch (e) {
            debugPrint("DB Error: $e");
            return null;
          }
        }
        return null; 
      },

      itemBuilder: (context, user) {
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: user['avatar_url'] != null ? NetworkImage(user['avatar_url']) : null,
            radius: 14,
            child: user['avatar_url'] == null ? const Icon(Icons.person, size: 14) : null,
          ),
          title: Text(user['username'] ?? 'User'),
          dense: true,
        );
      },

      onSelected: (user) {
        final text = controller.text;
        final selection = controller.selection;
        
        // Find start of word again to replace it
        int start = selection.baseOffset - 1;
        while (start >= 0 && text[start] != ' ' && text[start] != '\n') {
          start--;
        }
        start++; 

        final newText = text.replaceRange(start, selection.baseOffset, "@${user['username']} ");
        
        controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: start + user['username'].toString().length + 2),
        );
      },
    );
  }
}