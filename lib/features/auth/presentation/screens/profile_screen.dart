import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';
import '../../application/auth_provider.dart';
import '../../data/models/user_profile_model.dart';
import '../../../marketplace/presentation/widgets/marketplace_navigation.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _matricNumberController = TextEditingController();
  final _facultyController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _hasSeededProfile = false;
  bool _isSaving = false;
  bool _isSigningOut = false;

  String _initialsFor(UserProfile profile) {
    final source =
        (profile.fullName?.trim().isNotEmpty == true
                ? profile.fullName!.trim()
                : profile.email.trim())
            .split(RegExp(r'\s+|@'))
            .where((part) => part.isNotEmpty)
            .take(2)
            .map((part) => part[0].toUpperCase())
            .join();

    return source.isEmpty ? 'A' : source;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _matricNumberController.dispose();
    _facultyController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _seedProfile(UserProfile profile) {
    if (_hasSeededProfile) {
      return;
    }
    _fullNameController.text = profile.fullName ?? '';
    _matricNumberController.text = profile.matricNumber ?? '';
    _facultyController.text = profile.faculty ?? '';
    _phoneController.text = profile.phone ?? '';
    _hasSeededProfile = true;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      await ref
          .read(authControllerProvider)
          .updateProfile(
            fullName: _fullNameController.text.trim(),
            matricNumber: _matricNumberController.text.trim(),
            faculty: _facultyController.text.trim(),
            phone: _phoneController.text.trim(),
          );

      ref.invalidate(profileProvider);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully.'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save profile: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true);

    try {
      await ref.read(authControllerProvider).signOut();
      ref.invalidate(profileProvider);
      ref.invalidate(currentUserProvider);

      if (!mounted) {
        return;
      }

      context.go('/login');
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to sign out: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSigningOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      bottomNavigationBar: const MarketplaceBottomNavBar(
        currentTab: MarketplaceTab.profile,
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const Center(
              child: Text('No profile found for this account.'),
            );
          }

          _seedProfile(profile);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          height: 64,
                          width: 64,
                          decoration: const BoxDecoration(
                            color: AppColors.surfaceMuted,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _initialsFor(profile),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.displayName,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                profile.email,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'A complete profile makes your listings feel safer and more credible to buyers on campus.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Marketplace Identity',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Use your real details so buyers know who they are dealing with.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _fullNameController,
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Full name is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _matricNumberController,
                          decoration: const InputDecoration(
                            labelText: 'Matric Number',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _facultyController,
                          decoration: const InputDecoration(
                            labelText: 'Faculty',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _isSaving ? null : _saveProfile,
                          child: _isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('SAVE PROFILE'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Quick access',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: () => context.push('/my-listings'),
                          icon: const Icon(Icons.storefront_outlined),
                          label: const Text('MY LISTINGS'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => context.push('/orders'),
                          icon: const Icon(Icons.receipt_long_outlined),
                          label: const Text('ORDERS'),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _isSigningOut ? null : _signOut,
                          child: _isSigningOut
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('SIGN OUT'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Unable to load profile: $error'),
          ),
        ),
      ),
    );
  }
}
