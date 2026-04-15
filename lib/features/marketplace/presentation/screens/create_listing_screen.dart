import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../app/theme/colors.dart';
import '../../application/marketplace_providers.dart';
import '../../data/repositories/marketplace_repository.dart';

class CreateListingScreen extends ConsumerStatefulWidget {
  const CreateListingScreen({super.key});

  @override
  ConsumerState<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends ConsumerState<CreateListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  int? _selectedCategoryId;
  String? _selectedCondition;
  
  final List<File> _images = [];
  bool _isSubmitting = false;

  final _picker = ImagePicker();

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _images.add(File(pickedFile.path));
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a category')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(marketplaceRepositoryProvider);
      await repo.createProduct(
        title: _titleController.text.trim(),
        price: double.parse(_priceController.text),
        description: _descriptionController.text.trim(),
        categoryId: _selectedCategoryId,
        condition: _selectedCondition,
        images: _images,
      );

      // Refresh feed
      ref.invalidate(homeFeedProvider);
      
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing created successfully!'), backgroundColor: AppColors.primary),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Listing'),
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
              // Image Picker
              SizedBox(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (int i = 0; i < _images.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Stack(
                          children: [
                            Container(
                              height: 100,
                              width: 100,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: FileImage(_images[i]),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 4,
                              top: 4,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _images.removeAt(i);
                                  });
                                },
                                child: const CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Colors.black54,
                                  child: Icon(Icons.close, size: 16, color: Colors.white),
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 100,
                        width: 100,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.add_a_photo, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Price', prefixText: '\$'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Required';
                  if (double.tryParse(val) == null) return 'Invalid number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              categoriesAsync.when(
                data: (categories) => DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Category'),
                  value: _selectedCategoryId,
                  items: categories.map((c) {
                    return DropdownMenuItem(value: c.id, child: Text(c.name));
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedCategoryId = val),
                  validator: (val) => val == null ? 'Required' : null,
                ),
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const Text('Error loading categories'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Condition'),
                value: _selectedCondition,
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
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('SUBMIT LISTING'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
