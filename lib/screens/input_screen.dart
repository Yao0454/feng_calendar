import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class InputScreen extends StatefulWidget {
  const InputScreen({super.key});

  @override
  State<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends State<InputScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _textController = TextEditingController();
  File? _selectedImage;
  File? _selectedFile;
  String? _selectedFileType;
  String? _selectedFileName;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final xfile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (xfile != null) setState(() => _selectedImage = File(xfile.path));
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'md'],
    );
    if (result != null && result.files.single.path != null) {
      final file = result.files.single;
      final ext = file.path!.split('.').last.toLowerCase();
      setState(() {
        _selectedFile = File(file.path!);
        _selectedFileType = ext == 'md' ? 'txt' : ext;
        _selectedFileName = file.name;
      });
    }
  }

  Future<void> _extract() async {
    final provider = context.read<AppProvider>();
    final tab = _tabController.index;
    bool success = false;

    if (tab == 0) {
      final text = _textController.text.trim();
      if (text.isEmpty) return;
      success = await provider.extractFromText(text);
      if (success) _textController.clear();
    } else if (tab == 1) {
      if (_selectedImage == null) return;
      success = await provider.extractFromImage(_selectedImage!);
      if (success) setState(() => _selectedImage = null);
    } else if (tab == 2) {
      if (_selectedFile == null) return;
      success = await provider.extractFromFile(
          _selectedFile!, _selectedFileType ?? 'txt');
      if (success) {
        setState(() {
          _selectedFile = null;
          _selectedFileType = null;
          _selectedFileName = null;
        });
      }
    }

    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(provider.errorMessage ?? '提取失败，请检查服务器连接'),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLoading =
        context.watch<AppProvider>().status == ExtractionStatus.loading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('提取日程'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                onTap: (_) => setState(() {}),
                indicator: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: cs.shadow.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.all(3),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(height: 36, child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.text_fields_rounded, size: 16),
                      SizedBox(width: 5),
                      Text('文字'),
                    ],
                  )),
                  Tab(height: 36, child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_rounded, size: 16),
                      SizedBox(width: 5),
                      Text('图片'),
                    ],
                  )),
                  Tab(height: 36, child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.attach_file_rounded, size: 16),
                      SizedBox(width: 5),
                      Text('文件'),
                    ],
                  )),
                ],
              ),
            ),
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildTextTab(cs),
            _buildImageTab(cs),
            _buildFileTab(cs),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isLoading ? null : _extract,
        elevation: 2,
        icon: isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: cs.onPrimary),
              )
            : const Icon(Icons.auto_awesome_rounded),
        label: Text(
          isLoading ? '提取中...' : '开始提取',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildTextTab(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: TextField(
        controller: _textController,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(fontSize: 15, height: 1.6),
        decoration: InputDecoration(
          hintText:
              '粘贴日程文字内容...\n\n例如：\n明天下午 3 点在 11-100 开组会\nNext Monday 9am team meeting',
          hintStyle: TextStyle(color: cs.outline, height: 1.6),
          alignLabelWithHint: true,
          fillColor: cs.surfaceContainerLowest,
        ),
      ),
    );
  }

  Widget _buildImageTab(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_selectedImage != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  _selectedImage!,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('重新选择'),
              ),
            ] else ...[
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.image_rounded, size: 40, color: cs.primary),
              ),
              const SizedBox(height: 20),
              Text('选择一张截图或照片',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: cs.onSurface)),
              const SizedBox(height: 6),
              Text('支持 JPG / PNG',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.outline)),
              const SizedBox(height: 20),
              FilledButton.tonal(
                onPressed: _pickImage,
                child: const Text('从相册选择'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFileTab(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_selectedFile != null) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.description_rounded,
                    size: 48, color: cs.primary),
              ),
              const SizedBox(height: 16),
              Text(
                _selectedFileName ?? '',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('重新选择'),
              ),
            ] else ...[
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.upload_file_rounded,
                    size: 40, color: cs.primary),
              ),
              const SizedBox(height: 20),
              Text('选择一个文件',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: cs.onSurface)),
              const SizedBox(height: 6),
              Text('支持 PDF / TXT / MD',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.outline)),
              const SizedBox(height: 20),
              FilledButton.tonal(
                onPressed: _pickFile,
                child: const Text('选择文件'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
