import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/ui/snackbars.dart';
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
    if (_hasSeededProfile) return;
    _fullNameController.text = profile.fullName ?? '';
    _matricNumberController.text = profile.matricNumber ?? '';
    _facultyController.text = profile.faculty ?? '';
    _phoneController.text = profile.phone ?? '';
    _hasSeededProfile = true;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

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

      if (!mounted) return;
      AppSnackbars.showSuccess(context, 'Profile updated successfully.');
    } catch (error) {
      if (!mounted) return;
      AppSnackbars.showError(context, error);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true);

    try {
      await ref.read(authControllerProvider).signOut();
      ref.invalidate(profileProvider);
      ref.invalidate(currentUserProvider);

      if (!mounted) return;
      context.go('/login');
    } catch (error) {
      if (!mounted) return;
      AppSnackbars.showError(context, error);
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.profileTitle)),
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
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Avatar header ──
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Container(
                          height: 72,
                          width: 72,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _initialsFor(profile),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          profile.displayName,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile.email,
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          AppStrings.profileBio,
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Identity form ──
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
                          AppStrings.marketplaceIdentity,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppStrings.identityHint,
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
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _matricNumberController,
                          decoration: const InputDecoration(
                            labelText: 'Matric Number',
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _facultyController,
                          decoration: const InputDecoration(
                            labelText: 'Faculty',
                          ),
                        ),
                        const SizedBox(height: 14),
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
                              : const Text(AppStrings.saveProfile),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Quick access ──
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
                        _QuickAccessTile(
                          icon: Icons.storefront_outlined,
                          label: 'My Listings',
                          onTap: () => context.push('/my-listings'),
                        ),
                        const SizedBox(height: 8),
                        _QuickAccessTile(
                          icon: Icons.receipt_long_outlined,
                          label: 'Orders',
                          onTap: () => context.push('/orders'),
                        ),
                        const SizedBox(height: 8),
                        _QuickAccessTile(
                          icon: Icons.favorite_border,
                          label: 'Saved Items',
                          onTap: () => context.push('/favorites'),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: _isSigningOut ? null : _signOut,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.error,
                          ),
                          child: _isSigningOut
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(AppStrings.signOutAction),
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
            child: Text(ErrorMapper.toAppException(error).message),
          ),
        ),
      ),
    );
  }
}

class _QuickAccessTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAccessTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
