import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ShareService {
  
  // 1. THE WHATSAPP FIX
  static Future<void> openWhatsApp(BuildContext context, String rawPhone, String message) async {
    // 1. THE CLEANER: Remove everything that is NOT a number
    // "012-345 (Main)" -> "012345"
    // "http://scam.com" -> "" (Empty string)
    String phone = rawPhone.replaceAll(RegExp(r'\D'), ''); 

    // 2. Safety Check: If they typed nonsense/links, 'phone' is now empty.
    if (phone.isEmpty || phone.length < 9) { 
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid phone number format."))
      );
      return;
    }
    
    // 3. Malaysia Format Fix: Swap '01' with '601'
    if (phone.startsWith('01')) {
      phone = '60${phone.substring(1)}';
    } else if (!phone.startsWith('60')) {
        // Optional: Assume 60 if they just typed "123456789"
        phone = '60$phone';
    }

    final url = Uri.parse("https://wa.me/$phone?text=${Uri.encodeComponent(message)}");

    try {
      // mode: LaunchMode.externalApplication is CRITICAL for Android 11+
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open WhatsApp. Is it installed?")),
        );
      }
    }
  }

  // 2. THE SHARE FUNCTION (Image + Text)
  static Future<void> shareContent(BuildContext context, String title, String body, String? imageUrl) async {
    final box = context.findRenderObject() as RenderBox?;
    final String shareText = "$title\n\n$body\n\nCheck this out on MYKerawang!";

    try {
      if (imageUrl != null && imageUrl.isNotEmpty) {
        // A. Download Image First
        final uri = Uri.parse(imageUrl);
        final response = await http.get(uri);
        
        if (response.statusCode == 200) {
          // B. Save to Temp Folder
          final tempDir = await getTemporaryDirectory();
          final file = await File('${tempDir.path}/shared_image.jpg').create();
          file.writeAsBytesSync(response.bodyBytes);

          // C. Share Image + Text
          await Share.shareXFiles(
            [XFile(file.path)],
            text: shareText,
            sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
          );
          return;
        }
      }
      
      // Fallback: Share Text Only if no image
      await Share.share(shareText);
      
    } catch (e) {
      debugPrint("Share error: $e");
      // Fallback if download fails
      await Share.share(shareText);
    }
  }
}