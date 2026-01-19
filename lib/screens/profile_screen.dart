import 'package:flutter/material.dart';

import 'package:mykerawang/screens/notification_settings_screen.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'edit_profile_screen.dart';

import 'login_screen.dart';

import 'item_detail_screen.dart';



class ProfileScreen extends StatelessWidget {

  const ProfileScreen({super.key});



  @override

  Widget build(BuildContext context) {

    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) return const Center(child: Text("Not Logged In"));



    return Scaffold(

      appBar: AppBar(

        title: const Text("My Profile"),

        actions: [

          IconButton(

            icon: const Icon(Icons.settings),

            onPressed: () {

              Navigator.push(

                context,

                MaterialPageRoute(builder: (_) => const NotificationSettingsScreen())

              );

            },

          )

        ],

      ),

      body: FutureBuilder(

        future: Supabase.instance.client.from('profiles').select().eq('id', user.id).single(),

        builder: (context, snapshot) {

          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final profile = snapshot.data as Map;



          return SingleChildScrollView(

            child: Column(

              children: [

                const SizedBox(height: 20),

                CircleAvatar(radius: 50, backgroundImage: NetworkImage(profile['avatar_url'] ?? 'https://via.placeholder.com/150')),

                const SizedBox(height: 16),

                Text(profile['full_name'] ?? 'User', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),

                Text(profile['role'] == 'student' ? 'UiTM Student' : 'Club Admin', style: const TextStyle(color: Colors.grey)),

                // Bio Display

                Padding(

                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),

                  child: Text(profile['bio'] ?? 'No bio yet', textAlign: TextAlign.center),

                ),

               

                const SizedBox(height: 20),

                OutlinedButton(

                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),

                  child: const Text("Edit Profile"),

                ),

               

                const Divider(height: 40),

                const Padding(padding: EdgeInsets.only(left: 16, bottom: 8), child: Align(alignment: Alignment.centerLeft, child: Text("My Listings", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)))),

               

                // User Listings

                FutureBuilder(

                  future: Supabase.instance.client.from('listings').select().eq('seller_id', user.id),

                  builder: (ctx, snap) {

                    if (!snap.hasData) return const SizedBox();

                    final items = snap.data as List;

                    if (items.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No listings yet")));

                   

                    return ListView.builder(

                      shrinkWrap: true,

                      physics: const NeverScrollableScrollPhysics(),

                      itemCount: items.length,

                      itemBuilder: (c, i) => ListTile(

                        leading: Image.network(items[i]['image_url'] ?? '', width: 50, height: 50, fit: BoxFit.cover),

                        title: Text(items[i]['title']),

                        subtitle: Text("RM ${items[i]['price']}"),

                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),

                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ItemDetailScreen(item: items[i]))),

                      ),

                    );

                  },

                ),

              ],

            ),

          );

        },

      ),

    );

  }

}

