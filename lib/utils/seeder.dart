import 'package:supabase/supabase.dart';
import 'dart:math';

// ==========================================
// 1. CONFIGURATION
// ==========================================
const String supabaseUrl = 'https://zxjuqpqzyzmegdjttzyz.supabase.co';

// ⚠️ IMPORTANT: PASTE YOUR "SERVICE_ROLE" KEY HERE (NOT ANON KEY!)
const String serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp4anVxcHF6eXptZWdkanR0enl6Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2NDQzMDE3MiwiZXhwIjoyMDgwMDA2MTcyfQ.Y61O9-MFCAT0fOSaOtqxIh8_Fya7NLSTsOtbyr61_f4'; 

// ==========================================
// 2. DATA POOLS
// ==========================================
const _eventTitles = [
  'Grand Iftar 2026', 'Mobile Legend Tournament', 'Flutter Workshop', 'Charity Run 5KM',
  'Busking Night', 'Career Fair', 'Used Book Swap', 'Hostel Clean-up', 
  'Debate Club Intro', 'Robotics Showcase', 'Futsal Cup', 'Free Health Check'
];
const _listingTitles = [
  'Gaming Laptop', 'Calculus Textbook', 'Scientific Calculator', 'IKEA Lamp',
  'Fixie Bike', 'Lab Coat (Size M)', 'Graphic Tablet', 'Sony Headphones',
  'Extension Wire', 'Mini Fridge', 'Standing Fan', 'Badminton Racket'
];
const _postTitles = [
  'Where is the best place to nap on campus?',
  'Found a blue wallet at the library, DM me.',
  'Anyone taken ENT600 with Sir Azlan?',
  'Confession: I really miss my cat back home.',
  'Is the gym open on weekends?',
  'Looking for housemates for next sem',
  'Help! My laptop died during assignment.',
  'Best nasi lemak nearby?'
];

final _random = Random();

// ==========================================
// 3. MAIN SCRIPT
// ==========================================
Future<void> main() async {
  print("🌱 Initializing Seeder (GOD MODE)...");

  // Initialize Client with SERVICE ROLE KEY
  // This gives us access to 'client.auth.admin'
  final client = SupabaseClient(supabaseUrl, serviceRoleKey);

  String userId = '';
  const email = 'admin@uitm.edu.my';
  const password = 'StrongPassword123!';

  // 1. AUTHENTICATE (ADMIN WAY)
  try {
    print("🔑 Checking for Admin User...");
    
    // Check if user exists by trying to create it (Admin API is safer)
    final adminAuth = client.auth.admin;
    
    // LIST users to see if ours exists
    final listResponse = await adminAuth.listUsers();
    final existingUser = listResponse.map((u) => u).firstWhere(
      (u) => u.email == email, 
      orElse: () => User(id: '', appMetadata: {}, userMetadata: {}, aud: '', createdAt: '') // Dummy empty
    );

    if (existingUser.id.isNotEmpty) {
      userId = existingUser.id;
      print("✅ Found existing Admin ID: $userId");
    } else {
      print("⚠️ User not found. Force-creating VERIFIED user...");
      
      // ADMIN CREATE: Auto-confirms email!
      final response = await adminAuth.createUser(
        AdminUserAttributes(
          email: email,
          password: password,
          emailConfirm: true, // <--- THE MAGIC FIX
          userMetadata: {'full_name': 'System Admin'}
        )
      );
      
      if (response.user != null) {
        userId = response.user!.id;
        print("✅ User created and AUTO-VERIFIED: $userId");
      } else {
        print("❌ Admin Create Failed.");
        return;
      }
    }
  } catch (e) {
    print("❌ CRITICAL ERROR: $e");
    print("Make sure you are using the SERVICE_ROLE key, not the Anon key.");
    return;
  }

  // 2. SEED EVENTS
  print("\n📅 Generating Events...");
  List<Map<String, dynamic>> events = [];
  for (int i = 0; i < 20; i++) {
    final start = DateTime.now().add(Duration(days: i, hours: _random.nextInt(10)));
    events.add({
      'organizer_id': userId,
      'title': _eventTitles[_random.nextInt(_eventTitles.length)],
      'description': 'Seeded event via Service Role.',
      'location': 'UiTM Campus',
      'start_datetime': start.toUtc().toIso8601String(),
      'end_datetime': start.add(const Duration(hours: 3)).toUtc().toIso8601String(),
      'image_url': 'https://picsum.photos/seed/ev_$i/600/400',
      'is_public': true,
    });
  }
  await client.from('events').insert(events);

  // 3. SEED LISTINGS
  print("🛍️ Generating Listings...");
  List<Map<String, dynamic>> listings = [];
  for (int i = 0; i < 20; i++) {
    listings.add({
      'seller_id': userId,
      'title': _listingTitles[_random.nextInt(_listingTitles.length)],
      'description': 'Seeded item.',
      'price': (_random.nextInt(200) + 10).toDouble(),
      'category': 'General',
      'status': 'available',
      'is_sold': false,
      'image_url': 'https://picsum.photos/seed/list_$i/400/400',
    });
  }
  await client.from('listings').insert(listings);

  // 4. SEED POSTS
  print("💬 Generating Posts...");
  List<Map<String, dynamic>> posts = [];
  for (int i = 0; i < 20; i++) {
    posts.add({
      'user_id': userId,
      'title': _postTitles[_random.nextInt(_postTitles.length)],
      'body': 'Seeded discussion thread.',
      'is_anonymous': _random.nextBool(),
      'upvotes': _random.nextInt(50),
      'comment_count': 0,
    });
  }
  await client.from('posts').insert(posts);

  print("\n✨ DONE! Database populated using Service Role.");
}