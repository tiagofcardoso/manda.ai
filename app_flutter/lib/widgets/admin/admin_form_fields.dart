import 'package:flutter/material.dart';

class AdminSectionLabel extends StatelessWidget {
  final String label;

  const AdminSectionLabel(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.grey,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class AdminBottomLineTextField extends StatelessWidget {
  final TextEditingController controller;
  final IconData icon;
  final String placeholder;
  final int maxLines;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final bool obscureText;

  const AdminBottomLineTextField({
    super.key,
    required this.controller,
    required this.icon,
    required this.placeholder,
    this.maxLines = 1,
    this.validator,
    this.onChanged,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: maxLines > 1
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.grey[400], size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: controller,
                maxLines: maxLines,
                validator: validator,
                onChanged: onChanged,
                obscureText: obscureText,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: placeholder,
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 2,
          color: Colors.grey[200],
        ),
      ],
    );
  }
}

class AdminFeatureToggle extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const AdminFeatureToggle({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFFD32F2F),
          ),
        ],
      ),
    );
  }
}

class AdminImageUpload extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onTap;
  final bool isUploading;
  final VoidCallback? onPasteUrl;
  final String label;
  final String subLabel;

  const AdminImageUpload({
    super.key,
    required this.controller,
    required this.onTap,
    this.isUploading = false,
    this.onPasteUrl,
    this.label = 'Clique para enviar imagem',
    this.subLabel = 'JPG, PNG ou WEBP',
  });

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEA1D2C);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: isUploading ? null : onTap,
          child: Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey[300]!,
                width: 2,
                style: BorderStyle.solid,
              ),
              image: controller.text.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(controller.text),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: controller.text.isEmpty
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isUploading)
                        const CircularProgressIndicator()
                      else ...[
                        Icon(
                          Icons.cloud_upload_rounded,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ],
                  )
                : null,
          ),
        ),
        if (onPasteUrl != null) ...[
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onPasteUrl,
            icon: const Icon(Icons.link_rounded, size: 18, color: primaryColor),
            label: const Text(
              'Colar URL da imagem',
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
