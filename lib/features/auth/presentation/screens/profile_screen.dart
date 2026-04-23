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
import '../../../marketplace/application/marketplace_providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isSigningOut = false;

  String _initialsFor(UserProfile profile) {
    final source = (profile.fullName?.trim().isNotEmpty == true
            ? profile.fullName!.trim()
            : profile.email.trim())
        .split(RegExp(r'\s+|@'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return source.isEmpty ? 'A' : source;
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

  void _showEditProfileSheet(UserProfile profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditProfileSheet(profile: profile),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final listingsAsync = ref.watch(myListingsProvider);
    final purchasesAsync = ref.watch(purchaseOrdersProvider);
    final salesAsync = ref.watch(salesOrdersProvider);

    final listingsCount = listingsAsync.asData?.value.length ?? 0;
    final ordersCount = (purchasesAsync.asData?.value.length ?? 0) +
        (salesAsync.asData?.value.length ?? 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
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

          final isIdentityComplete = profile.fullName?.isNotEmpty == true &&
              profile.matricNumber?.isNotEmpty == true &&
              profile.faculty?.isNotEmpty == true &&
              profile.phone?.isNotEmpty == true;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Dark Green Header Card ──
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryDark.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            height: 64,
                            width: 64,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _initialsFor(profile),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
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
                                  profile.fullName?.isNotEmpty == true
                                      ? profile.fullName!
                                      : profile.email,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (profile.fullName?.isNotEmpty == true)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      profile.email,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.8),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'Verified student',
                                        style: TextStyle(
                                          color: AppColors.primaryDark,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.check_circle,
                                        size: 14,
                                        color: AppColors.primaryDark,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _showEditProfileSheet(profile),
                            icon: const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatColumn(
                            label: 'Listings',
                            value: listingsCount.toString(),
                            sublabel: 'Active',
                          ),
                          Container(
                            height: 40,
                            width: 1,
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                          _StatColumn(
                            label: 'Orders',
                            value: ordersCount.toString(),
                            sublabel: 'Completed',
                          ),
                          Container(
                            height: 40,
                            width: 1,
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                          _StatColumn(
                            label: 'Rating',
                            value: '4.8',
                            sublabel: '(12 reviews)',
                            hasStar: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Complete Identity Alert ──
                if (!isIdentityComplete)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryDark.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.shield_outlined,
                            color: AppColors.primaryDark,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Complete your identity',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Add a few details to build trust with buyers.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          onPressed: () => _showEditProfileSheet(profile),
                          style: OutlinedButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Edit profile',
                              style: TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                  ),

                // ── Marketplace identity ──
                Text(
                  'Marketplace identity',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      _IdentityTile(
                        icon: Icons.person_outline,
                        label: 'Full name',
                        value: profile.fullName?.isNotEmpty == true
                            ? profile.fullName!
                            : 'Not set',
                        onTap: () => _showEditProfileSheet(profile),
                      ),
                      _Divider(),
                      _IdentityTile(
                        icon: Icons.badge_outlined,
                        label: 'Matric number',
                        value: profile.matricNumber?.isNotEmpty == true
                            ? profile.matricNumber!
                            : 'Not set',
                        onTap: () => _showEditProfileSheet(profile),
                      ),
                      _Divider(),
                      _IdentityTile(
                        icon: Icons.school_outlined,
                        label: 'Faculty',
                        value: profile.faculty?.isNotEmpty == true
                            ? profile.faculty!
                            : 'Not set',
                        onTap: () => _showEditProfileSheet(profile),
                      ),
                      _Divider(),
                      _IdentityTile(
                        icon: Icons.phone_outlined,
                        label: 'Phone number',
                        value: profile.phone?.isNotEmpty == true
                            ? profile.phone!
                            : 'Not set',
                        onTap: () => _showEditProfileSheet(profile),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Account ──
                Text(
                  'Account',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      _AccountTile(
                        icon: Icons.storefront_outlined,
                        label: 'My listings',
                        subtitle: 'Manage your active and sold items',
                        onTap: () => context.push('/my-listings'),
                      ),
                      _Divider(),
                      _AccountTile(
                        icon: Icons.receipt_long_outlined,
                        label: 'Orders',
                        subtitle: 'View your purchases and sales',
                        onTap: () => context.push('/orders'),
                      ),
                      _Divider(),
                      _AccountTile(
                        icon: Icons.favorite_border,
                        label: 'Saved items',
                        subtitle: 'Items you\'ve saved for later',
                        onTap: () => context.push('/favorites'),
                      ),
                      _Divider(),
                      _AccountTile(
                        icon: Icons.notifications_none_outlined,
                        label: 'Notifications',
                        subtitle: 'Manage your alerts and updates',
                        onTap: () {},
                      ),
                      _Divider(),
                      ListTile(
                        leading: const Icon(Icons.logout, color: AppColors.error),
                        title: const Text(
                          'Sign out',
                          style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: const Text(
                          'You\'ll be logged out of your account',
                          style: TextStyle(fontSize: 12),
                        ),
                        trailing: _isSigningOut
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.chevron_right_rounded),
                        onTap: _isSigningOut ? null : _signOut,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
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

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final String sublabel;
  final bool hasStar;

  const _StatColumn({
    required this.label,
    required this.value,
    required this.sublabel,
    this.hasStar = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasStar) ...[
              const Icon(Icons.star, color: Color(0xFFFFC107), size: 16),
              const SizedBox(width: 4),
            ],
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          sublabel,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _IdentityTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _IdentityTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary, size: 22),
      title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textSecondary),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _AccountTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _AccountTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primaryDark, size: 24),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
      onTap: onTap,
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.border);
  }
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  final UserProfile profile;

  const _EditProfileSheet({required this.profile});

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _matricNumberController;
  late final TextEditingController _facultyController;
  late final TextEditingController _phoneController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.profile.fullName);
    _matricNumberController = TextEditingController(text: widget.profile.matricNumber);
    _facultyController = TextEditingController(text: widget.profile.faculty);
    _phoneController = TextEditingController(text: widget.profile.phone);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _matricNumberController.dispose();
    _facultyController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await ref.read(authControllerProvider).updateProfile(
            fullName: _fullNameController.text.trim(),
            matricNumber: _matricNumberController.text.trim(),
            faculty: _facultyController.text.trim(),
            phone: _phoneController.text.trim(),
          );

      ref.invalidate(profileProvider);

      if (!mounted) return;
      AppSnackbars.showSuccess(context, 'Profile updated successfully.');
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      AppSnackbars.showError(context, error);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Edit Profile',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Full name is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _matricNumberController,
                  decoration: const InputDecoration(labelText: 'Matric Number'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _facultyController,
                  decoration: const InputDecoration(labelText: 'Faculty'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(AppStrings.saveProfile),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
