import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../app/theme/colors.dart';
import '../../application/marketplace_providers.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/marketplace_repository.dart';

class CreateListingScreen extends ConsumerStatefulWidget {
  final String? productId;

  const CreateListingScreen({super.key, this.productId});

  @override
  ConsumerState<CreateListingScreen> createState() =>
      _CreateListingScreenState();
}

class _CreateListingScreenState extends ConsumerState<CreateListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();

  int? _selectedCategoryId;
  String? _selectedCondition;

  final List<File> _newImages = [];
  List<ProductImage> _existingImages = [];
  bool _isSubmitting = false;
  bool _hasSeededForm = false;

  final _picker = ImagePicker();

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _newImages.add(File(pickedFile.path));
      });
    }
  }

  void _seedForm(Product product) {
    if (_hasSeededForm) {
      return;
    }

    _titleController.text = product.title;
    _priceController.text = product.price.toStringAsFixed(2);
    _descriptionController.text = product.description ?? '';
    _selectedCategoryId = product.categoryId;
    _selectedCondition = product.condition;
    _existingImages = product.images;
    _hasSeededForm = true;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a category')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(marketplaceRepositoryProvider);
      final title = _titleController.text.trim();
      final description = _descriptionController.text.trim();
      final normalizedDescription = description.isEmpty ? null : description;
      final price = double.parse(_priceController.text);

      if (widget.productId == null) {
        await repo.createProduct(
          title: title,
          price: price,
          description: normalizedDescription,
          categoryId: _selectedCategoryId,
          condition: _selectedCondition,
          images: _newImages,
        );
      } else {
        await repo.updateProduct(
          productId: widget.productId!,
          title: title,
          price: price,
          description: normalizedDescription,
          categoryId: _selectedCategoryId,
          condition: _selectedCondition,
          images: _newImages,
        );
        ref.invalidate(productDetailsProvider(widget.productId!));
      }

      // Refresh feed
      ref.invalidate(homeFeedProvider);
      ref.invalidate(myListingsProvider);

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.productId == null
                  ? 'Listing created successfully!'
                  : 'Listing updated successfully!',
            ),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final productAsync = widget.productId == null
        ? null
        : ref.watch(productDetailsProvider(widget.productId!));

    if (productAsync != null && productAsync.hasValue && !_hasSeededForm) {
      _seedForm(productAsync.requireValue);
    }

    if (productAsync != null && productAsync.isLoading && !_hasSeededForm) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (productAsync != null && productAsync.hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Listing')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Unable to load listing: ${productAsync.error}'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.productId == null ? 'Create Listing' : 'Edit Listing',
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.productId == null
                          ? 'Create a polished listing'
                          : 'Update your listing details',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Clear photos, a strong title, and the right category help your item feel trustworthy at a glance.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 108,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final image in _existingImages)
                            Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: SizedBox(
                                  height: 108,
                                  width: 108,
                                  child: Image.network(
                                    image.imageUrl,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          for (int i = 0; i < _newImages.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: Stack(
                                children: [
                                  Container(
                                    height: 108,
                                    width: 108,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      image: DecorationImage(
                                        image: FileImage(_newImages[i]),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 6,
                                    top: 6,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _newImages.removeAt(i);
                                        });
                                      },
                                      child: const CircleAvatar(
                                        radius: 12,
                                        backgroundColor: Colors.black54,
                                        child: Icon(
                                          Icons.close,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              height: 108,
                              width: 108,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceMuted,
                                border: Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_a_photo_outlined,
                                    color: AppColors.textSecondary,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Add Photo',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Price',
                  prefixText: '₦ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Required';
                  if (double.tryParse(val) == null) return 'Invalid number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              categoriesAsync.when(
                data: (categories) {
                  if (categories.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.warningSoft,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Text(
                        'No categories are available yet. Apply the latest Supabase schema so listing categories can be selected.',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }

                  return DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'Category'),
                    initialValue: _selectedCategoryId,
                    items: categories.map((category) {
                      return DropdownMenuItem(
                        value: category.id,
                        child: Text(category.displayName),
                      );
                    }).toList(),
                    onChanged: (val) =>
                        setState(() => _selectedCategoryId = val),
                    validator: (val) => val == null ? 'Required' : null,
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: CircularProgressIndicator(),
                ),
                error: (_, _) => const Text('Error loading categories'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Condition'),
                initialValue: _selectedCondition,
                items: ['New', 'Like New', 'Good', 'Fair', 'Poor'].map((c) {
                  return DropdownMenuItem(value: c, child: Text(c));
                }).toList(),
                onChanged: (val) => setState(() => _selectedCondition = val),
                validator: (val) => val == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 4,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        widget.productId == null
                            ? 'SUBMIT LISTING'
                            : 'SAVE CHANGES',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
