import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mykerawang/screens/settings_screen.dart';
import 'edit_profile_screen.dart';
import 'item_detail_screen.dart';
import 'profile_cubit.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ProfileCubit(),
      child: const ProfileView(),
    );
  }
}

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProfileCubit, ProfileState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!), backgroundColor: Colors.red));
        }
      },
      builder: (context, state) {
        final profile = state.profile;
        
        if (state.isLoading && profile == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        if (profile == null) {
          return const Scaffold(body: Center(child: Text("Profile not found")));
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text("My Profile"),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings), // Gear Icon
                onPressed: () {
                  // 2. Navigate to the new SettingsScreen
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              )
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                CircleAvatar(
                  radius: 50,
                  backgroundImage: NetworkImage(profile['avatar_url'] ?? 'https://via.placeholder.com/150'),
                  backgroundColor: Colors.grey[200],
                ),
                const SizedBox(height: 16),
                Text(profile['full_name'] ?? 'User', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text(profile['role'] == 'student' ? 'UiTM Student' : 'Club Admin', style: const TextStyle(color: Colors.grey)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Text(profile['bio'] ?? 'No bio yet', textAlign: TextAlign.center),
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: () {
                    final cubit = context.read<ProfileCubit>();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BlocProvider.value(
                          value: cubit,
                          child: const EditProfileScreen(),
                        ),
                      ),
                    );
                  },
                  child: const Text("Edit Profile"),
                ),
                const Divider(height: 40),
                const Padding(padding: EdgeInsets.only(left: 16, bottom: 8), child: Align(alignment: Alignment.centerLeft, child: Text("My Listings", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)))),
                
                if (state.listings.isEmpty)
                  const Padding(padding: EdgeInsets.all(20), child: Text("No listings yet"))
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: state.listings.length,
                    itemBuilder: (c, i) {
                      final item = state.listings[i];
                      return ListTile(
                        leading: Image.network(item['image_url'] ?? '', width: 50, height: 50, fit: BoxFit.cover),
                        title: Text(item['title']),
                        subtitle: Text("RM ${item['price']}"),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item))),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}